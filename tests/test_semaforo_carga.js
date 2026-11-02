// Semáforo de carga (02/11/2026): semana cerrada completa y Club del mes anterior. Datos inventados.
// Uso: node tests/test_semaforo_carga.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 if(/;\s*$/.test(lines[i])&&!/[{(\[]\s*$/.test(lines[i]))return lines[i];let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,Intl,RegExp,Error,JSON};vm.createContext(ctx);
vm.runInContext(['const IVA_SEGUIMIENTO=1.20;','function _esComparable(c){ return !c||c===\'normal\'; }',
 ...['let psFactorIvaMemo','function _dateISO(','function _esFuenteVenta(','function _esBloque(','function _fechasDeFila(','function psFactorIva(','function psVentaSemanaConIva(','function _isoWeek(',
 'function _visSumaDias(','function _visLunes(','function _visPct(','function _visFechaES(','function _visSemanaTienda(',
 'function _faroUltimaSemanaCerrada(','function _faroSemanaCompleta(','function _faroSemanaCompletaTexto(','function _faroClubMesAnterior('].map(trozo)].join('\n'),ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}

const sum=(f,n)=>{const d=new Date(f+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
const semana=(t,lunes,quitar=[])=>[0,1,2,3,4,5].map(i=>sum(lunes,i)).filter(f=>!quitar.includes(f))
 .map(fecha=>({tienda:t,fecha,fuente:'FOLLOWUP_CSV',tipo_periodo:'dia',ventas:1000,ventas_ly:950,tickets:50,tickets_ly:48,upt:2.5,upt_ly:2.4,comparabilidad:'normal'}));
const T=['T91','T92','T93'];
const L='2026-10-26';

prueba('última semana cerrada: en domingo es la que acaba de terminar',ctx._faroUltimaSemanaCerrada('2026-11-01')==='2026-10-26');
prueba('última semana cerrada: el lunes, la anterior',ctx._faroUltimaSemanaCerrada('2026-11-02')==='2026-10-26');
prueba('última semana cerrada: el sábado aún no ha terminado',ctx._faroUltimaSemanaCerrada('2026-10-31')==='2026-10-19');

const llena=T.flatMap(t=>semana(t,L));
const r1=ctx._faroSemanaCompleta(llena,T,L,'2026-11-02');
prueba('semana completa',r1.completa&&ctx._faroSemanaCompletaTexto(r1)==='Semana 44 (26/10–31/10): completa en todas las tiendas',ctx._faroSemanaCompletaTexto(r1));

const sinFinde=T.flatMap(t=>semana(t,L,['2026-10-30','2026-10-31']));
const r2=ctx._faroSemanaCompleta(sinFinde,T,L,'2026-11-02');
prueba('faltan viernes y sábado en todas',!r2.completa&&ctx._faroSemanaCompletaTexto(r2)==='Semana 44 (26/10–31/10): faltan vie 30, sáb 31 en todas las tiendas',ctx._faroSemanaCompletaTexto(r2));

const mezcla=[...semana('T91',L),...semana('T92',L,['2026-10-31']),...semana('T93',L,['2026-10-31'])];
const r3=ctx._faroSemanaCompleta(mezcla,T,L,'2026-11-02');
prueba('falta un día en algunas tiendas: las nombra',ctx._faroSemanaCompletaTexto(r3)==='Semana 44 (26/10–31/10): faltan sáb 31 en T92, T93',ctx._faroSemanaCompletaTexto(r3));

const bloque=[...T.flatMap(t=>semana(t,L,['2026-10-30','2026-10-31'])),
 ...T.map(t=>({tienda:t,fecha:'2026-10-30',fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'viernes_sabado',ventas:2400,ventas_ly:2300,tickets:110,tickets_ly:100,comparabilidad:'normal'}))];
prueba('bloque viernes + sábado: completa',ctx._faroSemanaCompleta(bloque,T,L,'2026-11-02').completa);
prueba('semana sin terminar: nunca completa',!ctx._faroSemanaCompleta(llena,T,L,'2026-10-31').completa);
prueba('sin tiendas: no se da por completa',!ctx._faroSemanaCompleta(llena,[],L,'2026-11-02').completa);

const fid=[{tienda:'T91',mes:'2026-10-01',ventas:10000},{tienda:'T92',mes:'2026-10-01',ventas:0},{tienda:'T93',mes:'2026-09-01',ventas:9000}];
const c=ctx._faroClubMesAnterior(fid,T,'2026-11-02');
prueba('Club del mes anterior: cuenta solo las tiendas con venta de ese mes',c.mes==='2026-10'&&c.con===1&&c.total===3,JSON.stringify(c));
prueba('Club en enero mira diciembre del año anterior',ctx._faroClubMesAnterior([],T,'2027-01-15').mes==='2026-12');

console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
