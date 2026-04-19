-- NotchPet v2 initial schema.
--
-- Tables:
--   profiles   -- one row per auth.users (auto-created via trigger)
--   pets       -- current living pet + all historical departed pets
--   marriages  -- each local user's view of their own marriage record
--
-- RLS: every row is only visible/mutable by its owner (auth.uid()).
-- Sign in with Apple is configured separately in the Supabase dashboard.


-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  email        text,
  device_label text
);

alter table public.profiles enable row level security;

create policy "own profile rw" on public.profiles
  for all
  using (id = auth.uid())
  with check (id = auth.uid());

-- Auto-create a profile row whenever a new auth.users row is inserted
-- (both anonymous sign-ins and Apple sign-ins go through auth.users).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------------
-- pets — both current and historical. `departed_at` distinguishes them.
-- ---------------------------------------------------------------------------

create table if not exists public.pets (
  id                  uuid primary key,
  owner_id            uuid not null references public.profiles(id) on delete cascade,
  name                text not null,
  species             text not null,
  personality         text,
  generation          int  not null,
  born_at             timestamptz not null,
  departed_at         timestamptz,
  parents             uuid[],
  feed_count          int  not null default 0,
  play_count          int  not null default 0,
  weight              int  not null default 0,
  age_active_seconds  double precision not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists pets_owner_departed_idx
  on public.pets (owner_id, departed_at desc nulls first);

alter table public.pets enable row level security;

create policy "own pets rw" on public.pets
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Keep `updated_at` fresh on every mutation.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists pets_touch_updated_at on public.pets;
create trigger pets_touch_updated_at
  before update on public.pets
  for each row execute function public.touch_updated_at();


-- ---------------------------------------------------------------------------
-- marriages — each row captures the owner's side of a marriage.
-- ---------------------------------------------------------------------------

create table if not exists public.marriages (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.profiles(id) on delete cascade,
  own_pet_id        uuid not null,
  partner_pet_id    uuid not null,
  partner_snapshot  jsonb not null,
  married_at        timestamptz not null,
  ended_at          timestamptz,
  created_at        timestamptz not null default now()
);

create index if not exists marriages_owner_idx
  on public.marriages (owner_id, married_at desc);

alter table public.marriages enable row level security;

create policy "own marriages rw" on public.marriages
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
