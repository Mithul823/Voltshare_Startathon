# VoltShare Demo Data Seeder

This directory contains scripts and configuration for seeding, resetting,
verifying, and simulating live demo data in VoltShare's Supabase database.

## Prerequisites

- Python 3.10+
- Access to a Supabase project
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` configured

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes | Supabase project URL (e.g. `https://xyz.supabase.co`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Service-role key (keep secret!) |
| `DEMO_ADMIN_PASSWORD` | No | Admin account password (default: `VoltShareDemo2026!`) |
| `DEMO_CONSUMER_PASSWORD` | No | Consumer account password (default: `VoltShareDemo2026!`) |
| `DEMO_PRODUCER_PASSWORD` | No | Producer account password (default: `VoltShareDemo2026!`) |

## How to Seed

From the `backend/` directory:

```powershell
$env:SUPABASE_URL = "https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"
python scripts/seed_live_demo_data.py
```

## How to Verify

```powershell
python scripts/verify_live_demo_data.py
```

## How to Reset

```powershell
# Preview what will be deleted:
python scripts/reset_live_demo_data.py --dry-run

# Delete all demo data:
python scripts/reset_live_demo_data.py --yes
```

## How to Run the Simulator

```powershell
# Insert a new reading every 15 seconds for producer1:
python scripts/simulate_live_energy.py --email producer1@voltshare-demo.local --interval 15
```

Press Ctrl+C to stop gracefully.

## Demo Accounts

| Account | Email | Role | Default Password |
|---------|-------|------|-----------------|
| Admin | admin@voltshare-demo.local | admin | `VoltShareDemo2026!` |
| Consumer 1 | consumer1@voltshare-demo.local | consumer | `VoltShareDemo2026!` |
| Consumer 2 | consumer2@voltshare-demo.local | consumer | `VoltShareDemo2026!` |
| Producer 1 | producer1@voltshare-demo.local | producer | `VoltShareDemo2026!` |
| Producer 2 | producer2@voltshare-demo.local | producer | `VoltShareDemo2026!` |

Override passwords via environment variables `DEMO_ADMIN_PASSWORD`,
`DEMO_CONSUMER_PASSWORD`, and `DEMO_PRODUCER_PASSWORD`.

## Live Flutter Command

```powershell
C:\Development\flutter\bin\flutter.bat run -d emulator-5554 `
  --dart-define=SUPABASE_URL=<supabase-url> `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 `
  --dart-define=USE_MOCK_BACKEND=false
```

## Safety Notes

- The seed script is **idempotent** — running it multiple times will not
  create duplicate records.
- Demo records use the email domain `@voltshare-demo.local` and stable
  idempotency keys.
- The reset script **only deletes** demo-owned records. It identifies
  them by email domain and UUID lookup.
- Use `--dry-run` with the reset script to preview deletions before
  executing.
- Never commit the `.env` file or expose the Supabase service-role key.
- The seed script does **not** truncate any tables.
- Non-demo user data is **never** modified or deleted.

## Troubleshooting

| Symptom | Likely Cause |
|---------|-------------|
| "Auth user already exists" | First run created users; second run is idempotent (safe to ignore) |
| "Failed to create profile" | Profile may already exist; the script uses upsert |
| "API error 401" | SUPABASE_SERVICE_ROLE_KEY is missing or invalid |
| "API error 404" | Supabase project URL is incorrect |
| "Timeout" | Network issue or Supabase project is unreachable |
| Readings not appearing | Check that `USE_MOCK_BACKEND=false` is set in Flutter |

## File Reference

| File | Purpose |
|------|---------|
| `scripts/seed_live_demo_data.py` | Main seed script — creates all demo data |
| `scripts/reset_live_demo_data.py` | Safe reset — deletes only demo records |
| `scripts/verify_live_demo_data.py` | Integrity verification — checks all constraints |
| `scripts/simulate_live_energy.py` | Live energy simulator — inserts readings at intervals |
| `seed/demo_seed_config.json` | Seed configuration (markers, defaults, counts) |
| `seed/README.md` | This file |
