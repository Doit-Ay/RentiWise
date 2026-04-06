-- Fix public.items RLS so owners can manage their own listings
-- while everyone can continue browsing active listings.

alter table public.items enable row level security;

do $$
declare
    existing_policy record;
begin
    for existing_policy in
        select policyname
        from pg_policies
        where schemaname = 'public'
          and tablename = 'items'
    loop
        execute format(
            'drop policy if exists %I on public.items',
            existing_policy.policyname
        );
    end loop;
end
$$;

create policy "items_select_active_or_own"
on public.items
for select
to public
using (
    coalesce(is_active, true) = true
    or owner_id = auth.uid()
);

create policy "items_insert_own"
on public.items
for insert
to authenticated
with check (
    owner_id = auth.uid()
);

create policy "items_update_own"
on public.items
for update
to authenticated
using (
    owner_id = auth.uid()
)
with check (
    owner_id = auth.uid()
);
