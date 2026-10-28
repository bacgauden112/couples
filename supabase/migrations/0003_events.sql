-- MVP 3a: custom events / reminders (birthdays, anniversaries, special days)
-- Auto milestones (100/200/365 days...) are computed client-side from couples.anniversary.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 100),
  event_date date not null,
  kind text not null default 'custom' check (kind in ('birthday', 'anniversary', 'holiday', 'custom')),
  repeat_yearly boolean not null default true,
  remind_days_before int not null default 1 check (remind_days_before between 0 and 30),
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index events_couple_idx on public.events (couple_id, event_date);

alter table public.events enable row level security;

create policy "events read members" on public.events for select
  using (public.is_couple_member(couple_id));
create policy "events insert members" on public.events for insert
  with check (public.is_couple_member(couple_id));
create policy "events update members" on public.events for update
  using (public.is_couple_member(couple_id)) with check (public.is_couple_member(couple_id));
create policy "events delete members" on public.events for delete
  using (public.is_couple_member(couple_id));
