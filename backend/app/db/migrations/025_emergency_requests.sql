-- Emergency Assistance tables for VoltShare
-- Phase 6.7: Emergency Energy Assistance & Help Center

-- ============================================================
-- EMERGENCY REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS emergency_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'Medical', 'Natural Disaster', 'Fire', 'Flood',
        'Hospital', 'Government Relief', 'Other'
    )),
    description TEXT NOT NULL,
    required_energy_kwh DOUBLE PRECISION NOT NULL CHECK (required_energy_kwh > 0),
    allocated_energy_kwh DOUBLE PRECISION DEFAULT 0,
    priority TEXT NOT NULL CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN (
        'Pending', 'Approved', 'Rejected', 'In Progress', 'Completed'
    )),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    phone TEXT,
    image_url TEXT,
    admin_notes TEXT,
    assigned_admin UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- ============================================================
-- EMERGENCY ALLOCATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS emergency_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES emergency_requests(id) ON DELETE CASCADE,
    source TEXT NOT NULL CHECK (source IN (
        'Government Reserve', 'Partner Producer', 'Community Storage',
        'Battery Backup', 'Emergency Grid'
    )),
    allocated_energy DOUBLE PRECISION NOT NULL CHECK (allocated_energy > 0),
    remarks TEXT,
    allocated_by UUID NOT NULL REFERENCES profiles(id),
    allocated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_emergency_requests_consumer ON emergency_requests(consumer_id);
CREATE INDEX IF NOT EXISTS idx_emergency_requests_status ON emergency_requests(status);
CREATE INDEX IF NOT EXISTS idx_emergency_requests_priority ON emergency_requests(priority);
CREATE INDEX IF NOT EXISTS idx_emergency_allocations_request ON emergency_allocations(request_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE emergency_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_allocations ENABLE ROW LEVEL SECURITY;

-- Consumers can create their own requests
CREATE POLICY emergency_requests_insert_own ON emergency_requests
    FOR INSERT
    WITH CHECK (
        auth.uid() = consumer_id
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'consumer'
        )
    );

-- Consumers can view only their own requests
CREATE POLICY emergency_requests_select_own ON emergency_requests
    FOR SELECT
    USING (
        auth.uid() = consumer_id
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Only admins can update emergency requests (approve/reject/allocate/complete)
CREATE POLICY emergency_requests_update_admin ON emergency_requests
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Consumers cannot delete their requests
CREATE POLICY emergency_requests_delete_none ON emergency_requests
    FOR DELETE
    USING (false);

-- Emergency allocations: admins can insert and select all
CREATE POLICY emergency_allocations_insert_admin ON emergency_allocations
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY emergency_allocations_select_admin ON emergency_allocations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
        OR EXISTS (
            SELECT 1 FROM emergency_requests
            WHERE emergency_requests.id = emergency_allocations.request_id
            AND emergency_requests.consumer_id = auth.uid()
        )
    );

-- ============================================================
-- TRIGGER: updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_emergency_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_emergency_requests_updated_at
    BEFORE UPDATE ON emergency_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_emergency_requests_updated_at();
