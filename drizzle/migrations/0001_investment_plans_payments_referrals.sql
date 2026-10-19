CREATE TABLE public.investment_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  asset text NOT NULL DEFAULT 'BTC',
  category text NOT NULL DEFAULT 'Short term',
  invest numeric(14,2) NOT NULL,
  earning numeric(14,2) NOT NULL,
  estimated_total numeric(14,2) NOT NULL,
  term_days integer NOT NULL DEFAULT 14,
  status text NOT NULL DEFAULT 'Open',
  hot boolean NOT NULL DEFAULT false,
  risk text NOT NULL DEFAULT 'Medium',
  network text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.investment_plans TO authenticated;
GRANT ALL ON public.investment_plans TO service_role;
ALTER TABLE public.investment_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read plans" ON public.investment_plans FOR SELECT TO authenticated USING (active OR public.is_admin(auth.uid()));
CREATE POLICY "admin insert plans" ON public.investment_plans FOR INSERT TO authenticated WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "admin update plans" ON public.investment_plans FOR UPDATE TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
INSERT INTO public.investment_plans (name,asset,category,invest,earning,estimated_total,term_days,status,hot,risk,network,description,sort_order) VALUES
('Bitcoin Starter','BTC','Short term',5,0.5,7,14,'Open',false,'Medium','Bitcoin','A small starter cycle for exploring the CRYPTONVA experience.',1),
('Bitcoin Hot Cycle','BTC','Short term',101,20,280,14,'Hot',true,'High','Bitcoin','A highlighted plan with a short locked term.',2),
('Ethereum Growth','ETH','Short term',10,1,21,21,'Open',false,'Medium','Ethereum','An ETH growth cycle.',3),
('Litecoin Monthly','LTC','Long term',15,1.5,45,30,'Open',false,'Medium','Litecoin','An LTC monthly cycle.',4),
('Bitcoin Core','BTC','Long term',30,2,60,30,'Open',false,'Medium','Bitcoin','An BTC core cycle.',5),
('Tether Daily','USDT','Long term',50,5,150,30,'Open',false,'High','Tether','An USDT daily cycle.',6),
('Ethereum Prime','ETH','Long term',100,15,450,30,'Open',false,'High','Ethereum','An ETH prime cycle.',7),
('Litecoin Momentum','LTC','Long term',500,30,900,30,'Open',false,'High','Litecoin','An LTC momentum cycle.',8),
('Bitcoin Reserve','BTC','Long term',1000,150,4500,30,'Open',false,'High','Bitcoin','An BTC reserve cycle.',9),
('Ethereum Elite','ETH','Short term',2000,400,5600,14,'Open',false,'High','Ethereum','An ETH elite cycle.',10);

CREATE TABLE public.app_settings (
  key text PRIMARY KEY,
  value numeric NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read settings" ON public.app_settings FOR SELECT TO authenticated USING (true);
INSERT INTO public.app_settings(key,value) VALUES ('referral_bonus_cents',100),('min_withdrawal_cents',1000);

CREATE TABLE public.fx_rates (
  currency text PRIMARY KEY,
  units_per_usd numeric NOT NULL CHECK (units_per_usd > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.fx_rates TO authenticated;
GRANT ALL ON public.fx_rates TO service_role;
ALTER TABLE public.fx_rates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read fx" ON public.fx_rates FOR SELECT TO authenticated USING (true);
INSERT INTO public.fx_rates(currency,units_per_usd) VALUES
('UGX',3700),('KES',129),('RWF',1420),('USD',1),('CDF',2850),('ZMW',26),('XAF',600),('XOF',600),('SLE',22.7);

CREATE TABLE public.payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('deposit','withdrawal')),
  method text NOT NULL DEFAULT 'mobile_money',
  country text NOT NULL,
  currency text NOT NULL,
  local_amount numeric NOT NULL,
  usd_cents bigint NOT NULL,
  phone text,
  marz_uuid text,
  status text NOT NULL DEFAULT 'pending',
  redirect_url text,
  withdrawal_request_id uuid,
  credited boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.payment_transactions TO authenticated;
GRANT ALL ON public.payment_transactions TO service_role;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own payments" ON public.payment_transactions FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.profiles ADD COLUMN referral_code text UNIQUE, ADD COLUMN referred_by uuid;
UPDATE public.profiles SET referral_code = upper(substr(md5(user_id::text || random()::text),1,8)) WHERE referral_code IS NULL;

CREATE TABLE public.referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL,
  referred_id uuid NOT NULL UNIQUE,
  amount_cents bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.referral_rewards TO authenticated;
GRANT ALL ON public.referral_rewards TO service_role;
ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own rewards" ON public.referral_rewards FOR SELECT TO authenticated USING (referrer_id = auth.uid());

CREATE OR REPLACE FUNCTION public.ensure_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare u uuid := auth.uid(); m jsonb; ref uuid;
begin
  if u is null then return; end if;
  select raw_user_meta_data into m from auth.users where id = u;
  select p.user_id into ref from public.profiles p where p.referral_code = upper(coalesce(m->>'ref','')) and p.user_id <> u;
  insert into public.profiles(user_id, username, full_name, phone, country, timezone, referral_code, referred_by)
    values (u, m->>'username', coalesce(m->>'username',''), m->>'phone', coalesce(m->>'country','Uganda'), 'Africa/Kampala',
            upper(substr(md5(u::text || random()::text),1,8)), ref)
    on conflict (user_id) do nothing;
  update public.profiles set referral_code = upper(substr(md5(u::text || random()::text),1,8)) where user_id = u and referral_code is null;
  insert into public.accounts(user_id) values (u) on conflict (user_id) do nothing;
  insert into public.user_restrictions(user_id) values (u) on conflict (user_id) do nothing;
end $$;

CREATE OR REPLACE FUNCTION public.my_referral_stats()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  select jsonb_build_object(
    'code', (select referral_code from profiles where user_id = auth.uid()),
    'count', (select count(*) from profiles where referred_by = auth.uid()),
    'rewarded', (select count(*) from referral_rewards where referrer_id = auth.uid()),
    'earned_cents', (select coalesce(sum(amount_cents),0) from referral_rewards where referrer_id = auth.uid()),
    'bonus_cents', (select value from app_settings where key='referral_bonus_cents'));
$$;
GRANT EXECUTE ON FUNCTION public.my_referral_stats() TO authenticated;

CREATE OR REPLACE FUNCTION public.available_cents(_uid uuid)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  select coalesce((select sum(amount_cents) from ledger_entries where user_id=_uid and status='posted'),0)
       - coalesce((select sum(principal_cents) from investment_cycles where user_id=_uid and status='active'),0)
       - coalesce((select sum(amount_cents) from withdrawal_requests where user_id=_uid and status in ('pending','approved','processing')),0);
$$;

CREATE OR REPLACE FUNCTION public.validate_withdrawal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare minc numeric;
begin
  select value into minc from app_settings where key='min_withdrawal_cents';
  if new.amount_cents < coalesce(minc,0) then raise exception 'Minimum withdrawal is % USD', (minc/100)::numeric(12,2); end if;
  if new.amount_cents > public.available_cents(new.user_id) then raise exception 'Amount exceeds your available balance'; end if;
  if new.destination !~ '^[A-Z]{2}:\+[0-9]{8,15}$' then raise exception 'Enter a valid mobile money number'; end if;
  return new;
end $$;
CREATE TRIGGER withdrawal_validate BEFORE INSERT ON public.withdrawal_requests FOR EACH ROW EXECUTE FUNCTION public.validate_withdrawal();

CREATE OR REPLACE FUNCTION public.credit_deposit(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare t payment_transactions; ref uuid; bonus numeric;
begin
  update payment_transactions set credited=true, status='completed', updated_at=now()
    where id=p_id and kind='deposit' and credited=false returning * into t;
  if t.id is null then return; end if;
  insert into ledger_entries(user_id,kind,amount_cents,reference_id,status,description)
    values (t.user_id,'deposit',t.usd_cents,t.id::text,'posted','Deposit via '||t.method);
  insert into notifications(user_id,title,body,type) values (t.user_id,'Deposit received',
    'Your deposit of '||(t.usd_cents/100.0)::numeric(12,2)||' USD has been added to your balance.','success');
  select referred_by into ref from profiles where user_id=t.user_id;
  select value into bonus from app_settings where key='referral_bonus_cents';
  if ref is not null and coalesce(bonus,0) > 0 and not exists(select 1 from referral_rewards where referred_id=t.user_id) then
    insert into referral_rewards(referrer_id,referred_id,amount_cents) values (ref,t.user_id,bonus);
    insert into ledger_entries(user_id,kind,amount_cents,reference_id,status,description)
      values (ref,'adjustment',bonus,'referral:'||t.user_id,'posted','Referral bonus');
    insert into notifications(user_id,title,body,type) values (ref,'Referral bonus',
      'A friend you invited made their first deposit. You earned '||(bonus/100.0)::numeric(12,2)||' USD.','success');
  end if;
end $$;
REVOKE ALL ON FUNCTION public.credit_deposit(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_deposit(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.finalize_withdrawal(p_request_id uuid, p_success boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare w withdrawal_requests;
begin
  if p_success then
    update withdrawal_requests set status='paid', paid_at=now() where id=p_request_id and status='processing' returning * into w;
    if w.id is null then return; end if;
    insert into ledger_entries(user_id,kind,amount_cents,reference_id,status,description) values (w.user_id,'withdrawal',-w.amount_cents,w.id::text,'posted','Withdrawal paid');
    insert into notifications(user_id,title,body,type) values (w.user_id,'Withdrawal paid','Your withdrawal has been sent to your mobile money.','success');
  else
    update withdrawal_requests set status='failed', note=coalesce(note,'')||' Payout failed' where id=p_request_id and status='processing' returning * into w;
    if w.id is null then return; end if;
    insert into notifications(user_id,title,body,type) values (w.user_id,'Withdrawal failed','We could not send your withdrawal. The amount is back in your available balance.','info');
  end if;
end $$;
REVOKE ALL ON FUNCTION public.finalize_withdrawal(uuid,boolean) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_withdrawal(uuid,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_set_setting(p_key text, p_value numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
begin perform public.admin_guard();
  if p_key not in ('referral_bonus_cents','min_withdrawal_cents') or p_value < 0 then raise exception 'Invalid setting'; end if;
  insert into app_settings(key,value,updated_at) values (p_key,p_value,now()) on conflict (key) do update set value=excluded.value, updated_at=now();
end $$;
CREATE OR REPLACE FUNCTION public.admin_set_fx(p_currency text, p_rate numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
begin perform public.admin_guard();
  if p_rate <= 0 then raise exception 'Invalid rate'; end if;
  update fx_rates set units_per_usd=p_rate, updated_at=now() where currency=p_currency;
end $$;
GRANT EXECUTE ON FUNCTION public.admin_set_setting(text,numeric), public.admin_set_fx(text,numeric) TO authenticated;