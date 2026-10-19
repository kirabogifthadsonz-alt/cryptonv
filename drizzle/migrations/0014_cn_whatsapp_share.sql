CREATE TABLE public.cn_share_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  channel text NOT NULL DEFAULT 'whatsapp',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.cn_share_events TO authenticated;
GRANT ALL ON public.cn_share_events TO service_role;
ALTER TABLE public.cn_share_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "share own read" ON public.cn_share_events FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE INDEX cn_share_events_user ON public.cn_share_events(user_id, created_at);

CREATE OR REPLACE FUNCTION public.cn_share_status()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'shares', (SELECT count(*) FROM public.cn_share_events WHERE user_id = auth.uid()),
    'target', 10, 'reward', 2000,
    'claimed', EXISTS(SELECT 1 FROM public.cn_rewards WHERE user_id = auth.uid() AND reference = 'whatsapp_share_10'));
$$;

CREATE OR REPLACE FUNCTION public.cn_record_share()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _uid uuid := auth.uid(); _n int; _last timestamptz;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF EXISTS(SELECT 1 FROM public.cn_rewards WHERE user_id=_uid AND reference='whatsapp_share_10') THEN RETURN public.cn_share_status(); END IF;
  SELECT max(created_at) INTO _last FROM public.cn_share_events WHERE user_id=_uid;
  IF _last IS NULL OR _last < now() - interval '15 seconds' THEN
    INSERT INTO public.cn_share_events(user_id) VALUES(_uid);
  END IF;
  SELECT count(*) INTO _n FROM public.cn_share_events WHERE user_id=_uid;
  IF _n >= 10 THEN
    INSERT INTO public.cn_rewards(user_id,source,reference,coins) VALUES(_uid,'campaign','whatsapp_share_10',2000)
    ON CONFLICT(user_id,source,reference) DO NOTHING;
  END IF;
  RETURN public.cn_share_status();
END $$;
GRANT EXECUTE ON FUNCTION public.cn_share_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cn_record_share() TO authenticated;