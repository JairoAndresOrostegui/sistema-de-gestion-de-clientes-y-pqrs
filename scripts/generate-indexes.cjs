const fs=require('node:fs');
const indexes=[];const seen=new Set();
function add(collectionGroup,fields){if(fields.length<2)return;const key=collectionGroup+JSON.stringify(fields);if(seen.has(key))return;seen.add(key);indexes.push({collectionGroup,queryScope:'COLLECTION',fields:fields.map(f=>typeof f==='string'?{fieldPath:f,order:'ASCENDING'}:f)});}
const scopes=[[],['companyId'],['companyId','projectId'],['projectId']];
for(const coll of ['projects','contacts','catalog','articles','events','contracts','services','finance','publicContracts','publicServices','installations'])for(const scope of scopes){
  add(coll,[...scope,'searchName']);
  if(['catalog','articles','events','installations'].includes(coll))add(coll,[...scope,'published','searchName']);
  add(coll,[...scope,'status']);
}
for(const scope of scopes)for(const audience of [[],['requesterId'],[{fieldPath:'visibleTo',arrayConfig:'CONTAINS'}]])for(let mask=0;mask<8;mask++){
  const filters=['status','priority','assigneeId'].filter((_,i)=>mask&(1<<i));
  add('tickets',[...scope,...audience,...filters]);
  add('tickets',[...scope,...audience,...filters,'searchName']);
}
for(const coll of ['contracts','services']){add(coll,['status','endDate']);add(coll,['companyId','projectId','type']);}
add('memberships',['uid','active']);
add('notifications',['recipientId',{fieldPath:'createdAt',order:'DESCENDING'},{fieldPath:'__name__',order:'DESCENDING'}]);
add('notificationEvents',['state','nextAttemptAt']);
add('notificationEvents',['ticketId',{fieldPath:'createdAt',order:'DESCENDING'},{fieldPath:'__name__',order:'DESCENDING'}]);
add('notifications',['eventId','recipientId']);
fs.writeFileSync('firestore.indexes.json',JSON.stringify({indexes,fieldOverrides:[]},null,2)+'\n');
console.log(`${indexes.length} indexes generated`);
