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
      if(width<1080) { await page.getByRole('button',{name:'Abrir menú',exact:true}).click(); await page.waitForTimeout(250); }
      const links=page.getByText(destination,{exact:true});
      let target;
      // Flutter virtualizes its menu; scroll by pointer until the entry exists.
      for(let tries=0;tries<20;tries++) {
        const footer=await page.getByText('QA · Entorno de pruebas',{exact:true}).first().boundingBox({timeout:300}).catch(()=>null);
        for(const link of await links.all()) {
          const box=await link.boundingBox({timeout:300}).catch(()=>null);
          if(box && box.x<256 && box.y>125 && box.y+box.height<(footer?.y||height-115)-18) { target=box; break; }
        }
        if(target) break;
        await page.mouse.move(120,Math.max(160,height/2));
        await page.mouse.wheel(0,destination==='Resumen'?-350:150);
        await page.waitForTimeout(180);
      }
      if(!target) throw Error(`Menu entry not reachable: ${destination} at ${width}x${height}`);
      await page.mouse.click(target.x+target.width/2,target.y+target.height/2);
      await page.getByText(`DTS / ${destination}`,{exact:true}).waitFor({timeout:15000});
      // Network idleness alone can precede a Flutter frame that starts its fetch.
      // Wait for content that exists only after the FutureBuilder has resolved.
      if(destination==='Resumen') {
        await page.getByText(/^Solicitudes abiertas\s+\d/).waitFor({timeout:30000});
      } else if(destination==='Notificaciones') {
        await page.getByText('Estás al día',{exact:true}).or(page.getByRole('button',{name:'Leído',exact:true})).first().waitFor({timeout:30000});
      } else if(destination!=='Mi cuenta') {
        await page.getByText('Exportar esta página',{exact:true}).waitFor({timeout:30000});
      }
      if(await page.getByRole('button',{name:'Volver a intentar',exact:true}).count()) throw Error(`QA loading failure: ${destination} at ${width}`);
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
  await page.getByRole('button',{name:'Volver a intentar',exact:true}).waitFor({timeout:30000});
  await page.screenshot({path:'artifacts/audit-network-error.png',fullPage:true});
  await page.getByRole('button',{name:'Volver a intentar',exact:true}).click();
  await page.getByText('Exportar esta página',{exact:true}).waitFor({timeout:30000});
  if(await page.getByRole('button',{name:'Volver a intentar',exact:true}).count()) throw Error('Network retry did not recover');
  await page.screenshot({path:'artifacts/audit-network-recovered.png',fullPage:true});
  fs.writeFileSync('artifacts/browser-audit.json',JSON.stringify({visits,viewports:5,roles:['commercial'],consoleErrors:errors,consoleWarnings:warnings,networkFailureRecovered:true,injectedFaultConsole},null,2));
  console.log(`QA navigation audit passed: ${visits} screen visits across 5 viewports; ${warnings.length} console warnings (recorded).`);
  console.log('QA browser network fault: error displayed and retry recovered real data.');
};
