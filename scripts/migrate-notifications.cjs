// Preserves legacy notices as personal history without sending old pushes again.
// Explicit QA project, existing Firebase CLI IAM session, no credentials on disk.
const {request,project}=require('./cloud-admin.cjs');
const base=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const encode=v=>v===null?{nullValue:null}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:typeof v==='string'?{stringValue:v}:Array.isArray(v)?{arrayValue:{values:v.map(encode)}}:{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,v])=>[k,encode(v)]))}};
const decode=v=>v?.stringValue??v?.booleanValue??v?.integerValue??(v?.arrayValue?(v.arrayValue.values||[]).map(decode):v?.mapValue?Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,v])=>[k,decode(v)])):null);
const data=d=>decode({mapValue:{fields:d.fields||{}}});
(async()=>{
  let pageToken,migrated=0,skipped=0;const legacy=[];
  do{const page=await request(`${base}/notifications?pageSize=300${pageToken?'&pageToken='+encodeURIComponent(pageToken):''}`);for(const doc of page.documents||[])if(!data(doc).recipientId)legacy.push(doc);pageToken=page.nextPageToken;}while(pageToken);
  for(const doc of legacy){const n=data(doc);const id=doc.name.split('/').pop();let ticket;
    if(!n.source&&n.entityId){try{ticket=data(await request(`${base}/tickets/${n.entityId}`));}catch(e){if(!e.message.startsWith('404'))throw e;}}
    if(!ticket&&!n.source){skipped++;continue;}
    const event={historical:true,kind:'legacy',audience:n.audience==='staff'?'staff':'public',targetUid:n.audience==='staff'?null:n.audience,entityId:n.entityId||'',ticketId:ticket?n.entityId:null,companyId:n.companyId||ticket?.companyId||null,projectId:n.projectId||ticket?.projectId||null,body:n.body||'Aviso histórico DTS',source:n.source||null,dueDate:n.dueDate||null,readBy:n.readBy||{},actorId:'system',createdAt:n.createdAt||new Date().toISOString(),state:'pending',nextAttemptAt:new Date().toISOString()};
    try{await request(`${base}/notificationEvents?documentId=legacy_${id}`,'POST',{fields:encode(event).mapValue.fields});migrated++;}catch(e){if(!e.message.startsWith('409'))throw e;skipped++;}
  }
  console.log(JSON.stringify({project,legacyFound:legacy.length,historicalEventsCreated:migrated,alreadyPresentOrMissingSource:skipped}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
