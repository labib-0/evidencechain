-- Create functions for triggers
CREATE OR REPLACE FUNCTION insert_audit_log_on_evidence_insert()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (evidence_id, user_id, action, timestamp, result)
  VALUES (NEW.id, auth.uid(), 'Upload', now(), 'Success');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION insert_audit_log_on_evidence_update()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (evidence_id, user_id, action, details, timestamp, result)
  VALUES (NEW.id, auth.uid(), 'Modify', jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status), now(), 'Success');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION insert_access_log_on_evidence_select()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO access_log (evidence_id, user_id, timestamp, ip_address, user_agent)
  VALUES (NEW.id, auth.uid(), now(), inet_client_addr()::text, current_setting('request.headers')::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER trg_audit_log_insert
AFTER INSERT ON evidence
FOR EACH ROW EXECUTE FUNCTION insert_audit_log_on_evidence_insert();

CREATE TRIGGER trg_audit_log_update
AFTER UPDATE ON evidence
FOR EACH ROW EXECUTE FUNCTION insert_audit_log_on_evidence_update();

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update timestamp triggers to all tables that have updated_at
CREATE TRIGGER trigger_update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_cases_updated_at BEFORE UPDATE ON cases
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_evidence_updated_at BEFORE UPDATE ON evidence
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_custody_transfer_updated_at BEFORE UPDATE ON custody_transfer
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
