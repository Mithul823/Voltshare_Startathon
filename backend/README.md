# VoltShare FastAPI Backend

Phase 6.1 provides the production-oriented backend foundation:

- FastAPI application factory and `/docs`
- Supabase public and service-role clients
- Supabase access-token verification through JWKS, with HS256 compatibility for local projects that still use a JWT secret
- Profile-backed role authorization
- Standard error responses
- Root and API health checks
- User profile read/update endpoints
- Development-only role test endpoint
- Phase 6.2 dashboard and energy monitoring APIs
- Rule-based dashboard insights and sustainability scoring
- Authenticated dashboard WebSocket at `/ws/dashboard`

Run locally from `backend/`:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger:

```text
http://localhost:8000/docs
```

Flutter mock mode remains the default. Live backend mode is enabled with `USE_MOCK_BACKEND=false`.

Dashboard endpoints:

- `GET /api/v1/dashboard`
- `GET /api/v1/dashboard/summary`
- `GET /api/v1/dashboard/history?interval=hour`
- `GET /api/v1/dashboard/energy-history?interval=day`
- `GET /api/v1/dashboard/battery-history?interval=week`
- `GET /api/v1/dashboard/activity`

Dashboard WebSocket:

```text
ws://localhost:8000/ws/dashboard?token=SUPABASE_ACCESS_TOKEN
```

If the WebSocket is unavailable, Flutter live dashboard mode polls the REST API every 30 seconds.

## Phase 6.3 Marketplace API

Marketplace live mode is exposed under `/api/v1`:

- `GET /marketplace`, `GET /marketplace/summary`, `GET /marketplace/activity`
- `GET /listings`, `GET /listings/{listing_id}`, `POST /listings`, `PATCH /listings/{listing_id}`
- `POST /listings/{listing_id}/publish`, `/cancel`, `/suspend`, `/reactivate`
- `POST /purchases`, `GET /purchases/{purchase_id}`, `GET /users/me/listings`, `/users/me/purchases`, `/users/me/sales`

Purchase creation requires `Authorization: Bearer <access_token>` and `Idempotency-Key`. Retrying the same payload with the same key returns the same order. Reusing that key with a different payload returns `409 MARKETPLACE_IDEMPOTENCY_CONFLICT`.

Run marketplace SQL manually in this order:

1. `app/db/migrations/020_marketplace_listings.sql`
2. `app/db/migrations/021_marketplace_purchases.sql`
3. `app/db/migrations/022_marketplace_rls.sql`
4. `app/db/migrations/023_marketplace_indexes.sql`
5. `app/db/migrations/024_marketplace_functions.sql`

Seed data is explicit only. Review `app/db/seeds/seed_marketplace.sql`, then run it in Supabase after test producer/prosumer profiles exist.
