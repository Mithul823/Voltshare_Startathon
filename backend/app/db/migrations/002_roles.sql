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
    role,
    email_verified
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'VoltShare User'),
    new.raw_user_meta_data ->> 'phone',
    'consumer',
    coalesce(new.email_confirmed_at is not null, false)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_profile on auth.users;
create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user();
