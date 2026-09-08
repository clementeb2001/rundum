-- Run ONLY in an isolated Supabase test project after 001_initial.sql.
-- All fixtures roll back. This script has not been executed against a provisioned backend.
begin;
insert into auth.users(id, email) values
 ('10000000-0000-0000-0000-000000000001', 'owner@example.invalid'),
 ('10000000-0000-0000-0000-000000000002', 'member@example.invalid'),
 ('10000000-0000-0000-0000-000000000003', 'outsider@example.invalid');
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.create_shared_calendar('Access test');
insert into public.dashboard_configs values (auth.uid(), '{"cards":[]}');
do $$ begin
 if (select count(*) from public.shared_calendars) <> 1 then raise exception 'Owner cannot see calendar'; end if;
 begin
  perform public.create_shared_calendar('Must fail');
  raise exception 'FAIL: second owned calendar accepted';
 exception when others then
  if SQLERRM = 'FAIL: second owned calendar accepted' then raise; end if;
 end;
 perform set_config('test.calendar', (select id::text from public.shared_calendars limit 1), true);
 perform set_config('test.invite', public.create_calendar_invite(current_setting('test.calendar')::uuid), true);
end $$;
reset role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.shared_calendars) then raise exception 'Calendar leaked to outsider'; end if;
 if exists(select 1 from public.dashboard_configs) then raise exception 'Layout leaked to outsider'; end if;
 begin
  insert into public.shared_events(calendar_id,title,starts_at,ends_at,created_by) values(current_setting('test.calendar')::uuid,'Unauthorized',now(),now()+interval '1 hour',auth.uid());
  raise exception 'FAIL: unauthorized insert accepted';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select public.join_calendar(current_setting('test.invite'));
insert into public.shared_events(calendar_id,title,starts_at,ends_at,created_by) values(current_setting('test.calendar')::uuid,'Authorized',now(),now()+interval '1 hour',auth.uid());
do $$ begin
 if (select count(*) from public.shared_events) <> 1 then raise exception 'Member cannot read event'; end if;
 begin
  perform public.join_calendar(current_setting('test.invite'));
  raise exception 'FAIL: invite reused';
 exception when others then
  if SQLERRM = 'FAIL: invite reused' then raise; end if;
 end;
end $$;
select public.leave_calendar(current_setting('test.calendar')::uuid);
do $$ begin
 if exists(select 1 from public.shared_events) then raise exception 'Events visible after leaving'; end if;
end $$;
reset role;
rollback;
