alter table public.energy_listings enable row level security;
alter table public.energy_purchase_orders enable row level security;

drop policy if exists "read active marketplace listings" on public.energy_listings;
create policy "read active marketplace listings"
  on public.energy_listings for select
  to authenticated
  using (status = 'active');

drop policy if exists "sellers read own listings" on public.energy_listings;
create policy "sellers read own listings"
  on public.energy_listings for select
  to authenticated
  using (seller_id = auth.uid());

drop policy if exists "sellers create own listings" on public.energy_listings;
create policy "sellers create own listings"
  on public.energy_listings for insert
  to authenticated
  with check (
    seller_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('producer', 'prosumer')
    )
  );

drop policy if exists "sellers update own listings" on public.energy_listings;
create policy "sellers update own listings"
  on public.energy_listings for update
  to authenticated
  using (seller_id = auth.uid() and status in ('draft', 'active', 'partially_reserved'))
  with check (seller_id = auth.uid());

drop policy if exists "buyers read own purchase orders" on public.energy_purchase_orders;
create policy "buyers read own purchase orders"
  on public.energy_purchase_orders for select
  to authenticated
  using (buyer_id = auth.uid());

drop policy if exists "sellers read own sales" on public.energy_purchase_orders;
create policy "sellers read own sales"
  on public.energy_purchase_orders for select
  to authenticated
  using (seller_id = auth.uid());
