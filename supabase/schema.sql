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

-- Newer Supabase projects don't give the signed-in role table access automatically.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.players to authenticated;
grant select, update, delete on public.responses to authenticated;

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

-- Player view (r.html): a read-only page a player can open with their own link.
-- Returns only the summary the coach dashboard prepares for the player, nothing else.
alter table public.players add column if not exists report_code text unique;
create or replace function public.get_report(code text)
returns json language sql stable security definer set search_path = public as $$
  select (data->'report')::json from public.players
  where report_code = code and length(code) >= 10;
$$;
revoke all on function public.get_report(text) from public;
grant execute on function public.get_report(text) to anon, authenticated;

-- Player profile edits from the player view. They land in responses (kind "profile");
-- the coach dashboard applies them automatically. get_report shows them straight away.
drop policy if exists "coach reads own responses" on public.responses;
create policy "coach reads own responses" on public.responses
  for select to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code) and p.coach_id = auth.uid()));
drop policy if exists "coach updates own responses" on public.responses;
create policy "coach updates own responses" on public.responses
  for update to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code) and p.coach_id = auth.uid()));
drop policy if exists "coach deletes own responses" on public.responses;
create policy "coach deletes own responses" on public.responses
  for delete to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code) and p.coach_id = auth.uid()));

create or replace function public.update_profile(code text, payload jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if length(code) < 10 or not exists (select 1 from public.players where report_code = code) then
    return false;
  end if;
  if (select count(*) from public.responses where invite_code = code and submitted_at > now() - interval '1 day') >= 20 then
    return false;
  end if;
  if pg_column_size(payload) > 30000 then
    return false;
  end if;
  insert into public.responses (invite_code, data)
  values (code, jsonb_build_object('kind', 'profile', 'profile', coalesce(payload->'profile', '{}'::jsonb), 'health', coalesce(payload->>'health', '')));
  return true;
end;
$$;
revoke all on function public.update_profile(text, jsonb) from public;
grant execute on function public.update_profile(text, jsonb) to anon, authenticated;

create or replace function public.get_report(code text)
returns json language plpgsql stable security definer set search_path = public as $$
declare rep jsonb; prof jsonb; r record;
begin
  select data->'report' into rep from public.players where report_code = code and length(code) >= 10;
  if rep is null then return null; end if;
  prof := coalesce(rep->'profile', '{}'::jsonb);
  for r in select data from public.responses
           where invite_code = code and imported_at is null and data->>'kind' = 'profile'
           order by submitted_at loop
    prof := prof || (coalesce(r.data->'profile', '{}'::jsonb) - 'fmt')
                 || jsonb_build_object('fmt', coalesce(prof->'fmt', '{}'::jsonb) || coalesce(r.data->'profile'->'fmt', '{}'::jsonb));
  end loop;
  return (rep || jsonb_build_object('profile', prof))::json;
end;
$$;

-- =====================================================================
-- Player logins (email + password). Run after everything above.
-- Coaches: anyone already signed up when this first runs becomes a coach.
-- Players: can only create an account if a coach has added their email.
-- =====================================================================
create table if not exists public.coaches (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email   text
);
insert into public.coaches (user_id, email)
  select id, lower(email) from auth.users
  where not exists (select 1 from public.coaches)
on conflict do nothing;
alter table public.coaches enable row level security;
drop policy if exists "coach sees self" on public.coaches;
create policy "coach sees self" on public.coaches for select to authenticated using (user_id = auth.uid());
grant select on public.coaches to authenticated;

create or replace function public.is_coach()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coaches where user_id = auth.uid());
$$;
grant execute on function public.is_coach() to authenticated;

-- Only coaches can see or change player files.
drop policy if exists "coach owns players" on public.players;
create policy "coach owns players" on public.players
  for all to authenticated
  using (coach_id = auth.uid() and public.is_coach())
  with check (coach_id = auth.uid() and public.is_coach());

-- Which emails may sign in to see which player (a parent can have more than one child).
create table if not exists public.player_logins (
  email     text not null,
  player_id text not null references public.players(id) on delete cascade,
  coach_id  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  added_at  timestamptz not null default now(),
  primary key (email, player_id)
);
alter table public.player_logins enable row level security;
drop policy if exists "coach manages logins" on public.player_logins;
create policy "coach manages logins" on public.player_logins
  for all to authenticated
  using (coach_id = auth.uid() and public.is_coach())
  with check (coach_id = auth.uid() and public.is_coach()
              and exists (select 1 from public.players p where p.id = player_id and p.coach_id = auth.uid()));
grant select, insert, delete on public.player_logins to authenticated;

-- Block sign-ups from emails no coach has approved.
create or replace function public.only_approved_signups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.player_logins where email = lower(new.email))
     or exists (select 1 from public.coaches where email = lower(new.email)) then
    return new;
  end if;
  raise exception 'This email has not been given access by a coach';
end;
$$;
drop trigger if exists only_approved_signups on auth.users;
create trigger only_approved_signups before insert on auth.users
  for each row execute function public.only_approved_signups();

-- Profile edits from signed-in players are stored as responses with code 'pid:<player id>'.
drop policy if exists "coach reads own responses" on public.responses;
create policy "coach reads own responses" on public.responses
  for select to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code or 'pid:' || p.id = responses.invite_code) and p.coach_id = auth.uid()));
drop policy if exists "coach updates own responses" on public.responses;
create policy "coach updates own responses" on public.responses
  for update to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code or 'pid:' || p.id = responses.invite_code) and p.coach_id = auth.uid()));
drop policy if exists "coach deletes own responses" on public.responses;
create policy "coach deletes own responses" on public.responses
  for delete to authenticated
  using (exists (select 1 from public.players p where (p.invite_code = responses.invite_code or p.report_code = responses.invite_code or 'pid:' || p.id = responses.invite_code) and p.coach_id = auth.uid()));

-- What a signed-in player gets: the summary of each player their email is approved for.
create or replace function public.my_plans()
returns json language plpgsql stable security definer set search_path = public as $$
declare out jsonb := '[]'::jsonb; p record; rep jsonb; prof jsonb; r record;
begin
  for p in select pl.id, pl.data, pl.report_code from public.players pl
           join public.player_logins l on l.player_id = pl.id
           where l.email = lower(auth.jwt()->>'email') order by pl.data->>'name' loop
    rep := coalesce(p.data->'report', '{}'::jsonb);
    prof := coalesce(rep->'profile', '{}'::jsonb);
    for r in select data from public.responses
             where invite_code in ('pid:' || p.id, coalesce(p.report_code, '-'))
               and imported_at is null and data->>'kind' = 'profile'
             order by submitted_at loop
      prof := prof || (coalesce(r.data->'profile', '{}'::jsonb) - 'fmt')
                   || jsonb_build_object('fmt', coalesce(prof->'fmt', '{}'::jsonb) || coalesce(r.data->'profile'->'fmt', '{}'::jsonb));
    end loop;
    out := out || jsonb_build_array(jsonb_build_object('id', p.id, 'report', rep || jsonb_build_object('profile', prof)));
  end loop;
  return out::json;
end;
$$;
grant execute on function public.my_plans() to authenticated;

create or replace function public.update_my_profile(pid text, payload jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.player_logins where player_id = pid and email = lower(auth.jwt()->>'email')) then
    return false;
  end if;
  if (select count(*) from public.responses where invite_code = 'pid:' || pid and submitted_at > now() - interval '1 day') >= 20 then
    return false;
  end if;
  if pg_column_size(payload) > 30000 then
    return false;
  end if;
  insert into public.responses (invite_code, data)
  values ('pid:' || pid, jsonb_build_object('kind', 'profile', 'profile', coalesce(payload->'profile', '{}'::jsonb), 'health', coalesce(payload->>'health', '')));
  return true;
end;
$$;
revoke all on function public.update_my_profile(text, jsonb) from public;
grant execute on function public.update_my_profile(text, jsonb) to authenticated;
