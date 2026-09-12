# Fase puente: lectura de archivos, borrado seguro y días no comparables

Fecha: 11/09/2026 · Estado: aplicado en local, **sin publicar** · SQL `comparabilidad`: **ejecutado por Cesar el 11/09** · SQL `comparabilidad_nota`: **propuesto, sin ejecutar**

## Dónde está FARO

Estructura única desde el 11/09/2026. Ver `C:\Proyectos\FARO\LEEME.md`.

| Qué | Ruta |
|---|---|
| FARO maestro (carpeta) | `C:\Proyectos\FARO\app` |
| index.html maestro | `C:\Proyectos\FARO\app\index.html` |
| Rama de trabajo | `fase-puente-lectura-archivos` (sale de `fix/promo-area-agregada`, que incluye lo publicado en `main` + 3 arreglos del 10/09 sin publicar) |
| Web publicada | `https://cesarrear.github.io/faro-app/` = rama `main`, commit `1511827` (10/09 07:39) |
| src | El maestro no tiene `src`: todo va dentro de `index.html`, que es como se publica |
| Documentos del maestro | `app\README.md`, `FUNCIONAMIENTO.md`, `PENDIENTES.md`, `docs\` |
| Pruebas | `C:\Proyectos\FARO\pruebas` |

Nombres usados en fases anteriores (hoy archivados en `C:\Proyectos\FARO\archivo`):

- **Versión A**: copia modularizada por Codex, antes en `C:\Proyectos\FARO`, hoy en `archivo\A_codex_2026-09-11`. Se usó como fuente de mejoras técnicas. No es el maestro.
- **Versión B**: antes en `Downloads\FARO_REFERENCIA`, hoy en `archivo\B_referencia_2026-09-09`. Igual al commit `0e0b642` del 09/09. Fue la referencia funcional. **No es el maestro**: le faltan 4 cambios posteriores.

## Problema de partida

1. **Desde la subida del 03/09, todas las subidas de CSV y Excel fallaban a medias.** `handleFile` usaba la variable `recognized` fuera del bloque donde se declaraba, lo que daba un ReferenceError. El resultado era el aviso "No se ha podido leer el Excel/CSV", la sección de lectura oculta y la fecha sin sugerir.
2. **Un CSV de solo entradas se rechazaba.** La regla exigía dos métricas y además ventas o tickets. Ejemplo: `Tiendas,Entradas año anterior,Entradas año actual,Var. entradas`.
3. **Solo se leía CSV UTF-8 con coma o punto y coma.** UTF-16, ANSI y tabulador salían ilegibles.
4. **"1.300" se leía como 1,3** en CSV con separador `;` o tabulador.
5. **Una dirección podía convertirse en tienda**: "Av. Cerdanyola, 18" se leía como T18.
6. **Había botones que borraban histórico de verdad**, entre ellos "Vaciar archivos".
7. **Un festivo o cierre contaba como caída o subida** en día, semana, mes, área y tendencias.

## Cambios aplicados

### Lectura y clasificación (migrado de A y adaptado)

- **Lector robusto**, sección 14B de `index.html`:
  - codificaciones UTF-8, UTF-8 con BOM, UTF-16 LE y BE (con o sin BOM) y windows-1252,
  - separador coma, punto y coma o tabulador, elegido por consistencia de columnas,
  - admite la línea `sep=`,
  - libros XLSX y XLS.
- **Selector "Qué contiene el archivo"**: automático, Seguimiento Diario, FollowUp o resultados por tienda, MMV, o guardar solo el archivo.
- **FollowUp parcial**: basta con una columna de tienda y una métrica. Subtipos: solo entradas, solo ventas, solo tickets, ventas + tickets y KPI sueltos.
- **Un Excel no reconocido no se importa solo.** FARO propone el tipo y el usuario lo confirma.
- **Una columna que no viene en el archivo nunca borra un valor ya guardado** del mismo día, tienda y fuente (`_fusionarParcialConExistente`). Un KPI derivado (conversión, AOV o UPT) no se recupera si el archivo trae alguna de sus bases.
- **Tiendas canónicas**:
  - se reconocen por código, alias, dirección o la etiqueta "TIENDA NN",
  - una dirección desconocida no genera tienda,
  - el id interno sigue siendo `T26`, igual que en Supabase,
  - `store_id`, `store_label`, `store_address` y `raw_store_value` viajan como trazabilidad y no se guardan.
- **Diagnóstico por fase** en los mensajes: lectura, encoding, separador, cabecera, tienda, métrica, parcial válido, histórico, metadatos y Supabase.
- **Fecha del resultado** obligatoria. Se sugiere si el archivo trae fecha y se aclara que no es la fecha de subida.
- `archivos_faro`: la lectura usa primero `filename` y `tipo_archivo`, con `nombre` y `tipo` como respaldo legacy. La escritura ya usaba las columnas correctas.

### Borrado seguro

- **Siguen inertes**: `deleteFile`, `deleteFileAndImportedData`, `deleteHistoricalUpload`, `clearAllFiles`, las funciones legacy, `deletePromotion*` y `deleteFocoRow`.
- **No hay botón "Vaciar archivos"** ni borrado masivo.
- **Nuevo: `quitarSoloArchivo`**. Retira el registro del archivo y no toca el histórico. Pide escribir el nombre exacto o `BORRAR`.
- **Nuevo: `quitarCargaConDatos`**. Borra solo las filas de esa carga (mismo archivo, fecha y fuente), contadas antes y borradas por id. Pide tres pasos:
  1. confirmar un resumen con archivo, fecha, fuente, número de filas y tiendas,
  2. escribir el nombre exacto del archivo,
  3. escribir `BORRAR N`.
- Supabase exige además rol de administrador para borrar (`faro_is_admin`, SQL del 03/09).

### Día no comparable

- **Selector al subir**: Día normal, LY cerrado / festivo, CY cerrado / festivo, Apertura parcial LY, Apertura parcial CY, Incidencia excepcional.
- **Datos reales intactos**, ceros incluidos, sin medias.
- **Un día marcado** sale con `vsEur`, `vsTick` y `desv` a null, se ve como **N/A** y lleva la etiqueta del motivo.
- **Semana y mes**: los totales reales incluyen todos los días; el % y la desviación solo usan los días comparables. El acumulado de la hoja CUM resta los días no comparables cargados; si falta su valor, el % queda N/A.
- **Área** (Mi Área, alertas, posición y Rapport): el % se calcula con valores comparables.
- **Tendencias**: las magnitudes semanales solo usan días comparables. Las palancas semanales no cambian.
- **Basta con que una fuente del día lo marque** (Seguimiento o FollowUp) para que el día no sea comparable.
- **Sin la columna en Supabase**, FARO funciona exactamente igual que antes y no deja subir con una marca distinta de "Día normal".

### Corrección 11/09: NO COMPARABLE no es NO COMPUTABLE

**Error:** tres funciones usaban la venta comparable como si fuera la real, y la venta de un día marcado dejaba de sumar:

- `renderAreaAlerts` (aviso de Mi Área): el total en € y "tiendas por debajo del año pasado".
- `_areaTotalsForPeriod` (Posición): quitaba la tienda entera del total.
- `_trendAgregaSemana` (tendencias de tienda y de área): quitaba el día de todas las magnitudes.

**Corregido:**

- **La venta, los tickets y las entradas son siempre reales**: todas las tiendas y todos los días.
- **Solo el % frente a LY usa los campos comparables** (`salesComp`, `*_cmp`).
- **Se añade `vsEurReal`**, la evolución del total real, que se guarda aparte.
- **Una semana de tendencias con días no comparables** baja la confianza a BAJA y lo explica.

Caso validado: A 1000/900 normal, B 2000/0 LY cerrado y C 1100/1000 normal.

- **Real:** 4100 / 1900.
- **Comparable:** 2100 / 1900, **+10,53%**.
- **El día B** se ve con 2000 / 0, marcado y con el % en N/A.

### Corrección 11/09 (2): la venta seguía sin verse o sin sumar en dos sitios

- **`renderRL` (Ranking)**: filtraba `vsEur!==null`, así que una tienda con periodo no comparable desaparecía. Ahora sigue en la lista, al final, sin puesto, con "N/A · motivo" y su venta real.
- **Acumulado de mes (`s.monthCum`)**: usaba la hoja CUM del último Seguimiento subido. Los días cargados después no sumaban ni CY ni LY. Nueva `_completarCumConDiasPosteriores`: suma esos días al total real y, si son comparables, también al comparable. **Cambio visible**: el mes real ahora incluye todo lo cargado después del último Seguimiento, sean días normales o no.

Prueba obligatoria validada: A 1000/900 normal, B 2000/0 LY cerrado y C 0/1800 CY cerrado.

- **Real:** 3000 / 2700.
- **Comparable:** 1000 / 900, **+11,11%**.
- **Días B y C:** visibles con su % en N/A (nunca +100% ni -100%).
- **Mes:** el mismo resultado con la hoja CUM del día A y con la del día C, sin duplicar.

### Corrección 11/09 (3): tarjeta de tienda y Seguimiento Diario sin fila LY o CY

- **Tarjeta (`buildSG`)**: ya pintaba la venta real (`d.sales`). No había ningún código que la pusiera a 0 por la marca. Cambios:
  - dice "No comparable" en vez de "N/A",
  - en "Ayer" indica el día que enseña, porque "Ayer" es **el último día cargado**, y si ese día es un cierre su venta real es 0 €.
- **`extractSeguimientoReal`**: si faltaba la fila de la tienda en AYER LY (LY cerrado) o en AYER (CY cerrado), **la tienda se saltaba entera** y su venta real no se guardaba. Cambios:
  - basta con una de las dos filas del día,
  - el lado sin fila vale 0 solo si se ha marcado como cerrado; si no, se deja vacío,
  - si faltan las filas CUM, el acumulado se deja fuera (`month = null`) y no se guarda como 0,
  - `applySeguimientoReal` solo marca `_cumReal` si hay acumulado.
- **Validado**:
  - Caso A (2000 / 0, LY cerrado): la tarjeta muestra 2000 € y "No comparable".
  - Caso B (0 / 1800, CY cerrado): la tarjeta muestra 0 €, LY 1800 € y "No comparable".
  - Una tienda con todas sus filas da el mismo resultado que la versión anterior.
- **Pendiente**: `_num(null)` sigue convirtiendo una celda vacía en 0 en el resto de lecturas del Seguimiento. No se ha cambiado porque afecta a más cálculos; queda para revisar.

### Dato manual (12/09)

Para cuando la fuente oficial llega tarde: T13 hasta el lunes, o una fiesta que retrasa el Seguimiento.

- **Formulario "Añadir dato manual"** en Ficheros: tienda, fecha, venta CY, venta LY, tickets, entradas, conversión, AOV, UPT, comparabilidad y observaciones. Importes **con IVA**. Si ese día ya tiene dato manual, se rellena para editarlo, y avisa si además ya existe el oficial.
- **Se guarda como una fila más** en `datos_diarios_faro` con `fuente='MANUAL'`, `tipo_periodo='dia'`. La clave única `(user_id, fecha, tienda, fuente)` hace que conviva con el Seguimiento y el FollowUp del mismo día sin pisarlos y sin duplicar.
- **Suma como cualquier dato real** en el día, la semana, el mes y el área.
- **Prioridad por métrica** (decidido 12/09): ventas y ventas LY del Seguimiento; tickets, entradas, conversión y UPT del FollowUp; **el manual siempre el último**. La regla entre fuentes oficiales no cambia.
- **Reconciliación al llegar el oficial**, calculada al leer, sin tocar la fila manual:
  - sin oficial: "Dato manual pendiente de validar",
  - coincide: "Dato manual validado por la fuente oficial",
  - difiere: "Dato manual: Venta: manual X / oficial Y",
  - un KPI que el oficial no trae **no borra** el valor manual.
  - Tolerancia: ±1 € o 0,5% en venta, 0,01 en conversión, AOV y UPT, y valor exacto en tickets y entradas.
- **Bloque viernes+sábado:** si el Seguimiento del lunes trae los dos días en una fila y ese bloque se conserva, los manuales de esos dos días pierden sus magnitudes. **Sin esto, el sábado se contaba dos veces.**
- **T27** no guarda entradas ni conversión tampoco a mano.
- Las filas manuales se ven en Ficheros como "Dato manual" y se pueden retirar con "Quitar carga y datos".
- **Observaciones necesitan una columna nueva**: hasta que exista, el campo sale desactivado y el resto del dato manual sí se guarda.
- Validado con 15 pruebas: manual solo, oficial coincidente, oficial distinto, KPI ausente, prioridad por métrica, semana de la fiesta (jueves manual, viernes cerrado, sábado manual), bloque viernes+sábado sin duplicar y etiqueta en la tarjeta.

## Supabase: cambio propuesto, no ejecutado

Fichero: `docs\2026_09_11_PROPUESTA_columna_comparabilidad.sql`

- Tabla `public.datos_diarios_faro`, columna `comparabilidad text not null default 'normal'`, con un check de valores.
- Impacto: las filas existentes quedan como `normal` y no cambia ningún número. No toca claves ni RLS. La web publicada sigue funcionando.

## No migrado de A

- Repositorios Supabase separados y modularización en `src/`, porque el maestro se publica como un único fichero.
- `recommendations.js` (narrativa de tendencias). Queda para la siguiente fase.
- Resultados de promoción por fecha (`promociones_resultados_faro`) y contexto del día. Necesitan tablas o columnas nuevas.

## Riesgos pendientes

- La marca se aplica a **todas las tiendas del archivo**. Un festivo local de una sola tienda todavía no se puede marcar por separado.
- Si un parcial se fusionó con una carga anterior del mismo día y fuente, **"Quitar carga y datos" borra la fila entera**. El aviso lo explica.
- **El registro de Ficheros solo muestra la última carga** de cada día y fuente, porque el upsert sobrescribe `archivo_nombre`.
- Las etiquetas canónicas de tienda (T13 Baixada de la Plana, T53 Nou Masnou…) están copiadas de A y coinciden con los nombres del maestro, pero **conviene revisarlas**.
- **Días no comparables:** los sitios que calculan % por su cuenta ya están revisados (tarjetas, alertas, resumen de área, posición, Rapport, modal y tendencias). **Cualquier pantalla nueva debe usar `_cmp()`.**

## Pruebas técnicas realizadas

- `node --check` sobre el script inline: correcto.
- **67/67 pruebas de lectura**:
  - UTF-8, BOM, UTF-16 LE y BE, ANSI, tabulador, `sep=`, cabecera en la fila 3, XLSX y XLS,
  - direcciones y alias de tienda, mensajes por fase, fusión de parciales,
  - **regresión: un FollowUp completo da el mismo resultado que antes**.
- **Ficheros reales**: `2026-09-10_ventas.csv` y `2026_09_09_VENTAS_solo_entradas.csv`. Se leen 8 tiendas del área; T27 queda fuera por su contador y T13 no viene en el CSV.
- **23/23 pruebas de comparabilidad**:
  - **regresión: sin marcas, día, semana y tendencia son idénticos a antes**,
  - LY cerrado, CY cerrado, acumulado CUM, tendencia y vista de ayer.
- Auditoría de `.delete(`: solo las dos funciones nuevas pueden borrar.

## Pruebas manuales recomendadas

1. Entrar con usuario.
2. Revisar Mi Área, Ranking, Semanas, Rapport, Promociones, FOCO e Histórico.
3. Subir un Seguimiento Diario XLSX.
4. Subir un FollowUp CSV completo.
5. Subir un CSV de solo entradas y comprobar que no se pierden las ventas del día.
6. Subir un CSV tabulado o UTF-16 exportado desde Excel.
7. Subir el MMV.
8. Probar un archivo no reconocido y usar el selector manual.
9. "Quitar solo archivo" y "Quitar carga y datos" con una carga de prueba.
10. Con la columna ya creada: subir el 10/09 como LY cerrado y comprobar N/A en el día y el % comparable en semana y mes.

## Siguiente fase recomendada

1. Ejecutar el SQL de comparabilidad, tras aprobarlo.
2. Marca por tienda (festivos locales).
3. Narrativa de tendencias con contexto: dirección, persistencia, driver y contexto.
4. Resultados de promoción por fecha, con una tabla nueva a proponer.
5. Publicar el maestro y archivar las copias antiguas.
