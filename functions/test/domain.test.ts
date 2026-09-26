import {describe,it,expect} from 'vitest';
import {companySchema,projectSchema,canTransition,hasPermission,businessDeadline,businessMinutes,policySchema,reminderKey,daysUntil,csvCell} from '../src/domain';
import {allowedSource,inspectFiles,looksSensitive} from '../src/importer';
import {DateTime} from 'luxon';

describe('minimum creation and authorization',()=>{
  it('creates a company with only its name',()=>expect(companySchema.parse({name:'Empresa A'}).name).toBe('Empresa A'));
  it('requires project name and company',()=>{expect(projectSchema.safeParse({name:'Portal',companyId:'A'}).success).toBe(true);expect(projectSchema.safeParse({companyId:'A'}).success).toBe(false);});
  it('commercial cannot gain technical access with a permission flag',()=>expect(hasPermission({uid:'c',email:'c@test.co',role:'commercial',permissions:['technical']},'technical')).toBe(false));
  it('client cannot perform triage or escalation',()=>{expect(canTransition('client','nuevo','clasificacion')).toBe(false);expect(canTransition('client','primer_nivel','escalado')).toBe(false);});
  it('client can validate and reopen',()=>{expect(canTransition('client','resuelto','cerrado')).toBe(true);expect(canTransition('client','cerrado','reabierto')).toBe(true);});
  it('prevents skipping lifecycle states',()=>expect(canTransition('owner','nuevo','cerrado')).toBe(false));
});
describe('contractual business time',()=>{
  const policy=policySchema.parse({holidays:['2026-09-28']});
  it('skips weekends and configured holidays',()=>expect(businessDeadline('2026-09-25T21:00:00Z',120,policy)).toBe('2026-09-29T14:00:00.000Z'));
  it('moves an out-of-hours creation to the next business opening',()=>expect(businessDeadline('2026-09-26T02:00:00Z',60,policy)).toBe('2026-09-29T14:00:00.000Z'));
  it('computes only working minutes for justified pauses',()=>expect(businessMinutes('2026-09-25T21:00:00Z','2026-09-29T14:00:00Z',policy)).toBe(120));
  it('rejects inverted schedules',()=>expect(policySchema.safeParse({startHour:17,endHour:8}).success).toBe(false));
  it('local dates and renewal keys stay deterministic',()=>{expect(daysUntil('2026-09-26',DateTime.fromISO('2026-09-27T02:00:00Z'))).toBe(0);expect(reminderKey('services','s','2026-10-26',30)).toBe(reminderKey('services','s','2026-10-26',30));expect(reminderKey('services','s','2026-10-26',30)).not.toBe(reminderKey('services','s','2027-10-26',30));});
});
describe('bounded import and data handling',()=>{
  it.each(['.env','src/.env','node_modules/a.ts','src/service-account.json','docs/password.md','src/private_key.ts'])('excludes %s',p=>expect(allowedSource(p)).toBe(false));
  it('excludes secrets and marks inferences as proposals',()=>{const items=inspectFiles([{path:'README.md',content:'# Facturación\n## Reportes'},{path:'src/routes.ts',content:'const password = "supersecreto12345"'}]);expect(items).toHaveLength(2);expect(items[0].confidence).toBeLessThan(1);expect(looksSensitive('-----BEGIN PRIVATE KEY-----')).toBe(true);});
  it('has stable candidate IDs across updates',()=>{const a=inspectFiles([{path:'README.md',content:'# Clientes\nprimera versión'}])[0];const b=inspectFiles([{path:'README.md',content:'# Clientes\nsegunda versión'}])[0];expect(a.key).toBe(b.key);expect(a.fingerprint).not.toBe(b.fingerprint);});
  it('limits candidates and escapes CSV formula injection',()=>{expect(inspectFiles(Array.from({length:80},(_,i)=>({path:`docs/${i}.md`,content:'# Uno\n# Dos\n# Tres'}))).length).toBeLessThanOrEqual(120);expect(csvCell('=2+2')).toBe('"\'=2+2"');});
});
