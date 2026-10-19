CREATE OR REPLACE FUNCTION public.settle_my_cycles()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare u uuid := auth.uid(); c record;
begin
  if u is null then return; end if;
  for c in select ic.*, ip.estimated_total from investment_cycles ic left join investment_plans ip on ip.name=ic.plan_name
           where ic.user_id=u and ic.status='active' and ic.ends_at<=now() for update of ic loop
    update investment_cycles set status='completed' where id=c.id;
    if coalesce(c.estimated_total,0) > 0 then
      insert into ledger_entries(user_id,kind,amount_cents,reference_id,status,description)
        values (u,'investment_return',round(c.estimated_total*100),c.id::text,'posted','Profit from '||c.plan_name);
    end if;
    insert into notifications(user_id,title,body,type) values (u,'Cycle completed',c.plan_name||' completed. Principal and profit are now available.','success');
  end loop;
end $$;
GRANT EXECUTE ON FUNCTION public.settle_my_cycles() TO authenticated;

ALTER TABLE public.investment_plans ADD COLUMN IF NOT EXISTS max_investors integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.plan_investor_counts()
RETURNS TABLE(plan_id uuid, investors bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  select p.id, (select count(distinct c.user_id) from investment_cycles c where c.plan_name = p.name)
  from investment_plans p
$$;
GRANT EXECUTE ON FUNCTION public.plan_investor_counts() TO authenticated;

CREATE OR REPLACE FUNCTION public.start_investment(p_plan_id uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare u uuid := auth.uid(); p investment_plans; cents bigint; n bigint;
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
  insert into investment_cycles(user_id,plan_name,principal_cents,ends_at) values (u,p.name,cents,now() + make_interval(days => p.term_days));
  insert into notifications(user_id,title,body,type) values (u,'Investment started',p.name||' started with '||p.invest||' USD.','success');
end $function$;
GRANT EXECUTE ON FUNCTION public.start_investment(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_move_plan(p_plan_id uuid, p_position integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare total int; pos int;
begin
  perform public.admin_guard();
  select count(*) into total from investment_plans;
  pos := greatest(1, least(coalesce(p_position,1), total));
  with others as (
    select id, row_number() over (order by sort_order, created_at) as rn
    from investment_plans where id <> p_plan_id
  )
  update investment_plans ip set sort_order = case when o.rn >= pos then o.rn + 1 else o.rn end, updated_at = now()
  from others o where ip.id = o.id;
  update investment_plans set sort_order = pos, updated_at = now() where id = p_plan_id;
end $$;
GRANT EXECUTE ON FUNCTION public.admin_move_plan(uuid, integer) TO authenticated;