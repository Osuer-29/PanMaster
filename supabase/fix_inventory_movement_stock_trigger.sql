-- PanMaster: compatibilidad del trigger de entradas/salidas con el enum actual.
-- Ejecutar en Supabase SQL Editor con una cuenta propietaria.
-- No borra productos ni movimientos. Reemplaza únicamente el trigger conocido.

BEGIN;

CREATE OR REPLACE FUNCTION public.apply_inventory_movement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text := NEW.movement_type::text;
  v_changed integer;
BEGIN
  -- Entradas: suma al stock.
  IF v_type IN ('manual_in', 'purchase_receipt', 'return', 'production', 'opening')
     OR NEW.direction = 'in' THEN
    UPDATE public.products
       SET stock = COALESCE(stock, 0) + NEW.quantity,
           updated_at = now()
     WHERE id = NEW.product_id;
    GET DIAGNOSTICS v_changed = ROW_COUNT;
    IF v_changed = 0 THEN
      RAISE EXCEPTION 'No existe el producto %', NEW.product_id;
    END IF;

  -- Salidas: valida que haya existencia suficiente y resta.
  ELSIF v_type IN ('manual_out', 'recipe_consumption', 'sale', 'waste', 'expired', 'withdrawal')
        OR NEW.direction = 'out' THEN
    UPDATE public.products
       SET stock = COALESCE(stock, 0) - NEW.quantity,
           updated_at = now()
     WHERE id = NEW.product_id
       AND COALESCE(stock, 0) >= NEW.quantity;
    GET DIAGNOSTICS v_changed = ROW_COUNT;
    IF v_changed = 0 THEN
      RAISE EXCEPTION 'Existencia insuficiente para registrar la salida del producto %', NEW.product_id;
    END IF;

  -- Ajuste: quantity_after es la existencia final indicada en el movimiento.
  ELSIF v_type = 'count_adjustment' OR NEW.direction IN ('adjustment', 'set') THEN
    UPDATE public.products
       SET stock = GREATEST(COALESCE(NEW.quantity_after, NEW.quantity), 0),
           updated_at = now()
     WHERE id = NEW.product_id;
    GET DIAGNOSTICS v_changed = ROW_COUNT;
    IF v_changed = 0 THEN
      RAISE EXCEPTION 'No existe el producto %', NEW.product_id;
    END IF;

  -- Transferencias deben indicar dirección para que el stock sea inequívoco.
  ELSIF v_type = 'transfer' THEN
    RAISE EXCEPTION 'El movimiento transfer requiere direction = in u out en este formulario';
  ELSE
    RAISE EXCEPTION 'Tipo de movimiento no soportado: %', v_type;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventory_movement_apply_stock ON public.inventory_movements;
CREATE TRIGGER inventory_movement_apply_stock
AFTER INSERT ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.apply_inventory_movement();

COMMIT;

-- Verificación: debe aparecer inventory_movement_apply_stock y apply_inventory_movement.
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'inventory_movements'
  AND trigger_name = 'inventory_movement_apply_stock';
