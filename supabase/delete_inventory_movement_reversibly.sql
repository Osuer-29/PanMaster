-- PanMaster: eliminar una entrada/salida manual del historial de forma segura.
-- La función revierte el efecto sobre products.stock y elimina el movimiento
-- dentro de la misma transacción. Solo permite al superadministrador.
-- Solo admite movement_type manual_in/manual_out para evitar borrar otros
-- movimientos cuya reversión automática podría ser ambigua.

CREATE OR REPLACE FUNCTION public.delete_inventory_movement_reversibly(
  p_movement_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_movement public.inventory_movements%ROWTYPE;
  v_role text;
  v_stock numeric;
BEGIN
  SELECT p.role::text
    INTO v_role
  FROM public.profiles AS p
  WHERE p.id = auth.uid()
    AND p.active = true
  LIMIT 1;

  IF COALESCE(v_role, '') <> 'superadmin' THEN
    RAISE EXCEPTION 'Solo el superadministrador puede eliminar movimientos';
  END IF;

  SELECT *
    INTO v_movement
  FROM public.inventory_movements
  WHERE id = p_movement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontró el movimiento solicitado';
  END IF;

  IF v_movement.movement_type::text NOT IN ('manual_in', 'manual_out') THEN
    RAISE EXCEPTION 'Solo se pueden eliminar entradas/salidas manuales. Para otros movimientos registra un ajuste de inventario.';
  END IF;

  SELECT COALESCE(pr.stock, 0)
    INTO v_stock
  FROM public.products AS pr
  WHERE pr.id = v_movement.product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontró el producto asociado al movimiento';
  END IF;

  IF v_movement.movement_type::text = 'manual_out' OR v_movement.direction = 'out' THEN
    -- Revertir una salida: devolver la cantidad al stock.
    UPDATE public.products
       SET stock = COALESCE(stock, 0) + v_movement.quantity,
           updated_at = now()
     WHERE id = v_movement.product_id;
  ELSIF v_movement.movement_type::text = 'manual_in' OR v_movement.direction = 'in' THEN
    -- Revertir una entrada: solo si queda suficiente stock para descontarla.
    IF v_stock < v_movement.quantity THEN
      RAISE EXCEPTION 'No se puede eliminar esta entrada porque parte de esas existencias ya se consumieron. Registra un ajuste de inventario.';
    END IF;

    UPDATE public.products
       SET stock = COALESCE(stock, 0) - v_movement.quantity,
           updated_at = now()
     WHERE id = v_movement.product_id;
  ELSE
    RAISE EXCEPTION 'El movimiento no tiene una dirección válida para revertir el stock';
  END IF;

  DELETE FROM public.inventory_movements
  WHERE id = p_movement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_inventory_movement_reversibly(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_inventory_movement_reversibly(uuid) TO authenticated;

-- Verificación: debe devolver la firma de la función.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'delete_inventory_movement_reversibly';
