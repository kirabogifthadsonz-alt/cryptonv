create table public.admin_roles (user_id uuid primary key, role text not null default 'admin', created_at timestamptz not null default now());
create table public.profiles (user_id uuid primary key, username text, full_name text, phone text, country text, timezone text, updated_at timestamptz not null default now(), created_at timestamptz not null default now());
create table public.accounts (id uuid primary key default gen_random_uuid(), user_id uuid not null unique, currency text not null default 'USD', status text not null default 'active', created_at timestamptz not null default now());
create table public.user_restrictions (user_id uuid primary key, status text not null default 'active', reason text, updated_at timestamptz not null default now());
create table public.ledger_entries (id uuid primary key default gen_random_uuid(), user_id uuid not null, kind text not null check (kind in ('deposit','investment','investment_return','withdrawal','withdrawal_reversal','adjustment')), amount_cents bigint not null, reference_id text, status text not null default 'posted' check (status in ('pending','posted','reversed','failed')), description text not null default '', created_at timestamptz not null default now());
create index on public.ledger_entries(user_id, created_at desc);
create table public.investment_cycles (id uuid primary key default gen_random_uuid(), user_id uuid not null, plan_name text not null, principal_cents bigint not null check (principal_cents > 0), started_at timestamptz not null default now(), ends_at timestamptz not null, status text not null default 'active' check (status in ('active','completed','cancelled')), created_at timestamptz not null default now());
create table public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null, title text not null, body text not null, type text not null default 'info', unread boolean not null default true, created_at timestamptz not null default now());
create table public.support_messages (id uuid primary key default gen_random_uuid(), user_id uuid not null, subject text not null, message text not null, status text not null default 'open', created_at timestamptz not null default now());
create table public.withdrawal_requests (id uuid primary key default gen_random_uuid(), user_id uuid not null, account_id uuid not null references public.accounts(id) on delete cascade, amount_cents bigint not null check (amount_cents > 0), destination text not null, status text not null default 'pending' check (status in ('pending','approved','rejected','paid')), note text, reviewed_by uuid, reviewed_at timestamptz, paid_at timestamptz, requested_at timestamptz not null default now());
create table public.kyc_reviews (id uuid primary key default gen_random_uuid(), user_id uuid not null, document_type text, status text not null default 'pending' check (status in ('pending','approved','rejected')), reason text, reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz not null default now());
create table public.audit_log (id uuid primary key default gen_random_uuid(), actor_id uuid, action text not null, target_user_id uuid, target_reference text, created_at timestamptz not null default now());

grant select on public.admin_roles, public.accounts, public.user_restrictions, public.ledger_entries, public.investment_cycles, public.notifications, public.kyc_reviews to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert on public.support_messages, public.withdrawal_requests to authenticated;
grant update (unread) on public.notifications to authenticated;
grant insert on public.kyc_reviews to authenticated;
grant all on public.admin_roles, public.profiles, public.accounts, public.user_restrictions, public.ledger_entries, public.investment_cycles, public.notifications, public.support_messages, public.withdrawal_requests, public.kyc_reviews, public.audit_log to service_role;

alter table public.admin_roles enable row level security;
alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.user_restrictions enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.investment_cycles enable row level security;
alter table public.notifications enable row level security;
alter table public.support_messages enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.kyc_reviews enable row level security;
alter table public.audit_log enable row level security;

create or replace function public.is_admin(_uid uuid) returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.admin_roles where user_id=_uid) $$;

create policy "own role" on public.admin_roles for select to authenticated using (user_id = auth.uid());
create policy "own profile read" on public.profiles for select to authenticated using (user_id = auth.uid());
create policy "own profile update" on public.profiles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own account" on public.accounts for select to authenticated using (user_id = auth.uid());
create policy "own restriction" on public.user_restrictions for select to authenticated using (user_id = auth.uid());
create policy "own ledger" on public.ledger_entries for select to authenticated using (user_id = auth.uid());
create policy "own cycles" on public.investment_cycles for select to authenticated using (user_id = auth.uid());
create policy "own notifications" on public.notifications for select to authenticated using (user_id = auth.uid());
create policy "mark notifications" on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own support read" on public.support_messages for select to authenticated using (user_id = auth.uid());
create policy "own support insert" on public.support_messages for insert to authenticated with check (user_id = auth.uid() and status = 'open');
create policy "own withdrawals read" on public.withdrawal_requests for select to authenticated using (user_id = auth.uid());
create policy "own withdrawals insert" on public.withdrawal_requests for insert to authenticated with check (user_id = auth.uid() and status = 'pending' and reviewed_by is null and paid_at is null and exists(select 1 from public.accounts a where a.id = account_id and a.user_id = auth.uid()));
create policy "own kyc read" on public.kyc_reviews for select to authenticated using (user_id = auth.uid());
create policy "own kyc insert" on public.kyc_reviews for insert to authenticated with check (user_id = auth.uid() and status = 'pending' and reviewed_by is null);

create or replace function public.ensure_account() returns void language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); m jsonb;
begin
  if u is null then return; end if;
  select raw_user_meta_data into m from auth.users where id = u;
  insert into public.profiles(user_id, username, full_name, phone, country, timezone)
    values (u, m->>'username', coalesce(m->>'username',''), m->>'phone', coalesce(m->>'country','Uganda'), 'Africa/Kampala')
    on conflict (user_id) do nothing;
  insert into public.accounts(user_id) values (u) on conflict (user_id) do nothing;
  insert into public.user_restrictions(user_id) values (u) on conflict (user_id) do nothing;
end $$;
revoke all on function public.ensure_account() from public, anon;
grant execute on function public.ensure_account() to authenticated;

create or replace function public.admin_guard() returns void language plpgsql stable security definer set search_path = public as $$
begin if not public.is_admin(auth.uid()) then raise exception 'Admin access required'; end if; end $$;

create or replace function public.admin_overview() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return jsonb_build_object(
 'users',(select count(*) from auth.users),
 'total_deposits_cents',(select coalesce(sum(amount_cents),0) from ledger_entries where kind='deposit' and status='posted'),
 'total_withdrawals_cents',(select coalesce(sum(amount_cents),0) from withdrawal_requests where status='paid'),
 'pending_withdrawals_cents',(select coalesce(sum(amount_cents),0) from withdrawal_requests where status='approved'),
 'pending_withdrawals',(select count(*) from withdrawal_requests where status='pending'),
 'pending_kyc',(select count(*) from kyc_reviews where status='pending'),
 'restricted_users',(select count(*) from user_restrictions where status<>'active'));
end $$;

create or replace function public.admin_list_users() returns table(user_id uuid, email text, kyc_status text, restriction_status text, created_at timestamptz) language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return query select u.id, u.email::text,
  coalesce((select k.status from kyc_reviews k where k.user_id=u.id order by k.created_at desc limit 1),'not_submitted'),
  coalesce(r.status,'active'), u.created_at
 from auth.users u left join user_restrictions r on r.user_id=u.id order by u.created_at desc;
end $$;

create or replace function public.admin_list_withdrawals() returns table(id uuid, user_id uuid, email text, amount_cents bigint, destination text, status text, requested_at timestamptz) language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return query select w.id, w.user_id, u.email::text, w.amount_cents, w.destination, w.status, w.requested_at from withdrawal_requests w left join auth.users u on u.id=w.user_id order by w.requested_at desc;
end $$;

create or replace function public.admin_list_kyc() returns table(id uuid, user_id uuid, email text, document_type text, status text, created_at timestamptz) language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return query select k.id, k.user_id, u.email::text, k.document_type, k.status, k.created_at from kyc_reviews k left join auth.users u on u.id=k.user_id order by k.created_at desc;
end $$;

create or replace function public.admin_list_audit() returns table(id uuid, action text, target_user_id uuid, target_reference text, created_at timestamptz) language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return query select a.id, a.action, a.target_user_id, a.target_reference, a.created_at from audit_log a order by a.created_at desc limit 200;
end $$;

create or replace function public.admin_list_support() returns table(id uuid, email text, subject text, message text, status text, created_at timestamptz) language plpgsql stable security definer set search_path = public as $$
begin perform public.admin_guard();
return query select s.id, u.email::text, s.subject, s.message, s.status, s.created_at from support_messages s left join auth.users u on u.id=s.user_id order by s.created_at desc;
end $$;

create or replace function public.admin_set_user_restriction(p_user_id uuid, p_status text, p_reason text) returns void language plpgsql security definer set search_path = public as $$
begin perform public.admin_guard();
if p_status not in ('active','restricted','suspended','closed') then raise exception 'Invalid status'; end if;
insert into user_restrictions(user_id,status,reason,updated_at) values (p_user_id,p_status,p_reason,now())
 on conflict (user_id) do update set status=excluded.status, reason=excluded.reason, updated_at=now();
update accounts set status=p_status where user_id=p_user_id;
insert into audit_log(actor_id,action,target_user_id,target_reference) values (auth.uid(),'user_status_'||p_status,p_user_id,p_reason);
end $$;

create or replace function public.admin_review_withdrawal(p_request_id uuid, p_status text, p_note text) returns void language plpgsql security definer set search_path = public as $$
declare w withdrawal_requests;
begin perform public.admin_guard();
if p_status not in ('approved','rejected') then raise exception 'Invalid status'; end if;
update withdrawal_requests set status=p_status, note=p_note, reviewed_by=auth.uid(), reviewed_at=now() where id=p_request_id and status='pending' returning * into w;
if w.id is null then raise exception 'Request not pending'; end if;
insert into notifications(user_id,title,body,type) values (w.user_id,'Withdrawal '||p_status,coalesce(p_note,'Your withdrawal request was '||p_status||'.'),'info');
insert into audit_log(actor_id,action,target_user_id,target_reference) values (auth.uid(),'withdrawal_'||p_status,w.user_id,w.id::text);
end $$;

create or replace function public.admin_mark_withdrawal_paid(p_request_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare w withdrawal_requests;
begin perform public.admin_guard();
update withdrawal_requests set status='paid', paid_at=now() where id=p_request_id and status='approved' returning * into w;
if w.id is null then raise exception 'Request not approved'; end if;
insert into ledger_entries(user_id,kind,amount_cents,reference_id,status,description) values (w.user_id,'withdrawal',-w.amount_cents,w.id::text,'posted','Withdrawal paid');
insert into notifications(user_id,title,body,type) values (w.user_id,'Withdrawal paid','Your withdrawal has been paid out.','success');
insert into audit_log(actor_id,action,target_user_id,target_reference) values (auth.uid(),'withdrawal_paid',w.user_id,w.id::text);
end $$;

create or replace function public.admin_review_kyc(p_review_id uuid, p_status text, p_reason text) returns void language plpgsql security definer set search_path = public as $$
declare k kyc_reviews;
begin perform public.admin_guard();
if p_status not in ('approved','rejected') then raise exception 'Invalid status'; end if;
update kyc_reviews set status=p_status, reason=p_reason, reviewed_by=auth.uid(), reviewed_at=now() where id=p_review_id and status='pending' returning * into k;
if k.id is null then raise exception 'Review not pending'; end if;
insert into audit_log(actor_id,action,target_user_id,target_reference) values (auth.uid(),'kyc_'||p_status,k.user_id,k.id::text);
end $$;

revoke all on function public.admin_guard(), public.admin_overview(), public.admin_list_users(), public.admin_list_withdrawals(), public.admin_list_kyc(), public.admin_list_audit(), public.admin_list_support(), public.admin_set_user_restriction(uuid,text,text), public.admin_review_withdrawal(uuid,text,text), public.admin_mark_withdrawal_paid(uuid), public.admin_review_kyc(uuid,text,text), public.is_admin(uuid) from public, anon;
grant execute on function public.admin_overview(), public.admin_list_users(), public.admin_list_withdrawals(), public.admin_list_kyc(), public.admin_list_audit(), public.admin_list_support(), public.admin_set_user_restriction(uuid,text,text), public.admin_review_withdrawal(uuid,text,text), public.admin_mark_withdrawal_paid(uuid), public.admin_review_kyc(uuid,text,text), public.admin_guard(), public.is_admin(uuid) to authenticated;