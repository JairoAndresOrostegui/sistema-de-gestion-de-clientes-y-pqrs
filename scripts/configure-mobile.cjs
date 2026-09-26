const {request,project}=require('./cloud-admin.cjs');
const fs=require('node:fs');
(async()=>{
  for(const [kind,id,file] of [['android','1:1821240632:android:6a6758ae1d811693fae5cd','android/app/google-services.json'],['ios','1:1821240632:ios:e6e1726839af48d8fae5cd','ios/Runner/GoogleService-Info.plist']]) {
    const config=await request(`https://firebase.googleapis.com/v1beta1/projects/${project}/${kind}Apps/${id}/config`);
    fs.writeFileSync(file,Buffer.from(config.configFileContents,'base64'));
    console.log('Refreshed',file);
  }
  await request(`https://storage.googleapis.com/storage/v1/b/${project}.firebasestorage.app`,'PATCH',{cors:[{origin:[`https://${project}.web.app`,`https://${project}.firebaseapp.com`,'http://localhost:7357'],method:['GET','HEAD'],responseHeader:['Content-Type','Authorization'],maxAgeSeconds:3600}]});
  console.log('Storage CORS configured for QA hosting and localhost:7357');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
