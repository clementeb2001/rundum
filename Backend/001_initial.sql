-- Run once in a new Supabase project's SQL editor. No health data is stored here.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.dashboard_configs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  configuration jsonb not null check (jsonb_typeof(configuration) = 'object' and octet_length(configuration::text) < 32768)
);
create table public.shared_calendars (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 100),
  owner_id uuid not null references auth.users(id) on delete cascade
);
create table public.calendar_members (
  calendar_id uuid not null references public.shared_calendars(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (calendar_id, user_id)
);
create table public.shared_events (
  id uuid primary key default gen_random_uuid(),
  calendar_id uuid not null references public.shared_calendars(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 300),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  created_by uuid not null references auth.users(id) on delete cascade
);
create index shared_events_window on public.shared_events(calendar_id, starts_at);
create table private.calendar_invites (
  calendar_id uuid primary key references public.shared_calendars(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null
);
create function private.is_calendar_member(target uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.calendar_members where calendar_id = target and user_id = auth.uid());
$$;
create function private.owns_calendar(target uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.shared_calendars where id = target and owner_id = auth.uid());
$$;
revoke all on function private.is_calendar_member(uuid), private.owns_calendar(uuid) from public;
grant execute on function private.is_calendar_member(uuid), private.owns_calendar(uuid) to authenticated;

alter table public.dashboard_configs enable row level security;
alter table public.shared_calendars enable row level security;
alter table public.calendar_members enable row level security;
alter table public.shared_events enable row level security;
alter table private.calendar_invites enable row level security;
create policy own_config on public.dashboard_configs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy member_calendars on public.shared_calendars for select to authenticated using (private.is_calendar_member(id));
create policy own_membership on public.calendar_members for select to authenticated using (user_id = auth.uid());
create policy read_events on public.shared_events for select to authenticated using (private.is_calendar_member(calendar_id));
create policy insert_events on public.shared_events for insert to authenticated with check (private.is_calendar_member(calendar_id) and created_by = auth.uid());
create policy delete_events on public.shared_events for delete to authenticated using (private.is_calendar_member(calendar_id) and (created_by = auth.uid() or private.owns_calendar(calendar_id)));
create policy update_events on public.shared_events for update to authenticated using (private.is_calendar_member(calendar_id) and (created_by = auth.uid() or private.owns_calendar(calendar_id))) with check (private.is_calendar_member(calendar_id) and (created_by = auth.uid() or private.owns_calendar(calendar_id)));

-- Writes to calendars/members/invites are only possible through scoped RPCs.
revoke all on public.dashboard_configs, public.shared_calendars, public.calendar_members, public.shared_events from anon, authenticated;
grant select, insert, update, delete on public.dashboard_configs to authenticated;
grant select on public.shared_calendars, public.calendar_members to authenticated;
grant select, insert, delete on public.shared_events to authenticated;
grant update(title, starts_at, ends_at) on public.shared_events to authenticated;

create function public.create_shared_calendar(calendar_name text) returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid; actor uuid := auth.uid();
begin
 if actor is null then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
 -- One owned calendar in this release. Never trust a client-provided Pro flag.
 if exists(select 1 from public.shared_calendars where owner_id = actor) then raise exception 'One owned shared calendar per account in this release'; end if;
 insert into public.shared_calendars(name, owner_id) values(trim(calendar_name), actor) returning id into result;
 insert into public.calendar_members values(result, actor);
 return result;
end;
$$;
create function public.create_calendar_invite(target_calendar uuid) returns text language plpgsql security definer set search_path = '' as $$
declare token text;
begin
 if not private.owns_calendar(target_calendar) then raise exception 'Calendar owner required'; end if;
 token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
 insert into private.calendar_invites values(target_calendar, encode(extensions.digest(token, 'sha256'), 'hex'), now() + interval '7 days')
 on conflict(calendar_id) do update set token_hash = excluded.token_hash, expires_at = excluded.expires_at;
 return token;
end;
$$;
create function public.join_calendar(invite_code text) returns uuid language plpgsql security definer set search_path = '' as $$
declare target uuid; actor uuid := auth.uid();
begin
 if actor is null then raise exception 'Authentication required'; end if;
 if length(invite_code) <> 64 then raise exception 'Invalid or expired invitation'; end if;
 delete from private.calendar_invites where token_hash = encode(extensions.digest(invite_code, 'sha256'), 'hex') and expires_at > now() returning calendar_id into target;
 if target is null then raise exception 'Invalid or expired invitation'; end if;
 insert into public.calendar_members values(target, actor) on conflict do nothing;
 return target;
end;
$$;
create function public.leave_calendar(target_calendar uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if private.owns_calendar(target_calendar) then delete from public.shared_calendars where id = target_calendar;
 else delete from public.calendar_members where calendar_id = target_calendar and user_id = auth.uid(); end if;
end;
$$;
create function public.delete_own_account() returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.create_shared_calendar(text), public.create_calendar_invite(uuid), public.join_calendar(text), public.leave_calendar(uuid), public.delete_own_account() from public, anon;
grant execute on function public.create_shared_calendar(text), public.create_calendar_invite(uuid), public.join_calendar(text), public.leave_calendar(uuid), public.delete_own_account() to authenticated;
