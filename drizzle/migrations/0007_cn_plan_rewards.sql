ALTER TABLE public.investment_plans ADD COLUMN IF NOT EXISTS cn_reward numeric NOT NULL DEFAULT 0;
ALTER TABLE public.cn_tasks ADD COLUMN IF NOT EXISTS plan_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.cn_campaigns ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'proof';
ALTER TABLE public.cn_campaigns ADD COLUMN IF NOT EXISTS invest_target integer NOT NULL DEFAULT 0;
ALTER TABLE public.cn_campaigns ADD COLUMN IF NOT EXISTS reward_coins numeric NOT NULL DEFAULT 0;
ALTER TABLE public.cn_campaigns ADD COLUMN IF NOT EXISTS plan_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.cn_campaigns ADD CONSTRAINT cn_campaigns_kind_check CHECK (kind IN ('proof','invest'));
ALTER TABLE public.cn_tasks DROP CONSTRAINT cn_tasks_kind_check;
ALTER TABLE public.cn_tasks ADD CONSTRAINT cn_tasks_kind_check CHECK (kind IN ('social','invite','invest'));
ALTER TABLE public.cn_rewards DROP CONSTRAINT cn_rewards_source_check;
ALTER TABLE public.cn_rewards ADD CONSTRAINT cn_rewards_source_check CHECK (source IN ('signup','invite','task','campaign','plan'));

CREATE OR REPLACE FUNCTION public.cn_plan_match(_ids uuid[], _plan_name text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
 SELECT coalesce(array_length(_ids,1),0)=0 OR EXISTS(SELECT 1 FROM investment_plans p WHERE p.id=ANY(_ids) AND p.name=_plan_name);
$$;

CREATE OR REPLACE FUNCTION public.cn_task_eligible(_uid uuid, _task uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
 SELECT EXISTS(SELECT 1 FROM cn_tasks t WHERE t.id=_task AND t.kind='invest'
   AND EXISTS(SELECT 1 FROM investment_cycles c WHERE c.user_id=_uid AND cn_plan_match(t.plan_ids,c.plan_name)));
$$;

CREATE OR REPLACE FUNCTION public.cn_invest_campaign_count(_uid uuid, _camp uuid) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
 SELECT count(*)::int FROM cn_rewards r WHERE r.user_id=_uid AND r.source='campaign' AND r.reference LIKE _camp::text||':%';
$$;

CREATE OR REPLACE FUNCTION public.cn_award_investment(_uid uuid, _cycle uuid, _plan_name text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE p investment_plans; t cn_tasks; c cn_campaigns; per numeric;
BEGIN
 SELECT * INTO p FROM investment_plans WHERE name=_plan_name LIMIT 1;
 IF p.id IS NOT NULL AND p.cn_reward > 0 THEN
   INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (_uid,'plan',_cycle::text,p.cn_reward) ON CONFLICT DO NOTHING;
 END IF;
 FOR t IN SELECT * FROM cn_tasks WHERE active AND kind='invest' AND cn_plan_match(plan_ids,_plan_name) LOOP
   INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (_uid,'task',t.id::text,t.reward_coins) ON CONFLICT DO NOTHING;
 END LOOP;
 FOR c IN SELECT * FROM cn_campaigns WHERE kind='invest' AND status='active' AND ends_at>now() AND invest_target>0 AND reward_coins>0 AND cn_plan_match(plan_ids,_plan_name) LOOP
   IF cn_invest_campaign_count(_uid,c.id) < c.invest_target THEN
     per := round(c.reward_coins / c.invest_target, 4);
     IF per > 0 THEN
       INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (_uid,'campaign',c.id::text||':'||_cycle::text,per) ON CONFLICT DO NOTHING;
     END IF;
   END IF;
 END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION public.cn_award_investment(uuid,uuid,text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.start_investment(p_plan_id uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare u uuid := auth.uid(); p investment_plans; cents bigint; n bigint; cid uuid;
begin
  if u is null then raise exception 'Not signed in'; end if;
  if exists(select 1 from user_restrictions where user_id=u and status<>'active') then raise exception 'Your account is restricted'; end if;
  select * into p from investment_plans where id=p_plan_id and active for update;
  if p.id is null then raise exception 'Plan not available'; end if;
  if exists(select 1 from investment_cycles where user_id=u and plan_name=p.name and status='active') then raise exception 'This plan is already active'; end if;
  if p.max_investors > 0 then
    select count(distinct user_id) into n from investment_cycles where plan_name=p.name;
    if n >= p.max_investors and not exists(select 1 from investment_cycles where plan_name=p.name and user_id=u) then
      raise exception 'This plan is full (%/% investors)', n, p.max_investors;
    end if;
  end if;
  cents := round(p.invest*100);
  if cents > public.available_cents(u) then raise exception 'Insufficient balance'; end if;
  insert into investment_cycles(user_id,plan_name,principal_cents,ends_at) values (u,p.name,cents,now() + make_interval(days => p.term_days)) returning id into cid;
  perform public.cn_award_investment(u,cid,p.name);
  insert into notifications(user_id,title,body,type) values (u,'Investment started',p.name||' started with '||p.invest||' USD.'||case when p.cn_reward>0 then ' +'||p.cn_reward||' CN reward added.' else '' end,'success');
end $function$;

CREATE OR REPLACE FUNCTION public.cn_claim_invite_task(p_task uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE t cn_tasks;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
 SELECT * INTO t FROM cn_tasks WHERE id=p_task AND active AND kind IN ('invite','invest');
 IF NOT FOUND THEN RAISE EXCEPTION 'Task not available'; END IF;
 IF t.kind='invite' AND cn_invite_progress(auth.uid()) < t.invite_target THEN RAISE EXCEPTION 'Target not reached yet'; END IF;
 IF t.kind='invest' AND NOT cn_task_eligible(auth.uid(), t.id) THEN RAISE EXCEPTION 'Start an eligible earn plan first'; END IF;
 INSERT INTO cn_rewards(user_id,source,reference,coins) VALUES (auth.uid(),'task',t.id::text,t.reward_coins) ON CONFLICT DO NOTHING;
END; $function$;

CREATE OR REPLACE FUNCTION public.cn_campaign_scores(p_campaign uuid)
 RETURNS TABLE(user_id uuid, name text, score bigint, last_at timestamp with time zone)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
 SELECT x.user_id, coalesce(nullif(p.username,''),'Member'), count(*), max(x.at) FROM (
   SELECT s.user_id, s.created_at at FROM cn_submissions s WHERE s.campaign_id=p_campaign AND s.status='approved'
   UNION ALL
   SELECT r.user_id, r.created_at FROM cn_rewards r WHERE r.source='campaign' AND r.reference LIKE p_campaign::text||':%'
 ) x LEFT JOIN profiles p ON p.user_id=x.user_id
 GROUP BY x.user_id, p.username ORDER BY count(*) DESC, max(x.at) ASC;
$function$;

CREATE OR REPLACE FUNCTION public.cn_board()
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
 SELECT jsonb_build_object(
  'invite_progress', cn_invite_progress(auth.uid()),
  'tasks', coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'kind',t.kind,'title',t.title,'description',t.description,'link',t.link,'reward_coins',t.reward_coins,'invite_target',t.invite_target,
     'plan_ids',to_jsonb(t.plan_ids),
     'eligible', CASE WHEN t.kind='invest' THEN cn_task_eligible(auth.uid(),t.id) ELSE false END,
     'claimed', EXISTS(SELECT 1 FROM cn_rewards r WHERE r.user_id=auth.uid() AND r.source='task' AND r.reference=t.id::text),
     'my_status', (SELECT s.status FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.task_id=t.id ORDER BY s.created_at DESC LIMIT 1)) ORDER BY (t.kind='invest') DESC, t.created_at DESC) FROM cn_tasks t WHERE t.active),'[]'::jsonb),
  'campaigns', coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'link',c.link,'max_participations',c.max_participations,'ends_at',c.ends_at,'prize_type',c.prize_type,'prizes',to_jsonb(c.prizes),'status',c.status,
     'kind',c.kind,'invest_target',c.invest_target,'reward_coins',c.reward_coins,'plan_ids',to_jsonb(c.plan_ids),
     'my_invest_count', cn_invest_campaign_count(auth.uid(),c.id),
     'max_total_entries',c.max_total_entries,
     'total_entries',(SELECT count(*) FROM cn_submissions s WHERE s.campaign_id=c.id AND s.status IN ('pending','approved')),
     'my_approved',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='approved'),
     'my_pending',(SELECT count(*) FROM cn_submissions s WHERE s.user_id=auth.uid() AND s.campaign_id=c.id AND s.status='pending'),
     'leaders',coalesce((SELECT jsonb_agg(jsonb_build_object('name',left(x.name,2)||'***','score',x.score,'me',x.user_id=auth.uid())) FROM (SELECT * FROM cn_campaign_scores(c.id) LIMIT 10) x),'[]'::jsonb)
   ) ORDER BY c.ends_at) FROM cn_campaigns c WHERE c.status <> 'hidden'),'[]'::jsonb)
 );
$function$;