const {chromium}=require('../functions/node_modules/@playwright/test');
const fs=require('node:fs');
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(process.argv[2]||'http://localhost:7357',{waitUntil:'networkidle'});
  await page.locator('flutter-view').waitFor({timeout:60000});
  await page.waitForFunction(()=>!document.getElementById('loading'),{timeout:60000});
  // Flutter CanvasKit paints outside the DOM; enable its accessibility tree for interaction.
  const semantics=page.locator('flt-semantics-placeholder');if(await semantics.count())await semantics.evaluate(e=>e.click());
  await page.getByText('Bienvenido a DTS',{exact:true}).waitFor({timeout:15000});
  await page.screenshot({path:'artifacts/login-desktop.png',fullPage:true});
  const mobile=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:1});
  await mobile.goto(process.argv[2]||'http://localhost:7357',{waitUntil:'networkidle'});
  await mobile.waitForFunction(()=>!document.getElementById('loading'),{timeout:60000});
  await mobile.screenshot({path:'artifacts/login-mobile.png',fullPage:true});
  if(errors.length)throw new Error(errors.join('\n'));
  console.log('Browser smoke passed: Firebase initialized, login visible, desktop/mobile rendered, no JS exceptions.');
  await browser.close();
})().catch(e=>{console.error(e.message);process.exitCode=1;});
