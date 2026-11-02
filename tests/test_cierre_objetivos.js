// Cierre de la semana con los objetivos de la siguiente (02/11/2026). Datos inventados.
// Uso: node tests/test_cierre_objetivos.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 if(/;\s*$/.test(lines[i])&&!/[{(\[]\s*$/.test(lines[i]))return lines[i];let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,Intl,RegExp,Error,JSON};vm.createContext(ctx);
vm.runInContext([
 'const PS_OBJETIVOS_ESPERADOS=[{tipo:"VENTA",categoria:"GENERAL"},{tipo:"SELECTIVO",categoria:"FAMILIA_03"},{tipo:"SELECTIVO",categoria:"FAMILIA_08"}];',
 'let psObjetivosCache=[];',
 'function _weekKeyLabel(a,b){ return a+" a "+b; }',
 'function _semanaKpisFaltan(){ return []; }',
 'function _tonoSemanaKpis(){ return {tono:"neutro"}; }',
 'function psResumenSemanaCierre(){ return "Venta de la semana: 9.000 €."; }',
 'function psPalancasCierre(){ return []; }',
 'function _planListaDias(d){ return d.join(", "); }',
 'function psNombreFamilia(f){ return {"03":"Colorido selectivo","08":"Tratamiento selectivo"}[String(f).padStart(2,"0")]||("Familia "+f); }',
 ...['function _dateISO(','function getWeekBounds(','function _isoWeek(','function psEuros(','function psTextoCierre(','function psEtiquetaObjetivo(','function psValorTexto(',
  'function psObjetivosDe(','function psLineasObjetivosMensaje(','function psMensajeCierre('].map(trozo)
].join('\n')+'\nthis.setCache=c=>{psObjetivosCache=c;};',ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}

const cierre={objetivos:[{etiqueta:'Colorido selectivo (03)',objetivo:200.2,real:196,cumplimiento_pct:97.9,unidad:'EUR'},
 {etiqueta:'Tratamiento selectivo (08)',objetivo:1074.7,real:1625,cumplimiento_pct:151.2,unidad:'EUR'}],semana_kpis:null};
const obj=(categoria,tipo,valor)=>({tienda:'T91',semana_inicio:'2026-11-02',tipo_objetivo:tipo,categoria,familia:categoria.slice(-2),unidad:'EUR',valor_objetivo:valor});

ctx.setCache([obj('FAMILIA_03','SELECTIVO',147.4),obj('FAMILIA_08','SELECTIVO',564.3)]);
const m=ctx.psMensajeCierre('T91','Plaza Inventada','2026-10-26',cierre,'César');
console.log(m);
prueba('el cierre sigue diciendo el resultado de la semana',/Colorido selectivo \(03\): objetivo 200,20 € · real 196,00 €/.test(m)&&/Tratamiento selectivo \(08\): objetivo 1\.074,70 € · real 1\.625,00 € · cumplimiento 151,2%/.test(m),m);
prueba('añade los objetivos de la semana siguiente',/Objetivos de la semana 45 \(2026-11-02 a 2026-11-08\):/.test(m),m);
prueba('con Colorido, Tratamiento y total',/Colorido selectivo \(03\): 147,40 €/.test(m)&&/Tratamiento selectivo \(08\): 564,30 €/.test(m)&&/Total Selectivo: 711,70 €/.test(m),m);
prueba('sin objetivo de venta lo dice, sin inventarlo',/Venta semanal: sin objetivo informado/.test(m)&&!/Venta semanal: 0/.test(m),m);
prueba('los objetivos van antes del agradecimiento y la firma',m.indexOf('Objetivos de la semana 45')<m.indexOf('Gracias')&&m.trim().endsWith('César'),m);

ctx.setCache([obj('FAMILIA_03','SELECTIVO',147.4),{...obj('GENERAL','VENTA',9800),familia:null}]);
prueba('con objetivo de venta, lo pone',/Venta semanal: 9\.800,00 €/.test(ctx.psMensajeCierre('T91','x','2026-10-26',cierre,'César')));

ctx.setCache([]);
const sin=ctx.psMensajeCierre('T91','x','2026-10-26',cierre,'César');
prueba('sin objetivos cargados de la semana siguiente, no añade nada',!/Objetivos de la semana 45/.test(sin),sin);

ctx.setCache([{...obj('FAMILIA_03','SELECTIVO',147.4),tienda:'T92'}]);
prueba('solo los objetivos de esa tienda',!/Objetivos de la semana 45/.test(ctx.psMensajeCierre('T91','x','2026-10-26',cierre,'César')));

console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
