-- Replace the sample UUID below with a real public.profiles.id before running.
-- This generates realistic half-hour readings with daylight solar curves,
-- night consumption, battery charging/discharging, grid import/export,
-- earnings, cost, and carbon savings.

with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as user_id
),
series as (
  select generate_series(
    date_trunc('day', now()),
    date_trunc('day', now()) + interval '23 hours 30 minutes',
    interval '30 minutes'
  ) as ts
),
curves as (
  select
    params.user_id,
    ts,
    greatest(0, exp(-power((extract(hour from ts) + extract(minute from ts) / 60 - 12.5), 2) / 18) * 3.2) as solar,
    1.0
      + case when extract(hour from ts) between 18 and 22 then 1.1 else 0 end
      + case when extract(hour from ts) < 6 or extract(hour from ts) > 22 then 0.55 else 0 end as load
  from series cross join params
)
insert into public.energy_readings (
  user_id,
  timestamp,
  solar_generation_kwh,
  consumption_kwh,
  battery_percent,
  battery_charge_kw,
  grid_import_kwh,
  grid_export_kwh,
  carbon_saved,
  earnings,
  cost
)
select
  user_id,
  ts,
  round(solar::numeric, 3),
  round(load::numeric, 3),
  least(96, greatest(18, round(42 + solar * 12 - case when load > 2 then 8 else 0 end)))::int,
  round((solar - load)::numeric, 3),
  round(greatest(0, load - solar)::numeric * 0.4, 3),
  round(greatest(0, solar - load)::numeric * 0.5, 3),
  round((solar * 0.7)::numeric, 3),
  round((greatest(0, solar - load) * 0.5 * 8.0)::numeric, 2),
  round((greatest(0, load - solar) * 0.4 * 10.25)::numeric, 2)
from curves;
