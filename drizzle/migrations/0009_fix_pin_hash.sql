create or replace function public.set_withdrawal_pin(_pin text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if _pin !~ '^[0-9]{4,6}$' then raise exception 'PIN must be 4 to 6 digits'; end if;
  insert into public.user_pins (user_id, pin_hash, updated_at)
  values (auth.uid(), encode(extensions.digest(_pin::bytea, 'sha256'), 'hex'), now())
  on conflict (user_id) do update set pin_hash = excluded.pin_hash, updated_at = now();
end $$;