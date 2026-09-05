-- Help Center & Support Ticket tables for VoltShare
-- Phase 6.7: Emergency Energy Assistance & Help Center

-- ============================================================
-- SUPPORT TICKETS
-- ============================================================
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN (
        'Marketplace', 'Wallet', 'Payment', 'Login', 'Account',
        'AI Assistant', 'Energy Trading', 'Bug', 'Other'
    )),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN (
        'Open', 'In Progress', 'Resolved', 'Closed'
    )),
    assigned_admin UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- ============================================================
-- SUPPORT TICKET MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS support_ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id),
    message TEXT NOT NULL,
    is_admin_reply BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- TICKET ATTACHMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS ticket_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    message_id UUID REFERENCES support_ticket_messages(id) ON DELETE SET NULL,
    file_url TEXT NOT NULL,
    file_name TEXT,
    file_size INTEGER,
    mime_type TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_assigned ON support_tickets(assigned_admin);
CREATE INDEX IF NOT EXISTS idx_support_ticket_messages_ticket ON support_ticket_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_ticket ON ticket_attachments(ticket_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_attachments ENABLE ROW LEVEL SECURITY;

-- Users can create their own tickets
CREATE POLICY support_tickets_insert_own ON support_tickets
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can view their own tickets; admins can view all
CREATE POLICY support_tickets_select ON support_tickets
    FOR SELECT
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins can update tickets (assign, change status); users cannot modify
CREATE POLICY support_tickets_update_admin ON support_tickets
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- No deletes for users; admins can delete
CREATE POLICY support_tickets_delete_admin ON support_tickets
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Messages: users can insert on their own tickets; admins can reply to any
CREATE POLICY support_messages_insert ON support_ticket_messages
    FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id
        AND (
            EXISTS (
                SELECT 1 FROM support_tickets
                WHERE support_tickets.id = ticket_id
                AND (support_tickets.user_id = auth.uid()
                     OR EXISTS (
                        SELECT 1 FROM profiles
                        WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                     ))
            )
        )
    );

-- Messages: users can read messages on their own tickets; admins all
CREATE POLICY support_messages_select ON support_ticket_messages
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM support_tickets
            WHERE support_tickets.id = ticket_id
            AND (support_tickets.user_id = auth.uid()
                 OR EXISTS (
                    SELECT 1 FROM profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                 ))
        )
    );

-- Attachments: same access as messages
CREATE POLICY ticket_attachments_select ON ticket_attachments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM support_tickets
            WHERE support_tickets.id = ticket_id
            AND (support_tickets.user_id = auth.uid()
                 OR EXISTS (
                    SELECT 1 FROM profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                 ))
        )
    );

-- ============================================================
-- TRIGGER: updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_support_tickets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_support_tickets_updated_at
    BEFORE UPDATE ON support_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_support_tickets_updated_at();
