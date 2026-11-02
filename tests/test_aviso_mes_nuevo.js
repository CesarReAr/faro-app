// Aviso de mes nuevo sin datos en Mi Área (02/11/2026). Datos inventados.
// Uso: node tests/test_aviso_mes_nuevo.js
const fs=require('fs');const vm=require('vm');const path=require('path');
const src=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8').replace(/\r\n/g,'\n'))[1];
function trozo(cab){const lines=src.split('\n');const i=lines.findIndex(l=>l.startsWith(cab));if(i<0)throw new Error('falta '+cab);let j=i+1;while(j<lines.length&&!/^}\s*$/.test(lines[j]))j++;return lines.slice(i,j+1).join('\n');}
const ctx={String,Number};vm.createContext(ctx);
vm.runInContext(trozo('function _faroAvisoMesNuevo('),ctx);
let ok=0,total=0;function prueba(n,c,x){total++;if(c){ok++;console.log('  OK  ',n);}else console.log('  FALLA',n,'\n'+(x||''));}
const A=ctx._faroAvisoMesNuevo;
prueba('mes nuevo sin datos y el anterior cerrado',A('2026-11-02','2026-10-31',true)==='Octubre cerrado · noviembre todavía sin datos: se ve el último día cargado, el 31/10. Las fichas pasarán solas a noviembre cuando se suba el primer día.',A('2026-11-02','2026-10-31',true));
prueba('mes nuevo sin datos y el anterior sin cerrar',/^noviembre todavía sin datos/.test(A('2026-11-02','2026-10-31',false)));
prueba('con datos del mes actual no hay aviso',A('2026-11-03','2026-11-02',true)==='');
prueba('cambio de año',/^Diciembre cerrado · enero todavía sin datos: se ve el último día cargado, el 31\/12/.test(A('2027-01-02','2026-12-31',true)));
prueba('sin datos o sin fecha no hay aviso',A('2026-11-02',null,true)===''&&A(null,'2026-10-31',true)==='');
console.log(`\n${ok}/${total} pruebas correctas`);
process.exit(ok===total?0:1);
