// Cierre de la semana paso a paso (02/11/2026). Datos inventados.
// Uso: node tests/test_cierre_semana.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 if(/;\s*$/.test(lines[i])&&!/[{(\[]\s*$/.test(lines[i]))return lines[i];let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,RegExp,Error,JSON};vm.createContext(ctx);
vm.runInContext(['function _faroSemanaCompletaTexto(r){ return "S44: faltan sábado 31"; }',
 ...['function _isoWeek(','function _cierreSemanaPasos('].map(trozo)].join('\n'),ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}

const T=['T91','T92','T93'], semEval='2026-10-26', semPlan='2026-11-02';
const res=(t,c)=>({tienda:t,semana_inicio:semEval,categoria:c,resultado_eur:100});
const obj=(t,tipo,c)=>({tienda:t,semana_inicio:semPlan,tipo_objetivo:tipo,categoria:c});
const todoRes=T.flatMap(t=>[res(t,'FAMILIA_03'),res(t,'FAMILIA_08')]);
const todoObj=T.flatMap(t=>[obj(t,'SELECTIVO','FAMILIA_03'),obj(t,'SELECTIVO','FAMILIA_08')]);
const base={tiendas:T,semEval,semPlan,semanaCompleta:{completa:true},kpisAlDia:true,resultados:todoRes,objetivos:todoObj,
 focos:T.map(t=>({tienda:t,semana_inicio:semPlan})),cierres:{},enviadas:{}};
const paso=(r,k)=>r.pasos.find(p=>p.clave===k);

let r=ctx._cierreSemanaPasos(base);
prueba('seis pasos en orden',r.pasos.map(p=>p.clave).join()==='datos,resultados,objetivos,foco,cerrar,enviar');
prueba('con todo cargado se puede cerrar las tres',r.puedeCerrar&&r.porCerrar.join()==='T91,T92,T93');
prueba('títulos con la semana que se cierra y la nueva',paso(r,'datos').titulo==='Datos de la S44'&&paso(r,'objetivos').titulo==='Objetivos de la S45');
prueba('sin objetivo de venta lo avisa sin bloquear',paso(r,'objetivos').ok&&/Venta semanal: sin objetivo/.test(paso(r,'objetivos').texto));

r=ctx._cierreSemanaPasos({...base,resultados:todoRes.filter(x=>!(x.tienda==='T92'&&x.categoria==='FAMILIA_08'))});
prueba('falta un resultado: dice qué tienda y no deja cerrar',!paso(r,'resultados').ok&&/faltan T92/.test(paso(r,'resultados').texto)&&!r.puedeCerrar&&r.bloqueo.includes('faltan resultados'));

r=ctx._cierreSemanaPasos({...base,objetivos:todoObj.filter(x=>x.tienda!=='T93')});
prueba('faltan objetivos de Selectivo: no deja cerrar',!paso(r,'objetivos').ok&&/faltan T93/.test(paso(r,'objetivos').texto)&&!r.puedeCerrar);

r=ctx._cierreSemanaPasos({...base,semanaCompleta:{completa:false}});
prueba('semana incompleta: no deja cerrar y dice qué falta',!r.puedeCerrar&&/faltan sábado/.test(paso(r,'datos').texto));

r=ctx._cierreSemanaPasos({...base,focos:[]});
prueba('sin FOCO se avisa pero se puede cerrar',!paso(r,'foco').ok&&r.puedeCerrar);

r=ctx._cierreSemanaPasos({...base,kpisAlDia:false});
prueba('KPIs semanales sin subir: se avisa en el paso de datos',/KPIs semanales/.test(paso(r,'datos').texto)&&r.puedeCerrar);

const cierres={T91:{cerrada:true,mensaje:'Cierre...\nObjetivos de la semana 45 (...):'},T92:{cerrada:true,mensaje:'Cierre sin objetivos'}};
r=ctx._cierreSemanaPasos({...base,cierres});
prueba('solo quedan por cerrar las que faltan',r.porCerrar.join()==='T93');
prueba('un cierre guardado sin los objetivos nuevos pide regenerar',r.sinObjEnMensaje.join()==='T92'&&/T92: el mensaje se guardó sin los objetivos/.test(paso(r,'cerrar').texto)&&r.tiendas.find(t=>t.id==='T92').regenerar);
prueba('no pide regenerar si la tienda no tiene objetivos nuevos',ctx._cierreSemanaPasos({...base,cierres,objetivos:todoObj.filter(x=>x.tienda!=='T92')}).sinObjEnMensaje.length===0);

const todas={T91:cierres.T91,T92:{cerrada:true,mensaje:cierres.T91.mensaje},T93:{cerrada:true,mensaje:cierres.T91.mensaje}};
r=ctx._cierreSemanaPasos({...base,cierres:todas,enviadas:{T91:true}});
prueba('todo cerrado: paso de cerrar en verde y nada que cerrar',paso(r,'cerrar').ok&&!r.puedeCerrar&&!r.porCerrar.length);
prueba('enviadas: cuenta y dice cuáles faltan',!paso(r,'enviar').ok&&/1\/3 enviadas · faltan T92, T93/.test(paso(r,'enviar').texto));
r=ctx._cierreSemanaPasos({...base,cierres:todas,enviadas:{T91:true,T92:true,T93:true}});
prueba('todo hecho: los seis pasos en verde',r.pasos.every(p=>p.ok));

console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
