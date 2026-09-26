import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, FieldValue, FieldPath, Transaction, Query, DocumentData} from 'firebase-admin/firestore';
import {onCall, HttpsError, CallableRequest} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {deviceContext, deviceAction, notificationEvent, notificationList, notificationAction, processNotificationEvent, retryNotificationEvents, legacyNotification, mayReceive, deliveryView} from './notifications';
import {setGlobalOptions} from 'firebase-functions/v2';
import {z} from 'zod';
import {randomBytes, createHash} from 'node:crypto';
import {DateTime} from 'luxon';
import {Actor, Role, id, text, name, date, roleSchema, schemas, ticketSchema, audienceSchema, statuses, TicketStatus, canTransition, hasPermission, businessDeadline, businessMinutes, daysUntil, reminderKey} from './domain';
import {importSchema, inspectFiles, githubFiles, looksSensitive, Candidate} from './importer';

initializeApp();
setGlobalOptions({region:'us-central1', maxInstances:10, memory:'256MiB'});
const db=getFirestore();
const now=()=>new Date().toISOString();
function deny(message='No tienes permisos para esta operación'):never {throw new HttpsError('permission-denied',message);}
function requirePermission(a:Actor,p:string) {if(!hasPermission(a,p))deny();}
async function actor(req:CallableRequest):Promise<Actor> {
  if(!req.auth)throw new HttpsError('unauthenticated','Inicia sesión para continuar');
  if(!req.auth.token.email_verified)deny('Verifica tu correo antes de acceder');
  const profile=(await db.doc(`users/${req.auth.uid}`).get()).data();
  if(!profile?.active)deny('Tu cuenta todavía no tiene acceso. Solicita una invitación a DTS.');
  return {uid:req.auth.uid,email:String(req.auth.token.email||''),role:roleSchema.parse(profile.role),permissions:profile.permissions||[],device:await deviceContext(req.auth.uid,req.data?.clientContext)};
}
const isStaff=(a:Actor)=>['owner','commercial'].includes(a.role);
async function scope(a:Actor,companyId:string,projectId?:string) {
  id.parse(companyId);
  const company=await db.doc(`companies/${companyId}`).get();if(!company.exists)throw new HttpsError('not-found','Empresa no encontrada');
  if(projectId) {id.parse(projectId);const p=await db.doc(`projects/${projectId}`).get();if(!p.exists||p.get('companyId')!==companyId)deny('El proyecto no pertenece a esta empresa');}
  if(isStaff(a))return {allProjects:true,ticketScope:'project'};
  const m=(await db.doc(`memberships/${a.uid}_${companyId}`).get()).data();
  if(!m?.active || (projectId&&!m.allProjects&&!m.projectIds?.includes(projectId)))deny();
  return m;
}
async function ticketAccess(a:Actor,ticketId:string) {
  const snap=await db.doc(`tickets/${id.parse(ticketId)}`).get();if(!snap.exists)throw new HttpsError('not-found','Solicitud no encontrada');
  const t=snap.data()!;const m=await scope(a,t.companyId,t.projectId);
  if(a.role==='client'&&(m.ticketScope==='requester'||t.visibility==='requester')&&t.requesterId!==a.uid)deny();
  return {ref:snap.ref,data:t};
}
function audit(tx:Transaction,a:Actor,action:string,entity:string,summary:Record<string,unknown>={}) {
  tx.create(db.collection('audit').doc(),{actorId:a.uid,action,entity,summary,device:a.device||null,createdAt:now()});
}
function publicEvent(tx:Transaction,ticketId:string,a:Actor,body:string) {
  tx.create(db.collection(`tickets/${ticketId}/public`).doc(),{kind:'event',body,authorId:a.uid,createdAt:now(),audience:'public'});
}
const allowedLists=['companies','projects','contacts','catalog','articles','events','contracts','services','finance','tickets','memberships','users','notifications','audit','repositories','imports','catalogReviews','publicContracts','publicServices','installations','products'];
const privateLists=['contacts','contracts','services','finance','users','audit','products'];
async function list(a:Actor,input:unknown) {
  const v=z.object({collection:z.enum(allowedLists as [string,...string[]]),companyId:id.optional(),projectId:id.optional(),cursor:z.string().max(200).optional(),limit:z.number().int().min(1).max(100).default(30),status:text.optional(),category:text.optional(),priority:text.optional(),assigneeId:text.optional(),mine:z.boolean().optional(),search:z.string().max(100).optional()}).parse(input);
  if(v.collection==='notifications')return notificationList(a,v);
  if(privateLists.includes(v.collection)&&!isStaff(a))deny();
  if(['repositories','imports','catalogReviews'].includes(v.collection))requirePermission(a,'technical');
  if(v.collection==='users'||v.collection==='audit')requirePermission(a,'manageAccess');
  let q:Query=db.collection(v.collection);
  if(v.collection==='memberships'&&!isStaff(a))q=q.where('uid','==',a.uid).where('active','==',true);
  else if(v.collection==='notifications')q=q.where('audience','==',isStaff(a)?'staff':a.uid).where('status','==','pending');
  else if(!isStaff(a)) {
    if(!v.companyId)throw new HttpsError('invalid-argument','Selecciona una empresa');
    const m=await scope(a,v.companyId,v.projectId);
    if(v.collection==='companies') {
      const s=await db.doc(`companies/${v.companyId}`).get();const d=s.data()!;
      return {items:[{id:s.id,name:d.name,description:d.description,status:d.status}],cursor:null};
    }
    if(!m.allProjects&&!v.projectId) {
      if(v.collection==='projects') {
        const ids=(m.projectIds||[]).slice(0,30);if(!ids.length)return {items:[],cursor:null};
        q=q.where(FieldPath.documentId(),'in',ids);
      } else throw new HttpsError('invalid-argument','Selecciona un proyecto autorizado');
    }
    if(v.collection==='tickets') {
      // Scope is always applied in the query, not by filtering an unrestricted page.
      if(m.ticketScope==='requester'||v.mine)q=q.where('requesterId','==',a.uid);
      else q=q.where('visibleTo','array-contains-any',['project',a.uid]);
    }
    if(['catalog','articles','events','installations'].includes(v.collection))q=q.where('published','==',true);
  }
  if(v.companyId&&v.collection==='companies')q=q.where(FieldPath.documentId(),'==',v.companyId);
  if(v.companyId&&!['companies','products'].includes(v.collection)) {await scope(a,v.companyId,v.projectId);q=q.where('companyId','==',v.companyId);}
  if(v.projectId&&!['projects','companies','products'].includes(v.collection))q=q.where('projectId','==',v.projectId);
  if(v.projectId&&v.collection==='projects')q=q.where(FieldPath.documentId(),'==',v.projectId);
  if(v.status)q=q.where('status','==',v.status);
  if(v.category)q=q.where('category','==',v.category);
  if(v.priority)q=q.where('priority','==',v.priority);
  if(v.assigneeId!==undefined)q=q.where('assigneeId','==',v.assigneeId);
  if(v.mine&&isStaff(a))q=q.where('assigneeId','==',a.uid);
  // Stable document-id pagination avoids offset reads. Search is a prefix on normalized names.
  if(v.search) {q=q.orderBy('searchName');}
  q=q.orderBy(FieldPath.documentId());
  if(v.search) {q=q.startAt(v.search.toLocaleLowerCase('es')).endAt(v.search.toLocaleLowerCase('es')+'\uf8ff');}
  if(v.cursor){const cursor=await db.doc(`${v.collection}/${id.parse(v.cursor)}`).get();if(cursor.exists)q=q.startAfter(cursor);}
  const docs=await q.limit(v.limit+1).get();
  return {items:docs.docs.slice(0,v.limit).map(s=>({id:s.id,...s.data()})),cursor:docs.size>v.limit?docs.docs[v.limit-1].id:null};
}
async function save(a:Actor,input:unknown) {
  requirePermission(a,'manage');
  const v=z.object({collection:z.enum(Object.keys(schemas) as [keyof typeof schemas,...(keyof typeof schemas)[]]),id:id.optional(),data:z.unknown(),updatedAt:z.string().optional()}).parse(input);
  const parsed=schemas[v.collection].parse(v.data) as Record<string,any>;
  if(parsed.companyId)await scope(a,parsed.companyId,parsed.projectId);
  if(['services'].includes(v.collection)&&looksSensitive(JSON.stringify(parsed)))throw new HttpsError('invalid-argument','No guardes claves ni contraseñas; usa una referencia al gestor de secretos');
  const ref=v.id?db.doc(`${v.collection}/${v.id}`):db.collection(v.collection).doc();
  await db.runTransaction(async tx=>{
    const old=await tx.get(ref);
    if(v.id&&!old.exists)throw new HttpsError('not-found','Registro no encontrado');
    if(old.exists&&old.get('companyId')!==parsed.companyId)deny('No se puede mover un registro a otra empresa');
    if(old.exists&&old.get('projectId')!==parsed.projectId)deny('No se puede mover un registro a otro proyecto');
    if(v.updatedAt&&old.get('updatedAt')!==v.updatedAt)throw new HttpsError('aborted','El registro cambió. Recarga antes de guardar.');
    const data={...parsed,searchName:String(parsed.name).toLocaleLowerCase('es'),updatedAt:now(),updatedBy:a.uid,...(!old.exists?{createdAt:now(),createdBy:a.uid}:{})};
    tx.set(ref,{...data,createdAt:old.get('createdAt')||data.createdAt||now(),createdBy:old.get('createdBy')||a.uid});
    if(v.collection==='catalog'&&old.exists)tx.create(ref.collection('history').doc(),{...old.data(),archivedAt:now(),archivedBy:a.uid});
    if(['contracts','services'].includes(v.collection)) {
      const pub=db.doc(`${v.collection==='contracts'?'publicContracts':'publicServices'}/${ref.id}`);
      if(parsed.published)tx.set(pub,{companyId:parsed.companyId,projectId:parsed.projectId,name:parsed.name,type:parsed.type,startDate:parsed.startDate,endDate:parsed.endDate,status:parsed.status,updatedAt:now(),searchName:data.searchName});else tx.delete(pub);
    }
    audit(tx,a,old.exists?'update':'create',ref.path,{fields:Object.keys(parsed)});
  });return {id:ref.id};
}
async function createTicket(a:Actor,input:unknown) {
  if(a.role==='reader')deny();
  const v=ticketSchema.parse(input);const m=await scope(a,v.companyId,v.projectId);
  for(const featureId of v.featureIds){const f=await db.doc(`catalog/${featureId}`).get();if(f.get('projectId')!==v.projectId||(!isStaff(a)&&!f.get('published')))deny('Funcionalidad no autorizada');}
  const contracts=await db.collection('contracts').where('companyId','==',v.companyId).where('projectId','==',v.projectId).where('type','==','soporte').limit(50).get();
  const today=DateTime.now().setZone('America/Bogota').toISODate()!;
  const cover=contracts.docs.find(s=>s.get('status')==='activo'&&s.get('startDate')<=today&&s.get('endDate')>=today);
  const policy=cover?.get('sla');const createdAt=now();const ticket=db.collection('tickets').doc();
  const visibility=m.ticketScope==='requester'?'requester':v.visibility;
  const data={...v,visibility,visibleTo:visibility==='requester'?[a.uid]:['project',a.uid],requesterId:a.uid,searchName:v.subject.toLocaleLowerCase('es'),priority:'media',status:'nuevo',assigneeId:'',coverage:cover?'cubierto':'fuera_cobertura',contractId:cover?.id||null,sla:policy||null,responseDue:policy?businessDeadline(createdAt,policy.responseMinutes,policy):null,resolutionDue:policy?businessDeadline(createdAt,policy.resolutionMinutes,policy):null,firstResponseAt:null,resolvedAt:null,pausedAt:null,timeMinutes:0,createdAt,updatedAt:createdAt};
  return db.runTransaction(async tx=>{
    const counter=db.doc('counters/tickets');const c=await tx.get(counter);const sequence=(c.get('value')||0)+1;
    const number=`DTS-${String(sequence).padStart(6,'0')}`;tx.set(counter,{value:sequence});tx.create(ticket,{...data,number});
    publicEvent(tx,ticket.id,a,'Solicitud recibida. DTS revisará su clasificación y cobertura.');
    audit(tx,a,'ticket.create',ticket.path,{number});notificationEvent(tx,a,ticket.id,data,'ticket.create','public',`${number}: solicitud recibida`);
    return {id:ticket.id,number};
  });
}
async function ticketDetail(a:Actor,input:unknown) {
  const v=z.object({id, audience:audienceSchema.default('public'),cursor:id.optional()}).parse(input);
  const {data}=await ticketAccess(a,v.id);
  if(v.audience==='internal'&&!isStaff(a))deny();if(v.audience==='technical')requirePermission(a,'technical');
  let q:Query=db.collection(`tickets/${v.id}/${v.audience}`).orderBy('createdAt').orderBy(FieldPath.documentId());
  if(v.cursor){const s=await db.doc(`tickets/${v.id}/${v.audience}/${v.cursor}`).get();if(s.exists)q=q.startAfter(s);}
  const events=await q.limit(51).get();
  if(v.audience==='technical')await db.collection('audit').add({actorId:a.uid,action:'technical.read',entity:`tickets/${v.id}`,createdAt:now()});
  return {ticket:{id:v.id,...data},items:events.docs.slice(0,50).map(s=>({id:s.id,...s.data()})),cursor:events.size>50?events.docs[49].id:null};
}
async function ticketNotifications(a:Actor,input:unknown) {
  const v=z.object({ticketId:id,cursor:id.optional()}).parse(input);await ticketAccess(a,v.ticketId);
  let q=db.collection('notificationEvents').where('ticketId','==',v.ticketId).orderBy('createdAt','desc').orderBy('__name__','desc');
  if(v.cursor){const s=await db.doc(`notificationEvents/${v.cursor}`).get();if(s.exists&&s.get('ticketId')===v.ticketId)q=q.startAfter(s);}
  const page=await q.limit(51).get();const items=[];
  for(const event of page.docs.slice(0,50)) {
    const e=event.data();if(!await mayReceive(a.uid,e))continue;
    let notices:Query=db.collection('notifications').where('eventId','==',event.id);
    if(!isStaff(a))notices=notices.where('recipientId','==',a.uid);
    const recipients=[];
    for(const n of (await notices.get()).docs) {
      const u=await db.doc(`users/${n.get('recipientId')}`).get();
      recipients.push({id:n.id,recipient:isStaff(a)?u.get('email')||n.get('recipientId'):'Mi cuenta',readAt:n.get('readAt')||null,deliveries:(await n.ref.collection('deliveries').get()).docs.map(s=>deliveryView(s.id,s.data()))});
    }
    items.push({id:event.id,body:e.body,createdAt:e.createdAt,state:e.state,device:e.device?{slot:e.device.slot,platform:e.device.platform,label:e.device.label}:null,recipients});
  }
  return {items,cursor:page.size>50?page.docs[49].id:null};
}
async function comment(a:Actor,input:unknown) {
  const v=z.object({ticketId:id,audience:audienceSchema,body:text.min(1),attachments:z.array(z.object({path:z.string().max(500),name:z.string().max(180),size:z.number().max(10*1024*1024)})).max(5).default([]),minutes:z.number().int().min(0).max(1440).default(0)}).parse(input);
  if(a.role==='reader')deny();const {ref}=await ticketAccess(a,v.ticketId);
  if(v.audience==='internal'&&!isStaff(a))deny();if(v.audience==='technical')requirePermission(a,'technical');
  if(a.role==='client'&&v.minutes!==0)deny();
  if(v.attachments.some(f=>!f.path.startsWith(`attachments/${v.ticketId}/${v.audience}/${a.uid}/`)||f.path.includes('..')))deny('Adjunto fuera de la solicitud');
  await db.runTransaction(async tx=>{
    const ticket=await tx.get(ref);const t=ticket.data()!;
    tx.create(ref.collection(v.audience).doc(),{...v,authorId:a.uid,kind:'comment',createdAt:now()});
    const patch:Record<string,unknown>={updatedAt:now(),timeMinutes:FieldValue.increment(v.minutes)};
    if(isStaff(a)&&v.audience==='public'&&!t.firstResponseAt)patch.firstResponseAt=now();
    tx.update(ref,patch);audit(tx,a,'ticket.comment',ref.path,{audience:v.audience,minutes:v.minutes});
    notificationEvent(tx,a,ref.id,t,'ticket.comment',v.audience,`${t.number}: ${v.audience==='public'?'nueva respuesta':v.audience==='internal'?'nota interna':'nota técnica'}${v.attachments.length?' con evidencia':''}${v.minutes?' y tiempo registrado':''}`);
  });return {ok:true};
}
async function transition(a:Actor,input:unknown) {
  const v=z.object({ticketId:id,status:z.enum(statuses),reason:text.min(3),priority:z.enum(['baja','media','alta','critica']).optional(),assigneeId:z.string().max(128).optional()}).parse(input);
  const {ref,data:existingTicket}=await ticketAccess(a,v.ticketId);
  if(a.role==='client'&&existingTicket.requesterId!==a.uid)deny('Solo el solicitante puede confirmar o reabrir esta solicitud');
  if(a.role==='client'&&(v.priority||v.assigneeId!==undefined))deny();
  let assignee=v.assigneeId;
  if(v.status==='escalado'&&!assignee){const o=await db.collection('users').where('role','==','owner').where('active','==',true).limit(1).get();assignee=o.docs[0]?.id;if(!assignee)throw new HttpsError('failed-precondition','No hay responsable técnico activo');}
  if(assignee){const u=await db.doc(`users/${id.parse(assignee)}`).get();if(!u.get('active')||!['owner','commercial','technician'].includes(u.get('role')))deny('Responsable no autorizado');}
  await db.runTransaction(async tx=>{
    const snap=await tx.get(ref);const t=snap.data()!;
    if(!canTransition(a.role,t.status as TicketStatus,v.status))throw new HttpsError('failed-precondition','Transición no permitida');
    if(a.role==='client'&&v.status==='reabierto'&&t.resolvedAt&&Date.now()-Date.parse(t.resolvedAt)>30*86400000)throw new HttpsError('failed-precondition','Han pasado 30 días. Registra una nueva solicitud y referencia este número.');
    const stamp=now();const patch:Record<string,unknown>={status:v.status,updatedAt:stamp};
    if(v.priority)patch.priority=v.priority;if(assignee!==undefined)patch.assigneeId=assignee;
    if(v.status==='esperando_cliente')patch.pausedAt=stamp;
    if(t.status==='esperando_cliente'&&t.pausedAt&&t.sla){const pause=businessMinutes(t.pausedAt,stamp,t.sla);patch.resolutionDue=businessDeadline(t.resolutionDue,pause,t.sla);if(!t.firstResponseAt)patch.responseDue=businessDeadline(t.responseDue,pause,t.sla);patch.pausedAt=null;}
    if(v.status==='resuelto')patch.resolvedAt=stamp;
    if(v.status==='reabierto')patch.resolvedAt=null;
    tx.update(ref,patch);publicEvent(tx,ref.id,a,`${t.status} → ${v.status}. ${v.reason}`);
    audit(tx,a,'ticket.transition',ref.path,{from:t.status,to:v.status,priorityBefore:t.priority,priorityAfter:v.priority||t.priority,assigneeId:assignee||t.assigneeId});
    notificationEvent(tx,a,ref.id,t,'ticket.transition','public',`${t.number}: ${t.status} → ${v.status}`);
  });return {ok:true};
}
async function accessManagement(a:Actor,input:unknown) {
  requirePermission(a,'manageAccess');
  const v=z.object({uid:id,role:roleSchema,active:z.boolean(),companyId:id.optional(),projectIds:z.array(id).max(30).default([]),allProjects:z.boolean().default(false),ticketScope:z.enum(['project','requester']).default('project'),permissions:z.array(z.enum(['manage','technical'])).max(2).default([])}).parse(input);
  if(v.uid===a.uid&&(v.role!=='owner'||!v.active))throw new HttpsError('failed-precondition','No puedes revocar tu propio acceso principal');
  const user=await getAuth().getUser(v.uid);
  if(v.companyId){await scope(a,v.companyId);for(const p of v.projectIds)await scope(a,v.companyId,p);}
  await db.runTransaction(async tx=>{
    const ref=db.doc(`users/${v.uid}`);await tx.get(ref);
    tx.set(ref,{email:user.email||'',name:user.displayName||user.email||'',role:v.role,active:v.active,permissions:v.role==='commercial'?[]:v.permissions,updatedAt:now()},{merge:true});
    if(v.companyId)tx.set(db.doc(`memberships/${v.uid}_${v.companyId}`),{uid:v.uid,companyId:v.companyId,projectIds:v.projectIds,allProjects:v.allProjects,ticketScope:v.ticketScope,active:v.active,updatedAt:now()});
    audit(tx,a,'access.update',ref.path,{role:v.role,active:v.active,companyId:v.companyId||null});
  });return {ok:true};
}
async function invite(a:Actor,input:unknown) {
  requirePermission(a,'manageAccess');
  const v=z.object({email:z.string().email().transform(s=>s.toLowerCase()),role:z.enum(['client','commercial','technician','reader']).default('client'),companyId:id,projectIds:z.array(id).max(30),allProjects:z.boolean().default(false),ticketScope:z.enum(['project','requester']).default('project')}).parse(input);
  await scope(a,v.companyId);for(const p of v.projectIds)await scope(a,v.companyId,p);
  const token=randomBytes(32).toString('base64url');const hash=createHash('sha256').update(token).digest('hex');
  await db.runTransaction(async tx=>{tx.create(db.doc(`invitations/${hash}`),{...v,expiresAt:new Date(Date.now()+7*86400000).toISOString(),createdBy:a.uid,acceptedBy:null,createdAt:now()});audit(tx,a,'invitation.create',`companies/${v.companyId}`,{email:v.email});});
  return {token,expiresInDays:7};
}
async function accept(req:CallableRequest,input:unknown) {
  if(!req.auth||!req.auth.token.email_verified)deny('Inicia sesión con el correo verificado de la invitación');
  const v=z.object({token:z.string().min(40).max(100)}).parse(input);const hash=createHash('sha256').update(v.token).digest('hex');
  const uid=req.auth.uid;const email=String(req.auth.token.email||'').toLowerCase();
  await db.runTransaction(async tx=>{
    const ref=db.doc(`invitations/${hash}`);const inv=await tx.get(ref);const user=await tx.get(db.doc(`users/${uid}`));const d=inv.data();
    if(!d||d.email!==email||d.expiresAt<now()||d.acceptedBy)deny('Invitación inválida o vencida');
    if(user.exists&&user.get('active')===false)deny('Tu cuenta fue revocada. Contacta al propietario.');
    if(!user.exists)tx.create(db.doc(`users/${uid}`),{email,role:d.role||'client',active:true,permissions:d.role==='technician'?['technical']:[],createdAt:now()});
    tx.set(db.doc(`memberships/${uid}_${d.companyId}`),{uid,companyId:d.companyId,projectIds:d.projectIds,allProjects:d.allProjects,ticketScope:d.ticketScope,active:true,updatedAt:now()});
    tx.update(ref,{acceptedBy:uid,acceptedAt:now()});audit(tx,{uid,email,role:'client',permissions:[]},'invitation.accept',`companies/${d.companyId}`);
  });return {ok:true};
}
async function preview(a:Actor,input:unknown,remote=false) {
  requirePermission(a,'technical');
  const v=remote?z.object({companyId:id,projectId:id,url:z.string().max(300),installationId:z.string().regex(/^\d+$/).optional()}).parse(input):importSchema.parse(input);
  await scope(a,v.companyId,v.projectId);
  const source=remote?await githubFiles((v as any).url,(v as any).installationId):importSchema.parse(input);
  const candidates=inspectFiles(source.files);
  const repoId=createHash('sha256').update(`${v.projectId}:${source.repository}`).digest('hex').slice(0,32);
  const previous=await db.doc(`repositories/${repoId}`).get();
  const fingerprints=previous.get('fingerprints')||{};
  const existing=await db.collection('catalog').where('projectId','==',v.projectId).limit(300).get();
  const entries=candidates.map(c=>({...c,diff:!fingerprints[c.key]?'alta':fingerprints[c.key]===c.fingerprint?'sin_cambios':'cambio',duplicate:existing.docs.some(s=>s.get('name')?.toLowerCase()===c.name.toLowerCase())}));
  const missing=Object.keys(fingerprints).filter(k=>!candidates.some(c=>c.key===k));
  const ref=db.collection('imports').doc();
  await db.runTransaction(async tx=>{tx.create(ref,{companyId:v.companyId,projectId:v.projectId,repository:source.repository,repoId,commit:source.commit,candidates:entries,missing,status:'preview',createdAt:now(),createdBy:a.uid});audit(tx,a,'import.preview',ref.path,{count:entries.length});});
  return {id:ref.id,candidates:entries,missing,commit:source.commit};
}
async function approve(a:Actor,input:unknown) {
  requirePermission(a,'technical');
  const v=z.object({importId:id,items:z.array(z.object({key:id,name,description:text,published:z.boolean(),module:text.default('General'),version:text.default('')})).min(1).max(120)}).parse(input);
  const ref=db.doc(`imports/${v.importId}`);const s=await ref.get();if(!s.exists)throw new HttpsError('not-found','Importación no encontrada');
  await scope(a,s.get('companyId'),s.get('projectId'));
  await db.runTransaction(async tx=>{
    const snap=await tx.get(ref);const source=snap.data()!;if(source.status!=='preview')throw new HttpsError('failed-precondition','Esta revisión ya fue aprobada');
    const targets=v.items.map(item=>db.doc(`catalog/${source.repoId}_${item.key}`));
    const old=await tx.getAll(...targets);const repoRef=db.doc(`repositories/${source.repoId}`);const repo=await tx.get(repoRef);
    const fingerprints={...(repo.get('fingerprints')||{})};
    for(let i=0;i<v.items.length;i++) {
      const item=v.items[i];const candidate=source.candidates.find((c:Candidate)=>c.key===item.key);if(!candidate)deny('Elemento ajeno a la revisión');
      fingerprints[item.key]=candidate.fingerprint;
      if(old[i].exists) {
        // Reimport never overwrites manual/public copy. Store a review with the proposed version.
        tx.create(db.collection('catalogReviews').doc(),{catalogId:targets[i].id,companyId:source.companyId,projectId:source.projectId,proposal:item,sourceImport:v.importId,commit:source.commit,status:'pending',createdAt:now()});
      } else tx.create(targets[i],{companyId:source.companyId,projectId:source.projectId,name:item.name,description:item.description,module:item.module,version:item.version,published:item.published,status:'disponible',roles:'',faq:'',searchName:item.name.toLowerCase(),createdAt:now(),updatedAt:now()});
      tx.set(db.doc(`catalogOrigins/${targets[i].id}`),{source:candidate.source,commit:source.commit,importId:ref.id,repoId:source.repoId,confidence:candidate.confidence});
    }
    tx.set(repoRef,{companyId:source.companyId,projectId:source.projectId,repository:source.repository,commit:source.commit,fingerprints,status:'connected',lastSync:now()},{merge:true});
    tx.update(ref,{status:'approved',approvedAt:now(),approvedBy:a.uid});audit(tx,a,'import.approve',ref.path,{count:v.items.length});
  });return {ok:true};
}
async function renew(a:Actor,input:unknown) {
  requirePermission(a,'manage');const v=z.object({collection:z.enum(['contracts','services']),id,startDate:date,endDate:date}).refine(v=>v.endDate>v.startDate,'Vigencia inválida').parse(input);
  const ref=db.doc(`${v.collection}/${v.id}`);const s=await ref.get();if(!s.exists)throw new HttpsError('not-found','Registro no encontrado');await scope(a,s.get('companyId'),s.get('projectId'));
  await db.runTransaction(async tx=>{
    const old=(await tx.get(ref)).data()!;
    const notices=await tx.getAll(...[30,7,1,0].map(n=>db.doc(`notifications/${reminderKey(v.collection,v.id,old.endDate,n)}`)));
    if(v.endDate<=old.endDate)throw new HttpsError('invalid-argument','La renovación debe extender la vigencia');
    tx.create(ref.collection('renewals').doc(),{previousStart:old.startDate,previousEnd:old.endDate,startDate:v.startDate,endDate:v.endDate,createdAt:now(),createdBy:a.uid});
    tx.update(ref,{startDate:v.startDate,endDate:v.endDate,status:'activo',renewedAt:now(),updatedAt:now()});
    for(const notice of notices)if(notice.exists)tx.update(notice.ref,{status:'obsolete',resolvedAt:now()});
    if(old.published)tx.update(db.doc(`${v.collection==='contracts'?'publicContracts':'publicServices'}/${v.id}`),{startDate:v.startDate,endDate:v.endDate,status:'activo'});
    audit(tx,a,'renewal',ref.path,{previousEnd:old.endDate,endDate:v.endDate});
  });return {ok:true};
}
async function dashboard(a:Actor,input:any) {
  const v=z.object({companyId:id.optional(),projectId:id.optional()}).parse(input||{});
  let tickets:Query=db.collection('tickets'),projects:Query=db.collection('projects');
  if(v.companyId){await scope(a,v.companyId,v.projectId);tickets=tickets.where('companyId','==',v.companyId);projects=projects.where('companyId','==',v.companyId);}
  if(!isStaff(a)) {
    if(!v.companyId) return {open:0,new:0,activeProjects:0,resolved:0,scopeRequired:true};
    const m=await scope(a,v.companyId,v.projectId);if(!m.allProjects&&!v.projectId)return {open:0,new:0,activeProjects:0,resolved:0,scopeRequired:true};
    tickets=m.ticketScope==='requester'?tickets.where('requesterId','==',a.uid):tickets.where('visibleTo','array-contains-any',['project',a.uid]);
  }
  if(v.projectId){tickets=tickets.where('projectId','==',v.projectId);projects=projects.where(FieldPath.documentId(),'==',v.projectId);}
  const counts=await Promise.all([tickets.where('status','in',['nuevo','clasificacion','esperando_cliente','primer_nivel','escalado','analisis','ejecucion','reabierto']).count().get(),tickets.where('status','==','nuevo').count().get(),projects.where('status','==','activo').count().get(),tickets.where('status','in',['resuelto','cerrado']).count().get()]);
  return {open:counts[0].data().count,new:counts[1].data().count,activeProjects:counts[2].data().count,resolved:counts[3].data().count};
}
export const api=onCall({timeoutSeconds:120, cors:true},async req=>{
  try {
    const v=z.object({action:z.string().max(50),data:z.unknown().optional()}).parse(req.data);
    if(v.action==='acceptInvitation')return await accept(req,v.data);
    const a=await actor(req);
    switch(v.action){
      case 'session':return {uid:a.uid,email:a.email,role:a.role,permissions:a.permissions};
      case 'registerDevice':case 'updateDeviceToken':case 'unregisterDevice':case 'myDevices':return await deviceAction(a,v.action,v.data);
      case 'notificationDetail':case 'notificationReceipt':case 'markRead':return await notificationAction(a,v.action,v.data);
      case 'list':return await list(a,v.data);
      case 'save':return await save(a,v.data);
      case 'dashboard':return await dashboard(a,v.data);
      case 'createTicket':return await createTicket(a,v.data);
      case 'ticketDetail':return await ticketDetail(a,v.data);
      case 'ticketNotifications':return await ticketNotifications(a,v.data);
      case 'comment':return await comment(a,v.data);
      case 'transition':return await transition(a,v.data);
      case 'access':return await accessManagement(a,v.data);
      case 'invite':return await invite(a,v.data);
      case 'previewImport':return await preview(a,v.data);
      case 'githubImport':return await preview(a,v.data,true);
      case 'approveImport':return await approve(a,v.data);
      case 'renew':return await renew(a,v.data);
      default:throw new HttpsError('invalid-argument','Operación desconocida');
    }
  } catch(e) {
    if(e instanceof HttpsError)throw e;
    if(e instanceof z.ZodError)throw new HttpsError('invalid-argument',e.issues.map(i=>`${i.path.join('.')}: ${i.message}`).join('; ').slice(0,700));
    // Do not log request bodies, tokens or imported source.
    console.error('api.failure',e instanceof Error?e.name:'unknown');
    if(process.env.FUNCTIONS_EMULATOR==='true') console.error(e);
    if((e as {code?:number})?.code===9)throw new HttpsError('unavailable','Esta consulta aún no está disponible. Intenta nuevamente en unos minutos.');
    if(e instanceof Error&&e.message.startsWith('GitHub'))throw new HttpsError('failed-precondition',e.message);
    throw new HttpsError('internal','No se pudo completar la operación. Intenta nuevamente.');
  }
});

export async function generateReminders() {
  const today=DateTime.now().setZone('America/Bogota');
  for(const collection of ['contracts','services']) {
    let cursor:string|undefined;
    do {
      let q:Query=db.collection(collection).where('status','==','activo').where('endDate','<=',today.plus({days:30}).toISODate()).orderBy('endDate').orderBy(FieldPath.documentId()).limit(100);
      if(cursor){const s=await db.doc(`${collection}/${cursor}`).get();q=q.startAfter(s);}
      const page=await q.get();
      for(const s of page.docs) {
        const d=s.data();const days=daysUntil(d.endDate,today);const threshold=[30,7,1,0].find(n=>days<=n&&days>(n===30?7:n===7?1:n===1?0:-999999));if(threshold===undefined)continue;
        const key=reminderKey(collection,s.id,d.endDate,threshold);const ref=db.doc(`notifications/${key}`);
        await db.runTransaction(async tx=>{const current=await tx.get(s.ref);const exists=await tx.get(ref);if(exists.exists||current.get('endDate')!==d.endDate||current.get('status')!=='activo')return;tx.create(ref,{audience:'staff',companyId:d.companyId,projectId:d.projectId,entityId:s.id,source:collection,body:`${d.name}: ${days<0?'vencido':`vence en ${days} días`}`,dueDate:d.endDate,threshold,createdAt:now(),status:'pending',emailStatus:'not_configured',attempts:0});});
      }
      cursor=page.size===100?page.docs[99].id:undefined;
    }while(cursor);
  }
}
export const renewalReminders=onSchedule({schedule:'0 7 * * *',timeZone:'America/Bogota',retryCount:3},generateReminders);
export const notificationDispatch=onDocumentCreated({document:'notificationEvents/{eventId}',timeoutSeconds:540,retry:true},async event=>{
  if(process.env.FUNCTIONS_EMULATOR==='true')return; // FCM has no emulator; tests inject a sender explicitly.
  await processNotificationEvent(event.params.eventId);
});
export const notificationLegacy=onDocumentCreated({document:'notifications/{notificationId}',retry:true},async event=>{
  if(process.env.FUNCTIONS_EMULATOR==='true'||!event.data)return;
  await legacyNotification(event.params.notificationId,event.data.data());
});
export const notificationRetry=onSchedule({schedule:'every 5 minutes',timeoutSeconds:540,retryCount:3},retryNotificationEvents);
