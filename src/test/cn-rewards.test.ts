import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { describe, expect, it } from 'vitest';

const script = readFileSync('public/app.js', 'utf8');
const start = script.indexOf('function cnValueUsd(');
const end = script.indexOf('async function loadCNRewards(');
const rules = runInNewContext(`${script.slice(start, end)}; ({cnValueUsd,cnWithdrawalReady})`);

describe('CN rewards rules', () => {
  it('values the 800 CN signup allocation at $0.48 per coin ($384)', () => {
    expect(rules.cnValueUsd(800, 0.48)).toBe(384);
  });
  it('requires both TGE and CEX listing before CN is withdrawal-ready', () => {
    expect(rules.cnWithdrawalReady({tge_completed: false, cex_listed: false})).toBe(false);
    expect(rules.cnWithdrawalReady({tge_completed: true, cex_listed: false})).toBe(false);
    expect(rules.cnWithdrawalReady({tge_completed: false, cex_listed: true})).toBe(false);
    expect(rules.cnWithdrawalReady({tge_completed: true, cex_listed: true})).toBe(true);
    expect(rules.cnWithdrawalReady(null)).toBe(false);
  });
});