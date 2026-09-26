// Real Android QA via adb UI automation. Uses only a temporary QA account.
const {request,project}=require('./cloud-admin.cjs');
const {randomBytes,randomUUID}=require('node:crypto');
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
const {execFileSync}=require('node:child_process');
const path=require('node:path');
const sdk=process.env.ANDROID_HOME||path.join(process.env.LOCALAPPDATA,'Android/Sdk');
const serial=process.env.ANDROID_SERIAL||'emulator-5554';
const adb=(...args)=>{
  try{return execFileSync(path.join(sdk,'platform-tools',process.platform==='win32'?'adb.exe':'adb'),['-s',serial,...args],{encoding:'utf8',timeout:30000,stdio:'pipe'});}
  catch{throw Error(`Android command failed (${args[0]} ${args[1]||''})`);}
};
const app='co.com.dts.dts_gestion';
let uid;const eventIds=[],report={checks:[],startedAt:new Date().toISOString(),serial};
const pass=label=>{report.checks.push(label);console.log('PASS',label);};
async function nodes(){
  try {
    const output=adb('shell','uiautomator','dump','/sdcard/dts-qa.xml');
    if(!output.includes('dumped'))return [];
    return [...adb('shell','cat','/sdcard/dts-qa.xml').matchAll(/<node\s+([^>]+)>/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(v=>[v[1],v[2]])));
  } catch { return []; }
}
async function tap(label,timeout=90000){
  const node=await until(async()=>{const list=await nodes();return list.find(n=>[n.text,n['content-desc'],n.hint].includes(label));},`Android control ${label}`,timeout);
  const [x1,y1,x2,y2]=node.bounds.match(/\d+/g).map(Number);
  adb('shell','input','tap',String(Math.round((x1+x2)/2)),String(Math.round((y1+y2)/2)));
  await delay(700);
  console.log('UI control:',label);
}
async function delivery(id){try{return fields(await request(`${base}/notifications/${id}/deliveries/mobile`));}catch{return {};}}
async function event(kind){
  const id=`qa_android_${kind}_${Date.now()}`;eventIds.push(id);
  await put(`notificationEvents/${id}`,{kind:`qa.android.${kind}`,audience:'public',targetUid:uid,entityId:id,body:`Android QA ${kind}`,actorId:uid,createdAt:new Date().toISOString(),state:'pending',nextAttemptAt:new Date().toISOString()});
  const notice=await until(async()=>(await query('notifications','eventId',id)).find(d=>fields(d).recipientId===uid),'Android notification fanout');
  return notice.name.split('/').pop();
}
async function main(){
  if(!serial.startsWith('emulator-'))throw Error('Use a disposable emulator; this test clears the app data.');
  const email=`qa-android-${Date.now()}@example.test`,password=randomBytes(24).toString('hex');
  uid=(await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts`,'POST',{email,password,emailVerified:true,displayName:'Android QA temporal'})).localId;
  await put(`users/${uid}`,{email,role:'commercial',active:true,permissions:[]});
  adb('shell','pm','clear',app);
  adb('shell','settings','put','secure','autofill_service','null');
  adb('shell','pm','grant',app,'android.permission.POST_NOTIFICATIONS');
  adb('shell','am','start','-n',`${app}/.MainActivity`);
  await tap('Correo electrónico');adb('shell','input','text',email);adb('shell','input','keyevent','66');await delay(700);
  if(!(await nodes()).some(n=>n.text===email)){
    await tap('Correo electrónico');adb('shell','input','keycombination','113','29');
    adb('shell','input','text',email);adb('shell','input','keyevent','66');
    if(!(await nodes()).some(n=>n.text===email))throw Error('Android keyboard did not enter temporary email');
  }
  await tap('Contraseña');adb('shell','input','text',password);adb('shell','input','keyevent','66');await delay(700);
  await tap('Iniciar sesión');
  const mobile=await until(async()=>{try{const slot=fields(await request(`${base}/userDevices/${uid}/slots/mobile`));return slot.token?slot:false;}catch{return false;}},'native Android FCM registration',120000);
  if(mobile.platform!=='android')throw Error('Incorrect native platform');
  pass('Native login registers Android mobile destination and real FCM token');
  const foreground=await event('foreground');
  await until(async()=>{const d=await delivery(foreground);return d.status==='accepted'&&d.receivedAt;},'Android foreground receipt');
  pass('Real FCM foreground delivery acknowledged by Android app');
  adb('shell','input','keyevent','3');
  const background=await event('background');
  await until(async()=>(await delivery(background)).status==='accepted','Android background provider acceptance');
  // Android owns this notification while Flutter is backgrounded.
  await until(async()=>adb('shell','dumpsys','notification').includes(background),'Android system notification');
  if((await delivery(background)).receivedAt)throw Error('Background incorrectly claimed foreground receipt');
  pass('Background push is displayed by Android system without false receipt');
  adb('shell','cmd','statusbar','expand-notifications');
  await tap('Tienes una novedad. Abre DTS para consultar el detalle.');
  await until(async()=>fields(await request(`${base}/notifications/${background}`)).readAt&&(await delivery(background)).openedAt,'Android notification tap/open/read');
  pass('System notification tap resumes app and records opening/read');
  // Kill the background process without force-stop (force-stop disables FCM).
  adb('shell','input','keyevent','3');await delay(2000);adb('shell','am','kill',app);
  await until(async()=>{try{return !adb('shell','pidof',app).trim();}catch{return true;}},'Android process termination',20000);
  pass('App process is absent before testing a cold notification launch');
  const cold=await event('cold');
  await until(async()=>adb('shell','dumpsys','notification').includes(cold),'Android terminated-process notification');
  adb('shell','cmd','statusbar','expand-notifications');await tap('Tienes una novedad. Abre DTS para consultar el detalle.');
  await until(async()=>fields(await request(`${base}/notifications/${cold}`)).readAt&&(await delivery(cold)).openedAt,'Android cold-start opening/read');
  pass('Notification launches terminated app with restored session and records read');
}
main().catch(e=>{report.error=e.message;console.error(e.message);process.exitCode=1;}).finally(async()=>{
  if(uid){
    try{
      await put(`users/${uid}`,{active:false});
      try{adb('shell','pm','clear',app);}catch{console.error('Emulator unavailable during local app cleanup');}
      for(const eventId of eventIds){for(const n of await query('notifications','eventId',eventId)){const ds=await request(`https://firestore.googleapis.com/v1/${n.name}/deliveries`);for(const d of ds.documents||[])await remove(d);await remove(n);}await request(`${base}/notificationEvents/${eventId}`,'DELETE');}
      for(const col of ['deviceSessions','pushTokens'])for(const d of await query(col,'uid',uid))await remove(d);
      const slots=await request(`${base}/userDevices/${uid}/slots`);for(const d of slots.documents||[])await remove(d);
      await request(`${base}/users/${uid}`,'DELETE');await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:delete`,'POST',{localId:uid});
      pass('Temporary Android account, tokens, events and deliveries cleaned');
    }catch(e){report.cleanupError=e.message;console.error('QA cleanup:',e.message);process.exitCode=1;}
  }
  fs.mkdirSync('artifacts',{recursive:true});report.finishedAt=new Date().toISOString();fs.writeFileSync('artifacts/qa-android-notifications.json',JSON.stringify(report,null,2));
});
