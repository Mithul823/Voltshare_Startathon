# Marketplace Seeds

`seed_marketplace.sql` is intentionally manual. Do not run it automatically in production.

Use it only after Phase 6.3 migrations are applied and test `profiles` rows exist for producer or prosumer sellers.

To print the seed SQL:

```powershell
cd M:\VoltShare\backend
.\voltshare_env\Scripts\python.exe scripts\seed_marketplace.py
```
