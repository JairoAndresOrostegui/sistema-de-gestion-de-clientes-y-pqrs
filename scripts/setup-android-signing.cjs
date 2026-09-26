// Creates an upload key locally. Never uploads or prints private signing material.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {randomBytes} = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const config = path.join(root, 'android/key.properties');
const directory = path.join(os.homedir(), '.dts-signing', 'android');
const store = path.join(directory, 'dts-upload.jks');
if (fs.existsSync(config) || fs.existsSync(store)) {
  throw Error('Signing material already exists. Preserve it; this script never replaces a key.');
}
fs.mkdirSync(directory, {recursive: true, mode: 0o700});
if (process.platform === 'win32') {
  const account = spawnSync('whoami', [], {encoding: 'utf8'}).stdout.trim();
  const acl = spawnSync('icacls', [directory, '/inheritance:r', '/grant:r', `${account}:(OI)(CI)F`, 'SYSTEM:(OI)(CI)F'], {encoding: 'utf8'});
  if (acl.status !== 0) throw Error('Could not restrict signing directory permissions.');
}
const password = randomBytes(32).toString('hex');
const javaHome = process.env.JAVA_HOME || (process.platform === 'win32' ? 'C:/Program Files/Android/Android Studio/jbr' : '');
const keytool = javaHome ? path.join(javaHome, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool') : 'keytool';
const result = spawnSync(keytool, ['-genkeypair', '-keystore', store, '-storetype', 'JKS',
  '-storepass:env', 'DTS_SIGNING_PASSWORD', '-keypass:env', 'DTS_SIGNING_PASSWORD',
  '-alias', 'dts-upload', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
  '-dname', 'CN=DTS Android Upload, O=Desarrollo y Tecnologia Santander, C=CO'],
  {env: {...process.env, DTS_SIGNING_PASSWORD: password}, encoding: 'utf8'});
if (result.status !== 0) throw Error('Key generation failed: ' + (result.error?.message || result.stderr));
const properties = `storeFile=${store.replace(/\\/g, '/')}\nstorePassword=${password}\nkeyAlias=dts-upload\nkeyPassword=${password}\n`;
fs.writeFileSync(path.join(directory, 'key.properties'), properties, {flag: 'wx', mode: 0o600});
fs.writeFileSync(config, properties, {flag: 'wx', mode: 0o600});
console.log('Local upload key created. Back up the protected directory:', directory);
console.log('android/key.properties is excluded from Git. Store publication remains separate.');
