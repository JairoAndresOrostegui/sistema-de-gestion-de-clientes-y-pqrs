#!/usr/bin/env node
// Bounded, read-only source inspection. Writes only a local preview for explicit upload.
const fs=require('node:fs');const path=require('node:path');const {execFileSync}=require('node:child_process');
const {allowedSource,looksSensitive}=require('../functions/lib/importer.js');
const root=fs.realpathSync(process.argv[2]||'.');const files=[];const skipped=[];let total=0;
function visit(dir){
  if(files.length>=80||total>=1024*1024)return;
  for(const e of fs.readdirSync(dir,{withFileTypes:true})){
    if(e.isSymbolicLink())continue;
    const absolute=path.join(dir,e.name);const relative=path.relative(root,absolute).replaceAll('\\','/');
    if(e.isDirectory()){if(!/(^|\/)(\.[^/]*|node_modules|vendor|dist|build|coverage|Pods|target)$/.test(relative))visit(absolute);continue;}
    if(!allowedSource(relative))continue;
    const size=fs.statSync(absolute).size;if(size>65536||total+size>1024*1024||files.length>=80)continue;
    const content=fs.readFileSync(absolute,'utf8');if(looksSensitive(content)){skipped.push(relative);continue;}
    files.push({path:relative,content});total+=size;
  }
}
visit(root);let commit='local';try{commit=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();}catch{}
const out=path.resolve(process.argv[3]||'local-import-preview.json');
if(fs.existsSync(out))throw Error('El archivo de salida ya existe. Elige otro nombre.');
fs.writeFileSync(out,JSON.stringify({repository:'local',commit,files},null,2),{flag:'wx'});
console.log(`${files.length} archivos (${total} bytes). ${skipped.length} archivos sensibles excluidos.\nRevisa ${out} antes de cargarlo desde Enlazar proyecto.`);
