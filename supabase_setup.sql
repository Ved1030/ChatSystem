-- Create storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('profile-images', 'profile-images', true),
  ('chat-images', 'chat-images', true),
  ('albums', 'albums', true),
  ('voice-notes', 'voice-notes', false),
  ('videos', 'videos', false)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload files
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
);

-- Allow authenticated users to read files
CREATE POLICY "Allow authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
);

-- Allow authenticated deletes
CREATE POLICY "Allow authenticated deletes"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
);

-- Allow public reads for profile-images
CREATE POLICY "Allow public profile reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'profile-images');

-- Allow public reads for chat-images
CREATE POLICY "Allow public chat image reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'chat-images');

-- Allow public reads for albums
CREATE POLICY "Allow public album reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'albums');
