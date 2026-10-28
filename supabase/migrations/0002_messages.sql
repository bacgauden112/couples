-- MVP 2: realtime chat

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index messages_couple_created_idx on public.messages (couple_id, created_at desc);

alter table public.messages enable row level security;

create policy "messages read members" on public.messages for select
  using (public.is_couple_member(couple_id));

create policy "messages insert own" on public.messages for insert
  with check (public.is_couple_member(couple_id) and sender_id = auth.uid());

-- Read receipts: only the recipient can mark the partner's messages as read.
create or replace function public.mark_messages_read(cid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_couple_member(cid) then raise exception 'not a member'; end if;
  update public.messages
     set read_at = now()
   where couple_id = cid and sender_id <> auth.uid() and read_at is null;
end $$;

revoke execute on function public.mark_messages_read(uuid) from public, anon;
grant execute on function public.mark_messages_read(uuid) to authenticated;

alter publication supabase_realtime add table public.messages;
