const {request,project}=require('./cloud-admin.cjs');
const fs=require('node:fs');
async function main(){
  const config=await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`);
  console.log('Auth email:',config.signIn?.email?.enabled,'Domains:',config.authorizedDomains);
  await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config?updateMask=signIn.email,authorizedDomains`, 'PATCH', {signIn:{email:{enabled:true,passwordRequired:true}},authorizedDomains:[...new Set([...(config.authorizedDomains||[]),'localhost',`${project}.web.app`,`${project}.firebaseapp.com`])]});
  try {const provider=await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/defaultSupportedIdpConfigs/google.com`);console.log('Google sign in:',provider.enabled?'enabled':'disabled', 'client configured:',!!provider.clientId);}
  catch(e){console.log('Google provider:',e.message);}
  try {
    const bucket=await request(`https://firebasestorage.googleapis.com/v1alpha/projects/${project}/defaultBucket`);console.log('Storage:',bucket.name);
  }catch(e){
    console.log('Creating QA storage bucket');
    console.log(await request(`https://firebasestorage.googleapis.com/v1alpha/projects/${project}/defaultBucket`,'POST',{location:'US',storageClass:'STANDARD'}));
  }
  // Explicit IAM-authorized bootstrap for this exact owner, never public first-user signup.
  const email='jairoandresorostegui@gmail.com';
  const lookup=await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,'POST',{email:[email]});
  let uid=lookup.users?.[0]?.localId;
  if(!uid){const created=await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts`,'POST',{email,displayName:'Jairo Andrés Orostegui'});uid=created.localId;}
  if(!uid)throw Error('No UID returned');
  await request(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/users/${uid}`,'PATCH',{fields:{email:{stringValue:email},name:{stringValue:'Jairo Andrés Orostegui'},role:{stringValue:'owner'},active:{booleanValue:true},permissions:{arrayValue:{values:[]}},createdAt:{stringValue:new Date().toISOString()}}});
  console.log('Owner bootstrapped:',email,'UID:',uid,'(verified sign-in still required)');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
