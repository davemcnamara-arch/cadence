-- Test if the get_class_students RPC function exists and works

-- 1. Check if the function exists
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'get_class_students';

-- 2. Test calling it for class 8MS1
SELECT public.get_class_students('3097e838-27bb-475b-88bc-79653ad64844');

-- Expected: Should return JSON array with 1 student
-- If it returns empty array or error, the function needs to be created/fixed
