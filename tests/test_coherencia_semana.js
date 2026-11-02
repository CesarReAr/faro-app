// Regla única de semana completa (02/11/2026): aviso de arriba, cierre semanal y Visitas. Datos inventados.
// Uso: node tests/test_coherencia_semana.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 if(/;\s*$/.test(lines[i])&&!/[{(\[]\s*$/.test(lines[i]))return lines[i];let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,RegExp,Error,JSON};vm.createContext(ctx);
vm.runInContext(['const IVA_SEGUIMIENTO=1.20;',...['let psFactorIvaMemo','const FARO_COMPARABILIDAD','const _ORDEN_COMPARABILIDAD','function _comparabilidadValor(','function _esComparable(','function _comparabilidadDeFilas(',
 'function _dateISO(','function getWeekBounds(','function _isoWeek(','function _esFuenteVenta(','function _esFuenteMes(','function _esBloque(','function _fechasDeFila(','function psFactorIva(','function psVentaSemanaConIva(',
 'function _visSumaDias(','function _visLunes(','function _visPct(','function _visFechaES(','function _visSemanaTienda(',
 'const FARO_FUENTES_DIA','function _faroDiaValor(','function _faroEstadoDia(','function _faroUltimoDiaEsperado(','function _faroDiaEsperado(','const FARO_ESTADO_DIA_TEXTO','function _faroDiaEsperadoTexto(',
 'function _faroUltimoDiaConDatos(','function _faroUltimaSemanaCerrada(','function _faroSemanaCompleta(','function _faroSemanaCompletaTexto('].map(trozo)].join('\n'),ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}

// Semana 44 inventada: lunes 26/10 a sábado 31/10, revisada el lunes 02/11.
const L='2026-10-26', HOY='2026-11-02', T=['T91','T92'];
const dia=(t,f,extra)=>({tienda:t,fecha:f,fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'dia',ventas:1000,ventas_ly:900,tickets:40,tickets_ly:38,comparabilidad:'normal',...extra});
const bloque=(t,extra)=>({tienda:t,fecha:'2026-10-30',fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'bloque',dias_incluidos:2,ventas:3000,ventas_ly:2800,comparabilidad:'normal',...extra});
const mes=(t,f)=>({tienda:t,fecha:f,fuente:'KPIS_TIENDAS_FARO_MES',tipo_periodo:'mes',ventas:40000,ventas_ly:38000,comparabilidad:'normal'});
const lunAJue=t=>['2026-10-26','2026-10-27','2026-10-28','2026-10-29'].map(f=>dia(t,f));
const completa=T.flatMap(t=>[...lunAJue(t),bloque(t)]);
const semana=f=>ctx._faroSemanaCompleta(f,T,L,HOY);
const aviso=f=>ctx._faroDiaEsperado(f,T,HOY);
// El aviso y el recuadro dicen lo mismo del sábado; Visitas, lo mismo de la semana.
const coinciden=f=>{
 const s=semana(f), a=aviso(f);
 const sabRecuadro=T.map(t=>!s.tiendas.find(x=>x.tienda===t).faltan.includes('2026-10-31'));
 const sabAviso=T.map(t=>a.dias.find(x=>x.tienda===t).ok);
 const vis=T.map(t=>ctx._visSemanaTienda(f.filter(r=>r.tienda===t),L,1.2,HOY).faltan.join());
 const rec=T.map(t=>s.tiendas.find(x=>x.tienda===t).faltan.join());
 return JSON.stringify(sabRecuadro)===JSON.stringify(sabAviso)&&JSON.stringify(vis)===JSON.stringify(rec);
};

let s=semana(completa), a=aviso(completa);
prueba('semana realmente completa: recuadro completo',s.completa,JSON.stringify(s));
prueba('semana realmente completa: el aviso da el sábado por bueno',a.ok&&a.fecha==='2026-10-31',JSON.stringify(a));
prueba('el bloque viernes + sábado llega hasta el sábado en «Datos hasta»',ctx._faroUltimoDiaConDatos(completa)==='2026-10-31');
prueba('semana completa: aviso, recuadro y Visitas coinciden',coinciden(completa));

const sinLySab=T.flatMap(t=>[...lunAJue(t),dia(t,'2026-10-30'),dia(t,'2026-10-31',t==='T92'?{ventas_ly:null}:{})]);
s=semana(sinLySab); a=aviso(sinLySab);
prueba('sábado sin comparable: la semana no está completa',!s.completa&&s.tiendas[1].motivos[0].estado==='sin_comparable',JSON.stringify(s.tiendas[1]));
prueba('sábado sin comparable: el aviso lo dice con la tienda',!a.ok&&/sin comparable/.test(ctx._faroDiaEsperadoTexto(a))&&/T92/.test(ctx._faroDiaEsperadoTexto(a)),ctx._faroDiaEsperadoTexto(a));
prueba('sábado sin comparable: el texto de la semana lo explica',/sáb 31 \(sin comparable\) en T92/.test(ctx._faroSemanaCompletaTexto(s)),ctx._faroSemanaCompletaTexto(s));
prueba('sábado sin comparable: aviso, recuadro y Visitas coinciden',coinciden(sinLySab));
prueba('un bloque sin comparable tampoco vale',!semana(T.flatMap(t=>[...lunAJue(t),bloque(t,{ventas_ly:null})])).completa);

const faltaMie=completa.filter(r=>!(r.tienda==='T91'&&r.fecha==='2026-10-28'));
s=semana(faltaMie);
prueba('día ausente: falta el miércoles en T91',!s.completa&&s.tiendas[0].faltan.join()==='2026-10-28'&&s.tiendas[0].motivos[0].estado==='ausente',JSON.stringify(s.tiendas[0]));
prueba('día ausente: aviso, recuadro y Visitas coinciden',coinciden(faltaMie));
prueba('una venta vacía es un dato ausente, no un cero',ctx._faroEstadoDia([dia('T91','2026-10-28',{ventas:null})],'T91','2026-10-28',HOY).estado==='ausente');

const cero=completa.map(r=>r.tienda==='T91'&&r.fecha==='2026-10-27'?{...r,ventas:0,tickets:0}:r);
prueba('venta cero válida: cuenta como día completo',semana(cero).completa&&ctx._faroEstadoDia(cero,'T91','2026-10-27',HOY).estado==='completo');

const festivo=completa.map(r=>r.fecha==='2026-10-27'?{...r,ventas_ly:null,comparabilidad:'ly_cerrado'}:r);
prueba('festivo el año pasado marcado: sin comparable pero completo y avisado',semana(festivo).completa&&ctx._faroEstadoDia(festivo,'T91','2026-10-27',HOY).estado==='marcado');
const festivoSinMarca=completa.map(r=>r.fecha==='2026-10-27'?{...r,ventas_ly:null}:r);
prueba('sin la marca expresa, ese mismo día no vale',!semana(festivoSinMarca).completa);

const cerrada=completa.map(r=>r.tienda==='T92'&&r.fecha==='2026-10-29'?{...r,ventas:0,tickets:0,comparabilidad:'cy_cerrado'}:r);
prueba('tienda cerrada marcada: completo',semana(cerrada).completa&&ctx._faroEstadoDia(cerrada,'T92','2026-10-29',HOY).estado==='cerrado');
const cerradaSinVenta=completa.map(r=>r.tienda==='T92'&&r.fecha==='2026-10-29'?{...r,ventas:null,ventas_ly:null,comparabilidad:'cy_cerrado'}:r);
prueba('tienda cerrada marcada aunque la venta venga vacía: completo',semana(cerradaSinVenta).completa);

const soloMes=[...T.flatMap(t=>[...lunAJue(t),dia(t,'2026-10-30')]),...T.map(t=>mes(t,'2026-10-31'))];
s=semana(soloMes); a=aviso(soloMes);
prueba('acumulado sin fichero diario: el sábado falta',!s.completa&&s.tiendas.every(x=>x.motivos.some(m=>m.fecha==='2026-10-31'&&m.estado==='solo_acumulado')),JSON.stringify(s.tiendas[0]));
prueba('acumulado sin fichero diario: el aviso lo dice',!a.ok&&/solo está el acumulado del mes/.test(ctx._faroDiaEsperadoTexto(a)),ctx._faroDiaEsperadoTexto(a));
prueba('acumulado sin fichero diario: aviso, recuadro y Visitas coinciden',coinciden(soloMes));

const sinSab=T.flatMap(t=>[...lunAJue(t),dia(t,'2026-10-30')]);
prueba('carga tardía: antes de subir el sábado, falta',!semana(sinSab).completa&&!aviso(sinSab).ok);
const tarde=[...sinSab,...T.map(t=>dia(t,'2026-10-31',{fuente:'FOLLOWUP_CSV'}))];
prueba('carga tardía: al subirlo, aunque sea de otro fichero, ya cuenta',semana(tarde).completa&&aviso(tarde).ok);
prueba('carga tardía: aviso, recuadro y Visitas coinciden antes y después',coinciden(sinSab)&&coinciden(tarde));
prueba('un día que aún no ha terminado no se pide',ctx._faroEstadoDia([], 'T91','2026-11-02','2026-11-02').estado==='pendiente'
 &&!ctx._faroSemanaCompleta([],T,'2026-11-02','2026-11-03').tiendas[0].terminada);
prueba('el lunes se espera el sábado, no el domingo',ctx._faroUltimoDiaEsperado('2026-11-02')==='2026-10-31');

console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
