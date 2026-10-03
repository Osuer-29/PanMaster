-- Migración para inventario por módulos y cantidades de preparación.
-- No elimina ni reinicia datos existentes. Ejecutar en Supabase SQL Editor.

ALTER TABLE public.inventory_modules
  ADD COLUMN IF NOT EXISTS name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS module_id uuid,
  ADD COLUMN IF NOT EXISTS production_quantity numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unit text NOT NULL DEFAULT 'unidad',
  ADD COLUMN IF NOT EXISTS stock numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS min_stock numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;

ALTER TABLE public.inventory_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- Lectura para que los empleados vean los módulos activos y la cantidad que deben preparar.
DROP POLICY IF EXISTS inventory_modules_read_active ON public.inventory_modules;
CREATE POLICY inventory_modules_read_active
ON public.inventory_modules FOR SELECT TO authenticated
USING (active = true AND public.current_app_role() IN ('superadmin','employee'));

DROP POLICY IF EXISTS products_read_for_work ON public.products;
CREATE POLICY products_read_for_work
ON public.products FOR SELECT TO authenticated
USING (
  public.current_app_role() IN ('superadmin','employee')
  AND EXISTS (
    SELECT 1 FROM public.inventory_modules m
    WHERE m.id = products.module_id AND m.active = true
  )
);

-- Los empleados pueden registrar salidas, pero no crear, editar ni borrar productos.
-- El trigger apply_inventory_movement descuenta la existencia y bloquea cantidades insuficientes.
DROP POLICY IF EXISTS movements_employee_exit ON public.inventory_movements;
CREATE POLICY movements_employee_exit
ON public.inventory_movements FOR INSERT TO authenticated
WITH CHECK (
  public.current_app_role() = 'employee'
  AND movement_type = 'salida'
  AND created_by = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.products p
    JOIN public.inventory_modules m ON m.id = p.module_id
    WHERE p.id = inventory_movements.product_id AND p.active = true AND m.active = true
  )
);

CREATE INDEX IF NOT EXISTS products_module_id_idx ON public.products(module_id);
