/*
# Create the Relivator application schema in Supabase Postgres

1. Purpose
- Creates the server-side tables required by the imported Relivator application.
- Keeps the existing Better Auth, UploadThing, and Polar/checkout table names and column shapes so the dashboard and billing pages can query real records without code-side translation.

2. New enum
- `public.type` stores whether an uploaded media record is an `image` or `video`.

3. New tables and columns
- `public.user`: Better Auth user profiles, including name, email, optional profile fields, and two-factor status.
- `public.session`: Better Auth sessions linked to users.
- `public.account`: Better Auth password and provider account records linked to users.
- `public.verification`: Better Auth verification tokens.
- `public.two_factor`: Better Auth two-factor secrets and backup codes linked to users.
- `public.uploads`: UploadThing media records linked to users, including file key, URL, media type, and timestamps.
- `public.polar_customer`: The payment-provider customer ID linked to a user.
- `public.polar_subscription`: Subscription/order status records linked to a user and payment-provider customer.

4. Integrity and compatibility
- Foreign keys remove dependent authentication, upload, and billing records when their user is deleted.
- Unique constraints protect emails, session tokens, customer IDs, and subscription IDs from duplicates.
- Existing table definitions are preserved when this migration is re-run.

5. Security
- Row Level Security is enabled on every application table.
- Direct browser roles `anon` and `authenticated` receive no table access; the application reads and writes through its server-side database connection, where Better Auth can enforce the signed-in user context.
- No public Data API policy is added for these private server-managed records.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'type'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    CREATE TYPE public.type AS ENUM ('image', 'video');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public."user" (
  age integer,
  created_at timestamp NOT NULL,
  email text NOT NULL UNIQUE,
  email_verified boolean NOT NULL,
  first_name text,
  id text PRIMARY KEY,
  image text,
  last_name text,
  name text NOT NULL,
  two_factor_enabled boolean,
  updated_at timestamp NOT NULL
);

CREATE TABLE IF NOT EXISTS public.session (
  created_at timestamp NOT NULL,
  expires_at timestamp NOT NULL,
  id text PRIMARY KEY,
  ip_address text,
  token text NOT NULL UNIQUE,
  updated_at timestamp NOT NULL,
  user_agent text,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.account (
  access_token text,
  access_token_expires_at timestamp,
  account_id text NOT NULL,
  created_at timestamp NOT NULL,
  id text PRIMARY KEY,
  id_token text,
  password text,
  provider_id text NOT NULL,
  refresh_token text,
  refresh_token_expires_at timestamp,
  scope text,
  updated_at timestamp NOT NULL,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.verification (
  created_at timestamp,
  expires_at timestamp NOT NULL,
  id text PRIMARY KEY,
  identifier text NOT NULL,
  updated_at timestamp,
  value text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.two_factor (
  backup_codes text NOT NULL,
  id text PRIMARY KEY,
  secret text NOT NULL,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.uploads (
  created_at timestamp NOT NULL DEFAULT now(),
  id text PRIMARY KEY,
  key text NOT NULL,
  type public.type NOT NULL,
  updated_at timestamp NOT NULL DEFAULT now(),
  url text NOT NULL,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.polar_customer (
  created_at timestamp NOT NULL,
  customer_id text NOT NULL UNIQUE,
  id text PRIMARY KEY,
  updated_at timestamp NOT NULL,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.polar_subscription (
  created_at timestamp NOT NULL,
  customer_id text NOT NULL,
  id text PRIMARY KEY,
  product_id text NOT NULL,
  status text NOT NULL,
  subscription_id text NOT NULL UNIQUE,
  updated_at timestamp NOT NULL,
  user_id text NOT NULL REFERENCES public."user" (id) ON DELETE CASCADE
);

ALTER TABLE public."user" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.two_factor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polar_customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polar_subscription ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE
  public."user",
  public.session,
  public.account,
  public.verification,
  public.two_factor,
  public.uploads,
  public.polar_customer,
  public.polar_subscription
FROM anon, authenticated;
