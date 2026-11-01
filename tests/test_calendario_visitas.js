// Visitas: propuesta semanal y calendario (01/11/2026). Todo inventado: tiendas T91 a T96.
// Uso: node tests/test_calendario_visitas.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const HTML=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(HTML)[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);
 if(/;\s*$/.test(lines[i])&&!/[{(\[]\s*$/.test(lines[i]))return lines[i];let j=i+1;while(j<lines.length&&!/^[}\]]\)?\(?\)?;?\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={console,Map,Set,Number,Math,String,Date,Object,Array,Intl,RegExp,Error,JSON};vm.createContext(ctx);
const piezas=['let psFactorIvaMemo','function _dateISO(','function _esFuenteVenta(','function _esBloque(','function _fechasDeFila(','function psFactorIva(','function psVentaSemanaConIva(',
 'const VIS_REGLAS_DEFECTO','const VIS_PRIORIDADES','const VIS_ETIQUETA','const VIS_ESTADOS','const VIS_TEXTO_PROHIBIDO',
 'function _visSumaDias(','function _visLunes(','function _visPct(','function _visFmtPct(','function _visFmtNum(','function _visFechaES(','function _visReglas(','function _visTextoPermitido(',
 'function _visSemanaTienda(','function _visClub(','function _visObjetivoEur(','function _visEvaluaTienda(','function _visPropuesta(',
 'function _visEditable(','function _visCambia(','function _visMotivoObligatorio(','function visConfirmar(','function visCambiarFecha(','function visAplazar(','function visDescartar(',
 'function visRealizada(','function visObjetivo(','function visAnadirManual(','function visRevisar(','function _visRegenera(','function _visResumenMes(','function _visAnalisis('];
vm.runInContext(['const IVA_SEGUIMIENTO=1.20;','function _esComparable(c){ return !c||c===\'normal\'; }',...piezas.map(trozo)].join('\n')+'\nthis.VIS_TEXTO_PROHIBIDO=VIS_TEXTO_PROHIBIDO;this.VIS_REGLAS_DEFECTO=VIS_REGLAS_DEFECTO;',ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}
const lanza=(f,re)=>{try{f();return false;}catch(e){return re?re.test(e.message):true;}};

// ── Datos ficticios ─────────────────────────────────────────
// Semana analizada: lunes 19/10/2026; las tres anteriores empiezan el 28/09, 05/10 y 12/10.
const LUNES=['2026-09-28','2026-10-05','2026-10-12','2026-10-19'];
const HOY='2026-11-01';
const sum=(f,n)=>{const d=new Date(f+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
// g: % de venta frente al año pasado por semana; gt: % de tickets; upt/uptLy de la última semana.
function tienda(id,g,gt,{upt=[2.5,2.5],tm=null,quitar=[]}={}){
 const filas=[];
 LUNES.forEach((l,k)=>{ for(let i=0;i<6;i++){ const fecha=sum(l,i); if(quitar.includes(fecha)) continue;
  const tk=100, tkCy=Math.round(tk*(1+gt[k]/100));
  const ventaLy=2000, venta=Math.round(ventaLy*(1+g[k]/100)*(tm&&k===3?tm:1)*100)/100;
  filas.push({tienda:id,fecha,fuente:'FOLLOWUP_CSV',tipo_periodo:'dia',ventas:venta,ventas_ly:ventaLy,tickets:tkCy,tickets_ly:tk,
   upt:k===3?upt[0]:2.5,upt_ly:k===3?upt[1]:2.5,comparabilidad:'normal'}); } });
 return filas;
}
const AREA=[{id:'T91',name:'Plaza Inventada'},{id:'T92',name:'Paseo Imaginario'},{id:'T93',name:'Calle Ficticia'},{id:'T94',name:'Mercado Supuesto'},{id:'T95',name:'Avenida Ejemplo'}];
const FILAS=[
 ...tienda('T91',[-5,-8,-4,-6],[-2,-2,-1,-2]),           // varias semanas negativas
 ...tienda('T92',[5,6,4,5],[2,2,2,2]),                   // venta positiva, Club bajo
 ...tienda('T93',[3,2,4,1],[1,0,-1,-8]),                 // caída de tickets
 ...tienda('T94',[-5,-6,-3,4],[0,0,0,1]),                // mejora reciente
 ...tienda('T95',[6,7,5,6],[3,3,2,3]),                   // estable y buena
 ...tienda('T40',[-30,-30,-30,-30],[-20,-20,-20,-20])     // fuera del área: no debe aparecer
];
const FID=['T91','T92','T93','T94','T95'].map(t=>({tienda:t,mes:'2026-09-01',ventas:10000,ventas_identificadas:t==='T92'?4500:7000}));
const PERMISO={editar:true}, LECTURA={editar:false};
const A=ctx._visAnalisis({filas:FILAS,tiendas:AREA,lunes:'2026-10-19',hoy:HOY,filasFid:FID,filasObj:[],ahora:'2026-11-02T08:00:00Z'});
const ev=id=>A.evaluaciones.find(e=>e.tienda===id);
for(const e of A.evaluaciones) console.log('   ',e.tienda,e.prioridad,'·',e.motivo);

// ── Semana completa / incompleta ────────────────────────────
prueba('semana completa: todas las tiendas de lunes a sábado',A.completa&&A.propuesta.definitiva&&A.estado.every(e=>!e.faltan.length));
const inc=ctx._visAnalisis({filas:[...FILAS.filter(r=>!(r.tienda==='T91'&&r.fecha==='2026-10-24'))],tiendas:AREA,lunes:'2026-10-19',hoy:HOY,filasFid:FID});
prueba('semana incompleta: detecta el día que falta y la propuesta es provisional',!inc.completa&&!inc.propuesta.definitiva&&inc.estado.find(e=>e.tienda==='T91').faltan.join()==='2026-10-24');
const curso=ctx._visAnalisis({filas:FILAS,tiendas:AREA,lunes:'2026-10-19',hoy:'2026-10-22',filasFid:FID});
prueba('semana sin terminar: nunca es completa',!curso.completa&&curso.estado.every(e=>!e.terminada));
const bloque=FILAS.filter(r=>!(r.tienda==='T95'&&(r.fecha==='2026-10-23'||r.fecha==='2026-10-24')))
 .concat([{tienda:'T95',fecha:'2026-10-23',fuente:'SEGUIMIENTO_DIARIO',tipo_periodo:'viernes_sabado',ventas:3500,ventas_ly:3300,tickets:200,tickets_ly:190,comparabilidad:'normal'}]);
prueba('bloque viernes + sábado cubre los dos días',ctx._visAnalisis({filas:bloque,tiendas:AREA,lunes:'2026-10-19',hoy:HOY,filasFid:FID}).completa);
const editaProvisional=lanza(()=>ctx.visConfirmar(inc.propuesta,inc.propuesta.visitas[0].id,PERMISO,'x'),/provisional/);
prueba('propuesta provisional: no se puede editar',editaProvisional);

// ── Prioridades y motivos ───────────────────────────────────
prueba('varias semanas negativas: alta',ev('T91').prioridad==='alta'&&/4 semanas seguidas/.test(ev('T91').motivo),ev('T91').motivo);
prueba('venta positiva con Club bajo: media',ev('T92').prioridad==='media'&&/Club en 45,0 %/.test(ev('T92').motivo),ev('T92').motivo);
prueba('caída de tickets con la venta en positivo: media',ev('T93').prioridad==='media'&&/tickets en descenso \(−8,0 % frente al año pasado\) con la venta en positivo/.test(ev('T93').motivo),ev('T93').motivo);
const tkAlta=ctx._visEvaluaTienda({tienda:'T93',semanas:[-19,-2,-17,1].map((x,i)=>({lunes:'2026-10-0'+(i+1),vsVenta:x,venta:9000,ventaLY:8900,vsTickets:i===3?-12:-3,ticketMedio:20,ticketMedioLY:20,upt:2.5,uptLY:2.5}))},{});
prueba('caída de tickets con semanas negativas: alta',tkAlta.prioridad==='alta'&&/tickets en descenso \(−12,0 % frente al año pasado\) y venta por debajo del periodo comparable en 3 de las 4 últimas semanas/.test(tkAlta.motivo),tkAlta.motivo);
prueba('mejora reciente: seguimiento',ev('T94').prioridad==='seguimiento'&&/mejora reciente: venta \+4,0 % la última semana después de 3 semanas/.test(ev('T94').motivo),ev('T94').motivo);
prueba('tienda estable: mantenimiento',ev('T95').prioridad==='mantenimiento'&&/resultados buenos y estables/.test(ev('T95').motivo),ev('T95').motivo);
prueba('alta con Club bien: lo dice',/Se mantiene: Club en 70,0 %/.test(ev('T91').motivo),ev('T91').motivo);
prueba('cada motivo explica su prioridad con cifras',A.evaluaciones.every(e=>e.motivo.startsWith('Tienda recomendada con prioridad '+e.prioridad+':')&&/\d/.test(e.motivo)),A.evaluaciones.map(e=>e.motivo).join('\n'));
prueba('los datos que justifican van con la recomendación',ev('T91').datos.vsVenta.length===4&&ev('T93').datos.vsTickets<-7);
const obj=ctx._visEvaluaTienda({tienda:'T95',semanas:[{lunes:'2026-10-19',vsVenta:2,venta:9000,ventaLY:8800,vsTickets:1,ticketMedio:20,ticketMedioLY:20,upt:2.5,uptLY:2.5}],objetivoEur:10000},{});
prueba('resultado claramente inferior al objetivo: alta',obj.prioridad==='alta'&&/venta −10,0 % frente al objetivo de la semana \(9\.000 € de 10\.000 €\)/.test(obj.motivo),obj.motivo);
const tm=ctx._visEvaluaTienda({tienda:'T92',semanas:[{lunes:'2026-10-19',vsVenta:3,venta:9000,ventaLY:8700,vsTickets:2,ticketMedio:18,ticketMedioLY:19.5,upt:2.5,uptLY:2.5}],club:{pct:70,mes:'2026-09'}},{});
prueba('ticket medio en descenso con venta positiva: media',tm.prioridad==='media'&&/ticket medio −7,7 %/.test(tm.motivo),tm.motivo);
prueba('reglas configurables: con Club mínimo 40 la T92 deja de ser media',ctx._visAnalisis({filas:FILAS,tiendas:AREA,lunes:'2026-10-19',hoy:HOY,filasFid:FID,reglas:{clubMinimo:40}}).evaluaciones.find(e=>e.tienda==='T92').prioridad==='mantenimiento');
prueba('reglas: valores no numéricos se ignoran',ctx._visReglas({clubMinimo:'abc',noExiste:5}).clubMinimo===60&&!('noExiste' in ctx._visReglas({noExiste:5})));

// ── Datos ausentes y acceso ─────────────────────────────────
const sin=ctx._visAnalisis({filas:FILAS,tiendas:[...AREA,{id:'T96',name:'Sin Datos'}],lunes:'2026-10-19',hoy:HOY,filasFid:FID});
prueba('tienda sin datos: sin prioridad, no se propone y la semana queda incompleta',sin.evaluaciones.find(e=>e.tienda==='T96').prioridad==='sin_datos'&&sin.propuesta.sinDatos.includes('T96')&&!sin.propuesta.visitas.some(v=>v.tienda==='T96')&&!sin.completa);
prueba('sin Club: no inventa un Club bajo',ctx._visAnalisis({filas:FILAS,tiendas:AREA,lunes:'2026-10-19',hoy:HOY,filasFid:[]}).evaluaciones.find(e=>e.tienda==='T92').prioridad==='mantenimiento');
prueba('solo tiendas del área: T40 no se evalúa ni se propone',!A.evaluaciones.some(e=>e.tienda==='T40')&&!A.propuesta.visitas.some(v=>v.tienda==='T40'));

// ── Propuesta y calendario ──────────────────────────────────
const P=A.propuesta;
prueba('propuesta para la semana siguiente, lunes a viernes',P.semanaPropuesta==='2026-10-26'&&P.dias.join()==='2026-10-26,2026-10-27,2026-10-28,2026-10-29,2026-10-30');
prueba('una visita por día, alta primero',P.visitas[0].prioridad==='alta'&&P.visitas[0].tienda==='T91'&&new Set(P.visitas.map(v=>v.fecha)).size===5,JSON.stringify(P.visitas.map(v=>[v.tienda,v.prioridad,v.fecha])));
prueba('la propuesta conserva semana, fecha de generación, versión y revisión',P.semanaAnalizada==='2026-10-19'&&P.generada==='2026-11-02T08:00:00Z'&&P.version===1&&P.revisadaPor===null);
const pocos=ctx._visPropuesta(A.evaluaciones,'2026-10-19',true,{diasCalendario:3});
prueba('no se visitan todas: las que no caben quedan sin fecha',pocos.visitas.filter(v=>v.fecha).length===3&&pocos.visitas.filter(v=>!v.fecha).length===2);
const id91=P.visitas.find(v=>v.tienda==='T91').id, id95=P.visitas.find(v=>v.tienda==='T95').id;
let c=ctx.visConfirmar(P,id91,PERMISO,'Coordinación','2026-11-02T09:00:00Z');
prueba('confirmar',c.visitas.find(v=>v.id===id91).estado==='confirmada'&&P.visitas.find(v=>v.id===id91).estado==='propuesta');
prueba('cambiar fecha pide motivo',lanza(()=>ctx.visCambiarFecha(c,id95,'2026-10-26','',PERMISO),/motivo/));
c=ctx.visCambiarFecha(c,id95,'2026-10-26','Coincide con la reposición de campaña',PERMISO,'Coordinación');
prueba('dos tiendas el mismo día',c.visitas.filter(v=>v.fecha==='2026-10-26').length===2);
const h=c.visitas.find(v=>v.id===id95).historial.at(-1);
prueba('el cambio guarda motivo, fecha anterior y nueva',h.motivo==='Coincide con la reposición de campaña'&&h.de.fecha==='2026-10-30'&&h.a.fecha==='2026-10-26',JSON.stringify(h));
prueba('domingo no',lanza(()=>ctx.visCambiarFecha(c,id95,'2026-11-01','x',PERMISO),/domingo/));
prueba('aplazar y descartar piden motivo',lanza(()=>ctx.visAplazar(c,id91,'  ',PERMISO),/motivo/)&&lanza(()=>ctx.visDescartar(c,id91,'',PERMISO),/motivo/));
const ap=ctx.visAplazar(c,id91,'Campaña en curso, mejor la semana siguiente',PERMISO);
prueba('aplazar deja la visita sin fecha y con su motivo',ap.visitas.find(v=>v.id===id91).fecha===null&&ap.visitas.find(v=>v.id===id91).estado==='aplazada');
const de=ctx.visDescartar(c,id95,'Visitada la semana pasada',PERMISO);
prueba('descartar',de.visitas.find(v=>v.id===id95).estado==='descartada'&&de.visitas.find(v=>v.id===id95).motivoCambio==='Visitada la semana pasada');
c=ctx.visObjetivo(c,id91,'Revisar el lineal de entrada y la propuesta de segundo producto',PERMISO);
prueba('objetivo de la visita',c.visitas.find(v=>v.id===id91).objetivo.startsWith('Revisar el lineal'));
prueba('realizada pide resultado',lanza(()=>ctx.visRealizada(c,id91,'',null,PERMISO),/resultado/));
c=ctx.visRealizada(c,id91,'Lineal recolocado; segundo producto en el briefing',' 2026-11-16'.trim(),PERMISO);
prueba('realizada con resultado y próximo seguimiento',c.visitas.find(v=>v.id===id91).estado==='realizada'&&c.visitas.find(v=>v.id===id91).proximoSeguimiento==='2026-11-16');
c=ctx.visAnadirManual(c,'T94','Mercado Supuesto','2026-10-28','Lanzamiento de campaña',PERMISO,AREA.map(t=>t.id),'Coordinación');
prueba('añadir una tienda a mano',c.visitas.some(v=>v.manual&&v.tienda==='T94'&&v.fecha==='2026-10-28'));
prueba('no se puede añadir una tienda de fuera del área',lanza(()=>ctx.visAnadirManual(c,'T40','x','2026-10-28','x',PERMISO,AREA.map(t=>t.id)),/de tu área/));
prueba('solo consulta: Dirección no cambia el calendario',lanza(()=>ctx.visConfirmar(P,id91,LECTURA),/no cambiarlo/)&&lanza(()=>ctx.visAnadirManual(P,'T94','x',null,'x',LECTURA,['T94']),/no cambiarlo/));
const rev=ctx.visRevisar(c,PERMISO,'Coordinación','2026-11-02T10:00:00Z');
prueba('revisión: quién y cuándo',rev.revisadaPor==='Coordinación'&&rev.revisadaEn==='2026-11-02T10:00:00Z');
const v2=ctx._visRegenera(rev,ctx._visPropuesta(A.evaluaciones,'2026-10-19',true,{}));
prueba('nueva versión: conserva decisiones y añadidos, pide revisar otra vez',v2.version===2&&v2.visitas.find(v=>v.id===id91).estado==='realizada'&&v2.visitas.some(v=>v.manual)&&v2.revisadaPor===null);

// ── Datos personales ────────────────────────────────────────
prueba('textos con datos laborales o de contacto: rechazados',['Hablar de la baja','Revisar horarios','Vacaciones de la encargada','Ampliación de contrato','llamar al 612 345 678','escribir a x@ejemplo.com']
 .every(t=>lanza(()=>ctx.visObjetivo(P,id91,t,PERMISO),/datos personales ni laborales/)));
const todo=A.evaluaciones.map(e=>e.motivo).join(' ');
prueba('los motivos no llevan datos laborales ni comparaciones negativas',!ctx.VIS_TEXTO_PROHIBIDO.test(todo.normalize('NFD').replace(/[̀-ͯ]/g,''))&&!/la peor|el peor|más baja|mas baja|la última del/i.test(todo),todo);
prueba('no afirma que una visita cause una mejora',!/gracias a la visita|por la visita/i.test(todo));
const usaPersonas=piezas.map(trozo).join('\n');
prueba('el cálculo no lee campos de personas',!/coordinator_name|observaciones|user_id|nombre_empleado|email/.test(usaPersonas.replace(/\/\/.*$/gm,'')));

// ── Cierre mensual ──────────────────────────────────────────
const cal2=ctx.visConfirmar(ctx._visPropuesta(A.evaluaciones,'2026-10-26',true,{}),'v_T93_2026-11-02',PERMISO);
const R=ctx._visResumenMes([c,cal2],'2026-10',AREA.map(t=>t.id));
// La T94 añadida a mano nace confirmada.
prueba('resumen del mes: cuenta estados',R.propuestas===6&&R.realizadas===1&&R.confirmadas===1,JSON.stringify(R));
prueba('resumen: tiendas no visitadas y acciones abiertas',R.noVisitadas.length===4&&!R.noVisitadas.includes('T91')&&R.accionesAbiertas.some(x=>x.tienda==='T91'&&x.proximoSeguimiento==='2026-11-16'),JSON.stringify(R));
prueba('resumen: seguimiento del mes siguiente por próximo seguimiento',R.seguimientoSiguienteMes.includes('T91'),JSON.stringify(R.seguimientoSiguienteMes));
const Rap=ctx._visResumenMes([ap],'2026-10',AREA.map(t=>t.id));
prueba('resumen: una alta aplazada pasa al mes siguiente',Rap.aplazadas===1&&Rap.seguimientoSiguienteMes.includes('T91'),JSON.stringify(Rap));
const R11=ctx._visResumenMes([c,cal2],'2026-11',AREA.map(t=>t.id));
prueba('la semana del 02/11 cuenta en noviembre',R11.propuestas===5&&R11.confirmadas===1,JSON.stringify(R11));

console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
