ALTER TABLE public.cn_campaigns ADD COLUMN max_total_entries integer NOT NULL DEFAULT 0 CHECK (max_total_entries >= 0);
COMMENT ON COLUMN public.cn_campaigns.max_total_entries IS 'Campaign-wide cap on pending+approved entries; 0 = unlimited.';

CREATE OR REPLACE FUNCTION public.cn_submit_proof(p_task uuid, p_campaign uuid, p_proof text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE c cn_campaigns; t cn_tasks; n int; total int;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
 IF length(trim(coalesce(p_proof,''))) < 3 THEN RAISE EXCEPTION 'Please add your proof'; END IF;
 IF p_task IS NOT NULL THEN
  SELECT * INTO t FROM cn_tasks WHERE id=p_task AND active AND kind='social';
  IF NOT FOUND THEN RAISE EXCEPTION 'Task not available'; END IF;
  IF EXISTS (SELECT 1 FROM cn_submissions WHERE user_id=auth.uid() AND task_id=p_task AND status IN ('pending','approved')) THEN RAISE EXCEPTION 'You already submitted this task'; END IF;
  INSERT INTO cn_submissions(user_id,task_id,proof) VALUES (auth.uid(),p_task,left(trim(p_proof),1000));
 ELSE
  SELECT * INTO c FROM cn_campaigns WHERE id=p_campaign AND status='active' AND ends_at > now() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Campaign has ended'; END IF;
  IF c.max_total_entries > 0 THEN
   SELECT count(*) INTO total FROM cn_submissions WHERE campaign_id=p_campaign AND status IN ('pending','approved');
   IF total >= c.max_total_entries THEN RAISE EXCEPTION 'Campaign is full'; END IF;
  END IF;
  SELECT count(*) INTO n FROM cn_submissions WHERE user_id=auth.uid() AND campaign_id=p_campaign AND status IN ('pending','approved');
  IF n >= c.max_participations THEN RAISE EXCEPTION 'Participation limit reached'; END IF;
  INSERT INTO cn_submissions(user_id,campaign_id,proof) VALUES (auth.uid(),p_campaign,left(trim(p_proof),1000));
 END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.cn_board() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object(
  'invite_progress', cn_invite_progress(auth.uid()),
  'tasks', coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'kind',t.kind,'title',t.title,'description',t.description,'link',t.link,'reward_coins',t.reward_coins,'invite_target',t.invite_target,
     'claimed', EXISTS(SELECT 1 FROM cn_rewards r WHERE r.user_id=auth.uid() AND r.source='task' AND r.reference=t.id::text),
     'my_status', (SELECT s.status FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.task_id=t.id ORDER BY s.created_at DESC LIMIT 1)) ORDER BY t.created_at DESC) FROM cn_tasks t WHERE t.active),'[]'::jsonb),
  'campaigns', coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'link',c.link,'max_participations',c.max_participations,'ends_at',c.ends_at,'prize_type',c.prize_type,'prizes',to_jsonb(c.prizes),'status',c.status,
     'max_total_entries',c.max_total_entries,
     'total_entries',(SELECT count(*) FROM cn_submissions s WHERE s.campaign_id=c.id AND s.status IN ('pending','approved')),
     'my_approved',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='approved'),
     'my_pending',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='pending'),
     'leaders',coalesce((SELECT jsonb_agg(jsonb_build_object('name',left(x.name,2)||'***','score',x.score,'me',x.user_id=auth.uid())) FROM (SELECT * FROM cn_campaign_scores(c.id) LIMIT 10) x),'[]'::jsonb)
   ) ORDER BY c.ends_at) FROM cn_campaigns c WHERE c.status <> 'hidden'),'[]'::jsonb)
 );
$$;