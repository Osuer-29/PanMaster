-- PanMaster: employee-created printable labels.
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
-- Additive migration; does not delete or rewrite existing application data.

create table if not exists public.employee_custom_labels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label_name text not null check (char_length(trim(label_name)) between 1 and 120),
  label_date date not null default current_date,
  created_at timestamptz not null default now()
);

create index if not exists employee_custom_labels_user_created_idx
  on public.employee_custom_labels (user_id, created_at desc);

alter table public.employee_custom_labels enable row level security;

drop policy if exists "Employees and admins can view custom labels" on public.employee_custom_labels;
create policy "Employees and admins can view custom labels"
  on public.employee_custom_labels for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.active = true and p.role::text = 'superadmin'
    )
  );

drop policy if exists "Employees can create their own custom labels" on public.employee_custom_labels;
create policy "Employees can create their own custom labels"
  on public.employee_custom_labels for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true)
  );

drop policy if exists "Admins can delete employee custom labels" on public.employee_custom_labels;
create policy "Admins can delete employee custom labels"
  on public.employee_custom_labels for delete to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.active = true and p.role::text = 'superadmin'
    )
  );

grant select, insert, delete on public.employee_custom_labels to authenticated;

-- Some older deployments have a required product_id on recipes. The simplified
-- recipe form no longer asks for a linked product, so make it nullable only if
-- that column exists. This is safe for existing recipe rows.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'recipes' and column_name = 'product_id'
  ) then
    alter table public.recipes alter column product_id drop not null;
  end if;
end $$;
