-- Joining the CRYPTONVA WhatsApp group earns 2000 CN coins.
-- Runs through the existing social-task proof flow (cn_submit_proof ->
-- admin_review_cn_submission -> cn_rewards), so the reward is only granted after
-- an admin confirms the submitted proof. The link is the owner-provided invitation.
INSERT INTO public.cn_tasks (kind, title, description, link, reward_coins, active)
SELECT 'social',
       'Join the CRYPTONVA WhatsApp group',
       'Join our WhatsApp group to discover more opportunities, then submit proof that you joined. An admin confirms it and your 2000 CN reward is added.',
       'https://chat.whatsapp.com/K9DyjYzWErSFr0At6rzH7Z?s=cl&p=a&mlu=4&ilr=4',
       2000,
       true
WHERE NOT EXISTS (
  SELECT 1 FROM public.cn_tasks
  WHERE link = 'https://chat.whatsapp.com/K9DyjYzWErSFr0At6rzH7Z?s=cl&p=a&mlu=4&ilr=4'
);