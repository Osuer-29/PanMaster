-- Activación segura del superadministrador inicial.
-- Ejecuta este archivo en Supabase SQL Editor DESPUÉS de crear la cuenta
-- superadmin00@gmail.com desde la pantalla de acceso y confirmar el correo.
-- No crea una cuenta de Authentication por sí solo: eso debe hacerse mediante
-- Supabase Auth (no insertes manualmente en auth.users ni pongas service_role en la app).

update public.profiles p
set role = 'superadmin', active = true, email = u.email,
    full_name = coalesce(nullif(p.full_name, ''), 'Superadministrador')
from auth.users u
where u.id = p.id
  and lower(u.email) = 'superadmin00@gmail.com'
  and u.email_confirmed_at is not null;

-- Comprobación: debe devolver una fila con role = superadmin y active = true.
select p.id, p.email, p.role, p.active, u.email_confirmed_at
from public.profiles p
join auth.users u on u.id = p.id
where lower(u.email) = 'superadmin00@gmail.com';
