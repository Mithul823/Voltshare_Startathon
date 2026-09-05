-- Phase 6.6 AI intelligence layer.
-- These tables persist sanitized, user-scoped forecasts, recommendations,
-- sustainability scores, assistant history, anomaly indicators, and model runs.

create table if not exists public.ai_forecasts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  metric text not null,
  horizon text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  recommendation_id text not null,
  role text not null,
  payload jsonb not null,
  dismissed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.sustainability_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  total_score integer not null check (total_score between 0 and 100),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.assistant_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.assistant_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.assistant_conversations(id) on delete cascade,
  user_id uuid not null,
  role text not null check (role in ('user', 'assistant')),
  sanitized_content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.anomaly_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  role_scope text not null,
  severity text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.model_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  model_name text not null,
  result text not null,
  duration_ms integer not null default 0,
  fallback_used boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_forecasts_user_metric_time on public.ai_forecasts(user_id, metric, horizon, created_at desc);
create index if not exists idx_ai_recommendations_user_time on public.ai_recommendations(user_id, created_at desc);
create index if not exists idx_sustainability_scores_user_time on public.sustainability_scores(user_id, created_at desc);
create index if not exists idx_assistant_conversations_user_time on public.assistant_conversations(user_id, updated_at desc);
create index if not exists idx_assistant_messages_conversation_time on public.assistant_messages(conversation_id, created_at);
create index if not exists idx_anomaly_events_scope_time on public.anomaly_events(role_scope, created_at desc);
create index if not exists idx_model_runs_user_time on public.model_runs(user_id, created_at desc);

alter table public.ai_forecasts enable row level security;
alter table public.ai_recommendations enable row level security;
alter table public.sustainability_scores enable row level security;
alter table public.assistant_conversations enable row level security;
alter table public.assistant_messages enable row level security;
alter table public.anomaly_events enable row level security;
alter table public.model_runs enable row level security;

drop policy if exists "ai forecasts owner read" on public.ai_forecasts;
create policy "ai forecasts owner read" on public.ai_forecasts for select using (user_id = auth.uid());

drop policy if exists "ai recommendations owner read" on public.ai_recommendations;
create policy "ai recommendations owner read" on public.ai_recommendations for select using (user_id = auth.uid());

drop policy if exists "sustainability scores owner read" on public.sustainability_scores;
create policy "sustainability scores owner read" on public.sustainability_scores for select using (user_id = auth.uid());

drop policy if exists "assistant conversations owner read" on public.assistant_conversations;
create policy "assistant conversations owner read" on public.assistant_conversations for select using (user_id = auth.uid());

drop policy if exists "assistant messages owner read" on public.assistant_messages;
create policy "assistant messages owner read" on public.assistant_messages for select using (user_id = auth.uid());

drop policy if exists "model runs owner read" on public.model_runs;
create policy "model runs owner read" on public.model_runs for select using (user_id = auth.uid());

drop policy if exists "anomaly events admin read" on public.anomaly_events;
create policy "anomaly events admin read" on public.anomaly_events for select using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('admin', 'grid_operator', 'technician')
  )
);
