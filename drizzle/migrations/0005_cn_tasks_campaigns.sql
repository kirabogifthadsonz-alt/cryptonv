CREATE TABLE public.cn_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 kind text NOT NULL DEFAULT 'social' CHECK (kind IN ('social','invite')),
 title text NOT NULL,
 description text NOT NULL DEFAULT '',
 link text NOT NULL DEFAULT '',
 reward_coins numeric NOT NULL CHECK (reward_coins > 0),
 invite_target integer NOT NULL DEFAULT 0 CHECK (invite_target >= 0),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.cn_tasks TO authenticated;
GRANT ALL ON public.cn_tasks TO service_role;
ALTER TABLE public.cn_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read tasks" ON public.cn_tasks FOR SELECT TO authenticated USING (active OR public.is_admin(auth.uid()));
CREATE POLICY "admin insert tasks" ON public.cn_tasks FOR INSERT TO authenticated WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "admin update tasks" ON public.cn_tasks FOR UPDATE TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE TABLE public.cn_campaigns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL,
 description text NOT NULL DEFAULT '',
 link text NOT NULL DEFAULT '',
 max_participations integer NOT NULL DEFAULT 1 CHECK (max_participations > 0),
 ends_at timestamptz NOT NULL,
 prize_type text NOT NULL DEFAULT 'cn' CHECK (prize_type IN ('cn','cash')),
 prizes numeric[] NOT NULL DEFAULT '{}',
 status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','hidden','paid')),
 paid_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.cn_campaigns TO authenticated;
GRANT ALL ON public.cn_campaigns TO service_role;
ALTER TABLE public.cn_campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read campaigns" ON public.cn_campaigns FOR SELECT TO authenticated USING (status <> 'hidden' OR public.is_admin(auth.uid()));
CREATE POLICY "admin insert campaigns" ON public.cn_campaigns FOR INSERT TO authenticated WITH CHECK (public.is_admin(auth.uid()) AND status <> 'paid' AND paid_at IS NULL);
CREATE POLICY "admin update campaigns" ON public.cn_campaigns FOR UPDATE TO authenticated USING (public.is_admin(auth.uid()) AND status <> 'paid') WITH CHECK (public.is_admin(auth.uid()) AND status <> 'paid' AND paid_at IS NULL);

CREATE TABLE public.cn_submissions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL,
 task_id uuid REFERENCES public.cn_tasks(id) ON DELETE CASCADE,
 campaign_id uuid REFERENCES public.cn_campaigns(id) ON DELETE CASCADE,
 proof text NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
 reviewed_by uuid,
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK ((task_id IS NULL) <> (campaign_id IS NULL))
);
CREATE INDEX ON public.cn_submissions(campaign_id, status);
CREATE INDEX ON public.cn_submissions(user_id);
GRANT SELECT ON public.cn_submissions TO authenticated;
GRANT ALL ON public.cn_submissions TO service_role;
ALTER TABLE public.cn_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own submissions" ON public.cn_submissions FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE FUNCTION public.cn_invite_progress(_uid uuid) RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT count(*)::int FROM profiles p WHERE p.referred_by=_uid AND EXISTS (SELECT 1 FROM investment_cycles c WHERE c.user_id=p.user_id);
$$;
REVOKE ALL ON FUNCTION public.cn_invite_progress(uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.cn_submit_proof(p_task uuid, p_campaign uuid, p_proof text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE c cn_campaigns; t cn_tasks; n int;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
 IF length(trim(coalesce(p_proof,''))) < 3 THEN RAISE EXCEPTION 'Please add your proof'; END IF;
 IF p_task IS NOT NULL THEN
  SELECT * INTO t FROM cn_tasks WHERE id=p_task AND active AND kind='social';
  IF NOT FOUND THEN RAISE EXCEPTION 'Task not available'; END IF;
  IF EXISTS (SELECT 1 FROM cn_submissions WHERE user_id=auth.uid() AND task_id=p_task AND status IN ('pending','approved')) THEN RAISE EXCEPTION 'You already submitted this task'; END IF;
  INSERT INTO cn_submissions(user_id,task_id,proof) VALUES (auth.uid(),p_task,left(trim(p_proof),1000));
 ELSE
  SELECT * INTO c FROM cn_campaigns WHERE id=p_campaign AND status='active' AND ends_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'Campaign has ended'; END IF;
  SELECT count(*) INTO n FROM cn_submissions WHERE user_id=auth.uid() AND campaign_id=p_campaign AND status IN ('pending','approved');
  IF n >= c.max_participations THEN RAISE EXCEPTION 'Participation limit reached'; END IF;
  INSERT INTO cn_submissions(user_id,campaign_id,proof) VALUES (auth.uid(),p_campaign,left(trim(p_proof),1000));
 END IF;
END; $$;
REVOKE ALL ON FUNCTION public.cn_submit_proof(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cn_submit_proof(uuid,uuid,text) TO authenticated;

CREATE FUNCTION public.cn_claim_invite_task(p_task uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE t cn_tasks;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
 SELECT * INTO t FROM cn_tasks WHERE id=p_task AND active AND kind='invite';
 IF NOT FOUND THEN RAISE EXCEPTION 'Task not available'; END IF;
 IF cn_invite_progress(auth.uid()) < t.invite_target THEN RAISE EXCEPTION 'Target not reached yet'; END IF;
 INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (auth.uid(),'task',t.id::text,t.reward_coins) ON CONFLICT DO NOTHING;
END; $$;
REVOKE ALL ON FUNCTION public.cn_claim_invite_task(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cn_claim_invite_task(uuid) TO authenticated;

CREATE FUNCTION public.cn_campaign_scores(p_campaign uuid) RETURNS TABLE(user_id uuid, name text, score bigint, last_at timestamptz) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT s.user_id, coalesce(nullif(p.username,''),'Member'), count(*), max(s.created_at)
 FROM cn_submissions s LEFT JOIN profiles p ON p.user_id=s.user_id
 WHERE s.campaign_id=p_campaign AND s.status='approved'
 GROUP BY s.user_id, p.username ORDER BY count(*) DESC, max(s.created_at) ASC;
$$;
REVOKE ALL ON FUNCTION public.cn_campaign_scores(uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.cn_board() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object(
  'invite_progress', cn_invite_progress(auth.uid()),
  'tasks', coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'kind',t.kind,'title',t.title,'description',t.description,'link',t.link,'reward_coins',t.reward_coins,'invite_target',t.invite_target,
     'claimed', EXISTS(SELECT 1 FROM cn_rewards r WHERE r.user_id=auth.uid() AND r.source='task' AND r.reference=t.id::text),
     'my_status', (SELECT s.status FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.task_id=t.id ORDER BY s.created_at DESC LIMIT 1)) ORDER BY t.created_at DESC) FROM cn_tasks t WHERE t.active),'[]'::jsonb),
  'campaigns', coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'link',c.link,'max_participations',c.max_participations,'ends_at',c.ends_at,'prize_type',c.prize_type,'prizes',to_jsonb(c.prizes),'status',c.status,
     'my_approved',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='approved'),
     'my_pending',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='pending'),
     'leaders',coalesce((SELECT jsonb_agg(jsonb_build_object('name',left(x.name,2)||'***','score',x.score,'me',x.user_id=auth.uid())) FROM (SELECT * FROM cn_campaign_scores(c.id) LIMIT 10) x),'[]'::jsonb)
   ) ORDER BY c.ends_at) FROM cn_campaigns c WHERE c.status <> 'hidden'),'[]'::jsonb)
 );
$$;
REVOKE ALL ON FUNCTION public.cn_board() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cn_board() TO authenticated;

CREATE FUNCTION public.admin_list_cn_submissions() RETURNS TABLE(id uuid, email text, item text, kind text, proof text, status text, created_at timestamptz) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
BEGIN
 PERFORM admin_guard();
 RETURN QUERY SELECT s.id, u.email::text, coalesce(t.title,c.title), CASE WHEN s.task_id IS NOT NULL THEN 'task' ELSE 'campaign' END, s.proof, s.status, s.created_at
 FROM cn_submissions s JOIN auth.users u ON u.id=s.user_id LEFT JOIN cn_tasks t ON t.id=s.task_id LEFT JOIN cn_campaigns c ON c.id=s.campaign_id
 ORDER BY (s.status='pending') DESC, s.created_at DESC LIMIT 300;
END; $$;
REVOKE ALL ON FUNCTION public.admin_list_cn_submissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_cn_submissions() TO authenticated;

CREATE FUNCTION public.admin_review_cn_submission(p_id uuid, p_status text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE s cn_submissions; t cn_tasks;
BEGIN
 PERFORM admin_guard();
 IF p_status NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid status'; END IF;
 SELECT * INTO s FROM cn_submissions WHERE id=p_id AND status='pending' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Submission already reviewed'; END IF;
 UPDATE cn_submissions SET status=p_status, reviewed_by=auth.uid(), reviewed_at=now() WHERE id=p_id;
 IF p_status='approved' AND s.task_id IS NOT NULL THEN
  SELECT * INTO t FROM cn_tasks WHERE id=s.task_id;
  INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (s.user_id,'task',t.id::text,t.reward_coins) ON CONFLICT DO NOTHING;
 END IF;
 INSERT INTO audit_log(actor_id,action,target_user_id,target_reference) VALUES (auth.uid(),'cn_submission_'||p_status,s.user_id,p_id::text);
END; $$;
REVOKE ALL ON FUNCTION public.admin_review_cn_submission(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_cn_submission(uuid,text) TO authenticated;

CREATE FUNCTION public.admin_pay_cn_campaign(p_campaign uuid) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE c cn_campaigns; w record; i int := 0; prize numeric;
BEGIN
 PERFORM admin_guard();
 SELECT * INTO c FROM cn_campaigns WHERE id=p_campaign FOR UPDATE;
 IF NOT FOUND OR c.status='paid' THEN RAISE EXCEPTION 'Campaign already paid'; END IF;
 IF c.ends_at > now() THEN RAISE EXCEPTION 'Campaign has not ended yet'; END IF;
 FOR w IN SELECT * FROM cn_campaign_scores(p_campaign) LOOP
  i := i + 1;
  EXIT WHEN i > coalesce(array_length(c.prizes,1),0);
  prize := c.prizes[i];
  CONTINUE WHEN prize IS NULL OR prize <= 0;
  IF c.prize_type='cn' THEN
   INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (w.user_id,'campaign',c.id::text,prize) ON CONFLICT DO NOTHING;
  ELSE
   INSERT INTO ledger_entries(user_id,kind,amount_cents,reference_id,status,description) VALUES (w.user_id,'adjustment',round(prize*100)::bigint,'campaign:'||c.id,'posted','Campaign prize · rank '||i||' · '||c.title);
  END IF;
  INSERT INTO notifications(user_id,title,body,type) VALUES (w.user_id,'Campaign prize','You placed #'||i||' in '||c.title||' and won '||prize||CASE WHEN c.prize_type='cn' THEN ' CN' ELSE ' USD' END||'.','success');
 END LOOP;
 UPDATE cn_campaigns SET status='paid', paid_at=now() WHERE id=p_campaign;
 INSERT INTO audit_log(actor_id,action,target_reference) VALUES (auth.uid(),'cn_campaign_paid',p_campaign::text);
 RETURN least(i, coalesce(array_length(c.prizes,1),0));
END; $$;
REVOKE ALL ON FUNCTION public.admin_pay_cn_campaign(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_pay_cn_campaign(uuid) TO authenticated;