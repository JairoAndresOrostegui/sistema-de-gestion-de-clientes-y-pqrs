import {createHash,createSign} from 'node:crypto';
import {z} from 'zod';
export const sourceSchema=z.object({path:z.string().max(240),content:z.string().max(65536)});
export const importSchema=z.object({companyId:z.string().regex(/^[\w-]+$/),projectId:z.string().regex(/^[\w-]+$/),repository:z.string().max(300).default('local'),commit:z.string().max(80).default('local'),files:z.array(sourceSchema).max(80)});
export type Candidate={key:string;name:string;description:string;source:string;confidence:number;sensitive:boolean;fingerprint:string};
export function allowedSource(path:string) {
  if (/(^|\/)(\.|node_modules|vendor|build|dist|coverage|Pods|\.git)(\/|$)/i.test(path)|| /(^|\/)\.[^/]+/.test(path)) return false;
  if (/(secret|credential|private|password|token|service.?account|lock|dump)/i.test(path)) return false;
  return /(^|\/)(readme[^/]*|changelog[^/]*|package.json|pubspec.yaml)$/i.test(path)|| /^(docs|lib|src|app|routes|migrations|openapi|api)\/.*\.(md|dart|ts|tsx|js|json|yaml|yml|sql)$/i.test(path);
}
export function looksSensitive(value:string) {return /-----BEGIN|AIza[\w-]{20,}|gh[pousr]_[\w]{20,}|(?:password|secret|token|api[_-]?key)\s*[:=]\s*['"]?[^\s'"{}]{8,}/i.test(value);}
export function inspectFiles(files:z.infer<typeof sourceSchema>[]) {
  const result:Candidate[]=[]; let bytes=0;
  for(const f of files.slice(0,80)) {
    bytes+=Buffer.byteLength(f.content); if(bytes>1024*1024) break;
    if(!allowedSource(f.path)||looksSensitive(f.content)) continue;
    const headings=[...f.content.matchAll(/^#{1,3}\s+(.{3,120})$/gm)].map(m=>m[1]);
    const routes=[...f.content.matchAll(/(?:path|route|name)\s*:\s*['"]([^'"\n]{3,100})['"]/g)].map(m=>m[1]);
    const names=[...new Set([...headings,...routes])].slice(0,15);
    for(const n of names) {
      const key=createHash('sha256').update(`${f.path}:${n}`).digest('hex').slice(0,24);
      result.push({key,name:n,description:`Funcionalidad candidata detectada en ${f.path}. Requiere validación humana.`,source:f.path,confidence:headings.includes(n)?0.7:0.45,sensitive:false,fingerprint:createHash('sha256').update(`${n}:${f.content}`).digest('hex')});
      if(result.length>=120)return result;
    }
  } return result;
}
async function githubRequest(path:string,token?:string) {
  const r=await fetch(`https://api.github.com${path}`,{headers:{Accept:'application/vnd.github+json','User-Agent':'DTS-Catalog','X-GitHub-Api-Version':'2022-11-28',...(token?{Authorization:`Bearer ${token}`}:{})},signal:AbortSignal.timeout(12000)});
  if(!r.ok)throw new Error(`GitHub no disponible (${r.status}). Revisa URL y permisos de instalación.`);
  return r.json();
}
export async function installationToken(installationId:string) {
  const appId=process.env.GITHUB_APP_ID, key=process.env.GITHUB_APP_PRIVATE_KEY;
  if(!appId||!key)throw new Error('GitHub App pendiente de configurar. Usa repositorio público o importación local.');
  const base=(v:unknown)=>Buffer.from(JSON.stringify(v)).toString('base64url');
  const now=Math.floor(Date.now()/1000); const unsigned=`${base({alg:'RS256',typ:'JWT'})}.${base({iat:now-60,exp:now+540,iss:appId})}`;
  const jwt=`${unsigned}.${createSign('RSA-SHA256').update(unsigned).sign(key,'base64url')}`;
  const r=await fetch(`https://api.github.com/app/installations/${installationId}/access_tokens`,{method:'POST',headers:{Authorization:`Bearer ${jwt}`,Accept:'application/vnd.github+json','Content-Type':'application/json'},body:JSON.stringify({permissions:{contents:'read'}}),signal:AbortSignal.timeout(12000)});
  if(!r.ok)throw new Error('No se pudo autorizar la instalación GitHub App');
  return (await r.json() as {token:string}).token;
}
export async function githubFiles(url:string,installationId?:string) {
  const match=/^https:\/\/github\.com\/([\w.-]+)\/([\w.-]+?)(?:\.git)?\/?$/.exec(url);
  if(!match)throw new Error('Usa una URL https://github.com/organización/repositorio');
  const [,owner,repo]=match; const token=installationId?await installationToken(installationId):undefined;
  const meta=await githubRequest(`/repos/${owner}/${repo}`,token);
  const commit=await githubRequest(`/repos/${owner}/${repo}/commits/${encodeURIComponent(meta.default_branch)}`,token);
  const tree=await githubRequest(`/repos/${owner}/${repo}/git/trees/${commit.sha}?recursive=1`,token);
  const entries=tree.tree.filter((e:{type:string;path:string;size:number})=>e.type==='blob'&&e.size<=65536&&allowedSource(e.path)).slice(0,40);
  const files=[];let bytes=0;
  for(const e of entries) {
    if(bytes+e.size>1024*1024)break;
    const blob=await githubRequest(`/repos/${owner}/${repo}/git/blobs/${e.sha}`,token);
    const content=Buffer.from(blob.content,'base64').toString('utf8'); bytes+=Buffer.byteLength(content);
    files.push({path:e.path,content});
  }
  return {repository:`https://github.com/${owner}/${repo}`,commit:commit.sha,files,truncated:tree.truncated||entries.length===40};
}
