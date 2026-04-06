-- Create the notifications backend used by the iOS app.
-- This migration adds the backing table, secure RPC write path,
-- row-level security, and realtime publication support.

create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    type text not null,
    title text not null,
    message text not null,
    request_id uuid references public.requests(id) on delete cascade,
    item_id uuid references public.items(id) on delete cascade,
    is_read boolean not null default false,
    created_at timestamptz not null default now(),
    constraint notifications_type_check check (
        type in (
            'request_accepted',
            'request_rejected',
            'payment_received',
            'payment_confirmed',
            'pickup_confirmed',
            'new_request',
            'nearby_item_posted'
        )
    ),
    constraint notifications_reference_check check (
        (
            type = 'nearby_item_posted'
            and item_id is not null
            and request_id is null
        )
        or
        (
            type <> 'nearby_item_posted'
            and request_id is not null
            and item_id is null
        )
    )
);

create index if not exists notifications_user_created_at_idx
on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_is_read_idx
on public.notifications (user_id, is_read);

alter table public.notifications enable row level security;

grant select, update on table public.notifications to authenticated;
grant all on table public.notifications to service_role;

do $$
declare
    existing_policy record;
begin
    for existing_policy in
        select policyname
        from pg_policies
        where schemaname = 'public'
          and tablename = 'notifications'
    loop
        execute format(
            'drop policy if exists %I on public.notifications',
            existing_policy.policyname
        );
    end loop;
end
$$;

create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (
    user_id = auth.uid()
);

create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (
    user_id = auth.uid()
)
with check (
    user_id = auth.uid()
);

create or replace function public.create_notification(
    target_user_id uuid,
    notification_type text,
    notification_title text,
    notification_message text,
    request_ref_id uuid default null,
    item_ref_id uuid default null
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
    actor_id uuid := auth.uid();
    request_row public.requests%rowtype;
    item_row public.items%rowtype;
    inserted_row public.notifications;
begin
    if actor_id is null then
        raise exception 'Authentication required'
            using errcode = '42501';
    end if;

    if target_user_id is null then
        raise exception 'target_user_id is required'
            using errcode = '23502';
    end if;

    if coalesce(trim(notification_type), '') = '' then
        raise exception 'notification_type is required'
            using errcode = '22023';
    end if;

    if coalesce(trim(notification_title), '') = '' then
        raise exception 'notification_title is required'
            using errcode = '22023';
    end if;

    if coalesce(trim(notification_message), '') = '' then
        raise exception 'notification_message is required'
            using errcode = '22023';
    end if;

    if notification_type = 'nearby_item_posted' then
        if item_ref_id is null or request_ref_id is not null then
            raise exception 'nearby_item_posted requires item_ref_id only'
                using errcode = '22023';
        end if;

        select *
        into item_row
        from public.items
        where id = item_ref_id;

        if not found then
            raise exception 'Item not found for notification'
                using errcode = '23503';
        end if;

        if item_row.owner_id <> actor_id then
            raise exception 'Only the item owner can send nearby item notifications'
                using errcode = '42501';
        end if;

        if target_user_id = actor_id then
            raise exception 'Nearby item notifications must target another user'
                using errcode = '22023';
        end if;
    else
        if request_ref_id is null or item_ref_id is not null then
            raise exception '% notifications require request_ref_id only', notification_type
                using errcode = '22023';
        end if;

        select *
        into request_row
        from public.requests
        where id = request_ref_id;

        if not found then
            raise exception 'Request not found for notification'
                using errcode = '23503';
        end if;

        if actor_id <> request_row.owner_id and actor_id <> request_row.borrower_id then
            raise exception 'You are not allowed to send notifications for this request'
                using errcode = '42501';
        end if;

        case notification_type
        when 'new_request' then
            if actor_id <> request_row.borrower_id or target_user_id <> request_row.owner_id then
                raise exception 'Only the borrower can notify the owner about a new request'
                    using errcode = '42501';
            end if;
        when 'request_accepted', 'request_rejected', 'payment_confirmed' then
            if actor_id <> request_row.owner_id or target_user_id <> request_row.borrower_id then
                raise exception 'Only the owner can send this notification to the borrower'
                    using errcode = '42501';
            end if;
        when 'payment_received' then
            if actor_id <> request_row.borrower_id or target_user_id <> request_row.owner_id then
                raise exception 'Only the borrower can notify the owner that payment was sent'
                    using errcode = '42501';
            end if;
        when 'pickup_confirmed' then
            if actor_id <> request_row.owner_id
               or (
                   target_user_id <> request_row.owner_id
                   and target_user_id <> request_row.borrower_id
               ) then
                raise exception 'Only the owner can send pickup confirmation notifications for this request'
                    using errcode = '42501';
            end if;
        else
            raise exception 'Unsupported notification_type: %', notification_type
                using errcode = '22023';
        end case;
    end if;

    insert into public.notifications (
        user_id,
        type,
        title,
        message,
        request_id,
        item_id,
        is_read
    )
    values (
        target_user_id,
        notification_type,
        notification_title,
        notification_message,
        request_ref_id,
        item_ref_id,
        false
    )
    returning *
    into inserted_row;

    return inserted_row;
end;
$$;

revoke all on function public.create_notification(uuid, text, text, text, uuid, uuid) from public;
grant execute on function public.create_notification(uuid, text, text, text, uuid, uuid) to authenticated;
grant execute on function public.create_notification(uuid, text, text, text, uuid, uuid) to service_role;

do $$
begin
    if exists (
        select 1
        from pg_publication
        where pubname = 'supabase_realtime'
    ) and not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'notifications'
    ) then
        alter publication supabase_realtime add table public.notifications;
    end if;
end
$$;
