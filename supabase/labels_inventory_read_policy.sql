-- PANMASTER: lectura limitada para que usuarios activos puedan
-- elegir módulos y productos existentes al imprimir etiquetas.
-- No concede permisos de INSERT, UPDATE ni DELETE.
-- Ejecutar en Supabase SQL Editor solo si la pantalla de etiquetas
-- muestra un error de permisos al cargar módulos/productos.

BEGIN;

ALTER TABLE public.inventory_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS panmaster_active_users_read_modules_for_labels
  ON public.inventory_modules;
CREATE POLICY panmaster_active_users_read_modules_for_labels
  ON public.inventory_modules
  FOR SELECT
  TO authenticated
  USING (
    active = true
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.active = true
    )
  );

DROP POLICY IF EXISTS panmaster_active_users_read_products_for_labels
  ON public.products;
CREATE POLICY panmaster_active_users_read_products_for_labels
  ON public.products
  FOR SELECT
  TO authenticated
  USING (
    active = true
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.active = true
    )
  );

COMMIT;
