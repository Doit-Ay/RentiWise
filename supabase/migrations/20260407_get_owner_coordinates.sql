-- Function to get owner's default address coordinates (bypasses RLS for cross-user distance calc)
-- Returns only location-relevant columns (not sensitive address details)
CREATE OR REPLACE FUNCTION public.get_owner_coordinates(owner_user_id uuid)
RETURNS TABLE (
    user_id uuid,
    latitude double precision,
    longitude double precision,
    city text,
    state text,
    country text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        a.user_id,
        a.latitude,
        a.longitude,
        a.city,
        a.state,
        a.country
    FROM public.addresses a
    WHERE a.user_id = owner_user_id
    ORDER BY a.is_default DESC, a.created_at DESC
    LIMIT 1;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_owner_coordinates(uuid) TO authenticated;

-- Also fix the user_default_address view to be accessible
-- Drop and recreate with proper security
DROP VIEW IF EXISTS public.user_default_address;

CREATE OR REPLACE VIEW public.user_default_address AS
SELECT DISTINCT ON (a.user_id)
    a.user_id,
    a.latitude,
    a.longitude,
    a.city,
    a.state,
    a.country
FROM public.addresses a
ORDER BY a.user_id, a.is_default DESC, a.created_at DESC;

-- Allow authenticated users to read the view (needed for distance calculations)
GRANT SELECT ON public.user_default_address TO authenticated;

-- Add RLS policy on addresses to allow authenticated users to read location columns
-- (This is the most important fix - allows cross-user coordinate lookups)
DO $$
BEGIN
    -- Check if the policy already exists before creating
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'addresses' 
        AND policyname = 'authenticated_read_location'
    ) THEN
        CREATE POLICY authenticated_read_location ON public.addresses
            FOR SELECT
            TO authenticated
            USING (true);
    END IF;
END $$;