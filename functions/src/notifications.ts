import {createHash, randomUUID} from 'node:crypto';
import {getFirestore, Transaction, DocumentData} from 'firebase-admin/firestore';
import {getMessaging, Message} from 'firebase-admin/messaging';
import {HttpsError} from 'firebase-functions/v2/https';
import {z} from 'zod';
import {Actor, id, hasPermission} from './domain';

const db=()=>getFirestore();
const stamp=()=>new Date().toISOString();
const hash=(s:string)=>createHash('sha256').update(s).digest('hex');
const slotSchema=z.enum(['web','mobile']);
const deviceSchema=z.object({slot:slotSchema,installationId:z.string().uuid(),platform:z.enum(['web','android','ios']),label:z.string().trim().min(1).max(150)}).refine(v=>v.slot===(v.platform==='web'?'web':'mobile'),'Plataforma incompatible');
const tokenSchema=z.object({sessionId:z.string().uuid(),token:z.string().min(20).max(4096).nullable(),permission:z.enum(['authorized','provisional','denied','notDetermined','unavailable'])});
const deny=()=>{throw new HttpsError('permission-denied','Notificación o dispositivo no autorizado');};
export function deliveryView(slot:string,d:DocumentData) {
  const fields=['status','attempts','platform','label','updatedAt','acceptedAt','receivedAt','openedAt','readAt','nextAttemptAt','errorCode','reason'];
  return {slot,...Object.fromEntries(fields.filter(k=>d[k]!==undefined).map(k=>[k,d[k]]))};
}

export async function deviceContext(uid:string,input:any) {
  if(!input?.sessionId||!z.string().uuid().safeParse(input.sessionId).success)return null;
  const s=(await db().doc(`deviceSessions/${input.sessionId}`).get()).data();
  if(!s||s.uid!==uid||s.signedOutAt)return null;
  return {sessionId:input.sessionId,slot:s.slot,platform:s.platform,label:s.label,installationId:s.installationId};
}

export async function deviceAction(a:Actor,action:string,input:unknown) {
  if(action==='myDevices') {
    const rows=await db().collection(`userDevices/${a.uid}/slots`).get();
    return {items:rows.docs.map(s=>{const d=s.data();return {slot:s.id,platform:d.platform,label:d.label,lastLoginAt:d.lastLoginAt,permission:d.permission,enabled:!!d.token,signedOutAt:d.signedOutAt||null,current:d.sessionId===a.device?.sessionId};})};
  }
  if(action==='registerDevice') {
    const v=deviceSchema.parse(input);const sessionId=randomUUID();const lastLoginAt=stamp();
    await db().runTransaction(async tx=>{
      const ref=db().doc(`userDevices/${a.uid}/slots/${v.slot}`);const old=await tx.get(ref);
      // A login replaces only its own category. A stale refresh cannot take it back.
      if(old.get('token'))tx.delete(db().doc(`pushTokens/${hash(old.get('token'))}`));
      tx.set(ref,{...v,sessionId,lastLoginAt,permission:'notDetermined',token:null});
      tx.create(db().doc(`deviceSessions/${sessionId}`),{...v,uid:a.uid,lastLoginAt});
      tx.create(db().collection('audit').doc(),{actorId:a.uid,action:'device.login',entity:ref.path,createdAt:lastLoginAt,device:{...v,sessionId}});
    });
    return {sessionId,slot:v.slot};
  }
  const v=action==='updateDeviceToken'?tokenSchema.parse(input):z.object({sessionId:z.string().uuid()}).parse(input);
  return db().runTransaction(async tx=>{
    const sessionRef=db().doc(`deviceSessions/${v.sessionId}`);const session=await tx.get(sessionRef);
    if(session.get('uid')!==a.uid)deny();
    const ref=db().doc(`userDevices/${a.uid}/slots/${session.get('slot')}`);const current=await tx.get(ref);
    if(current.get('sessionId')!==v.sessionId||session.get('signedOutAt'))return {ok:false,superseded:true};
    const token=action==='updateDeviceToken'?(v as z.infer<typeof tokenSchema>).token:null;
    const permission=action==='updateDeviceToken'?(v as z.infer<typeof tokenSchema>).permission:current.get('permission');
    if(token&&!['authorized','provisional'].includes(permission))throw new HttpsError('invalid-argument','Activa el permiso antes de registrar el destino');
    const tokenRef=token?db().doc(`pushTokens/${hash(token)}`):null;
    const previous=tokenRef?await tx.get(tokenRef):null;
    const previousPath=previous?.get('path');
    const previousDevice=previousPath&&previousPath!==ref.path?await tx.get(db().doc(previousPath)):null;
    if(previousDevice?.get('token')===token)tx.update(previousDevice.ref,{token:null,disabledAt:stamp()});
    if(current.get('token')&&current.get('token')!==token)tx.delete(db().doc(`pushTokens/${hash(current.get('token'))}`));
    if(tokenRef)tx.set(tokenRef,{path:ref.path,uid:a.uid,updatedAt:stamp()});
    tx.update(ref,{token,permission,lastTokenAt:stamp(),...(action==='unregisterDevice'?{signedOutAt:stamp()}:{})});
    if(action==='unregisterDevice')tx.update(sessionRef,{signedOutAt:stamp()});
    return {ok:true};
  });
}

export function notificationEvent(tx:Transaction,a:Actor,ticketId:string,t:DocumentData,kind:string,audience:string,body:string) {
  const ref=db().collection('notificationEvents').doc();
  tx.create(ref,{ticketId,entityId:ticketId,companyId:t.companyId,projectId:t.projectId,kind,audience,body,actorId:a.uid,device:a.device||null,createdAt:stamp(),state:'pending',nextAttemptAt:stamp()});
  return ref.id;
}

// Authorization is evaluated again when expanding, sending, listing and opening.
export async function mayReceive(uid:string,e:DocumentData) {
  const u=(await db().doc(`users/${uid}`).get()).data();if(!u?.active)return false;
  const staff=['owner','commercial'].includes(u.role);
  if(e.audience==='internal'&&!staff)return false;
  if(e.audience==='technical'&&!hasPermission({uid,email:'',role:u.role,permissions:u.permissions||[]},'technical'))return false;
  if(e.audience==='staff')return staff;
  if(e.targetUid&&e.targetUid!==uid)return false;
  if(staff)return true;
  if(!e.companyId)return e.targetUid===uid;
  const m=(await db().doc(`memberships/${uid}_${e.companyId}`).get()).data();
  if(!m?.active||(!m.allProjects&&!m.projectIds?.includes(e.projectId)))return false;
  if(e.ticketId) {
    const t=(await db().doc(`tickets/${e.ticketId}`).get()).data();if(!t)return false;
    if(u.role==='client'&&(m.ticketScope==='requester'||t.visibility==='requester')&&t.requesterId!==uid)return false;
  }
  return true;
}

export type Sender=(message:Message)=>Promise<string>;
const realSender:Sender=message=>getMessaging().send(message);
const terminal=new Set(['accepted','no_device','permission_denied','invalid_token','failed','cancelled','historical']);

async function sendSlot(notificationId:string,uid:string,e:DocumentData,slot:string,sender:Sender) {
  const ref=db().doc(`notifications/${notificationId}/deliveries/${slot}`);
  const lease=randomUUID();
  const claimed=await db().runTransaction(async tx=>{
    const d=await tx.get(ref);
    if(terminal.has(d.get('status'))||d.get('nextAttemptAt')>stamp()||d.get('leaseUntil')>stamp())return false;
    tx.set(ref,{status:'processing',attempts:(d.get('attempts')||0)+1,lease,leaseUntil:new Date(Date.now()+120000).toISOString(),updatedAt:stamp()},{merge:true});return true;
  });
  if(!claimed)return;
  let result:DocumentData;
  const deviceRef=db().doc(`userDevices/${uid}/slots/${slot}`);const device=(await deviceRef.get()).data();
  if(e.historical)result={status:'historical'};
  else if(!await mayReceive(uid,e))result={status:'cancelled',reason:'access_revoked'};
  else if(e.source&&e.dueDate&&(await db().doc(`${e.source}/${e.entityId}`).get()).get('endDate')!==e.dueDate)result={status:'cancelled',reason:'renewed'};
  else if(!device)result={status:'no_device'};
  else if(!['authorized','provisional'].includes(device.permission))result={status:'permission_denied'};
  else if(!device.token||device.signedOutAt)result={status:'no_device'};
  else {
    const context={sessionId:device.sessionId,installationId:device.installationId,platform:device.platform,label:device.label};
    // Persist target before the provider call: a fast client may acknowledge immediately.
    await ref.update(context);
    const message:Message={token:device.token,notification:{title:'DTS · Nueva actualización',body:'Tienes una novedad. Abre DTS para consultar el detalle.'},data:{notificationId,ticketId:e.ticketId||'',slot},android:{priority:'high',notification:{tag:notificationId,channelId:'dts_updates'}},apns:{headers:{'apns-collapse-id':hash(notificationId).slice(0,64)},payload:{aps:{sound:'default'}}},webpush:{notification:{tag:notificationId,icon:'/icons/Icon-192.png'},fcmOptions:{link:`https://sistema-de-gestion-y-pqrs.web.app/?notification=${notificationId}`}}};
    try {result={...context,status:'accepted',providerMessageId:await sender(message),acceptedAt:stamp()};}
    catch(error) {
      const code=String((error as any)?.code||'unknown');
      const invalid=['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(code);
      const permanent=invalid||['messaging/invalid-argument','messaging/mismatched-credential','messaging/third-party-auth-error'].includes(code);
      const attempts=(await ref.get()).get('attempts')||1;
      result={...context,status:invalid?'invalid_token':permanent||attempts>=6?'failed':'retry',errorCode:code,nextAttemptAt:new Date(Date.now()+Math.min(3600000,30000*2**attempts)).toISOString()};
      if(invalid)await db().runTransaction(async tx=>{const latest=await tx.get(deviceRef);if(latest.get('token')===device.token){tx.update(deviceRef,{token:null,disabledAt:stamp()});tx.delete(db().doc(`pushTokens/${hash(device.token)}`));}});
    }
  }
  await db().runTransaction(async tx=>{const latest=await tx.get(ref);if(latest.get('lease')===lease)tx.update(ref,{...result,updatedAt:stamp(),leaseUntil:null});});
}

export async function processNotificationEvent(eventId:string,sender:Sender=realSender) {
  const ref=db().doc(`notificationEvents/${eventId}`);const lease=randomUUID();
  const e=await db().runTransaction(async tx=>{
    const s=await tx.get(ref);if(!s.exists||s.get('state')==='done'||s.get('leaseUntil')>stamp())return null;
    tx.update(ref,{lease,leaseUntil:new Date(Date.now()+240000).toISOString(),nextAttemptAt:new Date(Date.now()+300000).toISOString()});return s.data()!;
  });
  if(!e)return;
  try {
    // Fanout has durable deterministic IDs; duplicate events cannot duplicate the inbox.
    let users=db().collection('users').orderBy('__name__').limit(100);let cursor:string|undefined;
    do {
      const page=await (cursor?users.startAfter(cursor):users).get();
      for(const user of page.docs) {
        if(!await mayReceive(user.id,e))continue;
        const notificationId=`${eventId}_${hash(user.id).slice(0,32)}`;
        const notificationRef=db().doc(`notifications/${notificationId}`);
        await db().runTransaction(async tx=>{const old=await tx.get(notificationRef);if(!old.exists)tx.create(notificationRef,{eventId,recipientId:user.id,audience:user.id,entityId:e.entityId,ticketId:e.ticketId||null,companyId:e.companyId||null,projectId:e.projectId||null,body:e.body,kind:e.kind,createdAt:e.createdAt,status:'pending',readAt:e.readBy?.[user.id]||null,...(e.readBy?.[user.id]?{readBy:{[user.id]:e.readBy[user.id]}}:{})});});
        await Promise.all(['web','mobile'].map(slot=>sendSlot(notificationId,user.id,e,slot,sender)));
      }
      cursor=page.size===100?page.docs[99].id:undefined;
    }while(cursor);
    // Include recipients whose access was revoked between attempts, preserving history.
    const notices=await db().collection('notifications').where('eventId','==',eventId).get();let pending=false;
    for(const n of notices.docs)for(const slot of ['web','mobile']) {
      const delivery=await n.ref.collection('deliveries').doc(slot).get();
      if(!terminal.has(delivery.get('status'))) {
        if(!await mayReceive(n.get('recipientId'),e))await delivery.ref.set({status:'cancelled',reason:'access_revoked',updatedAt:stamp()},{merge:true});
        else pending=true;
      }
    }
    await db().runTransaction(async tx=>{const s=await tx.get(ref);if(s.get('lease')===lease)tx.update(ref,{state:pending?'pending':'done',leaseUntil:null,processedAt:stamp()});});
  }catch(error){await ref.update({leaseUntil:null,nextAttemptAt:new Date(Date.now()+300000).toISOString()});throw error;}
}

export async function retryNotificationEvents() {
  const due=await db().collection('notificationEvents').where('state','==','pending').where('nextAttemptAt','<=',stamp()).orderBy('nextAttemptAt').limit(100).get();
  for(const event of due.docs)await processNotificationEvent(event.id);
}

export async function legacyNotification(eventId:string,data:DocumentData) {
  if(data.recipientId)return;
  const ref=db().doc(`notificationEvents/legacy_${eventId}`);
  let ticket:DocumentData|undefined;
  if(!data.source&&data.entityId)ticket=(await db().doc(`tickets/${data.entityId}`).get()).data();
  await db().runTransaction(async tx=>{if((await tx.get(ref)).exists)return;tx.create(ref,{kind:'notice',entityId:data.entityId||'',ticketId:ticket?data.entityId:null,companyId:data.companyId||ticket?.companyId||null,projectId:data.projectId||ticket?.projectId||null,source:data.source||null,dueDate:data.dueDate||null,audience:data.audience==='staff'?'staff':'public',targetUid:data.audience==='staff'?null:data.audience,body:data.body,actorId:'system',createdAt:data.createdAt,state:'pending',nextAttemptAt:stamp()});});
}

async function ownNotice(a:Actor,noticeId:string) {
  const n=await db().doc(`notifications/${noticeId}`).get();
  if(!n.exists||n.get('recipientId')!==a.uid)deny();
  const e=n.get('eventId')?(await db().doc(`notificationEvents/${n.get('eventId')}`).get()).data():null;
  if(e&&!await mayReceive(a.uid,e))deny();
  return {n,e};
}

export async function notificationList(a:Actor,input:any) {
  const v=z.object({limit:z.number().int().min(1).max(100).default(50),cursor:id.optional()}).parse(input);
  let q=db().collection('notifications').where('recipientId','==',a.uid).orderBy('createdAt','desc').orderBy('__name__','desc');
  if(v.cursor){const s=await db().doc(`notifications/${v.cursor}`).get();if(s.exists&&s.get('audience')===a.uid)q=q.startAfter(s);}
  const page=await q.limit(v.limit+1).get();const items=[];
  for(const n of page.docs.slice(0,v.limit)) {
    const e=n.get('eventId')?(await db().doc(`notificationEvents/${n.get('eventId')}`).get()).data():null;
    if(e&&!await mayReceive(a.uid,e))continue;
    const deliveries=await n.ref.collection('deliveries').get();
    items.push({id:n.id,...n.data(),deliveries:deliveries.docs.map(d=>deliveryView(d.id,d.data()))});
  }
  return {items,cursor:page.size>v.limit?page.docs[v.limit-1].id:null};
}

export async function notificationAction(a:Actor,action:string,input:unknown) {
  const v=z.object({id,kind:z.enum(['received','opened','read']).default('read')}).parse(input);
  const {n,e}=await ownNotice(a,v.id);
  if(action==='notificationDetail')return {id:n.id,...n.data(),device:e?.device?{slot:e.device.slot,platform:e.device.platform,label:e.device.label}:null,deliveries:(await n.ref.collection('deliveries').get()).docs.map(s=>deliveryView(s.id,s.data()))};
  const kind=action==='markRead'?'read':v.kind;
  await db().runTransaction(async tx=>{
    const current=await tx.get(n.ref);
    const deliveryRef=a.device? n.ref.collection('deliveries').doc(a.device.slot):null;
    const delivery=deliveryRef?await tx.get(deliveryRef):null;
    const field=`${kind}At`;
    if(kind!=='read'&&(!delivery||delivery.get('installationId')!==a.device?.installationId))deny();
    if(!current.get(field))tx.update(n.ref,{[field]:stamp(),...(kind==='read'?{[`readBy.${a.uid}`]:stamp()}:{})});
    if(delivery?.exists&&delivery.get('installationId')===a.device?.installationId&&!delivery.get(field))tx.update(delivery.ref,{[field]:stamp()});
  });return {ok:true};
}
