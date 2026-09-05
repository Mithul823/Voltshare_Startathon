# VoltShare Backend Setup

1. Create and activate a virtual environment:

```powershell
cd M:\VoltShare\backend
python -m venv voltshare_env
.\voltshare_env\Scripts\Activate.ps1
```

2. Install dependencies:

```powershell
python -m pip install -r requirements.txt
```

3. Create local environment file:

```powershell
Copy-Item .env.example .env
```

4. Fill `backend\.env` with Supabase values:

- `SUPABASE_URL`: Project URL from Supabase settings.
- `SUPABASE_ANON_KEY`: Publishable anon key.
- `SUPABASE_SERVICE_ROLE_KEY`: Service-role key. Backend only.
- `SUPABASE_JWKS_URL`: `https://PROJECT_ID.supabase.co/auth/v1/.well-known/jwks.json`
- `HMAC_SECRET`: Long random secret.

5. Run migrations in Supabase SQL editor in order:

- `app/db/migrations/001_profiles.sql`
- `app/db/migrations/002_roles.sql`
- `app/db/migrations/003_rls_policies.sql`
- `app/db/migrations/004_dashboard_energy_monitoring.sql`

6. Start FastAPI:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

7. Open Swagger:

```text
http://localhost:8000/docs
```

8. Flutter Web/Desktop live API:

```powershell
flutter run -d chrome --dart-define=USE_MOCK_BACKEND=false --dart-define=API_BASE_URL=http://localhost:8000/api/v1 --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY
```

9. Android emulator live API:

```powershell
flutter run -d emulator-5554 --dart-define=USE_MOCK_BACKEND=false --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY
```

10. Physical Android device:

Use your computer LAN IP:

```text
http://LOCAL_COMPUTER_IP:8000/api/v1
```

11. Troubleshooting:

- `401`: Missing, expired, or invalid Supabase access token.
- `403`: Token is valid, but profile role is not allowed.
- Supabase degraded health: check `SUPABASE_URL`, network, and project status.
- Empty profile: run migrations and ensure trigger created a profile row.

12. Optional dashboard seed data:

Edit the sample user id in `scripts/seed_dashboard_data.sql`, then run it in
the Supabase SQL editor after dashboard migrations.

13. Phase 6.3 marketplace configuration:

```env
MARKETPLACE_PLATFORM_FEE_PERCENT=5
```

14. Run marketplace migrations after dashboard migrations:

- `app/db/migrations/020_marketplace_listings.sql`
- `app/db/migrations/021_marketplace_purchases.sql`
- `app/db/migrations/022_marketplace_rls.sql`
- `app/db/migrations/023_marketplace_indexes.sql`
- `app/db/migrations/024_marketplace_functions.sql`

15. Start FastAPI on loopback for local Swagger and Flutter desktop:

```powershell
cd M:\VoltShare\backend
.\voltshare_env\Scripts\uvicorn.exe app.main:app --reload --host 127.0.0.1 --port 8000
```

16. Flutter live marketplace mode:

```powershell
cd M:\VoltShare\frontend
C:\Development\flutter\bin\flutter.bat run --dart-define=USE_MOCK_BACKEND=false --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1 --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Android emulator live mode should use `API_BASE_URL=http://10.0.2.2:8000/api/v1`.
