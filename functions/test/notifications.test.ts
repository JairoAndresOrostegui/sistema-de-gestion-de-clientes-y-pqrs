import {beforeAll, describe, expect, it} from 'vitest';
import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {randomUUID} from 'node:crypto';
import {deviceAction, deviceContext, notificationEvent, processNotificationEvent, notificationAction, notificationList, mayReceive} from '../src/notifications';
import {Actor} from '../src/domain';

describe.skipIf(!process.env.FIRESTORE_EMULATOR_HOST)('device destinations and notification outbox',()=>{
  if(!getApps().length)initializeApp({projectId:'demo-dts-gestion'});
  const db=getFirestore();
  const owner:Actor={uid:'push-owner',email:'push-owner@example.test',role:'owner',permissions:[]};
  const client:Actor={uid:'push-client',email:'push-client@example.test',role:'client',permissions:[]};
  const commercial:Actor={uid:'push-commercial',email:'push-commercial@example.test',role:'commercial',permissions:[]};
  const technician:Actor={uid:'push-technician',email:'push-technician@example.test',role:'technician',permissions:['technical']};
  const reader:Actor={uid:'push-reader',email:'push-reader@example.test',role:'reader',permissions:[]};
  const t={companyId:'push-company',projectId:'push-project',requesterId:client.uid,visibility:'project',number:'DTS-PUSH'};
  let sequence=0;
  const login=(a:Actor,slot='web',installationId=randomUUID())=>deviceAction(a,'registerDevice',{slot,platform:slot==='web'?'web':'android',label:slot==='web'?'Chrome prueba':'Android prueba',installationId}) as Promise<any>;
  const token=(a:Actor,sessionId:string,value=`valid-test-token-${++sequence}-abcdefghijklmnopqrstuvwxyz`)=>deviceAction(a,'updateDeviceToken',{sessionId,token:value,permission:'authorized'});
  const event=async(audience='public')=>{let eventId='';await db.runTransaction(async tx=>{eventId=notificationEvent(tx,owner,'push-ticket',t,'ticket.transition',audience,'DTS-PUSH: analisis → resuelto');});return eventId;};
  const notices=(id:string)=>db.collection('notifications').where('eventId','==',id).get();
  const notice=async(id:string,uid=client.uid)=>(await notices(id)).docs.find(d=>d.get('recipientId')===uid)!;
  beforeAll(async()=>{
    for(const a of [owner,client,commercial,technician,reader]) {
      await db.doc(`users/${a.uid}`).set({...a,active:true});
      await db.doc(`memberships/${a.uid}_push-company`).set({uid:a.uid,companyId:'push-company',active:true,allProjects:true,ticketScope:'project'});
    }
    await db.doc('tickets/push-ticket').set(t);
  });
  it('keeps mobile and web independently; replacing web preserves mobile',async()=>{
    const web=await login(client),mobile=await login(client,'mobile');await token(client,mobile.sessionId);
    const next=await login(client);expect(next.sessionId).not.toBe(web.sessionId);
    const slots=await db.collection(`userDevices/${client.uid}/slots`).get();expect(slots.size).toBe(2);
    expect(slots.docs.find(d=>d.id==='mobile')?.get('sessionId')).toBe(mobile.sessionId);
    const result:any=await deviceAction(client,'myDevices',{});expect(JSON.stringify(result)).not.toContain('token');expect(JSON.stringify(result)).not.toContain('installationId');
  });
  it('rejects mismatched platform and forged ownership',async()=>{
    await expect(deviceAction(client,'registerDevice',{slot:'web',platform:'android',label:'invalid',installationId:randomUUID()})).rejects.toThrow();
    const session=await login(client);await expect(token(owner,session.sessionId)).rejects.toThrow();
    expect(await deviceContext(owner.uid,{sessionId:session.sessionId})).toBeNull();
  });
  it('concurrent logins leave one winner; stale refresh and logout cannot remove it',async()=>{
    const sessions=await Promise.all(Array.from({length:4},()=>login(client)));
    const current=(await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('sessionId');
    await token(client,current);
    for(const s of sessions.filter(s=>s.sessionId!==current)) {
      expect(await token(client,s.sessionId)).toMatchObject({superseded:true});
      expect(await deviceAction(client,'unregisterDevice',{sessionId:s.sessionId})).toMatchObject({superseded:true});
    }
    expect((await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('token')).toBeTruthy();
  });
  it('moving one browser token to a different account clears its previous owner',async()=>{
    const a=await login(client),b=await login(owner);const shared='shared-browser-token-abcdefghijklmnopqrstuvwxyz';
    await token(client,a.sessionId,shared);await token(owner,b.sessionId,shared);
    expect((await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('token')).toBeNull();
    expect((await db.doc(`userDevices/${owner.uid}/slots/web`).get()).get('token')).toBe(shared);
  });
  it('logout disables only its own current destination and records session end',async()=>{
    const web=await login(client);await token(client,web.sessionId);
    await deviceAction(client,'unregisterDevice',{sessionId:web.sessionId});
    expect((await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('token')).toBeNull();
    expect(await deviceContext(client.uid,{sessionId:web.sessionId})).toBeNull();
    expect((await db.doc(`userDevices/${client.uid}/slots/mobile`).get()).get('token')).toBeTruthy();
  });
  it('public lifecycle events include administrators, authorized clients, technician and reader',async()=>{
    const id=await event();await processNotificationEvent(id,async()=> 'mock/provider-id');
    const ids=(await notices(id)).docs.map(d=>d.get('recipientId'));
    for(const a of [owner,client,commercial,technician,reader])expect(ids).toContain(a.uid);
    const n=await notice(id);expect((await n.ref.collection('deliveries').get()).size).toBe(2);
  });
  it('internal notes never fan out to clients, technicians or readers',async()=>{
    const id=await event('internal');await processNotificationEvent(id,async()=> 'mock/internal');
    const ids=(await notices(id)).docs.map(d=>d.get('recipientId'));
    expect(ids).toContain(owner.uid);expect(ids).toContain(commercial.uid);
    for(const a of [client,technician,reader])expect(ids).not.toContain(a.uid);
  });
  it('technical notes are hidden from commercial administrators and clients',async()=>{
    const id=await event('technical');await processNotificationEvent(id,async()=> 'mock/technical');
    const ids=(await notices(id)).docs.map(d=>d.get('recipientId'));
    expect(ids).toContain(owner.uid);expect(ids).toContain(technician.uid);
    for(const a of [client,commercial,reader])expect(ids).not.toContain(a.uid);
  });
  it('failed business transaction leaves no event behind',async()=>{
    const count=(await db.collection('notificationEvents').count().get()).data().count;
    await expect(db.runTransaction(async tx=>{notificationEvent(tx,owner,'push-ticket',t,'ticket.comment','public','Should not exist');throw new Error('abort');})).rejects.toThrow('abort');
    expect((await db.collection('notificationEvents').count().get()).data().count).toBe(count);
  });
  it('duplicate concurrent dispatch claims produce one inbox entry per recipient and one send per slot',async()=>{
    const id=await event();let sends=0;const sender=async()=>{sends++;return 'mock/concurrent';};
    await Promise.all([processNotificationEvent(id,sender),processNotificationEvent(id,sender),processNotificationEvent(id,sender)]);
    const initial=sends;await processNotificationEvent(id,sender);expect(sends).toBe(initial);
    const rows=await notices(id);expect(new Set(rows.docs.map(d=>d.get('recipientId'))).size).toBe(rows.size);
    expect((await db.doc(`notificationEvents/${id}`).get()).get('state')).toBe('done');
  });
  it('payload on lock screens omits business text and identifies the durable notice',async()=>{
    const id=await event();const messages:any[]=[];await processNotificationEvent(id,async m=>{messages.push(m);return 'mock/safe';});
    expect(messages.length).toBeGreaterThan(0);
    for(const m of messages){expect(m.notification.body).not.toContain('DTS-PUSH');expect(m.notification.body).not.toContain('resuelto');expect(m.data.notificationId).toBeTruthy();expect(m.webpush.fcmOptions.link).toContain('?notification=');}
  });
  it('provider acceptance does not fabricate receipt, opening or reading',async()=>{
    const web=await login(client);await token(client,web.sessionId);
    const id=await event();await processNotificationEvent(id,async()=> 'mock/accepted');
    const n=await notice(id),d=await n.ref.collection('deliveries').doc('web').get();
    expect(d.get('status')).toBe('accepted');expect(d.get('receivedAt')).toBeUndefined();expect(n.get('readAt')).toBeNull();
  });
  it('receipts are owner-bound and concurrent acknowledgements preserve first timestamp',async()=>{
    const web=await login(client);await token(client,web.sessionId);
    const actor={...client,device:await deviceContext(client.uid,web)};
    const id=await event();await processNotificationEvent(id,async()=> 'mock/receipt');const n=await notice(id);
    await expect(notificationAction(owner,'markRead',{id:n.id})).rejects.toThrow();
    await expect(notificationAction(client,'notificationReceipt',{id:n.id,kind:'received'})).rejects.toThrow();
    await notificationAction(actor,'notificationReceipt',{id:n.id,kind:'received'});
    await Promise.all(Array.from({length:4},()=>notificationAction(actor,'markRead',{id:n.id})));
    const first=(await n.ref.get()).get('readAt');await notificationAction(actor,'markRead',{id:n.id});expect((await n.ref.get()).get('readAt')).toBe(first);
    expect((await n.ref.collection('deliveries').doc('web').get()).get('receivedAt')).toBeTruthy();
    const detail=JSON.stringify(await notificationAction(actor,'notificationDetail',{id:n.id}));expect(detail).not.toContain('installationId');expect(detail).not.toContain('sessionId');expect(detail).not.toContain('lease');
  });
  it('a revoked membership removes access to an existing notification and its contents',async()=>{
    const id=await event();await processNotificationEvent(id,async()=> 'mock/revoke');const n=await notice(id);
    await db.doc(`memberships/${client.uid}_push-company`).update({active:false});
    await expect(notificationAction(client,'notificationDetail',{id:n.id})).rejects.toThrow();
    expect((await notificationList(client,{limit:100})).items.some((v:any)=>v.id===n.id)).toBe(false);
    await db.doc(`memberships/${client.uid}_push-company`).update({active:true});
  });
  it('requester-only scope excludes a second client while allowing its requester',async()=>{
    await db.doc('users/push-other-client').set({role:'client',active:true});
    await db.doc('memberships/push-other-client_push-company').set({active:true,allProjects:true,ticketScope:'requester'});
    expect(await mayReceive('push-other-client',{...t,ticketId:'push-ticket',audience:'public'})).toBe(false);
    expect(await mayReceive(client.uid,{...t,ticketId:'push-ticket',audience:'public'})).toBe(true);
  });
  it('transient errors are retried, accepted sends are not repeated',async()=>{
    const web=await login(client);await token(client,web.sessionId);
    const id=await event();let failures=0;
    await processNotificationEvent(id,async m=>{if(m.data?.slot==='web'){failures++;throw Object.assign(new Error('offline'),{code:'messaging/server-unavailable'});}return 'mock/mobile';});
    expect(failures).toBeGreaterThan(0);expect((await db.doc(`notificationEvents/${id}`).get()).get('state')).toBe('pending');
    for(const n of (await notices(id)).docs)for(const d of (await n.ref.collection('deliveries').get()).docs)if(d.get('status')==='retry')await d.ref.update({nextAttemptAt:'2000-01-01T00:00:00.000Z'});
    let retries=0;await processNotificationEvent(id,async()=>{retries++;return 'mock/retry';});expect(retries).toBe(failures);
    expect((await db.doc(`notificationEvents/${id}`).get()).get('state')).toBe('done');
  });
  it('invalid tokens are removed and permanent provider failures are visible',async()=>{
    const web=await login(client);await token(client,web.sessionId);
    const id=await event();await processNotificationEvent(id,async()=>{throw Object.assign(new Error('gone'),{code:'messaging/registration-token-not-registered'});});
    const n=await notice(id);expect((await n.ref.collection('deliveries').doc('web').get()).get('status')).toBe('invalid_token');
    expect((await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('token')).toBeNull();
  });
  it('denied permission is recorded separately from no device and does not block inbox',async()=>{
    const web=await login(client);await deviceAction(client,'updateDeviceToken',{sessionId:web.sessionId,token:null,permission:'denied'});
    const id=await event();await processNotificationEvent(id,async()=> 'mock/none');
    const n=await notice(id);expect(n.exists).toBe(true);expect((await n.ref.collection('deliveries').doc('web').get()).get('status')).toBe('permission_denied');
  });
  it('historical migration preserves reading without sending retroactive pushes',async()=>{
    const id=await event();await db.doc(`notificationEvents/${id}`).update({historical:true,readBy:{[client.uid]:'2026-01-01T00:00:00.000Z'}});
    let sends=0;await processNotificationEvent(id,async()=>{sends++;return 'unexpected';});expect(sends).toBe(0);
    const n=await notice(id);expect(n.get('readAt')).toBe('2026-01-01T00:00:00.000Z');expect((await n.ref.collection('deliveries').doc('web').get()).get('status')).toBe('historical');
  });
  it('revocation between attempts cancels the remaining send without deleting history',async()=>{
    const web=await login(client);await token(client,web.sessionId);const id=await event();
    await processNotificationEvent(id,async()=>{throw Object.assign(new Error('offline'),{code:'messaging/server-unavailable'});});const n=await notice(id);
    await db.doc(`memberships/${client.uid}_push-company`).update({active:false});
    await processNotificationEvent(id,async()=> 'unexpected');
    expect((await n.ref.collection('deliveries').doc('web').get()).get('status')).toBe('cancelled');expect((await n.ref.get()).exists).toBe(true);
    await db.doc(`memberships/${client.uid}_push-company`).update({active:true});
  });
  it('a token becoming invalid during rotation cannot delete the replacement token',async()=>{
    const web=await login(client);const oldToken='old-rotation-token-abcdefghijklmnopqrstuvwxyz',newToken='new-rotation-token-abcdefghijklmnopqrstuvwxyz';await token(client,web.sessionId,oldToken);
    const id=await event();await processNotificationEvent(id,async m=>{if('token' in m&&m.token===oldToken){await token(client,web.sessionId,newToken);throw Object.assign(new Error('expired'),{code:'messaging/registration-token-not-registered'});}return 'mock/other';});
    expect((await db.doc(`userDevices/${client.uid}/slots/web`).get()).get('token')).toBe(newToken);
  });
});
