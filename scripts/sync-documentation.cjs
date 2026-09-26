const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=path.join(root,'documentacion');
const destination=path.resolve(root,'..','documentacion');
if(path.dirname(destination)!==path.dirname(root)||path.basename(destination)!=='documentacion')throw Error('Unexpected documentation destination');
fs.mkdirSync(destination,{recursive:true});
let count=0;
for(const entry of fs.readdirSync(source,{withFileTypes:true}))if(entry.isFile()&&/\.(md|pdf|html)$/.test(entry.name)){
  fs.copyFileSync(path.join(source,entry.name),path.join(destination,entry.name));count++;
}
console.log(`${count} documentation files synchronized to ${destination}`);
