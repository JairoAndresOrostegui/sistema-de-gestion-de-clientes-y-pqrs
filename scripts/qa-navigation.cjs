// Exercises rendered Flutter navigation against real QA with the temporary
// commercial account owned and cleaned up by qa-smoke.cjs.
const fs = require('node:fs');
module.exports = async function auditNavigation(page) {
  const destinations = ['Resumen','Solicitudes y PQRS','Empresas','Proyectos','Instalaciones y versiones','Productos y soluciones','Personas y estructura','Catálogo funcional','Contratos y cobertura','Servicios y renovaciones','Implementación y agenda','Base de conocimientos','Valores y movimientos','Notificaciones','Mi cuenta'];
  const errors = [], warnings = [];
  const injectedFaultConsole = [];
  let injectingFault = false;
  page.on('console', message => {
    if(injectingFault) { if(['error','warning'].includes(message.type())) injectedFaultConsole.push(message.text()); return; }
    if (message.type() === 'error') errors.push(message.text());
    if (message.type() === 'warning') warnings.push(message.text());
  });
  let visits = 0;
  for (const [width,height] of [[320,568],[390,844],[768,1024],[844,390],[1440,900]]) {
    await page.setViewportSize({width,height});
    for (const destination of destinations) {
      if(width<1080) await page.getByRole('button',{name:'Abrir menú',exact:true}).click();
      const link=page.getByText(destination,{exact:true}).first();
      // Flutter virtualizes its menu; scroll by pointer until the entry exists.
      for(let tries=0;tries<20;tries++) {
        if(await link.isVisible()) {
          const box=await link.boundingBox();
          if(box && box.y>120 && box.y+box.height<height-115) break;
        }
        await page.mouse.move(120,Math.max(160,height/2));
        await page.mouse.wheel(0,destination==='Resumen'?-350:150);
        await page.waitForTimeout(80);
      }
      await link.click({timeout:10000});
      await page.getByText(`DTS / ${destination}`,{exact:true}).waitFor({timeout:15000});
      await page.waitForLoadState('networkidle');
      if(await page.getByText('No pudimos cargar la información',{exact:true}).count()) throw Error(`QA loading failure: ${destination} at ${width}`);
      if(['Resumen','Solicitudes y PQRS','Empresas','Contratos y cobertura'].includes(destination)) {
        await page.screenshot({path:`artifacts/audit-${width}-${destinations.indexOf(destination)}.png`,fullPage:true});
      }
      visits++;
    }
  }
  if(errors.length) throw Error(`Browser console errors: ${errors.join('; ')}`);
  injectingFault = true;
  await page.route('**cloudfunctions.net/api',route=>route.abort('internetdisconnected'),{times:1});
  await page.mouse.move(120,450);await page.mouse.wheel(0,-2000);await page.waitForTimeout(200);
  await page.getByText('Empresas',{exact:true}).first().click();
  await page.getByText('No pudimos cargar la información',{exact:true}).waitFor({timeout:30000});
  await page.getByRole('button',{name:'Volver a intentar',exact:true}).click();
  await page.getByText('No pudimos cargar la información',{exact:true}).waitFor({state:'hidden',timeout:30000});
  await page.getByText('Verificación QA temporal',{exact:true}).first().waitFor({timeout:30000});
  fs.writeFileSync('artifacts/browser-audit.json',JSON.stringify({visits,viewports:5,roles:['commercial'],consoleErrors:errors,consoleWarnings:warnings,networkFailureRecovered:true,injectedFaultConsole},null,2));
  console.log(`QA navigation audit passed: ${visits} screen visits across 5 viewports; ${warnings.length} console warnings (recorded).`);
  console.log('QA browser network fault: error displayed and retry recovered real data.');
};
