-- Create enums
CREATE TYPE user_role AS ENUM ('Police Officer', 'Lab Staff', 'Judge', 'Admin', 'Internal Affairs');
CREATE TYPE user_status AS ENUM ('Active', 'Inactive', 'Suspended');
CREATE TYPE evidence_status AS ENUM ('Valid', 'Compromised', 'Under Review', 'Deleted');
CREATE TYPE evidence_type AS ENUM ('Photo', 'Video', 'Document', 'DNA', 'Fingerprint', 'Other');
CREATE TYPE verification_status AS ENUM ('Verified', 'Not Verified', 'Failed');
CREATE TYPE audit_action AS ENUM ('Upload', 'Download', 'Access', 'Verify', 'Transfer', 'Tampering', 'Modify');
CREATE TYPE audit_result AS ENUM ('Success', 'Failed', 'Blocked');
CREATE TYPE custody_status AS ENUM ('Pending', 'Accepted', 'Rejected', 'Expired');
CREATE TYPE anomaly_type AS ENUM ('Midnight Access', 'High Frequency', 'Unusual Location', 'Device Change');
CREATE TYPE anomaly_severity AS ENUM ('Low', 'Medium', 'High', 'Critical');
CREATE TYPE case_severity AS ENUM ('Murder', 'Rape', 'Robbery', 'Fraud', 'Other');
CREATE TYPE case_priority AS ENUM ('Urgent', 'Standard', 'Low');
CREATE TYPE case_status AS ENUM ('Open', 'Closed', 'Appeal');
CREATE TYPE modification_type AS ENUM ('Enhancement', 'Cropping', 'Analysis');
CREATE TYPE approval_status AS ENUM ('Pending', 'Approved', 'Rejected');
CREATE TYPE retention_type AS ENUM ('5 Years', '10 Years', '20 Years');
CREATE TYPE retention_status AS ENUM ('Active', 'Expiring Soon', 'Expired', 'Deleted');

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    organization TEXT NOT NULL,
    role user_role NOT NULL,
    status user_status NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login TIMESTAMPTZ,
    metadata JSONB
);

-- Cases table
CREATE TABLE cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_number TEXT UNIQUE NOT NULL,
    case_name TEXT NOT NULL,
    description TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    assigned_to UUID[] DEFAULT '{}',
    severity case_severity NOT NULL,
    priority case_priority NOT NULL,
    status case_status NOT NULL DEFAULT 'Open',
    retention_years INTEGER DEFAULT 5,
    retention_expiry TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

-- Evidence table
CREATE TABLE evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL REFERENCES cases(id),
    file_name TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    mime_type TEXT NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    upload_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_hash TEXT NOT NULL,
    previous_hash TEXT,
    previous_evidence_id UUID REFERENCES evidence(id),
    evidence_name TEXT NOT NULL,
    description TEXT,
    evidence_type evidence_type NOT NULL,
    status evidence_status NOT NULL DEFAULT 'Valid',
    storage_location TEXT NOT NULL,
    qr_code_data TEXT,
    qr_code_gen_date TIMESTAMPTZ,
    verification_status verification_status NOT NULL DEFAULT 'Not Verified',
    last_verified TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit log table (IMMUTABLE)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID REFERENCES evidence(id),
    user_id UUID NOT NULL REFERENCES users(id),
    action audit_action NOT NULL,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    location TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    result audit_result NOT NULL,
    reason TEXT
);

-- Custody transfer table
CREATE TABLE custody_transfer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID NOT NULL REFERENCES evidence(id),
    from_user_id UUID NOT NULL REFERENCES users(id),
    to_user_id UUID NOT NULL REFERENCES users(id),
    qr_code TEXT,
    transfer_code TEXT UNIQUE NOT NULL,
    current_hash TEXT NOT NULL,
    status custody_status NOT NULL DEFAULT 'Pending',
    expiry_date TIMESTAMPTZ NOT NULL,
    reason TEXT,
    transfer_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Anomaly table
CREATE TABLE anomaly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID REFERENCES evidence(id),
    user_id UUID NOT NULL REFERENCES users(id),
    anomaly_type anomaly_type NOT NULL,
    anomaly_score FLOAT NOT NULL DEFAULT 0,
    severity anomaly_severity NOT NULL,
    details JSONB,
    investigated BOOLEAN DEFAULT FALSE,
    investigation_notes TEXT,
    ip_address TEXT,
    location TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Version control table
CREATE TABLE version_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID NOT NULL REFERENCES evidence(id),
    original_hash TEXT NOT NULL,
    modified_hash TEXT NOT NULL,
    modification_type modification_type NOT NULL,
    modified_by UUID NOT NULL REFERENCES users(id),
    modification_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    approval_status approval_status NOT NULL DEFAULT 'Pending',
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retention table
CREATE TABLE retention (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL REFERENCES cases(id),
    evidence_id UUID REFERENCES evidence(id),
    retention_type retention_type NOT NULL,
    expiry_date TIMESTAMPTZ NOT NULL,
    deletion_approved_by UUID REFERENCES users(id),
    deletion_date TIMESTAMPTZ,
    deletion_reason TEXT,
    status retention_status NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Access log table
CREATE TABLE access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID NOT NULL REFERENCES evidence(id),
    user_id UUID NOT NULL REFERENCES users(id),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address TEXT,
    user_agent TEXT,
    location TEXT,
    duration INTEGER,
    device_hash TEXT
);

-- Create indexes for better performance
CREATE INDEX idx_evidence_case_id ON evidence(case_id);
CREATE INDEX idx_evidence_uploaded_by ON evidence(uploaded_by);
CREATE INDEX idx_evidence_status ON evidence(status);
CREATE INDEX idx_audit_log_evidence_id ON audit_log(evidence_id);
CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp DESC);
CREATE INDEX idx_custody_transfer_evidence_id ON custody_transfer(evidence_id);
CREATE INDEX idx_custody_transfer_status ON custody_transfer(status);
CREATE INDEX idx_anomaly_user_id ON anomaly(user_id);
CREATE INDEX idx_anomaly_timestamp ON anomaly(timestamp DESC);
CREATE INDEX idx_access_log_evidence_id ON access_log(evidence_id);
CREATE INDEX idx_access_log_user_id ON access_log(user_id);
CREATE INDEX idx_access_log_timestamp ON access_log(timestamp DESC);
CREATE INDEX idx_cases_status ON cases(status);
CREATE INDEX idx_cases_created_by ON cases(created_by);
