-- Supabase OTP System Setup
-- Run this SQL in your Supabase SQL Editor

-- Create OTP verifications table
CREATE TABLE IF NOT EXISTS otp_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    identifier TEXT NOT NULL, -- email or phone number
    otp_code TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('email', 'phone')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'expired', 'failed')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    attempts INTEGER DEFAULT 0,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_otp_verifications_identifier ON otp_verifications(identifier);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_status ON otp_verifications(status);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_expires_at ON otp_verifications(expires_at);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_created_at ON otp_verifications(created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE otp_verifications ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
-- Allow users to read their own OTP records
CREATE POLICY "Users can view their own OTP records" ON otp_verifications
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to insert OTP records
CREATE POLICY "Users can insert OTP records" ON otp_verifications
    FOR INSERT WITH CHECK (true);

-- Allow users to update their own OTP records
CREATE POLICY "Users can update their own OTP records" ON otp_verifications
    FOR UPDATE USING (auth.uid() = user_id OR user_id IS NULL);

-- Create a function to automatically clean up expired OTPs
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
    UPDATE otp_verifications 
    SET status = 'expired' 
    WHERE status = 'pending' 
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Create a function to get OTP status
CREATE OR REPLACE FUNCTION get_otp_status(p_identifier TEXT)
RETURNS TABLE (
    id UUID,
    status TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    attempts INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ov.id,
        ov.status,
        ov.expires_at,
        ov.created_at,
        ov.verified_at,
        ov.attempts
    FROM otp_verifications ov
    WHERE ov.identifier = p_identifier
    ORDER BY ov.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create a function to verify OTP
CREATE OR REPLACE FUNCTION verify_otp_code(
    p_identifier TEXT,
    p_otp_code TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    user_id UUID
) AS $$
DECLARE
    otp_record RECORD;
    user_record RECORD;
BEGIN
    -- Get the latest pending OTP for this identifier
    SELECT * INTO otp_record
    FROM otp_verifications
    WHERE identifier = p_identifier
    AND status = 'pending'
    ORDER BY created_at DESC
    LIMIT 1;

    -- Check if OTP exists
    IF otp_record IS NULL THEN
        RETURN QUERY SELECT false, 'No pending OTP found', NULL::UUID;
        RETURN;
    END IF;

    -- Check if OTP is expired
    IF otp_record.expires_at < NOW() THEN
        UPDATE otp_verifications 
        SET status = 'expired' 
        WHERE id = otp_record.id;
        RETURN QUERY SELECT false, 'OTP has expired', NULL::UUID;
        RETURN;
    END IF;

    -- Check if OTP code matches
    IF otp_record.otp_code != p_otp_code THEN
        UPDATE otp_verifications 
        SET attempts = attempts + 1 
        WHERE id = otp_record.id;
        RETURN QUERY SELECT false, 'Invalid OTP code', NULL::UUID;
        RETURN;
    END IF;

    -- Mark OTP as verified
    UPDATE otp_verifications 
    SET 
        status = 'verified',
        verified_at = NOW()
    WHERE id = otp_record.id;

    -- Try to find or create user
    IF p_identifier LIKE '%@%' THEN
        -- Email verification
        SELECT * INTO user_record
        FROM auth.users
        WHERE email = p_identifier;
        
        IF user_record IS NULL THEN
            -- Create new user (this would typically be done through Supabase Auth)
            RETURN QUERY SELECT true, 'OTP verified successfully', NULL::UUID;
        ELSE
            RETURN QUERY SELECT true, 'OTP verified successfully', user_record.id;
        END IF;
    ELSE
        -- Phone verification
        SELECT * INTO user_record
        FROM auth.users
        WHERE phone = p_identifier;
        
        IF user_record IS NULL THEN
            -- Create new user (this would typically be done through Supabase Auth)
            RETURN QUERY SELECT true, 'OTP verified successfully', NULL::UUID;
        ELSE
            RETURN QUERY SELECT true, 'OTP verified successfully', user_record.id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON otp_verifications TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_otp_status(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_otp_code(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_otps() TO anon, authenticated;

-- Create a trigger to automatically clean up expired OTPs
CREATE OR REPLACE FUNCTION trigger_cleanup_expired_otps()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM cleanup_expired_otps();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger (runs every time a new OTP is inserted)
CREATE TRIGGER cleanup_expired_otps_trigger
    AFTER INSERT ON otp_verifications
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_cleanup_expired_otps();

-- Insert some sample data for testing (optional)
-- INSERT INTO otp_verifications (identifier, otp_code, type, expires_at) 
-- VALUES ('test@example.com', '123456', 'email', NOW() + INTERVAL '5 minutes');
