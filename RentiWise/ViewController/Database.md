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
