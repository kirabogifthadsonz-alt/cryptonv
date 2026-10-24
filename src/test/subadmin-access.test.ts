import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { describe, expect, it } from 'vitest';

const script=readFileSync('public/app.js','utf8');
const start=script.indexOf('function adminCan(');
const end=script.indexOf('let adminSection',start);
function permissions(role:string,features:string[]){return runInNewContext(`${script.slice(start,end)};({adminCan,adminSectionAllowed})`,{adminAccess:{role,features}}) as {adminCan:(feature:string)=>boolean;adminSectionAllowed:(section:string)=>boolean};}
describe('delegated administration',()=>{
  for(const feature of ['plans','campaigns','prices'])it(`denies ${feature} without an owner grant`,()=>{expect(permissions('subadmin',['overview','users','kyc','support','proof_reviews']).adminCan(feature)).toBe(false);});
  it('allows only assigned features',()=>{const p=permissions('subadmin',['support']);expect(p.adminCan('support')).toBe(true);expect(p.adminCan('payouts')).toBe(false);});
  it('never lets a subadmin manage delegation',()=>{expect(permissions('subadmin',['subadmins']).adminSectionAllowed('subadmins')).toBe(false);});
  it('keeps full admin control',()=>{const p=permissions('admin',[]);for(const feature of ['plans','campaigns','prices','payouts'])expect(p.adminCan(feature)).toBe(true);expect(p.adminSectionAllowed('subadmins')).toBe(true);});
  it('does not trust feature lists for ordinary users',()=>{expect(permissions('user',['plans']).adminCan('plans')).toBe(false);});
});