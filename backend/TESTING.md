# VoltShare Backend Testing

Run backend tests:

```powershell
cd M:\VoltShare\backend
python -m pytest
```

Run Python compilation:

```powershell
python -m compileall app
```

Health checks:

- `GET /health` verifies the API process.
- `GET /api/v1/health` verifies configuration and Supabase reachability without exposing secrets.

Authentication verification:

- `GET /api/v1/auth/me` requires `Authorization: Bearer <supabase_access_token>`.
- Missing, invalid, and expired tokens return `401`.

Role testing:

- `GET /api/v1/auth/admin-only` is available only in development/demo mode.
- Non-admin users receive `403`.

Dashboard testing:

- `GET /api/v1/dashboard` returns summary, metrics, carbon, insights, timelines, distribution, activity, and legacy Flutter dashboard fields.
- `GET /api/v1/dashboard/history` and `/energy-history` return chart-ready energy and consumption points.
- `GET /api/v1/dashboard/battery-history` returns chart-ready battery points.
- `GET /api/v1/dashboard/activity` returns recent dashboard activity.
- `/ws/dashboard?token=...` sends the latest dashboard payload for authenticated users.

Flutter login verification:

- Log in through Supabase in Flutter.
- Run with `USE_MOCK_BACKEND=false`.
- The API client attaches the current Supabase session access token automatically.

Common causes:

- `401`: session expired, wrong project token, missing bearer prefix, JWKS URL mismatch.
- `403`: profile role is not admin or not in the allowed set.
- Supabase connection errors: check service URL, project status, local network, and service-role key.

Marketplace testing:

- Listing browsing returns active listings only.
- Producer/prosumer roles can create listings; consumer and technician roles cannot.
- Purchase creation requires an `Idempotency-Key`.
- Duplicate purchase retry with the same payload returns the same purchase.
- Reusing an idempotency key with different payload returns `409`.
- Self-purchase and insufficient quantity are rejected.

If global Python is missing test tools, use the project virtualenv:

```powershell
cd M:\VoltShare\backend
.\voltshare_env\Scripts\python.exe -m compileall app
.\voltshare_env\Scripts\python.exe -m pytest
.\voltshare_env\Scripts\python.exe -m ruff check .
.\voltshare_env\Scripts\python.exe -m mypy app
```
