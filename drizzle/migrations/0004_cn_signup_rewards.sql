CREATE TABLE public.cn_rewards (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL,
 source text NOT NULL CHECK (source IN ('signup','invite','task','campaign')),
 reference text NOT NULL,
 coins numeric NOT NULL CHECK (coins > 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id, source, reference)
);
GRANT SELECT ON public.cn_rewards TO authenticated;
GRANT ALL ON public.cn_rewards TO service_role;
ALTER TABLE public.cn_rewards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own CN rewards" ON public.cn_rewards FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE TABLE public.cn_launch_status (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),
 tge_completed boolean NOT NULL DEFAULT false,
 cex_listed boolean NOT NULL DEFAULT false
);
GRANT SELECT ON public.cn_launch_status TO authenticated;
GRANT ALL ON public.cn_launch_status TO service_role;
ALTER TABLE public.cn_launch_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read CN launch status" ON public.cn_launch_status FOR SELECT TO authenticated USING(true);
CREATE FUNCTION public.cn_signup_reward() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 INSERT INTO public.cn_rewards(user_id,source,reference,coins) VALUES(new.id,'signup','signup',800) ON CONFLICT(user_id,source,reference) DO NOTHING;
 RETURN new;
END;
$$;
REVOKE ALL ON FUNCTION public.cn_signup_reward() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER cn_signup_reward AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.cn_signup_reward();
INSERT INTO public.cn_rewards(user_id,source,reference,coins,created_at)
 SELECT id,'signup','signup',800,created_at FROM auth.users ON CONFLICT(user_id,source,reference) DO NOTHING;
CREATE FUNCTION public.my_cn_rewards() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object(
 'balance',coalesce((SELECT sum(coins) FROM public.cn_rewards WHERE user_id=auth.uid()),0),
 'price_usd',0.48,
 'tge_completed',coalesce((SELECT tge_completed FROM public.cn_launch_status WHERE id),false),
 'cex_listed',coalesce((SELECT cex_listed FROM public.cn_launch_status WHERE id),false),
 'withdrawal_ready',coalesce((SELECT tge_completed AND cex_listed FROM public.cn_launch_status WHERE id),false),
 'rewards',coalesce((SELECT jsonb_agg(r ORDER BY r.created_at DESC) FROM (SELECT id,source,coins,created_at FROM public.cn_rewards WHERE user_id=auth.uid()) r),'[]'::jsonb)
 );
$$;
REVOKE ALL ON FUNCTION public.my_cn_rewards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_cn_rewards() TO authenticated;
COMMENT ON TABLE public.cn_rewards IS 'CN allocations only; never included in cash ledger or payment balances.';