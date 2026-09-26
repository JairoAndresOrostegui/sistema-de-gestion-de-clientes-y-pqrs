import {beforeAll,afterAll,describe,it} from 'vitest';
import {initializeTestEnvironment,assertSucceeds,assertFails,RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {readFileSync} from 'node:fs';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {ref,uploadBytes,getBytes} from 'firebase/storage';

const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
describe.skipIf(!enabled)('Firestore and Storage tenant isolation',()=>{
  let env:RulesTestEnvironment;
  beforeAll(async()=>{
    env=await initializeTestEnvironment({projectId:'demo-dts-gestion',firestore:{rules:readFileSync('../firestore.rules','utf8')},storage:{rules:readFileSync('../storage.rules','utf8')}});
    await env.withSecurityRulesDisabled(async ctx=>{
      const db=ctx.firestore();
      for(const [uid,role] of [['owner','owner'],['commercial','commercial'],['client','client'],['outsider','client'],['revoked','client']])await setDoc(doc(db,'users',uid),{role,active:uid!=='revoked',permissions:[]});
      for(const company of ['A','B'])await setDoc(doc(db,'companies',company),{name:company});
      await setDoc(doc(db,'memberships','client_A'),{uid:'client',companyId:'A',active:true,allProjects:false,projectIds:['p1'],ticketScope:'project'});
      await setDoc(doc(db,'projects','p1'),{companyId:'A',name:'Permitido'});await setDoc(doc(db,'projects','p2'),{companyId:'A',name:'Oculto'});
      await setDoc(doc(db,'tickets','t1'),{companyId:'A',projectId:'p1',requesterId:'client',visibility:'project'});
      await setDoc(doc(db,'tickets','t2'),{companyId:'A',projectId:'p2',requesterId:'other',visibility:'project'});
      await setDoc(doc(db,'tickets','private'),{companyId:'A',projectId:'p1',requesterId:'other',visibility:'requester'});
      for(const audience of ['public','internal','technical'])await setDoc(doc(db,`tickets/t1/${audience}/note`),{body:audience});
      await setDoc(doc(db,'repositories','r1'),{companyId:'A',projectId:'p1',source:'private'});
      await setDoc(doc(db,'catalog','draft'),{companyId:'A',projectId:'p1',published:false});
      await setDoc(doc(db,'catalog','published'),{companyId:'A',projectId:'p1',published:true});
      await setDoc(doc(db,'contracts','c1'),{companyId:'A',projectId:'p1',amount:100});
    });
  });
  afterAll(async()=>{await env?.cleanup();});
  function db(uid:string){return env.authenticatedContext(uid,{email_verified:true}).firestore();}
  it('device tokens, outbox, inbox and receipts require the authorized callable even for owner',async()=>{
    for(const path of ['userDevices/client/slots/web','pushTokens/token','deviceSessions/session','notificationEvents/event','notifications/notice','notifications/notice/deliveries/web']) {
      await assertFails(getDoc(doc(db('owner'),path)));
      await assertFails(setDoc(doc(db('client'),path),{token:'forged',readAt:'forged'}));
    }
  });
  it('client reads only assigned company/project',async()=>{await assertSucceeds(getDoc(doc(db('client'),'companies','A')));await assertFails(getDoc(doc(db('client'),'companies','B')));await assertSucceeds(getDoc(doc(db('client'),'projects','p1')));await assertFails(getDoc(doc(db('client'),'projects','p2')));});
  it('requester visibility and project boundaries protect tickets',async()=>{await assertSucceeds(getDoc(doc(db('client'),'tickets','t1')));await assertFails(getDoc(doc(db('client'),'tickets','t2')));await assertFails(getDoc(doc(db('client'),'tickets','private')));});
  it('commercial can read public/internal, never technical or repositories',async()=>{await assertSucceeds(getDoc(doc(db('commercial'),'tickets/t1/public/note')));await assertSucceeds(getDoc(doc(db('commercial'),'tickets/t1/internal/note')));await assertFails(getDoc(doc(db('commercial'),'tickets/t1/technical/note')));await assertFails(getDoc(doc(db('commercial'),'repositories','r1')));await assertSucceeds(getDoc(doc(db('owner'),'tickets/t1/technical/note')));});
  it('client cannot read internal notes or draft catalogue or private contracts',async()=>{await assertFails(getDoc(doc(db('client'),'tickets/t1/internal/note')));await assertFails(getDoc(doc(db('client'),'catalog','draft')));await assertSucceeds(getDoc(doc(db('client'),'catalog','published')));await assertFails(getDoc(doc(db('client'),'contracts','c1')));});
  it('direct writes cannot assign roles or bypass privileged server',async()=>{await assertFails(setDoc(doc(db('client'),'users','client'),{role:'owner'}));await assertFails(setDoc(doc(db('owner'),'companies','C'),{name:'Bypass'}));});
  it('revoked, unknown and anonymous users have no data access',async()=>{await assertFails(getDoc(doc(db('revoked'),'companies','A')));await assertFails(getDoc(doc(db('outsider'),'companies','A')));await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'companies','A')));});
  it('storage enforces tenant, audience, mime and owner boundaries',async()=>{
    const storage=(uid:string)=>env.authenticatedContext(uid,{email_verified:true}).storage();
    const data=new TextEncoder().encode('evidence');
    await assertSucceeds(uploadBytes(ref(storage('client'),'attachments/t1/public/client/evidence.txt'),data,{contentType:'text/plain'}));
    await assertFails(uploadBytes(ref(storage('client'),'attachments/t2/public/client/evidence.txt'),data,{contentType:'text/plain'}));
    await assertFails(uploadBytes(ref(storage('commercial'),'attachments/t1/technical/commercial/secret.txt'),data,{contentType:'text/plain'}));
    await assertFails(uploadBytes(ref(storage('client'),'attachments/t1/public/client/code.html'),data,{contentType:'text/html'}));
    await assertSucceeds(uploadBytes(ref(storage('owner'),'attachments/t1/technical/owner/note.txt'),data,{contentType:'text/plain'}));
    await assertFails(getBytes(ref(storage('commercial'),'attachments/t1/technical/owner/note.txt')));
  });
});
