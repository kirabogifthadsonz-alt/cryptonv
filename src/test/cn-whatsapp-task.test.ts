import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { describe, expect, it } from 'vitest';

const script = readFileSync('public/app.js', 'utf8');
const start = script.indexOf('function cnSafeLink(');
const end = script.indexOf('async function loadAdminCN');
if (start < 0 || end < 0) throw new Error('CN task helpers missing from public/app.js');

const WA_GROUP_URL = 'https://chat.whatsapp.com/K9DyjYzWErSFr0At6rzH7Z?s=cl&p=a&mlu=4&ilr=4';
const escapedUrl = WA_GROUP_URL.replace(/&/g, '&amp;');
const waTask = {
  id: 'wa-1',
  kind: 'social',
  title: 'Join the CRYPTONVA WhatsApp group',
  description: 'Join our WhatsApp group to discover more opportunities.',
  link: WA_GROUP_URL,
  reward_coins: 2000,
  my_status: null,
};

function loadCnBoard(board: unknown, opened = new Set<string>()) {
  const ctx: Record<string, unknown> = {
    WA_GROUP_URL,
    cnOpened: opened,
    cnBoard: board,
    escapeHTML: (v: unknown) =>
      String(v ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' })[ch as string] as string),
    cnSymbol: () => '<svg></svg>',
    cnPlanNames: () => 'any earn plan',
  };
  return runInNewContext(`${script.slice(start, end)}; ({ cnCommunityCard, renderCNEarn })`, ctx) as {
    cnCommunityCard: () => string;
    renderCNEarn: () => string;
  };
}

describe('CN tab WhatsApp join reward', () => {
  it('shows the join button with the 2000 CN reward and the owner group link', () => {
    const html = loadCnBoard({ tasks: [waTask], campaigns: [] }).cnCommunityCard();
    expect(html).toContain('+2,000 CN');
    expect(html).toContain('Join WhatsApp group');
    expect(html).toContain(`data-link="${escapedUrl}"`);
    expect(html).toContain('data-cn-open="wa-1"');
    expect(html).not.toContain('data-cn-task-proof');
  });

  it('asks for proof only after the group link was opened, and never invents a reward', () => {
    const opened = new Set<string>(['wa-1']);
    const html = loadCnBoard({ tasks: [waTask], campaigns: [] }, opened).cnCommunityCard();
    expect(html).toContain('data-cn-task-proof="wa-1"');
    expect(html).toContain('2000 CN reward');

    const empty = loadCnBoard({ tasks: [], campaigns: [] }).cnCommunityCard();
    expect(empty).toContain('Reward pending');
    expect(empty).not.toContain('2,000');
    expect(empty).toContain(`href="${escapedUrl}"`);
  });

  it('reports the admin review state instead of a new claim', () => {
    const pending = loadCnBoard({ tasks: [{ ...waTask, my_status: 'pending' }], campaigns: [] }).cnCommunityCard();
    expect(pending).toContain('Proof under review');
    expect(pending).not.toContain('data-cn-open');

    const approved = loadCnBoard({ tasks: [{ ...waTask, my_status: 'approved' }], campaigns: [] }).cnCommunityCard();
    expect(approved).toContain('Approved · reward received');
    expect(approved).not.toContain('data-cn-task-proof');
  });

  it('lists the WhatsApp task once, in its own card, not again under Tasks', () => {
    const board = { tasks: [waTask, { ...waTask, id: 'other-1', title: 'Post about CRYPTONVA', link: 'https://x.com/cryptonva', reward_coins: 500 }], campaigns: [] };
    const { cnCommunityCard, renderCNEarn } = loadCnBoard(board);
    const tasksHtml = renderCNEarn();
    expect(tasksHtml).toContain('data-cn-open="other-1"');
    expect(tasksHtml).not.toContain('data-cn-open="wa-1"');
    expect(tasksHtml).not.toContain('+2,000 CN');
    expect(cnCommunityCard()).toContain('data-cn-open="wa-1"');
  });
});
