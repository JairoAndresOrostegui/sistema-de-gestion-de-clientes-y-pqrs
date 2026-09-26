// Real QA: temporary identity, browser FCM destination, deployed Firestore trigger,
// provider acceptance, foreground receipt, opening, reading and two-slot isolation.
// No passwords, JWTs or FCM tokens are printed or written to reports.
const {request,project}=require('./cloud-admin.cjs');
const {randomBytes,randomUUID}=require('node:crypto');
const {chromium}=require('../functions/node_modules/@playwright/test');
const fs=require('node:fs');
const base=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const encode=v=>v===null?{nullValue:null}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:typeof v==='string'?{stringValue:v}:Array.isArray(v)?{arrayValue:{values:v.map(encode)}}:{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,v])=>[k,encode(v)]))}};
const decode=v=>v?.stringValue??v?.booleanValue??v?.integerValue??(v?.arrayValue?(v.arrayValue.values||[]).map(decode):v?.mapValue?Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,v])=>[k,decode(v)])):null);
const fields=d=>decode({mapValue:{fields:d.fields||{}}});
const put=(path,data)=>request(`${base}/${path}`,'PATCH',{fields:encode(data).mapValue.fields});
async function query(collection,key,value){return (await request(`${base}:runQuery`,'POST',{structuredQuery:{from:[{collectionId:collection}],where:{fieldFilter:{field:{fieldPath:key},op:'EQUAL',value:encode(value)}}}})).filter(v=>v.document).map(v=>v.document);}
const remove=d=>request(`https://firestore.googleapis.com/v1/${d.name}`,'DELETE');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(check,description,timeout=90000){const end=Date.now()+timeout;while(Date.now()<end){const result=await check();if(result)return result;await delay(1200);}throw Error(`Timeout: ${description}`);}
let uid,browser,page,eventId;const report={checks:[],startedAt:new Date().toISOString()};
const pass=label=>{report.checks.push(label);console.log('PASS',label);};
async function main(){
  const email=`qa-push-${Date.now()}@example.test`,password=randomBytes(24).toString('base64url');
  uid=(await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts`,'POST',{email,password,emailVerified:true,displayName:'QA push temporal'})).localId;
  await put(`users/${uid}`,{email,role:'commercial',active:true,permissions:[]});
  const config=JSON.parse(fs.readFileSync('android/app/google-services.json','utf8'));const key=config.client[0].api_key[0].current_key;
  const response=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});const auth=await response.json();if(!response.ok)throw Error('QA authentication failed');
  async function api(action,data={},clientContext){const r=await fetch(`https://us-central1-${project}.cloudfunctions.net/api`,{method:'POST',headers:{Authorization:`Bearer ${auth.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({data:{action,data,clientContext}})});const j=await r.json();if(j.error)throw Error(`${action}: ${j.error.message}`);return j.result;}
  // A temporary regular profile permits Chrome's push service. Incognito profiles
  // and Playwright's background-networking suppression cannot validate real FCM.
  browser=await chromium.launchPersistentContext('',{channel:'chrome',headless:true,ignoreDefaultArgs:['--disable-background-networking'],permissions:['notifications'],viewport:{width:1440,height:1000}});const context=browser;page=await context.newPage();
  page.on('response',async r=>{try{if(r.url().includes('cloudfunctions.net/api')){const action=r.request().postDataJSON()?.data?.action;if(['registerDevice','updateDeviceToken'].includes(action)){const result=await r.json();console.log('Device API',action,result.error?.status||'OK',result.error?.message||'');}}else if(r.url().includes('fcmregistrations.googleapis.com')&&r.status()>=400){const error=(await r.json()).error;console.log('FCM registration error',r.status(),error?.status,error?.message);}}catch{}});
  page.on('console',m=>{if(m.text().startsWith('device.registration.failed'))console.log(m.text());});
  await page.goto(`https://${project}.web.app`,{waitUntil:'networkidle'});await page.locator('flutter-view').waitFor({timeout:60000});const semantics=page.locator('flt-semantics-placeholder');if(await semantics.count())await semantics.evaluate(e=>e.click());
  await page.getByLabel('Correo electrónico',{exact:true}).click();await page.getByLabel('Correo electrónico',{exact:true}).pressSequentially(email,{delay:15});
  await page.getByLabel('Contraseña',{exact:true}).click();await page.getByLabel('Contraseña',{exact:true}).pressSequentially(password,{delay:15});await page.getByRole('button',{name:'Iniciar sesión',exact:true}).click();
  await page.getByRole('button',{name:'Nueva solicitud',exact:true}).first().waitFor({timeout:60000});
  for(let i=0;i<20;i++){const account=page.getByText('Mi cuenta',{exact:true});if(await account.count()){await account.click();break;}await page.mouse.move(120,500);await page.mouse.wheel(0,200);await delay(200);}
  await page.getByRole('button',{name:'Activar notificaciones en este dispositivo',exact:true}).click();
  const web=await until(async()=>{try{const s=fields(await request(`${base}/userDevices/${uid}/slots/web`));return s.token?s:false;}catch{return false;}},'web FCM token registration');
  pass('Real Chrome login registers a web FCM token');
  const mobile=await api('registerDevice',{slot:'mobile',platform:'android',label:'Destino móvil sintético QA',installationId:randomUUID()});
  const devices=await api('myDevices',{}, {sessionId:web.sessionId});
  if(devices.items.length!==2||!devices.items.find(v=>v.slot==='web')?.enabled)throw Error('Mobile registration replaced web');
  if(JSON.stringify(devices).includes(web.token))throw Error('Token leaked in device response');
  pass('Mobile and web destinations remain independent; tokens are private');
  eventId=`qa_push_${Date.now()}`;
  await put(`notificationEvents/${eventId}`,{kind:'qa.push',audience:'public',targetUid:uid,entityId:eventId,body:'Comprobación temporal QA: recepción y lectura verificables',actorId:uid,device:{slot:'web',platform:'web',label:'Chrome QA',sessionId:web.sessionId,installationId:web.installationId},createdAt:new Date().toISOString(),state:'pending',nextAttemptAt:new Date().toISOString()});
  const notice=await until(async()=>{const items=await query('notifications','eventId',eventId);return items.find(v=>fields(v).recipientId===uid);},'deployed trigger fanout');
  const noticeId=notice.name.split('/').pop();
  const delivery=await until(async()=>{try{const s=fields(await request(`${base}/notifications/${noticeId}/deliveries/web`));if(['failed','invalid_token'].includes(s.status))throw Error(`FCM failure ${s.errorCode}`);return s.receivedAt?s:false;}catch(e){if(e.message.startsWith('FCM'))throw e;return false;}},'real FCM acceptance and foreground receipt');
  if(delivery.status!=='accepted')throw Error('Receipt without provider acceptance');
  pass('Deployed trigger sends through real FCM and browser confirms receipt');
  await page.getByRole('button',{name:'Ver',exact:true}).click({timeout:30000});
  await page.getByText('Comprobación temporal QA: recepción y lectura verificables',{exact:true}).waitFor({timeout:30000});
  const read=fields(await request(`${base}/notifications/${noticeId}`));const opened=fields(await request(`${base}/notifications/${noticeId}/deliveries/web`));
  if(!read.readAt||!opened.openedAt)throw Error('Open/read receipt missing');
  pass('Notification tap opens authorized detail and confirms opening and reading');
  const replacement=await api('registerDevice',{slot:'web',platform:'web',label:'Segundo navegador QA',installationId:randomUUID()});
  const stale=await api('updateDeviceToken',{sessionId:web.sessionId,token:web.token,permission:'authorized'});
  if(!stale.superseded)throw Error('Stale token refresh replaced newest destination');
  await api('unregisterDevice',{sessionId:replacement.sessionId});
  const after=await api('myDevices');if(!after.items.find(v=>v.slot==='mobile')||after.items.find(v=>v.slot==='web')?.enabled)throw Error('Logout isolation failed');
  await api('unregisterDevice',{sessionId:mobile.sessionId});
  pass('Stale refresh is rejected and logout affects only its destination');
  fs.mkdirSync('artifacts',{recursive:true});await page.screenshot({path:'artifacts/qa-notification-open.png',fullPage:true});
}
main().catch(async e=>{report.error=e.message;console.error(e.message);if(page){console.log('Browser visible state:',(await page.locator('body').innerText()).slice(-1800));await page.screenshot({path:'artifacts/qa-notification-failure.png',fullPage:true}).catch(()=>{});}process.exitCode=1;}).finally(async()=>{
  if(browser)await browser.close();
  if(uid){
    // Disable account first so a delayed worker cannot create new deliveries.
    try{await put(`users/${uid}`,{active:false});}catch{}
    try{
      if(eventId){for(const n of await query('notifications','eventId',eventId)){const ds=await request(`https://firestore.googleapis.com/v1/${n.name}/deliveries`);for(const d of ds.documents||[])await remove(d);await remove(n);}await request(`${base}/notificationEvents/${eventId}`,'DELETE');}
      for(const col of ['deviceSessions','pushTokens'])for(const d of await query(col,'uid',uid))await remove(d);
      const slots=await request(`${base}/userDevices/${uid}/slots`);for(const d of slots.documents||[])await remove(d);
      await request(`${base}/users/${uid}`,'DELETE');await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:delete`,'POST',{localId:uid});
      pass('Temporary identity, FCM references, event and delivery records cleaned');
    }catch(e){console.error('QA cleanup:',e.message);report.cleanupError=e.message;process.exitCode=1;}
  }
  fs.mkdirSync('artifacts',{recursive:true});report.finishedAt=new Date().toISOString();fs.writeFileSync('artifacts/qa-notifications.json',JSON.stringify(report,null,2));
});
