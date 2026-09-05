-- Phase 6.3 explicit seed data. Run manually after creating matching test profiles.
insert into public.energy_listings (
  seller_id, title, description, energy_source, quantity_total_kwh,
  quantity_available_kwh, price_per_kwh, location_name, available_from,
  available_until, status, is_featured, is_verified, minimum_purchase_kwh
)
select p.id, 'Rooftop solar surplus', 'Daytime solar surplus from a verified rooftop array.', 'solar',
       25.000, 25.000, 8.20, 'Kakkanad', now() - interval '1 hour',
       now() + interval '8 hours', 'active', true, true, 0.500
from public.profiles p
where p.role in ('producer', 'prosumer')
limit 1
on conflict do nothing;

insert into public.energy_listings (
  seller_id, title, description, energy_source, quantity_total_kwh,
  quantity_available_kwh, price_per_kwh, location_name, available_from,
  available_until, status, is_featured, is_verified, minimum_purchase_kwh
)
select p.id, 'Evening wind allocation', 'Small wind allocation available for evening loads.', 'wind',
       18.000, 12.000, 7.90, 'Fort Kochi', now() - interval '2 hours',
       now() + interval '10 hours', 'active', false, true, 1.000
from public.profiles p
where p.role in ('producer', 'prosumer')
offset 1
limit 1
on conflict do nothing;
