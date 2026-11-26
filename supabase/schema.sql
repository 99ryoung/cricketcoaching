-- Fledbury CC coaching app: database setup.
-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.

create extension if not exists pgcrypto;

-- One row per player. Only the coach who created a player can see or change it.
create table if not exists public.players (
  id          text primary key,
  coach_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data        jsonb not null default '{}'::jsonb,
  invite_code text unique,
  updated_at  timestamptz not null default now()
);
alter table public.players enable row level security;
drop policy if exists "coach owns players" on public.players;
create policy "coach owns players" on public.players
  for all to authenticated
  using (coach_id = auth.uid())
  with check (coach_id = auth.uid());

-- Questionnaire answers sent in by players through their link.
-- Players never sign in and can never read anything back.
create table if not exists public.responses (
  id           uuid primary key default gen_random_uuid(),
  invite_code  text not null,
  data         jsonb not null,
  submitted_at timestamptz not null default now(),
  imported_at  timestamptz
);
create index if not exists responses_invite_idx on public.responses(invite_code);
alter table public.responses enable row level security;

drop policy if exists "coach reads own responses" on public.responses;
create policy "coach reads own responses" on public.responses
  for select to authenticated
  using (exists (select 1 from public.players p where p.invite_code = responses.invite_code and p.coach_id = auth.uid()));
drop policy if exists "coach updates own responses" on public.responses;
create policy "coach updates own responses" on public.responses
  for update to authenticated
  using (exists (select 1 from public.players p where p.invite_code = responses.invite_code and p.coach_id = auth.uid()));
drop policy if exists "coach deletes own responses" on public.responses;
create policy "coach deletes own responses" on public.responses
  for delete to authenticated
  using (exists (select 1 from public.players p where p.invite_code = responses.invite_code and p.coach_id = auth.uid()));

-- What a player's link is allowed to see: first name, squad and age group only.
create or replace function public.get_invite(code text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'first', split_part(coalesce(data->>'name', ''), ' ', 1),
    'squad', data->>'squad',
    'ageGroup', data->>'ageGroup')
  from public.players where invite_code = code and length(code) >= 10;
$$;

-- How a player's answers get in: only with a valid link, at most 5 a day, size-capped.
create or replace function public.submit_questionnaire(code text, payload jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if length(code) < 10 or not exists (select 1 from public.players where invite_code = code) then
    return false;
  end if;
  if (select count(*) from public.responses where invite_code = code and submitted_at > now() - interval '1 day') >= 5 then
    return false;
  end if;
  if pg_column_size(payload) > 100000 then
    return false;
  end if;
  insert into public.responses (invite_code, data) values (code, payload);
  return true;
end;
$$;

revoke all on function public.get_invite(text) from public;
revoke all on function public.submit_questionnaire(text, jsonb) from public;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.submit_questionnaire(text, jsonb) to anon, authenticated;
