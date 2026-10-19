CREATE OR REPLACE FUNCTION public.cn_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  t record;
  _progress int;
BEGIN
  -- Auto-reward invite tasks whose target is reached (no proof, no manual claim)
  FOR t IN SELECT * FROM cn_tasks WHERE active AND kind='invite' LOOP
    _progress := cn_invite_progress(_uid);
    IF _progress >= t.invite_target THEN
      INSERT INTO cn_rewards(user_id,source,reference,coins)
      VALUES (_uid,'task',t.id::text,t.reward_coins) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
  'invite_progress', cn_invite_progress(_uid),
  'tasks', coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'kind',t.kind,'title',t.title,'description',t.description,'link',t.link,'reward_coins',t.reward_coins,'invite_target',t.invite_target,
     'plan_ids',to_jsonb(t.plan_ids),
     'progress', CASE WHEN t.kind='invite' THEN cn_invite_progress(_uid) ELSE NULL END,
     'remaining', CASE WHEN t.kind='invite' THEN GREATEST(0, t.invite_target - cn_invite_progress(_uid)) ELSE NULL END,
     'eligible', CASE WHEN t.kind='invest' THEN cn_task_eligible(_uid,t.id) ELSE false END,
     'claimed', EXISTS(SELECT 1 FROM cn_rewards r WHERE r.user_id=_uid AND r.source='task' AND r.reference=t.id::text),
     'my_status', (SELECT s.status FROM cn_submissions s WHERE s.user_id=_uid AND s.task_id=t.id ORDER BY s.created_at DESC LIMIT 1)) ORDER BY (t.kind='invest') DESC, t.created_at DESC) FROM cn_tasks t WHERE t.active),'[]'::jsonb),
  'campaigns', coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'link',c.link,'max_participations',c.max_participations,'ends_at',c.ends_at,'prize_type',c.prize_type,'prizes',to_jsonb(c.prizes),'status',c.status,
     'kind',c.kind,'invest_target',c.invest_target,'reward_coins',c.reward_coins,'plan_ids',to_jsonb(c.plan_ids),
     'my_invest_count', cn_invest_campaign_count(_uid,c.id),
     'max_total_entries',c.max_total_entries,
     'total_entries',(SELECT count(*) FROM cn_submissions s WHERE s.campaign_id=c.id AND s.status IN ('pending','approved')),
     'my_approved',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=_uid AND s.campaign_id=c.id AND s.status='approved'),
     'my_pending',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=_uid AND s.campaign_id=c.id AND s.status='pending'),
     'leaders',coalesce((SELECT jsonb_agg(jsonb_build_object('name',left(x.name,2)||'***','score',x.score,'me',x.user_id=_uid)) FROM (SELECT * FROM cn_campaign_scores(c.id) LIMIT 10) x),'[]'::jsonb)
   ) ORDER BY c.ends_at) FROM cn_campaigns c WHERE c.status <> 'hidden'),'[]'::jsonb)
 );
END; $function$;