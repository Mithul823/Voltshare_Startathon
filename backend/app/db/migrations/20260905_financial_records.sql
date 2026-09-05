-- Apply to the same Supabase PostgreSQL database used for wallets and energy_listings.
-- Only the backend database role may access these records (including KYC).
CREATE TABLE IF NOT EXISTS public.financial_records (
    namespace text NOT NULL,
    key text NOT NULL,
    payload text NOT NULL,
    PRIMARY KEY (namespace, key)
);
ALTER TABLE public.financial_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financial_records FROM anon, authenticated;
GRANT ALL ON public.financial_records TO service_role;
