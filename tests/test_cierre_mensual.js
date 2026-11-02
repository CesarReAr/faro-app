// Cierre del mes en Mi Área (02/11/2026). Solo datos ficticios: tiendas T91 y T92.
// Uso: node tests/test_cierre_mensual.js [--muestra]   (--muestra enseña el rapport, una ficha y el paquete)
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 // Una línea con las llaves equilibradas (const, let o función de una línea) es la pieza entera.
 const l=lines[i];if((l.match(/{/g)||[]).length===(l.match(/}/g)||[]).length&&/[;}]\s*$/.test(l))return l;let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,RegExp,Error,JSON,TextEncoder,Uint8Array,crypto:globalThis.crypto};vm.createContext(ctx);
vm.runInContext([...['const FARO_COMPARABILIDAD','const _ORDEN_COMPARABILIDAD','function _comparabilidadValor(','function _esComparable(','function _comparabilidadDeFilas(',
 'function _dateISO(','function _isoWeek(','function _esFuenteMes(','function _esBloque(','function _fechasDeFila(','function _visSumaDias(','function _visLunes(','const VIS_TEXTO_PROHIBIDO','function _visResumenMes(',
 'const FARO_FUENTES_DIA','function _faroDiaValor(','function _faroEstadoDia(',
 'const CMES_AVISO_LOCAL','const CMES_AVISO_VISITAS','const CMES_ESTADOS','const CMES_CLUB_OBJETIVO','const CMES_RESPONSABLE','const CMES_OBLIGATORIOS','const CMES_FUENTES',
 'function _cmesNum(','function _cmesN(','function _cmesEur(','function _cmesEur2(','function _cmesPct(','function _cmesPct0(','function _cmesFecha(','function _cmesNombreMes(','function _cmesUltimoDia(','function _cmesMesSiguiente(',
 'function _cmesDiasComerciales(','function _cmesLunesDelMes(','const CMES_PLAZO_LABORABLES','function _cmesLaborable(','function _cmesPlazoCarga(','function _cmesTarde(','function _cmesFestivos(','function cmesDatosMes(',
 'const CMES_NOMBRE_CORTO','function _cmesY(','function cmesResumenTienda(','function _cmesTramoParcial(','function _cmesRango(','function _cmesEtiquetaTramo(','function cmesTextoObjetivo(','function _dirPalancasAgregar(','function cmesResultados(','function cmesVisitas(','const CMES_AVISO_VISITAS_CLAVE','function cmesAvisos(','function cmesSeccionAvisos(','function cmesRapportFinal(','function cmesDatosPersonales(',
 'function cmesRapport(','function cmesFicha(','function cmesPuedeCerrar(','function _cmesCanon(','function cmesPaquete(','async function cmesHuella(','async function cmesVerificar('].map(trozo)].join('\n'),ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}
const MUESTRA=process.argv.includes('--muestra');

// Mes ficticio: septiembre de 2026 (1 a 30), revisado el 02/10. T91 y T92, KPIS diario completo.
const MES='2026-09', HOY='2026-10-02', T=['T91','T92'];
const dias=ctx._cmesDiasComerciales(MES,HOY);
const fila=(t,f,extra)=>({tienda:t,fecha:f,fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'dia',ventas:1000,ventas_ly:950,tickets:40,tickets_ly:39,upt:2.1,upt_ly:2.0,comparabilidad:'normal',created_at:f+'T20:00:00',...extra});
const filasOk=T.flatMap(t=>dias.map(f=>fila(t,f)));
const lunes=ctx._cmesLunesDelMes(MES);
const base={mes:MES,hoy:HOY,tiendas:T,filas:filasOk,objetivos:{T91:26000,T92:24000},club:{T91:62,T92:55},mv:{T91:4.5,T92:-2.1},division:{T91:true,T92:true},
 focos:T.flatMap(t=>lunes.map(l=>({tienda:t,semana_inicio:l})))};
const item=(p,t,k)=>p.tiendas.find(x=>x.tienda===t).items.find(i=>i.clave===k);
const cambia=(t,f,extra)=>filasOk.map(r=>r.tienda===t&&r.fecha===f?{...r,...extra}:r);

let p1=ctx.cmesDatosMes(base);
prueba('mes completo: 26 días comerciales de lunes a sábado',dias.length===26&&!dias.some(f=>new Date(f+'T12:00:00Z').getUTCDay()===0));
prueba('mes completo: todo en verde y estado completo',p1.estado==='completo'&&!p1.rojos.length&&!p1.amarillos.length,JSON.stringify(p1.amarillos));

p1=ctx.cmesDatosMes({...base,filas:filasOk.filter(r=>!(r.tienda==='T92'&&r.fecha==='2026-09-16'))});
prueba('mes incompleto: un día sin dato es rojo y bloquea',p1.estado==='bloqueado'&&item(p1,'T92','venta').color==='rojo'&&/16\/09/.test(item(p1,'T92','venta').texto));
prueba('semana incompleta: marca esa semana',item(p1,'T92','semanas').color==='rojo'&&/S38/.test(item(p1,'T92','semanas').texto),item(p1,'T92','semanas').texto);

p1=ctx.cmesDatosMes({...base,filas:cambia('T91','2026-09-10',{ventas_ly:null})});
prueba('comparable ausente: rojo en comparable',item(p1,'T91','comparable').color==='rojo'&&p1.estado==='bloqueado');

p1=ctx.cmesDatosMes({...base,filas:cambia('T91','2026-09-11',{ventas_ly:null,comparabilidad:'ly_cerrado'})});
prueba('festivo marcado: amarillo propio, el comparable queda justificado y no bloquea',item(p1,'T91','festivo').color==='amarillo'&&/11\/09/.test(item(p1,'T91','festivo').texto)
 &&item(p1,'T91','comparable').color==='verde'&&p1.estado==='advertencia');

p1=ctx.cmesDatosMes({...base,filas:cambia('T92','2026-09-12',{ventas:0,tickets:0,upt:null,comparabilidad:'cy_cerrado'})});
prueba('tienda cerrada marcada: amarillo, sin pedir tickets',item(p1,'T92','cerrada').color==='amarillo'&&/12\/09/.test(item(p1,'T92','cerrada').texto)&&item(p1,'T92','tickets').color==='verde'&&p1.estado==='advertencia');
p1=ctx.cmesDatosMes({...base,filas:cambia('T92','2026-09-15',{comparabilidad:'cy_parcial'}).map(r=>r.tienda==='T91'&&r.fecha==='2026-09-17'?{...r,comparabilidad:'incidencia'}:r)});
prueba('apertura parcial e incidencia: amarillos propios',item(p1,'T92','parcial').color==='amarillo'&&item(p1,'T91','incidencia').color==='amarillo'&&p1.estado==='advertencia');

p1=ctx.cmesDatosMes({...base,filas:cambia('T91','2026-09-14',{ventas:0,tickets:0})});
prueba('dato cero real: completo y señalado',item(p1,'T91','venta').color==='verde'&&/venta 0 real: 14\/09/.test(item(p1,'T91','dias').texto)&&p1.estado==='completo');

const acum=[...filasOk.filter(r=>!(r.tienda==='T91'&&r.fecha==='2026-09-30')),{tienda:'T91',fecha:'2026-09-30',fuente:'KPIS_TIENDAS_FARO_MES',tipo_periodo:'mes',ventas:26000,ventas_ly:25000}];
p1=ctx.cmesDatosMes({...base,filas:acum});
prueba('acumulado sin dato diario: rojo «solo acumulado»',item(p1,'T91','venta').color==='rojo'&&/solo acumulado: 30\/09/.test(item(p1,'T91','venta').texto),item(p1,'T91','venta').texto);

p1=ctx.cmesDatosMes({...base,filas:cambia('T92','2026-09-08',{created_at:'2026-09-20T09:00:00'})});
prueba('carga tardía: amarillo, no bloquea',item(p1,'T92','tarde').color==='amarillo'&&/08\/09/.test(item(p1,'T92','tarde').texto)&&p1.estado==='advertencia');

p1=ctx.cmesDatosMes({...base,focos:base.focos.filter(f=>!(f.tienda==='T92'&&f.semana_inicio==='2026-09-21'))});
prueba('FOCO pendiente: rojo con la semana, bloquea',item(p1,'T92','foco').color==='rojo'&&/S39/.test(item(p1,'T92','foco').texto)&&item(p1,'T92','foco').obligatorio&&p1.estado==='bloqueado');
prueba('FOCO pendiente: la tienda dice qué semanas se pueden aceptar',p1.tiendas.find(x=>x.tienda==='T92').focoPendiente.join()==='2026-09-21');
const sinFocoBase={...base,focos:base.focos.filter(f=>!(f.tienda==='T92'&&f.semana_inicio==='2026-09-21'))};
p1=ctx.cmesDatosMes({...sinFocoBase,sinFocoAceptado:{'T92|2026-09-21':true}});
prueba('FOCO no enviado aceptado: deja de bloquear y pasa a aviso',item(p1,'T92','foco').color==='verde'&&item(p1,'T92','foco_no_enviado').color==='amarillo'
 &&/S39/.test(item(p1,'T92','foco_no_enviado').texto)&&p1.estado==='advertencia'&&!p1.rojos.length,JSON.stringify(p1.rojos));
prueba('FOCO no enviado aceptado: resumen visible',/Advertencias: FOCO no enviado/.test(p1.tiendas.find(x=>x.tienda==='T92').resumen),p1.tiendas.find(x=>x.tienda==='T92').resumen);
prueba('aceptar una semana no acepta las demás',ctx.cmesDatosMes({...sinFocoBase,focos:sinFocoBase.focos.filter(f=>!(f.tienda==='T92'&&f.semana_inicio==='2026-09-28')),sinFocoAceptado:{'T92|2026-09-21':true}}).estado==='bloqueado');
p1=ctx.cmesDatosMes({...base,objetivos:{T91:26000}});
prueba('sin objetivo del mes: rojo obligatorio',item(p1,'T92','objetivo').color==='rojo'&&item(p1,'T92','objetivo').obligatorio);
p1=ctx.cmesDatosMes({...base,club:{T91:62}});
prueba('Club pendiente: amarillo, no bloquea',item(p1,'T92','club').color==='amarillo'&&p1.estado==='advertencia');

// Resultados: cifras ya consolidadas (como las da Acum. Mes).
const sem=(d,h,v,l)=>({desde:d,hasta:h,venta:v,ly:l,vs:(v/l-1)*100});
const tiendasRes=[
 {tienda:'T91',venta:26500,ventaLY:24800,vsLY:6.9,tickets:1040,vsTickets:2.0,ticketMedio:25.48,vsTicketMedio:4.8,upt:2.1,vsUpt:5.0,club:62,mv:4.5,division:{venta:24000,ly:22500},
  semanas:[sem('2026-09-01','2026-09-05',5200,5000),sem('2026-09-07','2026-09-12',6300,5900),sem('2026-09-14','2026-09-19',6200,5800),sem('2026-09-21','2026-09-26',6000,5600),sem('2026-09-28','2026-09-30',2800,2500)]},
 {tienda:'T92',venta:22100,ventaLY:23400,vsLY:-5.6,tickets:930,vsTickets:-4.1,ticketMedio:23.76,vsTicketMedio:-1.5,upt:1.9,vsUpt:-2.0,club:55,mv:-2.1,division:null,
  semanas:[sem('2026-09-01','2026-09-05',4500,4700),sem('2026-09-07','2026-09-12',5200,5500),sem('2026-09-14','2026-09-19',5100,5400),sem('2026-09-21','2026-09-26',5000,5300),sem('2026-09-28','2026-09-30',2300,2500)]}];
const p2=ctx.cmesResultados({mes:MES,objetivos:base.objetivos,tiendas:tiendasRes,
 area:{venta:48600,ventaLY:48200,vsLY:0.8,tickets:1970,vsTickets:-1.0,ticketMedio:24.67,vsTicketMedio:1.9,upt:2.0,vsUpt:1.6}});
prueba('resultados: objetivo y cumplimiento del área',p2.area.objetivo===50000&&Math.abs(p2.area.cumplimiento-97.2)<0.01);
prueba('resultados: evolución semanal sumada',p2.semanas.length===5&&p2.semanas[0].venta===9700);
prueba('resultados: T92 requiere seguimiento con motivos en cifras',p2.seguimiento.map(x=>x.tienda).join()==='T92'&&/cumplimiento del objetivo 92,1 %/.test(p2.seguimiento[0].motivos.join()),JSON.stringify(p2.seguimiento));

const cal=[{semanaPropuesta:'2026-09-07',visitas:[
 {tienda:'T92',prioridad:'alta',estado:'realizada',fecha:'2026-09-09',resultado:'Revisar exposición de la campaña.',proximoSeguimiento:'2026-09-25'},
 {tienda:'T91',prioridad:'media',estado:'aplazada'}]},
 {semanaPropuesta:'2026-09-21',visitas:[{tienda:'T92',prioridad:'alta',estado:'realizada',fecha:'2026-09-23',resultado:'Plan de clientes con el equipo.',proximoSeguimiento:'2026-10-14'}]}];
const p3=ctx.cmesVisitas(cal,MES,T,HOY);
prueba('visita local: avisa de que no está compartida ni en Supabase',p3.local&&p3.aviso==='Información local: este calendario todavía no está compartido ni guardado en Supabase');
prueba('visitas: realizadas, abiertas, vencidas y seguimiento',p3.realizadas===2&&p3.aplazadas===1&&p3.vencidas.length===1&&p3.abiertas.length===1&&p3.siguienteMes.includes('T92'));

p1=ctx.cmesDatosMes(base);
const rap=ctx.cmesRapport(MES,p1,p2,p3);
const lineasAuto=rap.texto.split('\n').filter(l=>l.startsWith('- ')&&!/Completar/.test(l));
prueba('rapport: todas las afirmaciones automáticas llevan fuente',lineasAuto.length>15&&lineasAuto.every(l=>/\[F\d\]$/.test(l)),lineasAuto.filter(l=>!/\[F\d\]$/.test(l)).join('\n'));
prueba('rapport: secciones pedidas',['RESUMEN EJECUTIVO','RESULTADO DEL ÁREA','EVOLUCIÓN','CUMPLIMIENTO DE OBJETIVOS','PRINCIPALES KPI','TIENDAS QUE REQUIEREN SEGUIMIENTO','VISITAS REALIZADAS','ACCIONES','RIESGOS','PRIORIDADES DEL MES SIGUIENTE','FUENTES'].every(s=>rap.texto.includes(s)));
prueba('rapport: no atribuye resultados a las visitas',/no atribuye resultados a las visitas/.test(rap.texto)&&!/gracias a la visita|por la visita/i.test(rap.texto));
prueba('rapport: sin expresiones de ranking',!/peor tienda|la más baja|la peor|ranking/i.test(rap.texto));

const f92=ctx.cmesFicha(MES,p2.tiendas.find(x=>x.tienda==='T92'),p3,['Club: llegar al 60 %.'],null,'2026-10-15');
prueba('ficha: solo datos de su tienda',!/T91/.test(f92.texto)&&/T92/.test(f92.texto)&&!/área/i.test(f92.texto));
prueba('ficha: resultado, KPI, compromisos, visitas, acciones y tres objetivos',/RESULTADO DEL MES/.test(f92.texto)&&/KPI QUE NECESITAN MEJORA/.test(f92.texto)&&/Club: llegar al 60 %/.test(f92.texto)
 &&/Plan de clientes/.test(f92.texto)&&f92.objetivos.length===3&&/Responsable: Responsable de tienda/.test(f92.texto)&&/15\/10|2026-10-15/.test(f92.texto),f92.texto);

const fichas=p2.tiendas.map(x=>ctx.cmesFicha(MES,x,p3,[],null));
prueba('ausencia de datos personales en rapport y fichas',!ctx.cmesDatosPersonales(rap.texto).length&&fichas.every(f=>!ctx.cmesDatosPersonales(f.texto).length));
prueba('detecta texto personal o laboral',ctx.cmesDatosPersonales('Ana está de baja y hace 20 horas').join()==='baja,horas');

let v=ctx.cmesPuedeCerrar(ctx.cmesDatosMes({...base,filas:filasOk.filter(r=>r.fecha!=='2026-09-16')}),{texto:rap.texto,aprobado:true},fichas);
prueba('bloqueo del cierre: con rojos no se cierra',!v.ok&&/faltas obligatorias/.test(v.motivos.join()));
v=ctx.cmesPuedeCerrar(p1,{texto:rap.texto,aprobado:false},fichas);
prueba('bloqueo del cierre: sin rapport aprobado no se cierra',!v.ok&&/no está aprobado/.test(v.motivos.join()));
v=ctx.cmesPuedeCerrar(p1,{texto:rap.texto+'\nT92: dos bajas esta semana.',aprobado:true},fichas);
prueba('bloqueo del cierre: con datos personales no se cierra',!v.ok&&/datos personales/.test(v.motivos.join()));
v=ctx.cmesPuedeCerrar(p1,{texto:rap.texto,aprobado:true},fichas,{},p3);
prueba('visitas solo en el navegador: amarillo que pide explicación',!v.ok&&/falta la explicación de: Visitas guardadas únicamente en el navegador/.test(v.motivos.join()),v.motivos.join());
const EXPL={visitas_local:'Piloto: el calendario de visitas aún no se guarda en Supabase.'};
v=ctx.cmesPuedeCerrar(p1,{texto:rap.texto,aprobado:true},fichas,EXPL,p3);
prueba('con todo en orden y las explicaciones puestas se puede cerrar',v.ok,v.motivos.join());
const p1SinFoco=ctx.cmesDatosMes({...sinFocoBase,sinFocoAceptado:{'T92|2026-09-21':true}});
v=ctx.cmesPuedeCerrar(p1SinFoco,{texto:rap.texto,aprobado:true},fichas,EXPL,p3);
prueba('FOCO no enviado aceptado: pide su explicación para cerrar',!v.ok&&/falta la explicación de: FOCO no enviado \(aceptado\)/.test(v.motivos.join()),v.motivos.join());
const EXPL_FOCO={...EXPL,foco_no_enviado:'La tienda no rellenó el FOCO de esa semana en el Drive.'};
prueba('FOCO no enviado aceptado y explicado: se puede cerrar y queda en el rapport',ctx.cmesPuedeCerrar(p1SinFoco,{texto:rap.texto,aprobado:true},fichas,EXPL_FOCO,p3).ok
 &&/FOCO no enviado \(aceptado\) \(T92\): La tienda no rellenó/.test(ctx.cmesRapportFinal(rap.texto,p1SinFoco,p3,EXPL_FOCO)));
const p1Club=ctx.cmesDatosMes({...base,club:{T91:62}});
v=ctx.cmesPuedeCerrar(p1Club,{texto:rap.texto,aprobado:true},fichas,EXPL,p3);
prueba('un amarillo sin explicación impide cerrar',!v.ok&&/falta la explicación de: Club/.test(v.motivos.join()),v.motivos.join());
const EXPL2={...EXPL,club:'El fichero de fidelización de septiembre llega el día 10.'};
prueba('con la explicación, ya se puede cerrar',ctx.cmesPuedeCerrar(p1Club,{texto:rap.texto,aprobado:true},fichas,EXPL2,p3).ok);
prueba('una explicación con datos personales impide cerrar',!ctx.cmesPuedeCerrar(p1Club,{texto:rap.texto,aprobado:true},fichas,{...EXPL2,club:'Ana está de vacaciones'},p3).ok);
const sec=ctx.cmesRapportFinal(rap.texto,p1Club,p3,EXPL2);
prueba('la explicación aparece en el rapport',/ADVERTENCIAS Y EXPLICACIONES/.test(sec)&&/Club \(T92\): El fichero de fidelización de septiembre llega el día 10\. \[F7\]/.test(sec)&&/Visitas guardadas únicamente en el navegador: Piloto/.test(sec),sec.slice(-400));

// ── Correcciones tras la prueba local de octubre ──
// Carga tardía por días laborables. Bloque viernes 25 + sábado 26/09 (fecha del viernes).
const bloqueSep=(creado)=>[{tienda:'T91',fecha:'2026-09-25',fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'bloque',dias_incluidos:2,ventas:3000,ventas_ly:2800,created_at:creado}];
prueba('lunes laborable: el bloque del fin de semana subido el lunes llega a tiempo',!ctx._cmesTarde(bloqueSep('2026-09-28T08:00:00'),'T91','2026-09-26',new Set()));
prueba('lunes laborable: subido el martes ya es tarde',ctx._cmesTarde(bloqueSep('2026-09-29T08:00:00'),'T91','2026-09-26',new Set()));
const bloqueOct=creado=>[{tienda:'T91',fecha:'2026-10-09',fuente:'KPIS_TIENDAS_FARO',tipo_periodo:'bloque',dias_incluidos:2,ventas:3000,ventas_ly:2800,created_at:creado}];
prueba('lunes festivo (12/10) y carga el martes 13: a tiempo',!ctx._cmesTarde(bloqueOct('2026-10-13T08:00:00'),'T91','2026-10-09',new Set(['2026-10-12'])));
prueba('carga realmente tardía (miércoles 14 con el lunes festivo): tarde',ctx._cmesTarde(bloqueOct('2026-10-14T08:00:00'),'T91','2026-10-09',new Set(['2026-10-12'])));
prueba('día suelto: el miércoles subido el jueves, a tiempo; el viernes, tarde',!ctx._cmesTarde([fila('T91','2026-09-16',{created_at:'2026-09-17T08:00:00'})],'T91','2026-09-16',new Set())
 &&ctx._cmesTarde([fila('T91','2026-09-16',{created_at:'2026-09-18T08:00:00'})],'T91','2026-09-16',new Set()));
const conFestivo=filasOk.map(r=>r.fecha==='2026-09-14'?{...r,ventas:0,tickets:0,comparabilidad:'cy_cerrado'}:r);
prueba('festivo del área: el día que todas las tiendas cierran',[...ctx._cmesFestivos(conFestivo,T)].join()==='2026-09-14'&&!ctx._cmesFestivos(cambia('T91','2026-09-14',{comparabilidad:'cy_cerrado'}),T).size);

// Resumen visible por tienda.
const pRes=ctx.cmesDatosMes({...base,objetivos:{T91:26000},club:{T91:62},division:{T91:true},focos:base.focos.filter(f=>!(f.tienda==='T92'&&f.semana_inicio==='2026-09-21'))});
const resT92=pRes.tiendas.find(x=>x.tienda==='T92').resumen, resT91=pRes.tiendas.find(x=>x.tienda==='T91').resumen;
prueba('resumen visible: bloqueado con lo que falta, advertencias y número',resT92==='Bloqueado: falta objetivo y FOCO · Advertencias: Club y División pendientes · 2 errores, 2 advertencias',resT92);
prueba('resumen visible: completo',resT91==='Completo',resT91);

// Objetivo parcial: mismo conjunto de tiendas para objetivo, venta y cumplimiento.
const p2Parcial=ctx.cmesResultados({mes:MES,objetivos:{T91:26000},tiendas:tiendasRes,area:{venta:48600,vsLY:0.8}});
const oP=ctx.cmesTextoObjetivo(p2Parcial.area);
prueba('objetivo parcial: «Objetivo de 1 de 2 tiendas» con la venta de esa tienda',oP.titulo==='Objetivo de 1 de 2 tiendas'&&p2Parcial.area.ventaConObjetivo===26500
 &&Math.abs(p2Parcial.area.cumplimiento-26500/26000*100)<1e-9&&/venta de esa tienda 26\.500 €/.test(oP.linea)&&oP.sinObjetivo==='1 tienda sin objetivo: T92',JSON.stringify(oP));
prueba('objetivo parcial: la venta total del área sigue aparte',p2Parcial.area.venta===48600);
const rapParcial=ctx.cmesRapport(MES,p1,p2Parcial,p3);
prueba('objetivo parcial: el rapport no compara el objetivo parcial con la venta total',/Objetivo de 1 de 2 tiendas: 26\.000 €; venta de esa tienda 26\.500 € · cumplimiento 101,9 %\. 1 tienda sin objetivo: T92\./.test(rapParcial.texto),rapParcial.texto.split('\n').find(l=>/Objetivo/.test(l)));

// Marcas Verdes ponderadas en euros con la función de Dirección.
const mvFilas=[{id:'T91',r:{marcas_verdes_ventas_cy:1000,marcas_verdes_ventas_ly:500,marcas_verdes_pct:100}},{id:'T92',r:{marcas_verdes_ventas_cy:100000,marcas_verdes_ventas_ly:100000,marcas_verdes_pct:0}}];
const mvArea=ctx._dirPalancasAgregar(mvFilas).mv.pct;
prueba('Marcas Verdes: una tienda con +100 % y poco volumen no distorsiona el área',Math.abs(mvArea-(101000/100500-1)*100)<1e-9&&mvArea<1,String(mvArea));
const p2Mv=ctx.cmesResultados({mes:MES,objetivos:base.objetivos,tiendas:tiendasRes.map(x=>({...x,mv:x.tienda==='T91'?100:0})),area:{venta:48600,mv:mvArea}});
prueba('Marcas Verdes: el área usa la ponderada, no la media de porcentajes (50 %)',Math.abs(p2Mv.area.mv-mvArea)<1e-9);

// Semana parcial.
prueba('semana parcial: el tramo 01–05/09 y el 28–30/09 son parciales',p2.semanas[0].parcial&&p2.semanas[4].parcial&&!p2.semanas[1].parcial);
prueba('semana parcial: la tendencia no llama «primera semana» a un periodo parcial',!/la primera,/.test(p2.tendencia)&&/primera semana completa \(07\/09–12\/09\)/.test(p2.tendencia)
 &&/Periodo inicial parcial, del 1 al 5 de septiembre/.test(p2.tendencia)&&/no comparable con una semana completa/.test(p2.tendencia),p2.tendencia);
prueba('semana parcial: el rapport y la ficha nombran el periodo parcial',/Periodo inicial parcial, del 1 al 5 de septiembre/.test(rap.texto)&&/Periodo final parcial, del 28 al 30 de septiembre/.test(f92.texto));

// Botón de cierre.
ctx.psEsc=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
vm.runInContext(trozo('function _cmesBotonCierre('),ctx);
const bNo=ctx._cmesBotonCierre({ok:false,motivos:['el rapport para Gerencia no está aprobado']}), bSi=ctx._cmesBotonCierre({ok:true,motivos:[]});
prueba('botón desactivado: disabled, aria-disabled, cursor y motivo',/ disabled /.test(bNo)&&/aria-disabled="true"/.test(bNo)&&/cursor:not-allowed/.test(bNo)&&/opacity:\.45/.test(bNo)&&/title="No se puede cerrar: el rapport para Gerencia no está aprobado\."/.test(bNo));
prueba('botón activo cuando se puede cerrar',!/disabled /.test(bSi)&&/aria-disabled="false"/.test(bSi)&&!/not-allowed/.test(bSi));

(async()=>{
 const paq=ctx.cmesPaquete({mes:MES,version:1,anterior:null,generado:'2026-10-02T10:00:00.000Z',coordinacion:'Coordinación de prueba',tiendas:T,p1,p2,p3,rapport:{texto:rap.texto,aprobado:true},fichas});
 paq.huella=await ctx.cmesHuella(paq);
 prueba('paquete: aviso de cierre local, rapport, fichas, acciones, objetivos, fuentes, fecha y versión',paq.aviso==='CIERRE LOCAL DE PRUEBA — AÚN NO GUARDADO EN SUPABASE'
  &&paq.rapport.aprobado&&paq.fichas.length===2&&paq.acciones&&paq.objetivosSiguientes.T92.length===3&&paq.fuentes.F1&&paq.generado&&paq.version===1);
 prueba('paquete: huella SHA-256 de 64 caracteres',/^[0-9a-f]{64}$/.test(paq.huella));
 const paqClub=ctx.cmesPaquete({mes:MES,version:1,anterior:null,generado:'2026-10-02T10:00:00.000Z',tiendas:T,p1:p1Club,p2,p3,rapport:{texto:rap.texto,aprobado:true},fichas,explicaciones:EXPL2});
 prueba('la explicación aparece en el paquete (advertencia, lista y rapport)',paqClub.datos.advertencias[0].explicacion===EXPL2.club
  &&paqClub.explicaciones.some(x=>x.clave==='visitas_local'&&x.explicacion===EXPL.visitas_local)&&paqClub.visitas.explicacion===EXPL.visitas_local&&/llega el día 10/.test(paqClub.rapport.texto));
 const json=JSON.parse(JSON.stringify(paq));
 prueba('paquete: descargado y vuelto a leer, la huella coincide',await ctx.cmesVerificar(json));
 json.resultados.tiendas[0].venta=99999;
 prueba('paquete: si cambia una cifra, la huella ya no coincide',!(await ctx.cmesVerificar(json)));
 const v2=ctx.cmesPaquete({mes:MES,version:2,anterior:paq.huella,generado:'2026-10-03T10:00:00.000Z',coordinacion:'Coordinación de prueba',tiendas:T,p1,p2,p3,rapport:{texto:rap.texto,aprobado:true},fichas});
 v2.huella=await ctx.cmesHuella(v2);
 prueba('versión: la v2 enlaza con la huella de la v1 y tiene otra huella',v2.version===2&&v2.cierreAnterior===paq.huella&&v2.huella!==paq.huella);
 prueba('paquete: sin datos personales',!ctx.cmesDatosPersonales(JSON.stringify({rapport:paq.rapport,fichas:paq.fichas,resultados:paq.resultados})).length);
 // Pantalla: se pinta con los seis pasos, sin «undefined» ni «NaN» (documento simulado, datos ficticios).
 const nodos={};
 ctx.document={getElementById:id=>nodos[id]||(nodos[id]={id,innerHTML:'',value:''})};
 ctx.currentUserId='usuario-ficticio';
 ctx.psEsc=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
 vm.runInContext([...['let cmesEstado','const CMES_CLAVE','function _cmesLeer(','function _cmesFichas(','function _cmesBotonCierre(','function _cmesChip(','function _cmesEstados(','function cmesPintar('].map(trozo),
  'this.fijar=e=>{cmesEstado=e;};'].join('\n'),ctx);
 ctx.fijar({mes:MES,hoy:HOY,ids:T,p1,p2,p3,compromisosPrevios:{},rapportAuto:rap,rapport:{texto:rap.texto,aprobado:false},objetivosSig:{},revisadas:{},explicaciones:{},paquete:null});
 ctx.cmesPintar();
 const html=nodos.cmesCuerpo.innerHTML;
 prueba('pantalla: seis pasos con su estado',['Datos del mes','Resultados del área','Visitas y acciones','Rapport para Gerencia','Reuniones con tiendas','Revisar y cerrar'].every(t=>html.includes(t))&&(html.match(/id="cmesChip\d/g)||[]).length===6);
 prueba('pantalla: sin undefined ni NaN',!/undefined|NaN/.test(html),(html.match(/.{60}(undefined|NaN).{20}/)||[''])[0]);
 prueba('pantalla: aviso de cierre local y de visitas locales',html.includes('CIERRE LOCAL DE PRUEBA — AÚN NO GUARDADO EN SUPABASE')&&html.includes('Información local: este calendario todavía no está compartido ni guardado en Supabase'));
 prueba('pantalla: sin rapport aprobado, el botón de cierre está desactivado',/disabled aria-disabled="true" title="No se puede cerrar: [^"]*no está aprobado[^"]*" onclick="cmesConfirmar\(\)"/.test(html)&&html.includes('Bloqueado'));
 ctx.fijar({mes:MES,hoy:HOY,ids:T,p1:ctx.cmesDatosMes(sinFocoBase),p2,p3,compromisosPrevios:{},rapportAuto:rap,rapport:{texto:rap.texto,aprobado:false},objetivosSig:{},revisadas:{},explicaciones:{},paquete:null});
 ctx.cmesPintar();
 prueba('pantalla: botón «Aceptar sin FOCO» con las semanas en la tienda que lo tiene pendiente',/onclick="cmesAceptarSinFoco\('T92',true\)">Aceptar sin FOCO \(S39\)/.test(nodos.cmesCuerpo.innerHTML));
 prueba('pantalla: sin FOCO pendiente no aparece el botón',!/cmesAceptarSinFoco\('T91'/.test(nodos.cmesCuerpo.innerHTML));
 prueba('pantalla: resumen visible junto a cada tienda',html.includes('<b>T91</b> <span')&&/Completo|Advertencias|Bloqueado/.test(html));
 prueba('pantalla: objetivo y venta total en tarjetas separadas',html.includes('Objetivo del área')&&html.includes('>Venta<'));
 if(MUESTRA){
  console.log('\n===== RAPPORT (ficticio) =====\n'+rap.texto);
  console.log('\n===== FICHA T92 (ficticia) =====\n'+f92.texto);
  const corto={...paq,rapport:{texto:paq.rapport.texto.slice(0,120)+'…',aprobado:true},fichas:paq.fichas.map(f=>({...f,texto:f.texto.slice(0,60)+'…'})),resultados:{...paq.resultados,semanas:'[5 semanas]'}};
  console.log('\n===== PAQUETE (ficticio, textos recortados) =====\n'+JSON.stringify(corto,null,1));
 }
 console.log(`\n${ok}/${total} pruebas correctas`);
 process.exit(ok===total?0:1);
})();
