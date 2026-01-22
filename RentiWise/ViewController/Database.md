// user

create table public.users (
  id uuid not null,
  email text null,
  full_name text null,
  phone text null,
  profile_photo_url text null,
  created_at timestamp with time zone null default now(),
  constraint users_pkey primary key (id),
  constraint users_email_key unique (email)
) TABLESPACE pg_default;


//item

create table public.items (
  id uuid not null default gen_random_uuid (),
  owner_id uuid not null,
  title text not null,
  description text null,
  category text null,
  condition text null,
  price_per_day numeric(10, 2) null default 0,
  deposit_amount numeric(10, 2) null default 0,
  images text[] null default '{}'::text[],
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint items_pkey primary key (id)
) TABLESPACE pg_default;

create index IF not exists idx_items_owner on public.items using btree (owner_id) TABLESPACE pg_default;

create index IF not exists items_owner_id_idx on public.items using btree (owner_id) TABLESPACE pg_default;

create index IF not exists items_is_active_idx on public.items using btree (is_active) TABLESPACE pg_default;


//request

create table public.requests (
  id uuid not null default gen_random_uuid (),
  item_id uuid not null,
  owner_id uuid not null,
  borrower_id uuid not null,
  start_date date not null,
  end_date date not null,
  pickup_time time with time zone null,
  status text not null default 'pending'::text,
  message text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint requests_pkey primary key (id),
  constraint requests_borrower_id_fkey foreign KEY (borrower_id) references auth.users (id) on delete CASCADE,
  constraint requests_item_id_fkey foreign KEY (item_id) references items (id) on delete CASCADE,
  constraint requests_owner_id_fkey foreign KEY (owner_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists requests_owner_id_idx on public.requests using btree (owner_id) TABLESPACE pg_default;

create index IF not exists requests_borrower_id_idx on public.requests using btree (borrower_id) TABLESPACE pg_default;

create index IF not exists requests_item_id_idx on public.requests using btree (item_id) TABLESPACE pg_default;


//rental-request

create table public.rentals_history (
  id uuid not null default gen_random_uuid (),
  item_id uuid not null,
  owner_id uuid not null,
  borrower_id uuid not null,
  start_date date not null,
  end_date date not null,
  pickup_time time with time zone null,
  total_amount numeric(10, 2) null default 0,
  created_at timestamp with time zone null default now(),
  constraint rentals_history_pkey primary key (id),
  constraint rentals_history_borrower_id_fkey foreign KEY (borrower_id) references auth.users (id) on delete CASCADE,
  constraint rentals_history_item_id_fkey foreign KEY (item_id) references items (id) on delete CASCADE,
  constraint rentals_history_owner_id_fkey foreign KEY (owner_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists rentals_history_owner_id_idx on public.rentals_history using btree (owner_id) TABLESPACE pg_default;

create index IF not exists rentals_history_borrower_id_idx on public.rentals_history using btree (borrower_id) TABLESPACE pg_default;

create index IF not exists rentals_history_item_id_idx on public.rentals_history using btree (item_id) TABLESPACE pg_default;





Final Database Design (Payments System)
1️⃣ payments — main payment record
One row = one payment attempt for a request
Supports retries, COD confirmation, refunds
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),

  -- relations
  request_id uuid not null,
  item_id uuid not null,
  owner_id uuid not null,
  borrower_id uuid not null,

  -- payment details
  provider text not null,  
  -- 'apple_pay', 'card', 'cod'
  
  status text not null default 'pending',
  -- 'pending', 'succeeded', 'failed', 'refunded', 'cancelled'

  currency text not null default 'INR',

  rental_fee numeric(10,2) not null default 0,
  deposit_amount numeric(10,2) not null default 0,
  total_amount numeric(10,2) not null default 0,

  -- revealed ONLY on success
  pickup_code text null,

  -- provider metadata
  provider_payment_id text null,
  provider_receipt_url text null,
  failure_reason text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- constraints
  constraint payments_request_fkey
    foreign key (request_id) references public.requests(id) on delete cascade,

  constraint payments_item_fkey
    foreign key (item_id) references public.items(id) on delete cascade,

  constraint payments_owner_fkey
    foreign key (owner_id) references auth.users(id) on delete cascade,

  constraint payments_borrower_fkey
    foreign key (borrower_id) references auth.users(id) on delete cascade
) tablespace pg_default;
Indexes
create index if not exists payments_request_id_idx on public.payments (request_id);
create index if not exists payments_item_id_idx on public.payments (item_id);
create index if not exists payments_owner_id_idx on public.payments (owner_id);
create index if not exists payments_borrower_id_idx on public.payments (borrower_id);
create index if not exists payments_status_idx on public.payments (status);
✅ Allow only ONE successful payment per request
create unique index if not exists payments_one_success_per_request
on public.payments (request_id)
where status = 'succeeded';
2️⃣ payment_events — audit log (VERY recommended)
Keeps immutable history of what happened
Useful for debugging Apple Pay / COD confirmations
create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),

  payment_id uuid not null,
  event_type text not null,
  -- 'created', 'authorized', 'captured', 'failed', 'refunded', 'cod_confirmed'

  raw_payload jsonb null,
  created_at timestamptz not null default now(),

  constraint payment_events_payment_fkey
    foreign key (payment_id) references public.payments(id) on delete cascade
) tablespace pg_default;
Indexes:
create index if not exists payment_events_payment_id_idx
  on public.payment_events (payment_id);

create index if not exists payment_events_event_type_idx
  on public.payment_events (event_type);
3️⃣ deposit_ledger — deposit hold / release / refund
Clean accounting trail for deposits
Optional, but future-proof
create table if not exists public.deposit_ledger (
  id uuid primary key default gen_random_uuid(),

  payment_id uuid not null,
  request_id uuid not null,
  item_id uuid not null,

  owner_id uuid not null,
  borrower_id uuid not null,

  entry_type text not null,
  -- 'hold', 'release', 'refund'

  amount numeric(10,2) not null default 0,
  notes text null,

  created_at timestamptz not null default now(),

  constraint deposit_ledger_payment_fkey
    foreign key (payment_id) references public.payments(id) on delete cascade,

  constraint deposit_ledger_request_fkey
    foreign key (request_id) references public.requests(id) on delete cascade,

  constraint deposit_ledger_item_fkey
    foreign key (item_id) references public.items(id) on delete cascade,

  constraint deposit_ledger_owner_fkey
    foreign key (owner_id) references auth.users(id) on delete cascade,

  constraint deposit_ledger_borrower_fkey
    foreign key (borrower_id) references auth.users(id) on delete cascade
) tablespace pg_default;
Indexes:
create index if not exists deposit_ledger_payment_id_idx
  on public.deposit_ledger (payment_id);

create index if not exists deposit_ledger_request_id_idx
  on public.deposit_ledger (request_id);

create index if not exists deposit_ledger_entry_type_idx
  on public.deposit_ledger (entry_type);
4️⃣ (Optional but Recommended) Link rentals_history to request
This gives full traceability from request → payment → rental.
alter table public.rentals_history
add column if not exists request_id uuid;

alter table public.rentals_history
add constraint rentals_history_request_fkey
foreign key (request_id) references public.requests(id) on delete set null;

create index if not exists rentals_history_request_id_idx
on public.rentals_history (request_id);


-- =====================================================
-- A) ENABLE ROW LEVEL SECURITY
-- =====================================================

alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.deposit_ledger enable row level security;


-- =====================================================
-- B) PAYMENTS — RLS POLICIES
-- =====================================================

-- Borrower can INSERT payment for their own request
create policy payments_insert_borrower
on public.payments
for insert
to authenticated
with check (
  exists (
    select 1
    from public.requests r
    where r.id = request_id
      and r.borrower_id = auth.uid()
  )
);

-- Borrower can SELECT their own payments
create policy payments_select_borrower
on public.payments
for select
to authenticated
using (borrower_id = auth.uid());

-- Owner can SELECT payments for their items
create policy payments_select_owner
on public.payments
for select
to authenticated
using (owner_id = auth.uid());

-- Borrower can UPDATE only pending payments (minimal)
create policy payments_update_borrower_pending
on public.payments
for update
to authenticated
using (
  borrower_id = auth.uid()
  and status = 'pending'
)
with check (
  borrower_id = auth.uid()
);

-- Owner can CONFIRM Cash on Delivery payments
create policy payments_update_owner_cod
on public.payments
for update
to authenticated
using (
  owner_id = auth.uid()
  and provider = 'cod'
)
with check (
  owner_id = auth.uid()
);


-- =====================================================
-- C) PAYMENT EVENTS — RLS POLICIES
-- =====================================================

-- Users can SELECT events for payments they are involved in
create policy payment_events_select
on public.payment_events
for select
to authenticated
using (
  exists (
    select 1
    from public.payments p
    where p.id = payment_id
      and (
        p.borrower_id = auth.uid()
        or p.owner_id = auth.uid()
      )
  )
);

-- Borrower can INSERT events for their payment
create policy payment_events_insert_borrower
on public.payment_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.payments p
    where p.id = payment_id
      and p.borrower_id = auth.uid()
  )
);

-- Owner can INSERT events (e.g., COD confirmation)
create policy payment_events_insert_owner
on public.payment_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.payments p
    where p.id = payment_id
      and p.owner_id = auth.uid()
  )
);


-- =====================================================
-- D) DEPOSIT LEDGER — READ ONLY FOR CLIENTS
-- =====================================================

create policy deposit_ledger_select
on public.deposit_ledger
for select
to authenticated
using (
  borrower_id = auth.uid()
  or owner_id = auth.uid()
);


-- =====================================================
-- E) UPDATED_AT TRIGGER (PAYMENTS)
-- =====================================================

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_payments_updated_at on public.payments;

create trigger trg_payments_updated_at
before update on public.payments
for each row
execute function public.set_updated_at();



create or replace view public.user_profiles as
select
  id,
  full_name,
  profile_photo_url
from public.users;

grant select on public.user_profiles to authenticated;

alter table public.users enable row level security;

create policy users_read_for_profiles_view
on public.users
for select
to authenticated
using (true);


1. Expose a minimal public view for names and avatar
• You already have user_profiles (id, full_name, profile_photo_url). Keep it and make it readable by anon too.

Run:
grant select on public.user_profiles to anon;

2. If the view doesn’t exist or might be outdated, ensure it’s correct and stable
Run:
create or replace view public.user_profiles as
select
id,
full_name,
profile_photo_url
from public.users;

Then grant:
grant select on public.user_profiles to authenticated;
grant select on public.user_profiles to anon;



-- ===============================
-- REVIEWS TABLE
-- ===============================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),

  item_id uuid not null
    references public.items(id)
    on delete cascade,

  reviewer_id uuid not null
    references public.users(id)
    on delete cascade,

  rating int not null
    check (rating >= 1 and rating <= 5),

  review_text text,

  created_at timestamptz default now()
);

-- ===============================
-- ENABLE ROW LEVEL SECURITY
-- ===============================

alter table public.reviews enable row level security;

-- ===============================
-- RLS POLICIES
-- ===============================

-- Insert: user can add only their own review
drop policy if exists "reviews_insert_own" on public.reviews;
create policy "reviews_insert_own"
on public.reviews
for insert
to authenticated
with check (reviewer_id = auth.uid());

-- Select: anyone can read reviews
drop policy if exists "reviews_select_all" on public.reviews;
create policy "reviews_select_all"
on public.reviews
for select
to anon, authenticated
using (true);

-- Update: user can update only their own review
drop policy if exists "reviews_update_own" on public.reviews;
create policy "reviews_update_own"
on public.reviews
for update
to authenticated
using (reviewer_id = auth.uid())
with check (reviewer_id = auth.uid());

-- Delete: user can delete only their own review
drop policy if exists "reviews_delete_own" on public.reviews;
create policy "reviews_delete_own"
on public.reviews
for delete
to authenticated
using (reviewer_id = auth.uid());

-- ===============================
-- PREVENT DUPLICATE REVIEWS
-- (One review per user per item)
-- ===============================

create unique index if not exists one_review_per_user_per_item
on public.reviews (item_id, reviewer_id);

-- ===============================
-- HELPFUL INDEXES (PERFORMANCE)
-- ===============================

create index if not exists reviews_item_id_idx
on public.reviews (item_id);

create index if not exists reviews_created_at_idx
on public.reviews (created_at desc);


-- =====================================
-- ADDRESSES TABLE
-- =====================================

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  label text,                    -- Home, Office, Hostel, etc.
  full_name text,
  phone text,

  address_line1 text not null,
  address_line2 text,
  city text not null,
  state text not null,
  postal_code text not null,
  country text not null default 'India',

  is_default boolean default false,

  created_at timestamptz default now()
);

-- =====================================
-- ENABLE ROW LEVEL SECURITY
-- =====================================

alter table public.addresses enable row level security;

-- =====================================
-- RLS POLICIES
-- =====================================

-- INSERT: user can add their own address
drop policy if exists "addresses_insert_own" on public.addresses;
create policy "addresses_insert_own"
on public.addresses
for insert
to authenticated
with check (user_id = auth.uid());

-- SELECT: user can view their own addresses
drop policy if exists "addresses_select_own" on public.addresses;
create policy "addresses_select_own"
on public.addresses
for select
to authenticated
using (user_id = auth.uid());

-- UPDATE: user can update their own addresses
drop policy if exists "addresses_update_own" on public.addresses;
create policy "addresses_update_own"
on public.addresses
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- DELETE: user can delete their own addresses
drop policy if exists "addresses_delete_own" on public.addresses;
create policy "addresses_delete_own"
on public.addresses
for delete
to authenticated
using (user_id = auth.uid());

-- =====================================
-- INDEXES (PERFORMANCE)
-- =====================================

create index if not exists addresses_user_id_idx
on public.addresses (user_id);

create index if not exists addresses_created_at_idx
on public.addresses (created_at desc);

create index if not exists addresses_default_idx
on public.addresses (user_id, is_default);

-- =====================================
-- ONE DEFAULT ADDRESS PER USER
-- =====================================

create unique index if not exists one_default_address_per_user
on public.addresses (user_id)
where is_default = true;


alter table public.addresses
add column if not exists latitude double precision,
add column if not exists longitude double precision;

create or replace view public.user_default_address as
select distinct on (a.user_id)
  a.user_id,
  a.id as address_id,
  a.city,
  a.state,
  a.country,
  a.latitude,
  a.longitude,
  a.is_default,
  a.created_at
from public.addresses a
order by
  a.user_id,
  a.is_default desc,
  a.created_at desc;

grant select on public.user_default_address to anon, authenticated;


-- =====================================
-- USER ↔ ITEM DISTANCE CACHE TABLE
-- =====================================

create table if not exists public.user_item_distances (
  id uuid primary key default gen_random_uuid(),

  viewer_user_id uuid not null
    references auth.users(id)
    on delete cascade,

  owner_user_id uuid not null
    references auth.users(id)
    on delete cascade,

  item_id uuid
    references public.items(id)
    on delete cascade,

  viewer_address_hash text not null,
  transport_type text not null default 'automobile',

  road_distance_m integer not null,
  straight_distance_m integer,

  computed_at timestamptz not null default now()
);

-- =====================================
-- ENABLE RLS
-- =====================================

alter table public.user_item_distances enable row level security;

-- =====================================
-- RLS POLICIES
-- =====================================

-- SELECT: viewer can read only their own distances
drop policy if exists "uid_select_own" on public.user_item_distances;
create policy "uid_select_own"
on public.user_item_distances
for select
to authenticated
using (viewer_user_id = auth.uid());

-- INSERT: viewer can insert only their own distances
drop policy if exists "uid_insert_own" on public.user_item_distances;
create policy "uid_insert_own"
on public.user_item_distances
for insert
to authenticated
with check (viewer_user_id = auth.uid());

-- UPDATE: viewer can update only their own distances
drop policy if exists "uid_update_own" on public.user_item_distances;
create policy "uid_update_own"
on public.user_item_distances
for update
to authenticated
using (viewer_user_id = auth.uid())
with check (viewer_user_id = auth.uid());

-- DELETE: viewer can delete only their own distances
drop policy if exists "uid_delete_own" on public.user_item_distances;
create policy "uid_delete_own"
on public.user_item_distances
for delete
to authenticated
using (viewer_user_id = auth.uid());

-- =====================================
-- INDEXES (PERFORMANCE)
-- =====================================

create index if not exists uid_owner_item_idx
on public.user_item_distances (viewer_user_id, owner_user_id, item_id);

create index if not exists uid_address_transport_idx
on public.user_item_distances (viewer_user_id, viewer_address_hash, transport_type);

create index if not exists uid_computed_at_idx
on public.user_item_distances (computed_at desc);


