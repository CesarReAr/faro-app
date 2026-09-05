# FARO · Cómo trata los datos

Documentado el 05/09/2026 tras revisar y corregir el código.
Repo `CesarReAr/faro-app`, un único `index.html`. App viva en
https://cesarrear.github.io/faro-app/

---

## 1. Las dos fuentes

FARO come de dos ficheros que **no compiten, se complementan**.

**SEGUIMIENTO DIARIO** — el Excel corporativo. Es la única fuente de:

- Marcas Verdes
- Selectivo
- Club
- Marcas de Oportunidad

Y además trae ventas, ventas LY, tickets, AOV y UPT. Incluye **T13**.

**FOLLOWUP (CSV)** — el comparativo diario. Trae ventas, ventas LY, tickets,
tickets LY, entradas, entradas LY, conversión, AOV y UPT. **No incluye T13.**

---

## 2. La regla de oro

> Nunca se elige un fichero ganador para todo el día.
> La consolidación se hace por `user_id + fecha + tienda` y después **campo a campo**.

Las dos fuentes se guardan por separado en Supabase, en `datos_diarios_faro`,
con clave lógica `user_id + fecha + tienda + fuente`. Subir el CSV **no borra ni
sustituye** la fila del Seguimiento.

La función central es **`mergeStoreDaySources(rowsForStoreAndDate, storeId)`**.
La usan Ayer, detalle de tienda, semana, mes, ranking y rapport. No hay una
consolidación distinta por pantalla.

---

## 3. Prioridad por campo

| Campo | Primero | Si falta |
|---|---|---|
| Ventas | Seguimiento | FollowUp |
| Ventas LY | Seguimiento | FollowUp |
| Tickets | FollowUp | Seguimiento |
| Tickets LY | FollowUp | Seguimiento |
| Entradas | FollowUp | — |
| Entradas LY | FollowUp | — |
| Conversión | FollowUp | tickets ÷ entradas |
| AOV | recalculado ventas ÷ tickets | fuente válida |
| AOV LY | recalculado ventas LY ÷ tickets LY | fuente válida |
| UPT | FollowUp | Seguimiento |
| UPT LY | FollowUp | Seguimiento |
| Marcas Verdes | Seguimiento | **solo Seguimiento** |
| Selectivo | Seguimiento | **solo Seguimiento** |
| Club | Seguimiento | **solo Seguimiento** |
| Marcas de Oportunidad | Seguimiento | **solo Seguimiento** |

**La venta oficial del día es la del Seguimiento.** El FollowUp complementa
tickets, tráfico, conversión, AOV y UPT. Nunca se suman las dos fuentes entre
sí: eso duplicaría la venta.

---

## 4. La regla de los nulos

`null`, `undefined`, `""` y `NaN` **nunca** pueden sobrescribir un valor válido
de la otra fuente. Lo garantiza `_mergeSourceObjects`, que sustituyó a un
`{...seguimiento, ...followup}` en el que un nulo del CSV machacaba el dato bueno.

Los KPI semanales arrastran de un día a otro. Si subes un CSV posterior, Marcas
Verdes, Selectivo, Club y Ocasión **no se quedan vacíos**: los recupera
`_latestWeeklyKpisForStore` de la última fila que los tenga.

---

## 5. T13

**T13 no está en el comparativo diario.** Su única fuente es el Seguimiento.

- Si falta en el FollowUp, **sigue existiendo** con sus datos del Seguimiento.
- **No se pone a cero** ni desaparece.
- Ausencia en una fuente significa "sin dato en esa fuente", no "sin dato".
- Si un día solo hay FollowUp, T13 muestra "sin datos para este periodo",
  nunca un cero.

Su serie histórica se puede reconstruir desde las hojas del Seguimiento:
lunes a jueves salen de `AYER`, y el fin de semana de restar el acumulado de
`CUM` entre el jueves y el lunes siguientes. Validado contra T40, T26, T81,
T85 y T56 con un 0,6% de error. Lo que no se puede separar es el viernes del
sábado: solo se conocen juntos.

---

## 6. T27

**T27 queda siempre sin entradas y sin conversión**, aunque el CSV las traiga.
Su contador de tráfico está caído desde el cierre de agosto de 2026 y los
valores no son utilizables. Está forzado en el código, no depende del fichero.

---

## 7. El bloque de viernes + sábado

El Seguimiento que se sube el lunes puede traer **viernes y sábado en una sola
fila**. En la pantalla de carga hay que marcarlo en el desplegable:

> **Viernes + sábado consolidado**

Y la fecha que se teclea es **la del viernes**. FARO deduce el sábado sumando
un día. Si se pone otra fecha, la protección no salta.

Qué hace FARO con ese bloque:

- Si el FollowUp **ya cubre viernes y sábado**, del bloque se anulan solo las
  magnitudes de venta y tráfico: ventas, ventas LY, tickets, tickets LY,
  entradas, entradas LY, AOV y AOV LY. La venta la ponen los CSV, que son día
  a día. **Los KPI semanales del bloque se conservan intactos.**
- Si el FollowUp **solo cubre uno** de los dos días, el bloque se conserva
  entero para no perder la venta del otro.
- **T13 nunca se neutraliza**, porque nunca hay cobertura de FollowUp para
  ella. Su fin de semana entra completo bajo la fecha del viernes.

Sin esto, el fin de semana se contaría dos veces en Semana y en Mes.

---

## 8. Los dos formatos del CSV

El comparativo llega con **dos cabeceras distintas según la hora de descarga**:

```
Venta año anterior, Venta año actual, ...   19 columnas
Venta 1, Venta 2, ...                       16 columnas
```

En el formato corto, **`1` es el año anterior y `2` el año actual**. FARO
reconoce los dos. Las columnas `Var. ...` se descartan: son un porcentaje, no
un valor.

**El comparativo descargado antes del cierre de tienda va incompleto.** El
04/09/2026 la descarga de las 20:57 daba 12.696 € de área y la de la mañana
siguiente 13.042 €. Descargarlo siempre a la mañana siguiente.

---

## 9. Orden de cálculo

1. Leer las filas originales de Supabase
2. Agrupar por fecha + tienda
3. Consolidar las fuentes del día por KPI
4. Obtener un único día lógico por tienda
5. Agregar esos días a semana
6. Agregar esos días a mes

**Nunca** sumar todas las filas y corregir duplicados después.

---

## 10. Borrado de archivos

Ya no pide la contraseña de Supabase. Pide **teclear el nombre del archivo**.
Si no coincide, no borra nada.

| Acción | Qué escribir | Solo admin |
|---|---|---|
| Eliminar solo el archivo | el nombre del archivo | no |
| Quitar esta carga de FARO | el nombre de la carga | no |
| Eliminar archivo + datos importados | el nombre del archivo | no |
| Vaciar la biblioteca | `VACIAR` | sí |

El rol se lee de la tabla `profiles`.

---

## 11. Dónde está cada cosa en el código

| Qué hace | Función |
|---|---|
| Consolidación central por tienda y día | `mergeStoreDaySources` |
| Merge campo a campo de filas de histórico | `_mergeHistoryDayRows` |
| Merge de las fuentes en memoria al subir | `_mergeLiveDaySources` |
| Protección de nulos | `_mergeSourceObjects` |
| Arrastre de KPI semanales | `_latestWeeklyKpisForStore` · `_applyWeeklyKpiFallback` |
| Bloque viernes+sábado | `_neutralizeCoveredBlocks` |
| Agregación a semana y mes | `consolidateHistoryRows` |
| Lectura del CSV | `_followupMap` · `_followupNormalizeHeaders` · `_followupIsLY` |
| Guardado | `saveDailyHistory`, upsert con `onConflict: user_id,fecha,tienda,fuente` |
| Recarga desde Supabase | `loadHistoricalState` · `applyLatestDayFromHistory` |
| Borrado | `_confirmFileDeletion` |

`consolidateHistoryRowsLegacy` y `extractFollowupCSVLegacy` son **código
muerto**: están definidas y no se llaman. No tocarlas creyendo que hacen algo.

---

## 12. Limitaciones conocidas

**`dias_incluidos` se guarda pero no lo lee nadie.** Hoy no molesta porque los
totales de semana y mes salen bien. Molestará el día que se calculen medias
diarias: trataría el bloque de dos días como uno y la media de T13 saldría
inflada.

**La pantalla Ayer se construye con una sola fecha**, la más alta que haya en
el histórico. Si las dos fuentes quedan en fechas distintas, la venta será la
de la fecha más reciente. Los KPI semanales sí arrastran, así que no se pierden.

**El campo de fecha del formulario se vacía entre subidas** y el Seguimiento la
autodetecta de su hoja `AYER`, que es el día anterior. Si quieres que las dos
fuentes caigan en el mismo día, hay que teclear la misma fecha en las dos.

---

## 13. Rutina recomendada

**Cada día**, por la mañana: descargar el comparativo del día anterior ya
cerrado y subirlo como FollowUp, con la fecha de ese día.

**Los lunes**: subir además el Seguimiento marcando **"Viernes + sábado
consolidado"** y poniendo **la fecha del viernes**. Es lo que trae los KPI
semanales y los datos de T13.

Después de la segunda carga, comprobar que **Marcas Verdes, Selectivo, Club y
Ocasión siguen ahí** y que T13 no ha desaparecido. Si algo de eso falla, la
consolidación tiene un problema.
