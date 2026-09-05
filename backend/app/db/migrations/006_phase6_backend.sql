create extension if not exists "pgcrypto";

create type user_role as enum ('consumer','producer','prosumer','technician','grid_operator','admin');
create type listing_status as enum ('active','sold','cancelled');
create type purchase_status as enum ('pending','completed','cancelled');
create type escrow_status as enum ('energyDeliveryPending','deliveryConfirmed','deliveryPartiallyConfirmed','released','refunded','disputed','frozen','cancelled');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text not null default 'VoltShare User',
  role user_role not null default 'consumer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.energy_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  solar_power_kw numeric(8,3) not null check (solar_power_kw >= 0),
  consumption_kw numeric(8,3) not null check (consumption_kw >= 0),
  battery_percentage int not null check (battery_percentage between 0 and 100),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.energy_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id),
  energy_source text not null,
  available_energy_kwh numeric(10,3) not null check (available_energy_kwh >= 0),
  original_energy_kwh numeric(10,3) not null check (original_energy_kwh > 0),
  price_per_kwh_paise int not null check (price_per_kwh_paise > 0),
  status listing_status not null default 'active',
  battery_backed boolean not null default false,
  renewable_verified boolean not null default false,
  availability_start timestamptz not null,
  availability_end timestamptz not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint listing_window_valid check (availability_end > availability_start)
);

create table if not exists public.energy_purchases (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.energy_listings(id),
  buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.profiles(id),
  quantity_kwh numeric(10,3) not null check (quantity_kwh > 0),
  unit_price_paise int not null check (unit_price_paise > 0),
  platform_fee_paise int not null check (platform_fee_paise >= 0),
  total_amount_paise int not null check (total_amount_paise > 0),
  status purchase_status not null default 'completed',
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (buyer_id, idempotency_key)
);

create table if not exists public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id),
  currency text not null default 'INR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallet_accounts(id),
  user_id uuid not null references public.profiles(id),
  entry_type text not null,
  amount_paise int not null check (amount_paise >= 0),
  direction text not null check (direction in ('credit','debit','hold','release')),
  purchase_id uuid references public.energy_purchases(id),
  escrow_id uuid,
  reference text not null,
  idempotency_key text,
  integrity_hash text not null,
  created_at timestamptz not null default now(),
  unique (wallet_id, idempotency_key)
);

create table if not exists public.escrow_agreements (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null unique references public.energy_purchases(id),
  listing_id uuid not null references public.energy_listings(id),
  buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.profiles(id),
  energy_quantity_kwh numeric(10,3) not null check (energy_quantity_kwh > 0),
  amount_held_paise int not null check (amount_held_paise >= 0),
  platform_fee_paise int not null check (platform_fee_paise >= 0),
  total_held_paise int not null check (total_held_paise = amount_held_paise + platform_fee_paise),
  delivered_energy_kwh numeric(10,3) not null default 0 check (delivered_energy_kwh >= 0),
  status escrow_status not null default 'energyDeliveryPending',
  failure_reason text,
  integrity_hash text not null,
  version int not null default 1,
  funded_at timestamptz,
  delivery_deadline timestamptz not null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.escrow_operations (
  id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null references public.escrow_agreements(id),
  operation_type text not null,
  status text not null,
  idempotency_key text not null,
  request_hash text not null,
  response_payload jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (escrow_id, operation_type, idempotency_key)
);

create table if not exists public.trade_default_cases (
  id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null references public.escrow_agreements(id),
  defaulting_party uuid references public.profiles(id),
  reason text not null,
  status text not null,
  financial_impact_paise int not null check (financial_impact_paise >= 0),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null references public.escrow_agreements(id),
  raised_by uuid not null references public.profiles(id),
  category text not null,
  description text not null,
  status text not null default 'underReview',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (escrow_id, raised_by)
);

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  event_type text not null,
  risk_score int check (risk_score between 0 and 100),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  device_fingerprint text not null,
  trusted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_fingerprint)
);

create table if not exists public.login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  success boolean not null,
  ip_hash text,
  user_agent_hash text,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id),
  action text not null,
  resource_type text not null,
  resource_id text not null,
  status text not null,
  risk_score int check (risk_score between 0 and 100),
  request_id uuid,
  idempotency_key text,
  metadata jsonb not null default '{}',
  integrity_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  source text not null check (source in ('Gemini','fallback rule engine')),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  operation text not null,
  idempotency_key text not null,
  request_hash text not null,
  response_payload jsonb,
  http_status int not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (user_id, operation, idempotency_key)
);

create index if not exists idx_energy_readings_user_time on public.energy_readings(user_id, recorded_at desc);
create index if not exists idx_listings_status_price on public.energy_listings(status, price_per_kwh_paise);
create index if not exists idx_purchases_buyer on public.energy_purchases(buyer_id, created_at desc);
create index if not exists idx_purchases_seller on public.energy_purchases(seller_id, created_at desc);
create index if not exists idx_ledger_user_time on public.wallet_ledger_entries(user_id, created_at desc);
create index if not exists idx_escrow_participants on public.escrow_agreements(buyer_id, seller_id);
create index if not exists idx_audit_actor_time on public.audit_events(actor_user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.energy_readings enable row level security;
alter table public.energy_listings enable row level security;
alter table public.energy_purchases enable row level security;
alter table public.wallet_accounts enable row level security;
alter table public.wallet_ledger_entries enable row level security;
alter table public.escrow_agreements enable row level security;
alter table public.disputes enable row level security;
alter table public.audit_events enable row level security;
alter table public.ai_insights enable row level security;

create policy "profiles own read update" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "listings active readable" on public.energy_listings for select using (status = 'active' or seller_id = auth.uid());
create policy "listing owners manage" on public.energy_listings for all using (seller_id = auth.uid()) with check (seller_id = auth.uid());
create policy "purchases participants read" on public.energy_purchases for select using (buyer_id = auth.uid() or seller_id = auth.uid());
create policy "wallet owner read" on public.wallet_accounts for select using (user_id = auth.uid());
create policy "ledger owner read" on public.wallet_ledger_entries for select using (user_id = auth.uid());
create policy "escrow participants read" on public.escrow_agreements for select using (buyer_id = auth.uid() or seller_id = auth.uid());
create policy "dispute participants read" on public.disputes for select using (
  raised_by = auth.uid() or exists (
    select 1 from public.escrow_agreements e where e.id = escrow_id and (e.buyer_id = auth.uid() or e.seller_id = auth.uid())
  )
);
create policy "audit actor read" on public.audit_events for select using (actor_user_id = auth.uid());
create policy "ai owner read" on public.ai_insights for select using (user_id = auth.uid());

create or replace function public.block_audit_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'audit_events are append-only';
end;
$$;

drop trigger if exists trg_audit_no_update on public.audit_events;
create trigger trg_audit_no_update before update or delete on public.audit_events
for each row execute function public.block_audit_mutation();

-- Financial writes should be performed by service-role backend RPC/functions so
-- purchase creation, wallet deduction, escrow funding, listing inventory update,
-- settlement, refunds, and reconciliation commit atomically.
