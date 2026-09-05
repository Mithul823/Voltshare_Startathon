alter table public.profiles
  add column if not exists phone text,
  add column if not exists city text,
  add column if not exists district text,
  add column if not exists state text,
  add column if not exists is_active boolean not null default true,
  add column if not exists email_verified boolean not null default false;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('consumer','producer','prosumer','technician','grid_operator','admin'));

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    phone,
    city,
    district,
    state,
    role,
    email_verified
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'VoltShare User'),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'city',
    new.raw_user_meta_data ->> 'district',
    new.raw_user_meta_data ->> 'state',
    coalesce(new.raw_user_meta_data ->> 'role', 'consumer'),
    coalesce(new.email_confirmed_at is not null, false)
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    city = excluded.city,
    district = excluded.district,
    state = excluded.state,
    role = excluded.role,
    email_verified = excluded.email_verified,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_created_create_profile on auth.users;

create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user();
