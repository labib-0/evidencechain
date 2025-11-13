-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE custody_transfer ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomaly ENABLE ROW LEVEL SECURITY;
ALTER TABLE version_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE retention ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_log ENABLE ROW LEVEL SECURITY;

-- USERS table RLS
CREATE POLICY "Users can view own data or admin" ON users
    FOR SELECT USING (auth.uid() = id OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Users can update own or admin update" ON users
    FOR UPDATE USING (auth.uid() = id OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'))
    WITH CHECK (auth.uid() = id OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Admin can delete users" ON users
    FOR DELETE USING (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Anyone authenticated can insert user" ON users
    FOR INSERT WITH CHECK (true);

-- CASES table RLS
CREATE POLICY "Users can view assigned or admin" ON cases
    FOR SELECT USING (
        auth.uid() = created_by 
        OR auth.uid() = ANY(assigned_to)
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Users can insert cases" ON cases
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update assigned cases or admin" ON cases
    FOR UPDATE USING (
        auth.uid() = created_by
        OR auth.uid() = ANY(assigned_to)
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    )
    WITH CHECK (
        auth.uid() = created_by
        OR auth.uid() = ANY(assigned_to)
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

-- EVIDENCE table RLS
CREATE POLICY "Users assigned to case can view evidence" ON evidence
    FOR SELECT USING (
        EXISTS(
            SELECT 1 FROM cases
            WHERE id = evidence.case_id
            AND (auth.uid() = created_by OR auth.uid() = ANY(assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Police officers can upload evidence" ON evidence
    FOR INSERT WITH CHECK (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Police Officer', 'Admin'))
    );

CREATE POLICY "Case assignees can update evidence" ON evidence
    FOR UPDATE USING (
        EXISTS(
            SELECT 1 FROM cases
            WHERE id = evidence.case_id
            AND (auth.uid() = created_by OR auth.uid() = ANY(assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    )
    WITH CHECK (
        EXISTS(
            SELECT 1 FROM cases
            WHERE id = evidence.case_id
            AND (auth.uid() = created_by OR auth.uid() = ANY(assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Admin can delete evidence" ON evidence
    FOR DELETE USING (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

-- AUDIT_LOG table RLS (IMMUTABLE - only INSERT)
CREATE POLICY "Users can view audit logs for their cases" ON audit_log
    FOR SELECT USING (
        EXISTS(
            SELECT 1 FROM evidence e
            JOIN cases c ON e.case_id = c.id
            WHERE e.id = audit_log.evidence_id
            AND (auth.uid() = c.created_by OR auth.uid() = ANY(c.assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Backend functions can insert audit logs" ON audit_log
    FOR INSERT WITH CHECK (true);

-- ACCESS_LOG table RLS
CREATE POLICY "Users can view access logs for their cases" ON access_log
    FOR SELECT USING (
        EXISTS(
            SELECT 1 FROM evidence e
            JOIN cases c ON e.case_id = c.id
            WHERE e.id = access_log.evidence_id
            AND (auth.uid() = c.created_by OR auth.uid() = ANY(c.assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Backend functions can insert access logs" ON access_log
    FOR INSERT WITH CHECK (true);

-- CUSTODY_TRANSFER table RLS
CREATE POLICY "Transfer participants and case assignees can view" ON custody_transfer
    FOR SELECT USING (
        auth.uid() = from_user_id
        OR auth.uid() = to_user_id
        OR EXISTS(
            SELECT 1 FROM evidence e
            JOIN cases c ON e.case_id = c.id
            WHERE e.id = custody_transfer.evidence_id
            AND (auth.uid() = c.created_by OR auth.uid() = ANY(c.assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Police officers can create transfer" ON custody_transfer
    FOR INSERT WITH CHECK (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Police Officer', 'Admin'))
    );

CREATE POLICY "Recipients can update transfer" ON custody_transfer
    FOR UPDATE USING (auth.uid() = to_user_id OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'))
    WITH CHECK (auth.uid() = to_user_id OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

-- ANOMALY table RLS
CREATE POLICY "Internal affairs and admin can view anomalies" ON anomaly
    FOR SELECT USING (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Internal Affairs', 'Admin'))
    );

CREATE POLICY "Backend functions can insert anomalies" ON anomaly
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Internal affairs and admin can update anomalies" ON anomaly
    FOR UPDATE USING (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Internal Affairs', 'Admin'))
    )
    WITH CHECK (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Internal Affairs', 'Admin'))
    );

-- VERSION_CONTROL table RLS
CREATE POLICY "Case assignees can view version control" ON version_control
    FOR SELECT USING (
        EXISTS(
            SELECT 1 FROM evidence e
            JOIN cases c ON e.case_id = c.id
            WHERE e.id = version_control.evidence_id
            AND (auth.uid() = c.created_by OR auth.uid() = ANY(c.assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Lab staff can create version records" ON version_control
    FOR INSERT WITH CHECK (
        EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('Lab Staff', 'Admin'))
    );

CREATE POLICY "Admin can update version records" ON version_control
    FOR UPDATE USING (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'))
    WITH CHECK (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

-- RETENTION table RLS
CREATE POLICY "Case assignees can view retention" ON retention
    FOR SELECT USING (
        EXISTS(
            SELECT 1 FROM cases c
            WHERE c.id = retention.case_id
            AND (auth.uid() = c.created_by OR auth.uid() = ANY(c.assigned_to))
        )
        OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
    );

CREATE POLICY "Admin can insert retention records" ON retention
    FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Admin can update retention records" ON retention
    FOR UPDATE USING (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'))
    WITH CHECK (EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));
