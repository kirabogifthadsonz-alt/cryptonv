create extension if not exists pgcrypto;

create table public.user_pins (
  user_id uuid primary key,
  pin_hash text not null,
  updated_at timestamptz not null default now()
);
grant all on public.user_pins to service_role;
alter table public.user_pins enable row level security;

create or replace function public.set_withdrawal_pin(_pin text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if _pin !~ '^[0-9]{4,6}$' then raise exception 'PIN must be 4 to 6 digits'; end if;
  insert into public.user_pins (user_id, pin_hash, updated_at)
  values (auth.uid(), crypt(_pin, gen_salt('bf')), now())
  on conflict (user_id) do update set pin_hash = excluded.pin_hash, updated_at = now();
end $$;

create or replace function public.has_withdrawal_pin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_pins where user_id = auth.uid())
$$;

create table public.login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  device text not null default 'Unknown device',
  created_at timestamptz not null default now()
);
grant select on public.login_events to authenticated;
grant all on public.login_events to service_role;
alter table public.login_events enable row level security;
create policy "Users read own login events" on public.login_events for select to authenticated using (user_id = auth.uid());

create or replace function public.record_login_event(_device text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if exists (select 1 from public.login_events where user_id = auth.uid() and device = _device and created_at > now() - interval '12 hours') then return; end if;
  insert into public.login_events (user_id, device) values (auth.uid(), left(coalesce(_device,'Unknown device'), 200));
end $$;

create or replace function public.my_login_events()
returns table(device text, created_at timestamptz) language sql stable security definer set search_path = public as $$
  select device, created_at from public.login_events where user_id = auth.uid() order by created_at desc limit 20
$$;