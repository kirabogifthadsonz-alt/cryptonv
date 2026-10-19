ALTER TABLE public.investment_plans ADD COLUMN roi_percent numeric NOT NULL DEFAULT 0;
UPDATE public.investment_plans SET roi_percent = ROUND((earning / NULLIF(invest, 0)) * 100, 2) WHERE invest > 0;
COMMENT ON COLUMN public.investment_plans.roi_percent IS 'Daily return on investment as a percentage of the invest amount; earning and estimated_total are derived from it.';