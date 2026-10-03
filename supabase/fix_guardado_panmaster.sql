-- ============================================================
-- PANMASTER: CORRECCIÓN DE PERMISOS PARA GUARDAR REGISTROS
-- Ejecutar en Supabase SQL Editor con la cuenta propietaria.
-- No borra tablas ni registros. No desactiva RLS.
-- Otorga permisos de datos únicamente a sesiones cuyo perfil
-- activo tenga role = 'superadmin'.
-- ============================================================

BEGIN;

-- Función de lectura del rol de la sesión autenticada.
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.role::text
  FROM public.profiles AS p
  WHERE p.id = auth.uid()
    AND p.active = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_app_role() = 'superadmin', false);
$$;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_app_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;

-- Activar RLS y crear una política administrativa aditiva.
-- No elimina las políticas existentes para otros roles.
DO $$
DECLARE
  t text;
  v_tables text[] := ARRAY[
    'profiles',
    'inventory_modules',
    'products',
    'inventory_movements',
    'suppliers',
    'recipes',
    'employees',
    'employee_shifts',
    'final_products',
    'production_records',
    'product_categories',
    'units_of_measure',
    'inventory_locations'
  ];
BEGIN
  FOREACH t IN ARRAY v_tables LOOP
    IF to_regclass(format('public.%I', t)) IS NOT NULL THEN
      EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', t
      );
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format(
        'DROP POLICY IF EXISTS panmaster_superadmin_all ON public.%I', t
      );
      EXECUTE format(
        'CREATE POLICY panmaster_superadmin_all ON public.%I '
        'FOR ALL TO authenticated '
        'USING (public.is_superadmin()) '
        'WITH CHECK (public.is_superadmin())', t
      );
    END IF;
  END LOOP;
END $$;

-- Activar el perfil de la cuenta administrativa ya existente.
-- No crea usuarios ni contraseñas; el usuario debe existir en Auth.
UPDATE public.profiles AS p
SET role = 'superadmin',
    active = true,
    email = u.email,
    full_name = COALESCE(NULLIF(p.full_name, ''), 'Superadministrador')
FROM auth.users AS u
WHERE u.id = p.id
  AND lower(u.email) = 'superadmin00@gmail.com'
  AND u.email_confirmed_at IS NOT NULL;

COMMIT;

-- Diagnóstico: debe devolver role=superadmin, active=true y confirmado=true.
SELECT
  u.email,
  (u.email_confirmed_at IS NOT NULL) AS correo_confirmado,
  p.role::text AS role,
  p.active,
  CASE
    WHEN u.email_confirmed_at IS NOT NULL
      AND p.role::text = 'superadmin'
      AND p.active = true
    THEN 'ADMIN LISTO PARA PROBAR'
    ELSE 'REVISAR: el usuario debe existir, confirmar el correo y tener perfil'
  END AS resultado
FROM auth.users AS u
LEFT JOIN public.profiles AS p ON p.id = u.id
WHERE lower(u.email) = 'superadmin00@gmail.com';
