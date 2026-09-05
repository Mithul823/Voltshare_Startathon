create index if not exists energy_listings_status_available_until_idx
  on public.energy_listings (status, available_until);

create index if not exists energy_listings_seller_status_idx
  on public.energy_listings (seller_id, status);

create index if not exists energy_listings_price_idx
  on public.energy_listings (price_per_kwh);

create index if not exists energy_listings_quantity_available_idx
  on public.energy_listings (quantity_available_kwh);

create index if not exists energy_purchase_orders_buyer_created_idx
  on public.energy_purchase_orders (buyer_id, created_at desc);

create index if not exists energy_purchase_orders_seller_created_idx
  on public.energy_purchase_orders (seller_id, created_at desc);
