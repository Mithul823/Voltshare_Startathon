alter table public.profiles enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "Users can update safe profile fields" on public.profiles;
create policy "Users can update safe profile fields"
on public.profiles
for update
using (auth.uid() = id)
with check (
  auth.uid() = id
  and role = (select role from public.profiles existing where existing.id = auth.uid())
  and is_active = (select is_active from public.profiles existing where existing.id = auth.uid())
  and email_verified = (select email_verified from public.profiles existing where existing.id = auth.uid())
);

comment on policy "Users can read their own profile" on public.profiles is
  'Allows authenticated users to read only their own profile row.';

comment on policy "Users can update safe profile fields" on public.profiles is
  'Allows self-service profile edits while preventing role, active-state, and email-verification escalation.';

-- Admin and backend maintenance operations are performed through trusted
-- service-role backend code. Supabase service-role bypasses RLS and must never
-- be exposed to Flutter or other clients.
