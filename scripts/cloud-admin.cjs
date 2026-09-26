// Local provisioning only. Uses the already authenticated Firebase CLI; never prints tokens.
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {configstore} = require(path.join(cli, 'configstore.js'));
const {getAccessToken} = require(path.join(cli, 'auth.js'));
const project = 'sistema-de-gestion-y-pqrs';
async function request(url, method = 'GET', body) {
  const token = await getAccessToken(configstore.get('tokens').refresh_token, ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  const r = await fetch(url, {method, headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type':'application/json'}, body: body ? JSON.stringify(body) : undefined});
  const raw = await r.text();
  const data = raw ? JSON.parse(raw) : {};
  if (!r.ok) throw new Error(`${r.status}: ${data.error?.message || (Array.isArray(data) && data[0]?.error?.message) || 'Cloud request failed'}`);
  return data;
}
module.exports = {request, project};
if (require.main === module) (async () => {
  if (process.argv[2] === 'inspect') {
    console.log('Billing:', await request(`https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`));
    for (const api of ['firestore.googleapis.com','identitytoolkit.googleapis.com','firebasestorage.googleapis.com','cloudfunctions.googleapis.com']) {
      console.log(api, (await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services/${api}`)).state);
    }
  }
  if (process.argv[2] === 'enable') {
    console.log(await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services:batchEnable`, 'POST', {serviceIds:['firestore.googleapis.com','identitytoolkit.googleapis.com','firebasestorage.googleapis.com','cloudfunctions.googleapis.com','cloudbuild.googleapis.com','artifactregistry.googleapis.com','run.googleapis.com','cloudscheduler.googleapis.com','secretmanager.googleapis.com']}));
  }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
