create or replace function public.create_energy_purchase_order(
  p_listing_id uuid,
  p_buyer_id uuid,
  p_quantity_kwh numeric,
  p_platform_fee_percent numeric,
  p_idempotency_key text,
  p_request_hash text
) returns public.energy_purchase_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing public.energy_listings%rowtype;
  v_existing public.energy_purchase_orders%rowtype;
  v_subtotal numeric(12, 2);
  v_fee numeric(12, 2);
  v_total numeric(12, 2);
  v_order public.energy_purchase_orders%rowtype;
begin
  select * into v_existing
  from public.energy_purchase_orders
  where buyer_id = p_buyer_id and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.request_hash is distinct from p_request_hash then
      raise exception 'MARKETPLACE_IDEMPOTENCY_CONFLICT';
    end if;
    return v_existing;
  end if;

  select * into v_listing
  from public.energy_listings
  where id = p_listing_id
  for update;

  if not found then
    raise exception 'MARKETPLACE_LISTING_NOT_FOUND';
  end if;
  if v_listing.status <> 'active' then
    raise exception 'MARKETPLACE_LISTING_NOT_ACTIVE';
  end if;
  if v_listing.available_until <= now() then
    raise exception 'MARKETPLACE_LISTING_EXPIRED';
  end if;
  if v_listing.seller_id = p_buyer_id then
    raise exception 'MARKETPLACE_SELF_PURCHASE_NOT_ALLOWED';
  end if;
  if p_quantity_kwh < v_listing.minimum_purchase_kwh
     or (v_listing.maximum_purchase_kwh is not null and p_quantity_kwh > v_listing.maximum_purchase_kwh) then
    raise exception 'MARKETPLACE_INVALID_QUANTITY';
  end if;
  if p_quantity_kwh > v_listing.quantity_available_kwh then
    raise exception 'MARKETPLACE_INSUFFICIENT_QUANTITY';
  end if;

  v_subtotal := round((p_quantity_kwh * v_listing.price_per_kwh)::numeric, 2);
  v_fee := round((v_subtotal * p_platform_fee_percent / 100)::numeric, 2);
  v_total := v_subtotal + v_fee;

  update public.energy_listings
  set quantity_available_kwh = quantity_available_kwh - p_quantity_kwh,
      quantity_reserved_kwh = quantity_reserved_kwh + p_quantity_kwh,
      status = case when quantity_available_kwh - p_quantity_kwh <= 0 then 'sold_out' else status end,
      updated_at = now(),
      version = version + 1
  where id = p_listing_id;

  insert into public.energy_purchase_orders (
    listing_id, buyer_id, seller_id, quantity_kwh, price_per_kwh,
    subtotal_amount, platform_fee_amount, total_amount, currency,
    status, idempotency_key, request_hash
  ) values (
    p_listing_id, p_buyer_id, v_listing.seller_id, p_quantity_kwh, v_listing.price_per_kwh,
    v_subtotal, v_fee, v_total, v_listing.currency,
    'confirmed', p_idempotency_key, p_request_hash
  ) returning * into v_order;

  return v_order;
end;
$$;
