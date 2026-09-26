// Creates one synthetic, short-lived commercial account in QA; credentials stay in memory.
const {request,project}=require('./cloud-admin.cjs');
const {randomBytes}=require('node:crypto');
const {chromium}=require('../functions/node_modules/@playwright/test');
const fs=require('node:fs');
const base=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const created=[];let uid;let browser;let page;
async function main(){
  const email=`qa-smoke-${Date.now()}@example.test`,password=randomBytes(24).toString('base64url');
  const user=await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts`,'POST',{email,password,emailVerified:true,displayName:'Prueba técnica temporal QA'});uid=user.localId;
  await request(`${base}/users/${uid}`,'PATCH',{fields:{email:{stringValue:email},role:{stringValue:'commercial'},active:{booleanValue:true},permissions:{arrayValue:{values:[]}}}});
  const config=JSON.parse(fs.readFileSync('android/app/google-services.json','utf8'));const apiKey=config.client[0].api_key[0].current_key;
  const sign=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});const login=await sign.json();if(!sign.ok)throw Error('QA test authentication failed');
  async function api(action,data={}){const r=await fetch(`https://us-central1-${project}.cloudfunctions.net/api`,{method:'POST',headers:{Authorization:`Bearer ${login.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({data:{action,data}})});const j=await r.json();if(j.error)throw Error(`QA ${action}: ${j.error.status} ${j.error.message}`);return j.result;}
  console.log('QA session:',(await api('session')).role);
  const company=(await api('save',{collection:'companies',data:{name:'Verificación QA temporal'}})).id;created.push(`companies/${company}`);
  const p=(await api('save',{collection:'projects',data:{companyId:company,name:'Proyecto QA temporal'}})).id;created.push(`projects/${p}`);
  const t=await api('createTicket',{companyId:company,projectId:p,subject:'Verificación temporal de despliegue',description:'Solicitud sintética para verificar autenticación, persistencia e índices.',category:'consulta'});created.push(`tickets/${t.id}`);
  for(const collection of ['tickets','projects','events','services','catalog','companies']){
    const list=await api('list',{collection,companyId:company,projectId:p});console.log(`QA ${collection}: query OK (${list.items.length})`);
  }
  await api('list',{collection:'tickets',companyId:company,projectId:p,search:'verificación'});
  const counts=await api('dashboard',{companyId:company,projectId:p});if(counts.open!==1)throw Error('Unexpected dashboard aggregation');
  console.log('QA dashboard and prefix search: OK');
  browser=await chromium.launch({channel:'chrome',headless:true});page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(process.argv[2]||`https://${project}.web.app`,{waitUntil:'networkidle'});await page.locator('flutter-view').waitFor({timeout:60000});const semantics=page.locator('flt-semantics-placeholder');if(await semantics.count())await semantics.evaluate(e=>e.click());
  await page.getByLabel('Correo electrónico',{exact:true}).click();await page.getByLabel('Correo electrónico',{exact:true}).pressSequentially(email,{delay:15});
  await page.getByLabel('Contraseña',{exact:true}).click();await page.getByLabel('Contraseña',{exact:true}).pressSequentially(password,{delay:15});
  await page.getByRole('button',{name:'Iniciar sesión',exact:true}).click();
  await page.getByRole('button',{name:'Nueva solicitud',exact:true}).first().waitFor({timeout:45000});
  if(errors.length)throw Error('Browser exception: '+errors[0]);
  fs.mkdirSync('artifacts',{recursive:true});await page.screenshot({path:'artifacts/dashboard-qa.png',fullPage:true});console.log('QA authenticated browser dashboard: OK');
}
main().catch(async e=>{console.error(e.message);if(page){await page.screenshot({path:'artifacts/qa-failure.png',fullPage:true});console.log((await page.locator('body').innerText()).slice(0,2500));}process.exitCode=1;}).finally(async()=>{
  if(browser)await browser.close();
  // Delete only the IDs created by this execution; audit remains as a record of validation.
  for(const p of created.reverse())try{
    if(p.startsWith('tickets/')){
      const notes=await request(`${base}/${p}/public`);for(const d of notes.documents||[])await request(`https://firestore.googleapis.com/v1/${d.name}`,'DELETE');
      const notifications=await request(`${base}:runQuery`,'POST',{structuredQuery:{from:[{collectionId:'notifications'}],where:{fieldFilter:{field:{fieldPath:'entityId'},op:'EQUAL',value:{stringValue:p.split('/')[1]}}}}});
      for(const n of notifications)if(n.document)await request(`https://firestore.googleapis.com/v1/${n.document.name}`,'DELETE');
    }
    await request(`${base}/${p}`,'DELETE');
  }catch(e){console.error('Entity cleanup failed:',p,e.message);process.exitCode=1;}
  if(uid){try{await request(`${base}/users/${uid}`,'DELETE');await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:delete`,'POST',{localId:uid});console.log('Temporary QA account and entities removed.');}catch(e){console.error('QA cleanup:',e.message);process.exitCode=1;}}
});
