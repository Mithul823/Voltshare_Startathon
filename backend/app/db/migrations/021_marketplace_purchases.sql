do $$
begin
  if exists (select 1 from pg_type where typname = 'purchase_status') then
    alter type public.purchase_status add value if not exists 'initiated';
    alter type public.purchase_status add value if not exists 'pending_reservation';
    alter type public.purchase_status add value if not exists 'reserved';
    alter type public.purchase_status add value if not exists 'awaiting_payment';
    alter type public.purchase_status add value if not exists 'confirmed';
    alter type public.purchase_status add value if not exists 'failed';
    alter type public.purchase_status add value if not exists 'expired';
    alter type public.purchase_status add value if not exists 'refunded';
  end if;
end $$;

create table if not exists public.energy_purchase_orders (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.energy_listings(id) on delete restrict,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  quantity_kwh numeric(12, 3) not null,
  price_per_kwh numeric(12, 2) not null,
  subtotal_amount numeric(12, 2) not null,
  platform_fee_amount numeric(12, 2) not null default 0,
  total_amount numeric(12, 2) not null,
  currency text not null default 'INR',
  status text not null default 'confirmed',
  idempotency_key text,
  request_hash text,
  failure_code text,
  failure_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  expires_at timestamptz,
  constraint energy_purchase_orders_status_check check (status in ('initiated', 'pending_reservation', 'reserved', 'awaiting_payment', 'confirmed', 'cancelled', 'failed', 'expired', 'refunded')),
  constraint energy_purchase_orders_quantity_check check (quantity_kwh > 0),
  constraint energy_purchase_orders_price_check check (price_per_kwh > 0),
  constraint energy_purchase_orders_amounts_check check (subtotal_amount >= 0 and platform_fee_amount >= 0 and total_amount >= subtotal_amount),
  constraint energy_purchase_orders_no_self_purchase check (buyer_id <> seller_id)
);

create unique index if not exists energy_purchase_orders_buyer_idempotency_idx
  on public.energy_purchase_orders (buyer_id, idempotency_key)
  where idempotency_key is not null;
