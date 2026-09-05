-- Phase 6.4 financial layer: wallets, ledger, escrow, settlements and audits.

do $$ begin
  create type public.wallet_status as enum ('ACTIVE', 'SUSPENDED', 'LOCKED', 'CLOSED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.financial_transaction_type as enum (
    'Deposit','Withdrawal','Purchase','Sale','Refund','Escrow Hold',
    'Escrow Release','Settlement','Adjustment','Transfer'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.financial_record_status as enum ('PENDING', 'ACTIVE', 'COMPLETED', 'FAILED', 'CANCELLED', 'REFUNDED', 'RELEASED');
exception when duplicate_object then null; end $$;

create table if not exists public.wallets (
  wallet_id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  available_balance bigint not null default 0 check (available_balance >= 0),
  held_balance bigint not null default 0 check (held_balance >= 0),
  currency text not null default 'INR',
  status public.wallet_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  transaction_id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(wallet_id),
  user_id uuid not null references public.profiles(id),
  type public.financial_transaction_type not null,
  status public.financial_record_status not null default 'PENDING',
  amount bigint not null check (amount > 0),
  currency text not null default 'INR',
  idempotency_key text,
  reference text not null,
  description text not null default '',
  related_purchase_id uuid,
  related_escrow_id uuid,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (wallet_id, idempotency_key)
);

create table if not exists public.ledger_entries (
  entry_id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null,
  wallet_id uuid references public.wallets(wallet_id),
  user_id uuid references public.profiles(id),
  account_type text not null,
  debit bigint not null default 0 check (debit >= 0),
  credit bigint not null default 0 check (credit >= 0),
  description text not null,
  created_at timestamptz not null default now(),
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create table if not exists public.escrow_accounts (
  escrow_account_id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null unique,
  purchase_id uuid not null,
  buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.profiles(id),
  amount_held bigint not null check (amount_held >= 0),
  platform_fee bigint not null default 0 check (platform_fee >= 0),
  status public.financial_record_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.escrow_transactions (
  escrow_transaction_id uuid primary key default gen_random_uuid(),
  escrow_account_id uuid not null references public.escrow_accounts(escrow_account_id),
  transaction_id uuid not null,
  type public.financial_transaction_type not null,
  amount bigint not null check (amount > 0),
  status public.financial_record_status not null default 'PENDING',
  created_at timestamptz not null default now()
);

create table if not exists public.settlements (
  settlement_id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null,
  purchase_id uuid not null,
  seller_id uuid not null references public.profiles(id),
  amount bigint not null check (amount >= 0),
  platform_fee bigint not null default 0 check (platform_fee >= 0),
  status public.financial_record_status not null default 'COMPLETED',
  created_at timestamptz not null default now()
);

create table if not exists public.withdrawals (
  withdrawal_id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(wallet_id),
  user_id uuid not null references public.profiles(id),
  amount bigint not null check (amount > 0),
  method text not null,
  status public.financial_record_status not null default 'PENDING',
  created_at timestamptz not null default now()
);

create table if not exists public.deposits (
  deposit_id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(wallet_id),
  user_id uuid not null references public.profiles(id),
  amount bigint not null check (amount > 0),
  method text not null,
  status public.financial_record_status not null default 'COMPLETED',
  created_at timestamptz not null default now()
);

create table if not exists public.payment_methods (
  payment_method_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  type text not null check (type in ('UPI','Bank','Wallet')),
  label text not null,
  metadata jsonb not null default '{}'::jsonb,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.refunds (
  refund_id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(wallet_id),
  user_id uuid not null references public.profiles(id),
  transaction_id uuid not null,
  amount bigint not null check (amount > 0),
  status public.financial_record_status not null default 'COMPLETED',
  created_at timestamptz not null default now()
);

create table if not exists public.transaction_audit (
  audit_id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  role text not null,
  endpoint text not null,
  transaction_id uuid,
  wallet_id uuid references public.wallets(wallet_id),
  ip_address inet,
  created_at timestamptz not null default now()
);

create index if not exists idx_wallets_user_id on public.wallets(user_id);
create index if not exists idx_wallet_transactions_wallet_time on public.wallet_transactions(wallet_id, created_at desc);
create index if not exists idx_ledger_entries_transaction on public.ledger_entries(transaction_id);
create index if not exists idx_ledger_entries_user_time on public.ledger_entries(user_id, created_at desc);
create index if not exists idx_escrow_accounts_participants on public.escrow_accounts(buyer_id, seller_id);
create index if not exists idx_settlements_seller_time on public.settlements(seller_id, created_at desc);
create index if not exists idx_withdrawals_user_time on public.withdrawals(user_id, created_at desc);
create index if not exists idx_deposits_user_time on public.deposits(user_id, created_at desc);
create index if not exists idx_refunds_user_time on public.refunds(user_id, created_at desc);
create index if not exists idx_transaction_audit_user_time on public.transaction_audit(user_id, created_at desc);

alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.escrow_accounts enable row level security;
alter table public.escrow_transactions enable row level security;
alter table public.settlements enable row level security;
alter table public.withdrawals enable row level security;
alter table public.deposits enable row level security;
alter table public.payment_methods enable row level security;
alter table public.refunds enable row level security;
alter table public.transaction_audit enable row level security;

drop policy if exists "wallet owner read" on public.wallets;
create policy "wallet owner read" on public.wallets for select using (user_id = auth.uid());

drop policy if exists "wallet transaction owner read" on public.wallet_transactions;
create policy "wallet transaction owner read" on public.wallet_transactions for select using (user_id = auth.uid());

drop policy if exists "ledger owner read" on public.ledger_entries;
create policy "ledger owner read" on public.ledger_entries for select using (user_id = auth.uid());

drop policy if exists "escrow participant read" on public.escrow_accounts;
create policy "escrow participant read" on public.escrow_accounts for select using (buyer_id = auth.uid() or seller_id = auth.uid());

drop policy if exists "settlement seller read" on public.settlements;
create policy "settlement seller read" on public.settlements for select using (seller_id = auth.uid());

drop policy if exists "withdrawal owner read" on public.withdrawals;
create policy "withdrawal owner read" on public.withdrawals for select using (user_id = auth.uid());

drop policy if exists "deposit owner read" on public.deposits;
create policy "deposit owner read" on public.deposits for select using (user_id = auth.uid());

drop policy if exists "payment method owner read" on public.payment_methods;
create policy "payment method owner read" on public.payment_methods for select using (user_id = auth.uid());

drop policy if exists "refund owner read" on public.refunds;
create policy "refund owner read" on public.refunds for select using (user_id = auth.uid());

drop policy if exists "transaction audit owner read" on public.transaction_audit;
create policy "transaction audit owner read" on public.transaction_audit for select using (user_id = auth.uid());
