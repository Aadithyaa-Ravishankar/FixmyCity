-- Simplified Supabase Storage Policy Setup
-- Run this SQL in your Supabase SQL Editor
-- (Buckets are already created and public)

-- Simple policy to allow any authenticated user to upload files
CREATE POLICY IF NOT EXISTS "Allow authenticated uploads" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id IN ('Images', 'Videos', 'Audios')
  );

-- Policy to allow public read access (for public buckets)
CREATE POLICY IF NOT EXISTS "Allow public downloads" ON storage.objects
  FOR SELECT USING (
    bucket_id IN ('Images', 'Videos', 'Audios')
  );
