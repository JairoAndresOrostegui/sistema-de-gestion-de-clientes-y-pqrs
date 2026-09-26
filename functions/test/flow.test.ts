import {describe,beforeAll,afterAll,it,expect} from 'vitest';
import {initializeApp as adminApp,deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeApp,deleteApp,FirebaseApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,signInWithEmailAndPassword} from 'firebase/auth';
import {getFunctions,connectFunctionsEmulator,httpsCallable} from 'firebase/functions';
import {DateTime} from 'luxon';

describe.skipIf(!process.env.FUNCTIONS_EMULATOR)('real callable workflows on Firebase emulators',()=>{
  const admin=adminApp({projectId:'demo-dts-gestion'},'integration-admin');const db=getFirestore(admin);const apps:FirebaseApp[]=[];const calls:Record<string,(action:string,data?:unknown)=>Promise<any>>={};
  let company:string,project:string,hiddenProject:string,ticket:string;
  beforeAll(async()=>{
    for(const [uid,role] of [['flow-owner','owner'],['flow-commercial','commercial'],['flow-client','client']]){
      const email=`${uid}@example.test`;try{await adminAuth(admin).createUser({uid,email,emailVerified:true,password:'Test-only-9876!'});}catch{}
      await db.doc(`users/${uid}`).set({role,active:true,permissions:[],email});
      const app=initializeApp({projectId:'demo-dts-gestion',apiKey:'demo-key',authDomain:'localhost'},uid);apps.push(app);
      const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});await signInWithEmailAndPassword(auth,email,'Test-only-9876!');
      const functions=getFunctions(app,'us-central1');connectFunctionsEmulator(functions,'127.0.0.1',5001);
      calls[role]=async(action,data={})=>(await httpsCallable(functions,'api')({action,data})).data;
    }
  });
  afterAll(async()=>{await Promise.all(apps.map(deleteApp));await deleteAdmin(admin);});
  it('creates a minimal company and two independently scoped projects',async()=>{
    company=(await calls.owner('save',{collection:'companies',data:{name:'Empresa A (prueba)'}})).id;
    project=(await calls.owner('save',{collection:'projects',data:{name:'Proyecto autorizado',companyId:company}})).id;
    hiddenProject=(await calls.owner('save',{collection:'projects',data:{name:'Proyecto privado',companyId:company}})).id;
    await calls.owner('access',{uid:'flow-client',role:'client',active:true,companyId:company,projectIds:[project]});
    const list=await calls.client('list',{collection:'projects',companyId:company});expect(list.items.map((v:any)=>v.id)).toEqual([project]);
  });
  it('rejects unauthorized direct server requests for the second project and technical content',async()=>{
    await expect(calls.client('list',{collection:'catalog',companyId:company,projectId:hiddenProject})).rejects.toThrow();
    await expect(calls.commercial('previewImport',{companyId:company,projectId:project,files:[]})).rejects.toThrow();
    await expect(calls.client('save',{collection:'companies',data:{name:'forbidden'}})).rejects.toThrow();
  });
  it('client creates ticket without a catalogue or coverage',async()=>{
    const created=await calls.client('createTicket',{companyId:company,projectId:project,subject:'No puedo ingresar',description:'La pantalla muestra un error al ingresar.',category:'incidente'});
    ticket=created.id;expect(created.number).toMatch(/^DTS-\d{6}$/);
    const detail=await calls.client('ticketDetail',{id:ticket});expect(detail.ticket.coverage).toBe('fuera_cobertura');expect(detail.ticket.sla).toBeNull();
  });
  it('commercial triages, answers and escalates, with private notes inaccessible to client',async()=>{
    await calls.commercial('transition',{ticketId:ticket,status:'clasificacion',reason:'Revisamos el contexto de la solicitud.'});
    await calls.commercial('transition',{ticketId:ticket,status:'primer_nivel',reason:'Atención inicial.'});
    await calls.commercial('comment',{ticketId:ticket,audience:'internal',body:'Nota comercial interna'});
    await calls.commercial('comment',{ticketId:ticket,audience:'public',body:'Estamos revisando tu solicitud.'});
    await calls.commercial('transition',{ticketId:ticket,status:'escalado',reason:'Se requiere diagnóstico técnico.'});
    await expect(calls.client('ticketDetail',{id:ticket,audience:'internal'})).rejects.toThrow();
    const detail=await calls.client('ticketDetail',{id:ticket});expect(detail.items.some((v:any)=>v.body==='Nota comercial interna')).toBe(false);expect(detail.ticket.firstResponseAt).toBeTruthy();
  });
  it('owner diagnoses and resolves; client validates then reopens; forbidden transitions rejected',async()=>{
    await calls.owner('comment',{ticketId:ticket,audience:'technical',body:'Diagnóstico técnico restringido',minutes:15});
    await expect(calls.commercial('ticketDetail',{id:ticket,audience:'technical'})).rejects.toThrow();
    await calls.owner('transition',{ticketId:ticket,status:'analisis',reason:'Diagnóstico iniciado.'});
    await calls.owner('transition',{ticketId:ticket,status:'resuelto',reason:'Se corrigió el comportamiento.'});
    await calls.client('transition',{ticketId:ticket,status:'cerrado',reason:'Confirmo que funciona.'});
    await calls.client('transition',{ticketId:ticket,status:'reabierto',reason:'Volvió a ocurrir el error.'});
    await expect(calls.client('transition',{ticketId:ticket,status:'escalado',reason:'Intento inválido.'})).rejects.toThrow();
    expect((await calls.owner('ticketDetail',{id:ticket})).ticket.timeMinutes).toBe(15);
  });
  it('scoped lists, searches and dashboard work',async()=>{
    const page=await calls.client('list',{collection:'tickets',companyId:company,projectId:project,search:'no puedo'});expect(page.items).toHaveLength(1);
    const metrics=await calls.client('dashboard',{companyId:company,projectId:project});expect(metrics.open).toBe(1);
    await calls.owner('save',{collection:'contacts',data:{companyId:company,name:'Contacto de prueba',area:'Operaciones'}});
  });
  it('import is preview-only; approval publishes selected elements and reimport preserves manual edits',async()=>{
    const source={companyId:company,projectId:project,repository:'local',commit:'v1',files:[{path:'README.md',content:'# Facturación\n## Reportes'}]};
    const preview=await calls.owner('previewImport',source);
    expect((await calls.client('list',{collection:'catalog',companyId:company,projectId:project})).items).toHaveLength(0);
    const c=preview.candidates[0];await calls.owner('approveImport',{importId:preview.id,items:[{key:c.key,name:'Facturación validada',description:'Texto editado por el propietario',published:true}]});
    const published=await calls.client('list',{collection:'catalog',companyId:company,projectId:project});expect(published.items).toHaveLength(1);expect(published.items[0].source).toBeUndefined();
    const next=await calls.owner('previewImport',{...source,commit:'v2',files:[{path:'README.md',content:'# Facturación\nCambios nuevos'}]});
    await calls.owner('approveImport',{importId:next.id,items:[{key:c.key,name:'Otro nombre',description:'Propuesta nueva',published:true}]});
    expect((await calls.client('list',{collection:'catalog',companyId:company,projectId:project})).items[0].name).toBe('Facturación validada');
  });
  it('renewals preserve history and reminder executions are idempotent',async()=>{
    const end=DateTime.now().setZone('America/Bogota').plus({days:7}).toISODate();
    const created=await calls.owner('save',{collection:'services',data:{companyId:company,projectId:project,name:'Dominio prueba',startDate:'2026-01-01',endDate:end}});
    const {generateReminders}=await import('../src/index');await generateReminders();await generateReminders();
    const notifications=await db.collection('notifications').where('entityId','==',created.id).get();expect(notifications.size).toBe(1);
    await calls.owner('renew',{collection:'services',id:created.id,startDate:end,endDate:DateTime.now().plus({years:1}).toISODate()});
    await generateReminders();expect((await db.collection('notifications').where('entityId','==',created.id).get()).size).toBe(1);
    expect((await db.collection(`services/${created.id}/renewals`).get()).size).toBe(1);
  });
  it('revocation takes effect without trusting cached custom claims',async()=>{
    await calls.owner('access',{uid:'flow-client',role:'client',active:false});
    await expect(calls.client('ticketDetail',{id:ticket})).rejects.toThrow();
    expect((await db.collection('audit').where('action','==','ticket.transition').get()).size).toBeGreaterThan(3);
  });
  it('only owner can invite staff, and privileged invitations require exact verified identity',async()=>{
    const payload={email:'new-commercial@example.test',role:'commercial',companyId:company,projectIds:[project]};
    await expect(calls.commercial('invite',payload)).rejects.toThrow();
    const inv=await calls.owner('invite',payload);expect(inv.token.length).toBeGreaterThan(40);
    await expect(calls.commercial('acceptInvitation',{token:inv.token})).rejects.toThrow();
    await adminAuth(admin).createUser({uid:'flow-new-staff',email:payload.email,emailVerified:true,password:'Test-only-9876!'});
    const app=initializeApp({projectId:'demo-dts-gestion',apiKey:'demo-key',authDomain:'localhost'},'flow-new-staff');apps.push(app);
    const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});await signInWithEmailAndPassword(auth,payload.email,'Test-only-9876!');
    const functions=getFunctions(app,'us-central1');connectFunctionsEmulator(functions,'127.0.0.1',5001);const call=httpsCallable(functions,'api');
    await call({action:'acceptInvitation',data:{token:inv.token}});
    expect((await db.doc('users/flow-new-staff').get()).get('role')).toBe('commercial');
    await expect(call({action:'acceptInvitation',data:{token:inv.token}})).rejects.toThrow();
  });
});
