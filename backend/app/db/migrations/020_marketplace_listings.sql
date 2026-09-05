create extension if not exists pgcrypto;

do $$
begin
  if exists (select 1 from pg_type where typname = 'listing_status') then
    alter type public.listing_status add value if not exists 'draft';
    alter type public.listing_status add value if not exists 'partially_reserved';
    alter type public.listing_status add value if not exists 'sold_out';
    alter type public.listing_status add value if not exists 'expired';
    alter type public.listing_status add value if not exists 'suspended';
  end if;
end $$;

create table if not exists public.energy_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  energy_source text not null,
  quantity_total_kwh numeric(12, 3) not null,
  quantity_available_kwh numeric(12, 3) not null,
  quantity_reserved_kwh numeric(12, 3) not null default 0,
  price_per_kwh numeric(12, 2) not null,
  currency text not null default 'INR',
  minimum_purchase_kwh numeric(12, 3) not null default 0.500,
  maximum_purchase_kwh numeric(12, 3),
  location_name text not null,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  available_from timestamptz not null,
  available_until timestamptz not null,
  status text not null default 'draft',
  is_featured boolean not null default false,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  suspended_at timestamptz,
  version integer not null default 1,
  constraint energy_listings_source_check check (energy_source in ('solar', 'wind', 'hydro', 'biomass', 'mixed_renewable', 'other')),
  constraint energy_listings_status_check check (status in ('draft', 'active', 'partially_reserved', 'sold_out', 'expired', 'cancelled', 'suspended')),
  constraint energy_listings_quantity_total_check check (quantity_total_kwh > 0),
  constraint energy_listings_quantity_available_check check (quantity_available_kwh >= 0),
  constraint energy_listings_quantity_reserved_check check (quantity_reserved_kwh >= 0),
  constraint energy_listings_quantity_balance_check check (quantity_available_kwh + quantity_reserved_kwh <= quantity_total_kwh),
  constraint energy_listings_price_check check (price_per_kwh > 0),
  constraint energy_listings_minimum_check check (minimum_purchase_kwh > 0),
  constraint energy_listings_maximum_check check (maximum_purchase_kwh is null or maximum_purchase_kwh >= minimum_purchase_kwh),
  constraint energy_listings_window_check check (available_until > available_from)
);

alter table public.energy_listings add column if not exists title text;
alter table public.energy_listings add column if not exists description text;
alter table public.energy_listings add column if not exists quantity_total_kwh numeric(12, 3);
alter table public.energy_listings add column if not exists quantity_available_kwh numeric(12, 3);
alter table public.energy_listings add column if not exists quantity_reserved_kwh numeric(12, 3) not null default 0;
alter table public.energy_listings add column if not exists price_per_kwh numeric(12, 2);
alter table public.energy_listings add column if not exists currency text not null default 'INR';
alter table public.energy_listings add column if not exists minimum_purchase_kwh numeric(12, 3) not null default 0.500;
alter table public.energy_listings add column if not exists maximum_purchase_kwh numeric(12, 3);
alter table public.energy_listings add column if not exists location_name text;
alter table public.energy_listings add column if not exists latitude numeric(10, 7);
alter table public.energy_listings add column if not exists longitude numeric(10, 7);
alter table public.energy_listings add column if not exists available_from timestamptz;
alter table public.energy_listings add column if not exists available_until timestamptz;
alter table public.energy_listings add column if not exists is_featured boolean not null default false;
alter table public.energy_listings add column if not exists is_verified boolean not null default false;
alter table public.energy_listings add column if not exists cancelled_at timestamptz;
alter table public.energy_listings add column if not exists suspended_at timestamptz;
alter table public.energy_listings add column if not exists version integer not null default 1;

update public.energy_listings
set
  title = coalesce(title, 'Renewable energy listing'),
  quantity_total_kwh = coalesce(quantity_total_kwh, original_energy_kwh, available_energy_kwh),
  quantity_available_kwh = coalesce(quantity_available_kwh, available_energy_kwh),
  price_per_kwh = coalesce(price_per_kwh, round(price_per_kwh_paise::numeric / 100, 2)),
  location_name = coalesce(location_name, 'Local marketplace'),
  available_from = coalesce(available_from, availability_start, now()),
  available_until = coalesce(available_until, availability_end, now() + interval '1 day'),
  is_verified = coalesce(is_verified, renewable_verified, false)
where
  title is null
  or quantity_total_kwh is null
  or quantity_available_kwh is null
  or price_per_kwh is null
  or location_name is null
  or available_from is null
  or available_until is null;

alter table public.energy_listings alter column title set not null;
alter table public.energy_listings alter column quantity_total_kwh set not null;
alter table public.energy_listings alter column quantity_available_kwh set not null;
alter table public.energy_listings alter column price_per_kwh set not null;
alter table public.energy_listings alter column location_name set not null;
alter table public.energy_listings alter column available_from set not null;
alter table public.energy_listings alter column available_until set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'energy_listings_quantity_total_check'
      and conrelid = 'public.energy_listings'::regclass
  ) then
    alter table public.energy_listings add constraint energy_listings_quantity_total_check check (quantity_total_kwh > 0);
  end if;
end $$;
