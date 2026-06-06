# Supabase Storage Policies

Apply these policies in the Supabase Dashboard under Authentication > Policies for the storage schema.

## Buckets: profile-images, chat-images, albums, voice-notes, videos

### Policy: Allow authenticated users to upload files

```sql
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
  AND
  -- Validate file extension
  (
    lower(right(name, 4)) IN ('.jpg', 'jpeg', '.png', '.webp', '.m4a', '.mp4', '.mov')
    OR lower(right(name, 5)) = '.webp'
  )
  AND
  -- Validate file size (max 10MB)
  octet_length(DECODE(substring(encode(metadata->'contentLength', 'hex') FROM 3), 'hex')) <= 10485760
);
```

### Policy: Allow authenticated users to read files

```sql
CREATE POLICY "Allow authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
);
```

### Policy: Allow users to delete their own files

```sql
CREATE POLICY "Allow authenticated deletes"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id IN ('profile-images', 'chat-images', 'albums', 'voice-notes', 'videos')
  AND auth.role() = 'authenticated'
);
```

### Policy: Allow public reads for profile-images bucket

```sql
CREATE POLICY "Allow public profile reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'profile-images');
```

### Policy: Allow public reads for chat-images bucket

```sql
CREATE POLICY "Allow public chat image reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'chat-images');
```

### Policy: Allow public reads for albums bucket

```sql
CREATE POLICY "Allow public album reads"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'albums');
```

## Apply to storage.objects table

All policies above should be created on the `storage.objects` table.
