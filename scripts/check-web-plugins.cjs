// Detects stale Flutter web build caches after adding plugins. This is a build
// check, since widget tests replace transport and do not load browser plugins.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..','.dart_tool','flutter_build');
const registrants=fs.readdirSync(root).filter(n=>/^[a-f0-9]{32}$/.test(n)).map(n=>path.join(root,n,'web_plugin_registrant.dart')).filter(p=>fs.existsSync(p)).sort((a,b)=>fs.statSync(b).mtimeMs-fs.statSync(a).mtimeMs);
if(!registrants.length)throw Error('Build Flutter web before checking browser plugins');
const source=fs.readFileSync(registrants[0],'utf8');
for(const plugin of ['DeviceInfoPlusWebPlugin','FirebaseMessagingWeb','SharedPreferencesPlugin'])if(!source.includes(`${plugin}.registerWith`))throw Error(`Stale Flutter web plugin registry: ${plugin}. Regenerate the Flutter web build cache before deployment.`);
if(!fs.existsSync(path.resolve(__dirname,'../build/web/firebase-messaging-sw.js')))throw Error('Messaging service worker is missing from the web build');
console.log('Web plugin registry and messaging service worker verified');
