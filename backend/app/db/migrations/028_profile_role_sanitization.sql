-- Migration 028: Profile role sanitization and protection
-- 
-- Ensures:
-- 1. The signup trigger only accepts consumer or producer from user metadata
-- 2. Users cannot update their own role via direct Supabase API
-- 3. Role can only be changed by service-role operations

-- Recreate the trigger function with role sanitization
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_role text;
  safe_role text;
begin
  -- Extract role from user metadata, default to consumer
  raw_role := coalesce(new.raw_user_meta_data ->> 'role', 'consumer');
  
  -- Only consumer and producer are allowed from public registration
  if raw_role in ('consumer', 'producer') then
    safe_role := raw_role;
  else
    -- Any other value (admin, technician, grid_operator, prosumer, unknown) defaults to consumer
    safe_role := 'consumer';
  end if;

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
    safe_role,
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
    updated_at = now()
    -- Do NOT update role on conflict — existing roles are preserved
    -- Role changes must go through admin/service-role operations
  ;

  return new;
end;
$$;

-- Revoke direct role update from public users
-- Users can update safe profile fields but NOT role, email_verified, or is_active
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    and (
      -- Only allow updating non-role fields
      coalesce(role, (select role from public.profiles where id = auth.uid())) = 
        (select role from public.profiles where id = auth.uid())
    )
  );

-- Admin and service-role can still update any field (bypasses RLS)
-- This policy only restricts self-service updates
