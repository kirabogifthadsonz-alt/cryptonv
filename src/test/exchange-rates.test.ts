import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { describe, expect, it } from 'vitest';

const script = readFileSync('public/app.js', 'utf8');
const start = script.indexOf('let displayFxRates=');
const end = script.indexOf('function moneyText(');
const rules = runInNewContext(`${script.slice(start, end)}; ({validatedUsdRates,displayRate,localAmount,setRates:r=>displayFxRates=r})`, {
  profile: {country:'Uganda'}, currencyForCountry:()=>({code:'UGX',locale:'en-UG',decimals:0}),toAmount:Number,
});
const feed = {result:'success',base_code:'USD',time_last_update_unix:Math.floor(Date.now()/1000),rates:{USD:1,UGX:4060.877425}};
describe('Current USD display rates',()=>{
  it('uses the current USD-to-UGX feed for local equivalents',()=>{
    const valid=rules.validatedUsdRates(feed);
    rules.setRates(valid.rates);
    expect(rules.displayRate('UGX')).toBe(4060.877425);
    expect(rules.localAmount(384)).toContain('1,559,377');
  });
  it('rejects non-USD feeds and invalid or stale rates',()=>{
    expect(rules.validatedUsdRates({...feed,base_code:'EUR'})).toBeNull();
    expect(rules.validatedUsdRates({...feed,time_last_update_unix:1})).toBeNull();
    expect(rules.validatedUsdRates({...feed,rates:{USD:1,UGX:-1}}).rates.UGX).toBeUndefined();
  });
  it('does not invent an exchange rate when no current rate exists',()=>{
    rules.setRates({});
    expect(rules.displayRate('UGX')).toBeNull();
    expect(rules.localAmount(384)).toBe('UGX —');
    expect(rules.displayRate('USD')).toBe(1);
  });
});