-- MVP 1: profiles, couples, pairing (max 2 members), RLS

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 8)),
  anniversary date,
  created_at timestamptz not null default now()
);

create table public.couple_members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (couple_id, user_id)
);

-- Helper: is the current user in this couple? (security definer avoids RLS recursion)
create or replace function public.is_couple_member(cid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.couple_members
    where couple_id = cid and user_id = auth.uid()
  );
$$;

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Create a couple and join it as the first member
create or replace function public.create_couple()
returns uuid language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from couple_members where user_id = auth.uid()) then
    raise exception 'already in a couple';
  end if;
  insert into couples default values returning id into cid;
  insert into couple_members (couple_id, user_id) values (cid, auth.uid());
  return cid;
end $$;

-- Join a couple by invite code; refuses when it already has 2 members
create or replace function public.join_couple(code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from couple_members where user_id = auth.uid()) then
    raise exception 'already in a couple';
  end if;
  select id into cid from couples where invite_code = upper(trim(code));
  if cid is null then raise exception 'invalid invite code'; end if;
  if (select count(*) from couple_members where couple_id = cid) >= 2 then
    raise exception 'couple is full';
  end if;
  insert into couple_members (couple_id, user_id) values (cid, auth.uid());
  return cid;
end $$;

alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.couple_members enable row level security;

-- profiles: own profile + partner's profile
create policy "profiles read own or partner" on public.profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.couple_members a
    join public.couple_members b on a.couple_id = b.couple_id
    where a.user_id = auth.uid() and b.user_id = profiles.id
  )
);
create policy "profiles update own" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- couples: members only; members may update (e.g. anniversary)
create policy "couples read members" on public.couples for select
  using (public.is_couple_member(id));
create policy "couples update members" on public.couples for update
  using (public.is_couple_member(id)) with check (public.is_couple_member(id));

-- couple_members: read-only for members; inserts go through the RPCs above
create policy "members read own couple" on public.couple_members for select
  using (public.is_couple_member(couple_id));

revoke execute on function public.create_couple() from public, anon;
revoke execute on function public.join_couple(text) from public, anon;
grant execute on function public.create_couple() to authenticated;
grant execute on function public.join_couple(text) to authenticated;
