// Documentation-only renderer. Uses marked included with the installed Firebase CLI
// and the project's Playwright; produces PDFs with selectable text and page numbers.
const fs=require('node:fs'),path=require('node:path');
const {marked}=require(require.resolve('marked',{paths:[path.resolve(__dirname,'../functions'),path.join(process.env.APPDATA||'','npm/node_modules/firebase-tools')]}));
const {chromium}=require('../functions/node_modules/@playwright/test');
(async()=>{
  const directory=path.resolve(__dirname,'../documentacion');
  const browser=await chromium.launch({channel:'chrome',headless:true});
  try{const page=await browser.newPage();
    for(const name of fs.readdirSync(directory).filter(n=>/^0[1-8]_.*\.md$/.test(n))){
      const content=marked.parse(fs.readFileSync(path.join(directory,name),'utf8'));
      await page.setContent(`<!doctype html><html lang="es"><meta charset="utf-8"><style>@page{size:A4;margin:20mm 17mm 22mm}body{font:10.5pt/1.55 Arial,sans-serif;color:#203445}h1{font-size:25pt;line-height:1.15;color:#0a3d62;border-bottom:5px solid #ffc300;padding-bottom:20px}h2{font-size:15pt;color:#0a3d62;margin-top:26px;break-after:avoid}h3{break-after:avoid}p,li{orphans:3;widows:3}table{border-collapse:collapse;width:100%;font-size:8.5pt}td,th{border:1px solid #ccd5db;padding:6px;vertical-align:top}th{background:#eaf0f4;text-align:left}tr{break-inside:avoid}a{color:#0a3d62;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:8pt;background:#eef2f5;padding:12px}code{overflow-wrap:anywhere}img{max-width:100%}</style><body><p>DTS · Desarrollo &amp; Tecnología Santander</p>${content}</body></html>`);
      await page.pdf({path:path.join(directory,name.replace(/\.md$/,'.pdf')),format:'A4',printBackground:true,displayHeaderFooter:true,headerTemplate:'<span></span>',footerTemplate:'<div style="font:8px Arial;width:100%;margin:0 17mm;color:#607080;display:flex;justify-content:space-between"><span>DTS · Documentación QA · 26/09/2026</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>'});
      console.log('PDF',name.replace(/\.md$/,'.pdf'));
    }
  }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
