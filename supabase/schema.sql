-- ============================================================
-- SISTEMA DE INVENTARIO PARA PANADERIA - SUPABASE
-- Script idempotente: crea tablas y agrega columnas faltantes
-- sin borrar registros existentes. Ejecutar en Supabase SQL Editor.
-- ============================================================

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('superadmin','employee');
exception when duplicate_object then null;
end $$;

-- 1. TABLAS PRINCIPALES
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text,
  role public.app_role not null default 'employee',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_modules (
  id uuid primary key default gen_random_uuid(), name text not null default '',
  description text, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(), contact_name text not null default '',
  company_name text, phone text, email text, address text, products_supplied text, notes text,
  active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(), name text not null default '', sku text, barcode text,
  module_id uuid references public.inventory_modules(id) on delete restrict,
  category text, unit text not null default 'unidad', stock numeric(14,3) not null default 0,
  cost numeric(14,2) not null default 0, entry_date date not null default current_date,
  min_stock numeric(14,3) not null default 0, supplier_id uuid references public.suppliers(id) on delete set null,
  supplier_name text, notes text, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- IMPORTANTE: CREATE TABLE IF NOT EXISTS no actualiza tablas antiguas.
-- Estas sentencias agregan columnas que falten en instalaciones previas.
alter table public.profiles add column if not exists full_name text not null default '';
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role public.app_role not null default 'employee';
alter table public.profiles add column if not exists active boolean not null default true;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

alter table public.inventory_modules add column if not exists name text not null default '';
alter table public.inventory_modules add column if not exists description text;
alter table public.inventory_modules add column if not exists active boolean not null default true;
alter table public.inventory_modules add column if not exists created_at timestamptz not null default now();
alter table public.inventory_modules add column if not exists updated_at timestamptz not null default now();

alter table public.suppliers add column if not exists contact_name text not null default '';
alter table public.suppliers add column if not exists company_name text;
alter table public.suppliers add column if not exists phone text;
alter table public.suppliers add column if not exists email text;
alter table public.suppliers add column if not exists address text;
alter table public.suppliers add column if not exists products_supplied text;
alter table public.suppliers add column if not exists notes text;
alter table public.suppliers add column if not exists active boolean not null default true;
alter table public.suppliers add column if not exists created_at timestamptz not null default now();
alter table public.suppliers add column if not exists updated_at timestamptz not null default now();

alter table public.products add column if not exists name text not null default '';
alter table public.products add column if not exists sku text;
alter table public.products add column if not exists barcode text;
alter table public.products add column if not exists module_id uuid;
alter table public.products add column if not exists category text;
alter table public.products add column if not exists cost numeric(14,2) not null default 0;
alter table public.products add column if not exists entry_date date not null default current_date;
alter table public.products add column if not exists unit text not null default 'unidad';
alter table public.products add column if not exists stock numeric(14,3) not null default 0;
alter table public.products add column if not exists min_stock numeric(14,3) not null default 0;
alter table public.products add column if not exists supplier_id uuid;
alter table public.products add column if not exists supplier_name text;
alter table public.products add column if not exists notes text;
alter table public.products add column if not exists active boolean not null default true;
alter table public.products add column if not exists created_at timestamptz not null default now();
alter table public.products add column if not exists updated_at timestamptz not null default now();

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete restrict,
  movement_type text not null check (movement_type in ('entrada','salida','ajuste')),
  quantity numeric(14,3) not null check (quantity >= 0), reason text, notes text,
  created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
alter table public.inventory_movements add column if not exists product_id uuid;
alter table public.inventory_movements add column if not exists movement_type text not null default 'entrada';
alter table public.inventory_movements add column if not exists quantity numeric(14,3) not null default 0;
alter table public.inventory_movements add column if not exists reason text;
alter table public.inventory_movements add column if not exists notes text;
alter table public.inventory_movements add column if not exists created_by uuid;
alter table public.inventory_movements add column if not exists created_at timestamptz not null default now();

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(), name text not null default '', category text,
  yield_amount numeric(14,3), yield_unit text, ingredients_text text not null default '',
  instructions text, prep_minutes integer, temperature text, notes text, active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.recipes add column if not exists name text not null default '';
alter table public.recipes add column if not exists category text;
alter table public.recipes add column if not exists yield_amount numeric(14,3);
alter table public.recipes add column if not exists yield_unit text;
alter table public.recipes add column if not exists ingredients_text text not null default '';
alter table public.recipes add column if not exists instructions text;
alter table public.recipes add column if not exists prep_minutes integer;
alter table public.recipes add column if not exists temperature text;
alter table public.recipes add column if not exists notes text;
alter table public.recipes add column if not exists active boolean not null default true;
alter table public.recipes add column if not exists created_by uuid;
alter table public.recipes add column if not exists created_at timestamptz not null default now();
alter table public.recipes add column if not exists updated_at timestamptz not null default now();

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(), user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null default '', department text, job_title text, phone text, email text, hire_date date,
  active boolean not null default true, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.employees add column if not exists user_id uuid;
alter table public.employees add column if not exists full_name text not null default '';
alter table public.employees add column if not exists department text;
alter table public.employees add column if not exists job_title text;
alter table public.employees add column if not exists phone text;
alter table public.employees add column if not exists email text;
alter table public.employees add column if not exists hire_date date;
alter table public.employees add column if not exists active boolean not null default true;
alter table public.employees add column if not exists notes text;
alter table public.employees add column if not exists created_at timestamptz not null default now();
alter table public.employees add column if not exists updated_at timestamptz not null default now();

create table if not exists public.employee_shifts (
  id uuid primary key default gen_random_uuid(), employee_id uuid references public.employees(id) on delete set null,
  employee_name text not null default '', shift_date date not null default current_date,
  status text not null default 'ON', start_time time, end_time time,
  break_minutes integer not null default 0, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.employee_shifts add column if not exists employee_id uuid;
alter table public.employee_shifts add column if not exists employee_name text not null default '';
alter table public.employee_shifts add column if not exists shift_date date not null default current_date;
alter table public.employee_shifts add column if not exists status text not null default 'ON';
alter table public.employee_shifts add column if not exists start_time time;
alter table public.employee_shifts add column if not exists end_time time;
alter table public.employee_shifts add column if not exists break_minutes integer not null default 0;
alter table public.employee_shifts add column if not exists notes text;
alter table public.employee_shifts add column if not exists created_at timestamptz not null default now();
alter table public.employee_shifts add column if not exists updated_at timestamptz not null default now();

create table if not exists public.final_products (
  id uuid primary key default gen_random_uuid(), name text not null default '',
  requested_quantity numeric(14,3) not null default 0, unit text not null default 'unidad',
  produced_quantity numeric(14,3) not null default 0, production_date date not null default current_date,
  status text not null default 'pendiente', notes text, created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.final_products add column if not exists name text not null default '';
alter table public.final_products add column if not exists requested_quantity numeric(14,3) not null default 0;
alter table public.final_products add column if not exists unit text not null default 'unidad';
alter table public.final_products add column if not exists produced_quantity numeric(14,3) not null default 0;
alter table public.final_products add column if not exists production_date date not null default current_date;
alter table public.final_products add column if not exists status text not null default 'pendiente';
alter table public.final_products add column if not exists notes text;
alter table public.final_products add column if not exists created_by uuid;
alter table public.final_products add column if not exists created_at timestamptz not null default now();
alter table public.final_products add column if not exists updated_at timestamptz not null default now();

create table if not exists public.production_records (
  id uuid primary key default gen_random_uuid(), final_product_id uuid not null references public.final_products(id) on delete restrict,
  requested_quantity numeric(14,3) not null default 0, produced_quantity numeric(14,3) not null default 0,
  production_date date not null default current_date, status text not null default 'pendiente', notes text,
  created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
alter table public.production_records add column if not exists final_product_id uuid;
alter table public.production_records add column if not exists requested_quantity numeric(14,3) not null default 0;
alter table public.production_records add column if not exists produced_quantity numeric(14,3) not null default 0;
alter table public.production_records add column if not exists production_date date not null default current_date;
alter table public.production_records add column if not exists status text not null default 'pendiente';
alter table public.production_records add column if not exists notes text;
alter table public.production_records add column if not exists created_by uuid;
alter table public.production_records add column if not exists created_at timestamptz not null default now();

-- 2. INDICES. Los de SKU/código de barras son no únicos para que datos antiguos
-- duplicados no impidan ejecutar la migración. Se pueden hacer únicos después de limpiar duplicados.
create index if not exists inventory_modules_name_idx on public.inventory_modules (lower(name));
create index if not exists products_sku_idx on public.products (sku);
create index if not exists products_barcode_idx on public.products (barcode);
create index if not exists products_name_search on public.products using gin (
  to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(sku, '') || ' ' || coalesce(category, ''))
);
create index if not exists inventory_movements_product_created_idx on public.inventory_movements (product_id, created_at desc);
create index if not exists employee_shifts_date_idx on public.employee_shifts (shift_date);

-- 3. FUNCIONES Y TRIGGER DE STOCK
create or replace function public.apply_inventory_movement() returns trigger
language plpgsql security definer set search_path = public
as $$
declare changed integer;
begin
  if new.movement_type = 'entrada' then
    update public.products set stock = stock + new.quantity where id = new.product_id;
  elsif new.movement_type = 'salida' then
    update public.products set stock = stock - new.quantity where id = new.product_id and stock >= new.quantity;
    get diagnostics changed = row_count;
    if changed = 0 then raise exception 'Existencia insuficiente para registrar esta salida'; end if;
  elsif new.movement_type = 'ajuste' then
    update public.products set stock = new.quantity where id = new.product_id;
  else
    raise exception 'Tipo de movimiento no válido';
  end if;
  return new;
end $$;
drop trigger if exists inventory_movement_apply_stock on public.inventory_movements;
create trigger inventory_movement_apply_stock after insert on public.inventory_movements
for each row execute function public.apply_inventory_movement();

create or replace function public.current_app_role() returns text
language sql stable security definer set search_path = public
as $$ select role::text from public.profiles where id = auth.uid() and active = true limit 1 $$;
create or replace function public.is_superadmin() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_app_role() = 'superadmin', false) $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
declare
  assigned_role public.app_role;
begin
  -- La cuenta administrativa solo se promueve si existe y el correo figura confirmado.
  if lower(coalesce(new.email, '')) = 'superadmin00@gmail.com' and new.email_confirmed_at is not null then
    assigned_role := 'superadmin';
  else
    assigned_role := 'employee';
  end if;

  insert into public.profiles(id, full_name, email, role, active)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email, assigned_role, true)
  on conflict (id) do update
    set email = excluded.email,
        role = case when lower(coalesce(excluded.email, '')) = 'superadmin00@gmail.com'
                    and exists (select 1 from auth.users u where u.id = excluded.id and u.email_confirmed_at is not null)
                    then 'superadmin'::public.app_role
                    else public.profiles.role end;
  return new;
end $$;

-- Sincroniza perfiles de usuarios que ya existían antes de instalar este schema.
insert into public.profiles(id, full_name, email, role, active)
select u.id,
       coalesce(u.raw_user_meta_data->>'full_name', ''),
       u.email,
       case when lower(coalesce(u.email, '')) = 'superadmin00@gmail.com' and u.email_confirmed_at is not null
            then 'superadmin'::public.app_role else 'employee'::public.app_role end,
       true
from auth.users u
on conflict (id) do update
set email = excluded.email,
    role = case when lower(coalesce(excluded.email, '')) = 'superadmin00@gmail.com'
                     and exists (select 1 from auth.users u where u.id = excluded.id and u.email_confirmed_at is not null)
                then 'superadmin'::public.app_role
                else public.profiles.role end;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is distinct from u.email;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_confirmed_profile on auth.users;
create trigger on_auth_user_confirmed_profile after update of email_confirmed_at, email on auth.users
for each row execute function public.handle_new_user();

create or replace function public.set_updated_at() returns trigger
language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end $$;
do $$ declare t text; begin
  foreach t in array array['profiles','inventory_modules','suppliers','products','recipes','employees','employee_shifts','final_products'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- 4. SEGURIDAD RLS
alter table public.profiles enable row level security;
alter table public.inventory_modules enable row level security;
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.recipes enable row level security;
alter table public.employees enable row level security;
alter table public.employee_shifts enable row level security;
alter table public.final_products enable row level security;
alter table public.production_records enable row level security;

-- Eliminar políticas de esta versión antes de recrearlas evita error por duplicados.
drop policy if exists profiles_read_self_or_admin on public.profiles;
drop policy if exists profiles_admin_insert on public.profiles;
drop policy if exists profiles_admin_update on public.profiles;
drop policy if exists profiles_admin_delete on public.profiles;
drop policy if exists inventory_modules_admin_all on public.inventory_modules;
drop policy if exists suppliers_admin_all on public.suppliers;
drop policy if exists products_admin_all on public.products;
drop policy if exists movements_admin_all on public.inventory_movements;
drop policy if exists recipes_admin_all on public.recipes;
drop policy if exists employees_admin_all on public.employees;
drop policy if exists shifts_admin_all on public.employee_shifts;
drop policy if exists final_products_read_auth on public.final_products;
drop policy if exists final_products_admin_write on public.final_products;
drop policy if exists final_products_admin_update on public.final_products;
drop policy if exists final_products_admin_delete on public.final_products;
drop policy if exists production_admin_all on public.production_records;

create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.is_superadmin());
create policy profiles_admin_insert on public.profiles for insert to authenticated
with check (public.is_superadmin());
create policy profiles_admin_update on public.profiles for update to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy profiles_admin_delete on public.profiles for delete to authenticated
using (public.is_superadmin());

create policy inventory_modules_admin_all on public.inventory_modules for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy suppliers_admin_all on public.suppliers for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy products_admin_all on public.products for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy movements_admin_all on public.inventory_movements for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy recipes_admin_all on public.recipes for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy employees_admin_all on public.employees for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy shifts_admin_all on public.employee_shifts for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy final_products_read_auth on public.final_products for select to authenticated
using (public.current_app_role() in ('superadmin', 'employee'));
create policy final_products_admin_write on public.final_products for insert to authenticated
with check (public.is_superadmin());
create policy final_products_admin_update on public.final_products for update to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());
create policy final_products_admin_delete on public.final_products for delete to authenticated
using (public.is_superadmin());
create policy production_admin_all on public.production_records for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());

-- 5. IMPORTANTE: después de crear tu usuario, conviértelo en superadministrador.
-- Reemplaza el UUID por el ID real de Authentication > Users.
-- update public.profiles set role = 'superadmin' where id = 'UUID-DEL-USUARIO';
-- Nunca pongas la clave service_role en una aplicación web.
