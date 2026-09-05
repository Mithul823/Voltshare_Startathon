create table if not exists public.energy_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  timestamp timestamptz not null default now(),
  solar_generation_kwh numeric(10,3) not null default 0 check (solar_generation_kwh >= 0),
  consumption_kwh numeric(10,3) not null default 0 check (consumption_kwh >= 0),
  battery_percent int not null default 0 check (battery_percent between 0 and 100),
  battery_charge_kw numeric(10,3) not null default 0,
  grid_import_kwh numeric(10,3) not null default 0 check (grid_import_kwh >= 0),
  grid_export_kwh numeric(10,3) not null default 0 check (grid_export_kwh >= 0),
  carbon_saved numeric(10,3) not null default 0 check (carbon_saved >= 0),
  earnings numeric(12,2) not null default 0 check (earnings >= 0),
  cost numeric(12,2) not null default 0 check (cost >= 0),
  created_at timestamptz not null default now()
);

-- Earlier VoltShare phases may already have created energy_readings with a
-- narrower simulation schema. Keep this migration rerunnable by adding the
-- Phase 6.2 dashboard columns when the table already exists.
alter table public.energy_readings
  add column if not exists timestamp timestamptz not null default now(),
  add column if not exists solar_generation_kwh numeric(10,3) not null default 0,
  add column if not exists consumption_kwh numeric(10,3) not null default 0,
  add column if not exists battery_percent int not null default 0,
  add column if not exists battery_charge_kw numeric(10,3) not null default 0,
  add column if not exists grid_import_kwh numeric(10,3) not null default 0,
  add column if not exists grid_export_kwh numeric(10,3) not null default 0,
  add column if not exists carbon_saved numeric(10,3) not null default 0,
  add column if not exists earnings numeric(12,2) not null default 0,
  add column if not exists cost numeric(12,2) not null default 0,
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'energy_readings'
      and column_name = 'recorded_at'
  ) then
    update public.energy_readings
    set timestamp = recorded_at
    where timestamp is null;
  end if;
end $$;

alter table public.energy_readings
  drop constraint if exists energy_readings_solar_generation_kwh_check,
  drop constraint if exists energy_readings_consumption_kwh_check,
  drop constraint if exists energy_readings_battery_percent_check,
  drop constraint if exists energy_readings_grid_import_kwh_check,
  drop constraint if exists energy_readings_grid_export_kwh_check,
  drop constraint if exists energy_readings_carbon_saved_check,
  drop constraint if exists energy_readings_earnings_check,
  drop constraint if exists energy_readings_cost_check;

alter table public.energy_readings
  add constraint energy_readings_solar_generation_kwh_check check (solar_generation_kwh >= 0),
  add constraint energy_readings_consumption_kwh_check check (consumption_kwh >= 0),
  add constraint energy_readings_battery_percent_check check (battery_percent between 0 and 100),
  add constraint energy_readings_grid_import_kwh_check check (grid_import_kwh >= 0),
  add constraint energy_readings_grid_export_kwh_check check (grid_export_kwh >= 0),
  add constraint energy_readings_carbon_saved_check check (carbon_saved >= 0),
  add constraint energy_readings_earnings_check check (earnings >= 0),
  add constraint energy_readings_cost_check check (cost >= 0);

create index if not exists idx_energy_readings_user_timestamp
on public.energy_readings(user_id, timestamp desc);

create or replace view public.dashboard_daily_summary as
select
  user_id,
  date_trunc('day', timestamp)::date as day,
  sum(solar_generation_kwh) as daily_production_kwh,
  sum(consumption_kwh) as daily_consumption_kwh,
  sum(earnings) as daily_earnings,
  sum(cost) as daily_cost,
  sum(grid_import_kwh) as grid_import_kwh,
  sum(grid_export_kwh) as grid_export_kwh,
  avg(battery_percent) as average_battery_percent,
  sum(carbon_saved) as carbon_saved
from public.energy_readings
group by user_id, date_trunc('day', timestamp)::date;

alter table public.energy_readings enable row level security;

drop policy if exists "Users can read own energy readings" on public.energy_readings;
create policy "Users can read own energy readings"
on public.energy_readings
for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert own demo energy readings" on public.energy_readings;
create policy "Users can insert own demo energy readings"
on public.energy_readings
for insert
with check (auth.uid() = user_id);

comment on table public.energy_readings is
  'Per-user solar, consumption, battery, grid, carbon, earnings, and cost readings for dashboard monitoring.';

comment on view public.dashboard_daily_summary is
  'Per-user daily dashboard aggregate for production, consumption, earnings, savings, grid totals, and battery averages.';
