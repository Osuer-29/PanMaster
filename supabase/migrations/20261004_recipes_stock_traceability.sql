-- Ejecutar SOLO esta migración en Supabase SQL Editor. No recalcula históricos.
BEGIN;

-- Compatibilidad con el esquema legado, sin cambiar las unidades existentes.
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name_es text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit_id uuid;

ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS ingredients_text text NOT NULL DEFAULT '';
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS instructions text;
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.panmaster_require_admin() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND active AND role::text = 'superadmin'
  ) THEN RAISE EXCEPTION 'Solo un superadministrador activo puede guardar o anular registros'; END IF;
  RETURN auth.uid();
END $$;

CREATE OR REPLACE FUNCTION public.save_panmaster_recipe(
  p_id uuid, p_name text, p_ingredients text, p_notes text, p_create boolean
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := public.panmaster_require_admin();
BEGIN
  IF p_id IS NULL OR COALESCE(btrim(p_name), '') = '' OR COALESCE(btrim(p_ingredients), '') = '' THEN
    RAISE EXCEPTION 'El nombre y los ingredientes de la receta son obligatorios';
  END IF;
  IF p_create THEN
    INSERT INTO public.recipes(id, name, ingredients_text, notes, instructions, active, created_by)
    VALUES (p_id, btrim(p_name), btrim(p_ingredients), NULLIF(btrim(p_notes), ''), NULLIF(btrim(p_notes), ''), true, v_actor)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  UPDATE public.recipes SET name = btrim(p_name), ingredients_text = btrim(p_ingredients),
    notes = NULLIF(btrim(p_notes), ''), instructions = NULLIF(btrim(p_notes), ''), updated_at = now()
  WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'La receta ya no existe. Actualiza la lista'; END IF;
  RETURN p_id;
END $$;

ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS direction text;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS quantity_before numeric;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS quantity_after numeric;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS unit_id uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS quantity_base numeric;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS batch_id uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS reversal_of uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS cancelled_by uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS product_name_snapshot text;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS module_name_snapshot text;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS module_id_snapshot uuid;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS unit_snapshot text;
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS actor_name_snapshot text;
CREATE UNIQUE INDEX IF NOT EXISTS panmaster_one_reversal ON public.inventory_movements(reversal_of) WHERE reversal_of IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.panmaster_inventory_batches (
  id uuid PRIMARY KEY, actor_id uuid NOT NULL, payload jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.panmaster_inventory_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movement_id uuid NOT NULL, action text NOT NULL, actor_id uuid,
  recorded_at timestamptz NOT NULL DEFAULT now(), old_record jsonb, new_record jsonb
);
ALTER TABLE public.panmaster_inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.panmaster_inventory_audit ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS panmaster_admin_read ON public.panmaster_inventory_batches;
CREATE POLICY panmaster_admin_read ON public.panmaster_inventory_batches FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND active AND role::text = 'superadmin'));
DROP POLICY IF EXISTS panmaster_admin_read ON public.panmaster_inventory_audit;
CREATE POLICY panmaster_admin_read ON public.panmaster_inventory_audit FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND active AND role::text = 'superadmin'));
GRANT SELECT ON public.panmaster_inventory_batches, public.panmaster_inventory_audit TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.panmaster_inventory_batches, public.panmaster_inventory_audit FROM authenticated, anon;

-- El bloqueo por producto hace que dos salidas concurrentes no lean el mismo saldo.
-- El stock y el movimiento se confirman o se revierten en una misma transacción.
CREATE OR REPLACE FUNCTION public.apply_inventory_movement() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_product public.products%ROWTYPE; v_type text := NEW.movement_type::text; v_after numeric;
BEGIN
  IF NEW.quantity IS NULL OR NEW.quantity < 0 OR NEW.quantity::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Cantidad inválida';
  END IF;
  SELECT * INTO v_product FROM public.products WHERE id = NEW.product_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El producto no existe'; END IF;
  IF v_type IN ('entrada','manual_in','purchase_receipt','return','production','opening') THEN NEW.direction := 'in';
  ELSIF v_type IN ('salida','manual_out','recipe_consumption','sale','waste','expired','withdrawal') THEN NEW.direction := 'out';
  ELSIF v_type IN ('ajuste','count_adjustment') THEN NEW.direction := 'adjustment';
  ELSIF v_type = 'transfer' AND NEW.direction IN ('in','out') THEN NULL;
  ELSE RAISE EXCEPTION 'Tipo de movimiento no soportado: %', v_type; END IF;
  IF NEW.direction <> 'adjustment' AND NEW.quantity = 0 THEN RAISE EXCEPTION 'La cantidad debe ser mayor que cero'; END IF;
  NEW.quantity_before := COALESCE(v_product.stock, 0);
  v_after := CASE NEW.direction WHEN 'in' THEN NEW.quantity_before + NEW.quantity
    WHEN 'out' THEN NEW.quantity_before - NEW.quantity ELSE NEW.quantity END;
  IF v_after < 0 THEN RAISE EXCEPTION 'Existencia insuficiente: disponible %, salida %', NEW.quantity_before, NEW.quantity; END IF;
  NEW.quantity_after := v_after;
  NEW.quantity_base := NEW.quantity;
  NEW.unit_id := COALESCE(NEW.unit_id, v_product.unit_id);
  NEW.user_id := COALESCE(auth.uid(), NEW.user_id, NEW.created_by);
  NEW.created_by := COALESCE(auth.uid(), NEW.created_by, NEW.user_id);
  NEW.product_name_snapshot := COALESCE(v_product.name_es, v_product.name);
  NEW.unit_snapshot := v_product.unit;
  NEW.module_id_snapshot := v_product.module_id;
  SELECT name INTO NEW.module_name_snapshot FROM public.inventory_modules WHERE id = v_product.module_id;
  SELECT COALESCE(full_name, email) INTO NEW.actor_name_snapshot FROM public.profiles WHERE id = NEW.created_by;
  UPDATE public.products SET stock = v_after, updated_at = now() WHERE id = NEW.product_id;
  RETURN NEW;
END $$;
-- Evita duplicar el trigger conocido aunque se haya instalado con otro nombre.
DO $$ DECLARE t record; BEGIN
  FOR t IN SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.inventory_movements'::regclass
    AND NOT tgisinternal AND tgfoid = 'public.apply_inventory_movement()'::regprocedure
  LOOP EXECUTE format('DROP TRIGGER %I ON public.inventory_movements', t.tgname); END LOOP;
END $$;
CREATE TRIGGER inventory_movement_apply_stock BEFORE INSERT ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.apply_inventory_movement();

CREATE OR REPLACE FUNCTION public.panmaster_audit_movement() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO public.panmaster_inventory_audit(movement_id, action, actor_id, old_record, new_record)
  VALUES (COALESCE(NEW.id, OLD.id), TG_OP, auth.uid(),
    CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END);
  RETURN COALESCE(NEW, OLD);
END $$;
DROP TRIGGER IF EXISTS panmaster_movement_audit ON public.inventory_movements;
CREATE TRIGGER panmaster_movement_audit AFTER INSERT OR UPDATE OR DELETE ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.panmaster_audit_movement();

-- Conserva el enum o CHECK existente: escoge el vocabulario que acepta la tabla.
CREATE OR REPLACE FUNCTION public.panmaster_movement_type(p_direction text) RETURNS text
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE v_modern text; v_legacy text; v_type oid; v_constraints text;
BEGIN
  v_modern := CASE p_direction WHEN 'in' THEN 'manual_in' WHEN 'out' THEN 'manual_out' ELSE 'count_adjustment' END;
  v_legacy := CASE p_direction WHEN 'in' THEN 'entrada' WHEN 'out' THEN 'salida' ELSE 'ajuste' END;
  SELECT atttypid INTO v_type FROM pg_attribute WHERE attrelid = 'public.inventory_movements'::regclass AND attname = 'movement_type';
  IF EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = v_type) THEN
    IF EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = v_type AND enumlabel = v_modern) THEN RETURN v_modern; END IF;
    IF EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = v_type AND enumlabel = v_legacy) THEN RETURN v_legacy; END IF;
    RAISE EXCEPTION 'El enum no admite el movimiento %', p_direction;
  END IF;
  SELECT string_agg(pg_get_constraintdef(oid), ' ') INTO v_constraints FROM pg_constraint
  WHERE conrelid = 'public.inventory_movements'::regclass AND contype = 'c';
  IF position(quote_literal(v_legacy) IN COALESCE(v_constraints,'')) > 0
    AND position(quote_literal(v_modern) IN COALESCE(v_constraints,'')) = 0 THEN RETURN v_legacy; END IF;
  RETURN v_modern;
END $$;

CREATE OR REPLACE FUNCTION public.record_panmaster_inventory_batch(p_batch_id uuid, p_items jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := public.panmaster_require_admin(); v_existing public.panmaster_inventory_batches%ROWTYPE;
  v_item jsonb; v_row public.inventory_movements%ROWTYPE; v_type text;
BEGIN
  IF p_batch_id IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'El lote debe contener movimientos';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_batch_id::text, 0));
  SELECT * INTO v_existing FROM public.panmaster_inventory_batches WHERE id = p_batch_id;
  IF FOUND THEN
    IF v_existing.actor_id <> v_actor OR v_existing.payload <> p_items THEN RAISE EXCEPTION 'El identificador ya pertenece a otro lote'; END IF;
  ELSE
    INSERT INTO public.panmaster_inventory_batches(id, actor_id, payload) VALUES(p_batch_id, v_actor, p_items);
    -- Orden estable para evitar deadlocks de lotes sobre los mismos productos.
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) ORDER BY value->>'product_id', value->>'direction' LOOP
      IF COALESCE(v_item->>'direction','') NOT IN ('in','out','adjustment') THEN RAISE EXCEPTION 'Dirección inválida'; END IF;
      IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = (v_item->>'product_id')::uuid AND active) THEN RAISE EXCEPTION 'Producto inexistente o inactivo'; END IF;
      v_type := public.panmaster_movement_type(v_item->>'direction');
      v_row := jsonb_populate_record(NULL::public.inventory_movements, jsonb_build_object('movement_type', v_type));
      INSERT INTO public.inventory_movements(product_id, movement_type, direction, quantity, reason, notes, user_id, created_by, batch_id)
      VALUES((v_item->>'product_id')::uuid, v_row.movement_type, v_item->>'direction',
        (v_item->>'quantity')::numeric, NULLIF(v_item->>'reason',''), NULLIF(v_item->>'notes',''), v_actor, v_actor, p_batch_id);
    END LOOP;
  END IF;
  RETURN jsonb_build_object('batch_id', p_batch_id, 'movements', COALESCE((
    SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at, m.id) FROM public.inventory_movements m WHERE batch_id = p_batch_id
  ), '[]'::jsonb));
END $$;

-- Mantiene la firma anterior, pero anula conservando el registro original.
CREATE OR REPLACE FUNCTION public.delete_inventory_movement_reversibly(p_movement_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := public.panmaster_require_admin(); v_old public.inventory_movements%ROWTYPE;
  v_row public.inventory_movements%ROWTYPE; v_direction text;
BEGIN
  SELECT * INTO v_old FROM public.inventory_movements WHERE id = p_movement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El movimiento no existe'; END IF;
  IF v_old.cancelled_at IS NOT NULL THEN RETURN; END IF;
  IF v_old.reversal_of IS NOT NULL OR v_old.movement_type::text NOT IN ('manual_in','manual_out','entrada','salida') THEN
    RAISE EXCEPTION 'Solo se pueden anular entradas y salidas manuales originales';
  END IF;
  v_direction := CASE WHEN v_old.movement_type::text IN ('manual_out','salida') THEN 'in' ELSE 'out' END;
  v_row := jsonb_populate_record(NULL::public.inventory_movements,
    jsonb_build_object('movement_type', public.panmaster_movement_type(v_direction)));
  INSERT INTO public.inventory_movements(product_id, movement_type, direction, quantity, reason, notes, user_id, created_by, reversal_of)
  VALUES(v_old.product_id, v_row.movement_type, v_direction, v_old.quantity, 'Anulación de movimiento',
    'Reversión del registro ' || v_old.id::text, v_actor, v_actor, v_old.id);
  UPDATE public.inventory_movements SET cancelled_at = now(), cancelled_by = v_actor WHERE id = v_old.id;
END $$;

REVOKE ALL ON FUNCTION public.panmaster_require_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_panmaster_recipe(uuid,text,text,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_panmaster_inventory_batch(uuid,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_inventory_movement_reversibly(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_panmaster_recipe(uuid,text,text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_panmaster_inventory_batch(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_inventory_movement_reversibly(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
