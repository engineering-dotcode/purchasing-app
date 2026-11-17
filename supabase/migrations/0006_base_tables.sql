-- Base tables that 0007_purchase_orders.sql references: organizations, vendors, products.
--
-- Numbered 0006, not "next number", on purpose: these tables existed before
-- 0007 but were missing from this repository, so a fresh database could not
-- apply 0007. They must run first.

-- Tenant comes from the signed JWT, never from the request payload.
-- Defined here because the policies below need it; 0007 re-creates it with the same body.
create or replace function current_org_id() returns uuid
language sql stable as $$
  select (auth.jwt() ->> 'org_id')::uuid
$$;

-- Organizations are the tenants themselves, so they have no organization_id.
create table organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

alter table organizations enable row level security;

-- A user sees only their own organization. Read-only from the client:
-- organizations are created by the platform, not by tenants.
create policy organizations_tenant on organizations
  for select
  using (id = current_org_id() and deleted_at is null);

create table vendors (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  name            text not null,
  email           text,
  created_by      uuid not null references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create unique index vendors_name_uq
  on vendors (organization_id, name)
  where deleted_at is null;

alter table vendors enable row level security;

create policy vendors_tenant on vendors
  for all
  using (organization_id = current_org_id() and deleted_at is null)
  with check (organization_id = current_org_id());

create table products (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  sku             text not null,
  name            text not null,
  unit_price      numeric(14,2) not null default 0 check (unit_price >= 0),
  created_by      uuid not null references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create unique index products_sku_uq
  on products (organization_id, sku)
  where deleted_at is null;

alter table products enable row level security;

create policy products_tenant on products
  for all
  using (organization_id = current_org_id() and deleted_at is null)
  with check (organization_id = current_org_id());
