-- Create storage bucket for student resources (drawings, notes, PDFs)

-- Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'student-resources',
  'student-resources',
  true,  -- public bucket so files can be viewed without auth
  5242880,  -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload student resources"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'student-resources'
);

-- Allow anyone to view files (public bucket)
CREATE POLICY "Anyone can view student resources"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'student-resources'
);

-- Allow users to update their own uploads
CREATE POLICY "Users can update their own uploads"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'student-resources'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow teachers/admins to delete any files
CREATE POLICY "Teachers can delete student resources"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'student-resources'
  AND EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('teacher', 'admin')
  )
);
