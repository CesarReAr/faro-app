# FARO · Cómo trata los datos

Al día a 25/10/2026, contrastado con `index.html`. Sustituye a la versión del 05/09, que describía
solo dos fuentes.

---

## 1. Las fuentes

Todas se guardan en `datos_diarios_faro`, **una fila por `user_id + fecha + tienda + fuente`**. Subir
un fichero no borra ni sustituye las filas de otra fuente.

| Fuente (`fuente`) | Fichero | Qué aporta |
|---|---|---|
| `KPIS_TIENDAS_FARO` | KPIS diario de la red (hoja «dia»); fuente principal desde el 28/09/2026 | Venta y venta LY **con IVA**, tickets, UPT, palancas, objetivo del día. Puede traer varios días en una fila (`tipo_periodo='bloque'`). |
| `KPIS_TIENDAS_FARO_MES` | KPIS, hoja «mes» | Acumulado del mes. Solo sirve de control (ver 6). |
| `SEGUIMIENTO_DIARIO` | Seguimiento diario corporativo (formato anterior) | Venta **sin IVA**, Marcas Verdes, Selectivo, Club, Oportunidad. El del lunes trae viernes + sábado juntos (`tipo_periodo='viernes_sabado'`). |
| `SEGUIMIENTO_MES` | Seguimiento, hoja CUM | Acumulado del mes, control. |
| `FOLLOWUP_CSV` | Comparativo diario | Tickets, entradas, conversión y UPT de este año y del pasado. **No trae T13.** |
| `MANUAL` | Dato tecleado en FARO | Lo que ninguna fuente oficial trae. |

El KPIS y el Seguimiento hacen el mismo papel (venta principal del día, `_esFuenteVenta`) y no
conviven en las mismas fechas: el importador del KPIS no guarda si ya hay Seguimiento.

Las divisiones (VENTAS DIV) van aparte, en `ventas_division_faro`. El fichero va sin IVA y
× 1,205 cuadra con el KPIS (`DIV_IVA`).

---

## 2. La regla de oro

> Nunca gana un fichero entero. Se combina **campo a campo**.

Entrada única: `mergeStoreDaySources(filasDeLaTiendaYElDia, tienda)` →
`_mergeHistoryDayRows`. La usan Mi Área, la ficha de tienda, Semanas, el mes, el Ranking y el
Rapport.

---

## 3. Prioridad por campo (`_mergeHistoryDayRows`)

| Campo | Orden |
|---|---|
| Venta y venta LY | KPIS / Seguimiento → FollowUp → manual |
| Tickets y tickets LY | FollowUp → KPIS / Seguimiento → manual |
| UPT y UPT LY | FollowUp → KPIS / Seguimiento → manual |
| **Entradas y entradas LY** | **Solo FollowUp** → manual. Nunca las del KPIS (14/10/2026): su hoja de tráfico a veces repite días antiguos. |
| **Conversión** | La del FollowUp, o sus propios tickets ÷ sus propias entradas (`_conversionFollowupDia`). Un día con 0 tickets es un día cerrado: sin conversión. Nunca tickets de caja ÷ entradas del contador. |
| Marcas Verdes, Selectivo, Club, Oportunidad | KPIS / Seguimiento → FollowUp → manual |

- **Un nulo nunca pisa un valor válido** (`_historyValid`, `_mergeSourceObjects`).
- **El dato manual va siempre el último.** Si una fuente oficial trae el mismo campo, se compara
  y se marca como validado, pendiente o con discrepancia (`_estadoDatoManual`), sin cambiar nada.
- Si dos usuarios suben la misma fuente el mismo día, manda la fila más reciente
  (`_recientePrimeroPorFuente`).
- **T27 no tiene nunca entradas ni conversión** (contador averiado), aunque el fichero las traiga.
- **T13 no viene en el FollowUp**: sus tickets y su UPT salen del KPIS o del Seguimiento. No tiene
  conversión.

---

## 4. IVA

Las tiendas ven siempre la cifra **con IVA**. El Seguimiento llega sin IVA y `_normalizaIva`
multiplica venta, venta LY y AOV por `IVA_SEGUIMIENTO` (1,20) **dentro de la consolidación**, al
leer. Si se normalizara antes, saldría IVA doble. El KPIS y el FollowUp ya vienen con IVA.

---

## 5. Bloques de varios días (`_neutralizeCoveredBlocks`)

El KPIS (`bloque`, con `dias_incluidos`) y el Seguimiento del lunes (`viernes_sabado`) pueden traer
varios días en una fila, con la fecha del primero. El domingo no cuenta: la tienda no abre.

- Si el FollowUp cubre por separado **todos** los días abiertos del bloque, del bloque se anulan
  las magnitudes de venta y tráfico; sus KPI semanales (Marcas Verdes, Selectivo, Club) se
  conservan.
- Si no los cubre todos, el bloque se conserva entero y son el FollowUp y el manual de esos días
  los que no suman.

Sin esto, el fin de semana se contaría dos veces.

---

## 6. Semana y mes

- `consolidateHistoryRows`: primero un día lógico por tienda, después se agregan días. **Nunca se
  suman filas `mes` con filas de día** (`_soloFilasDiarias`).
- La semana es ISO, de lunes a sábado. Un domingo sin fila no es un hueco.
- **El total del mes es la suma de los días.** El acumulado del mes (hoja «mes» o CUM) solo manda
  (`_totalMesDeTienda`) si:
  - a la tienda le faltan días que el resto del área sí tiene (T13), o
  - la venta de este año descuadra más de un 1 % (`FARO_DESCUADRE_MES`) y la del año pasado
    cuadra: es venta registrada tarde.

  Si descuadran las dos, el sospechoso es el acumulado y se sigue con la suma.

---

## 7. Comparable frente a real

Un día marcado en `comparabilidad` (festivo, tienda cerrada…; `_comparabilidadDeFilas`, basta con
que lo marque una fuente):

- **suma siempre su venta real** al día, la semana, el mes, el área y las tendencias;
- sale del % frente al año pasado, a la vez en este año y en el pasado (`_marcarNoComparable`);
- se enseñan los dos: el total real (`vsEurReal`) y el comparable (`vsEur`).

No comparable no significa no computable. Un filtro que exija un % válido hace desaparecer la
tienda o el día: es un error. Un festivo a mitad de semana no es un día que falte.

---

## 8. Área: CY, LY y LW

- Totales con `_areaTotalsFromRows`; la semana anterior desplazada con `_areaTotalsLastWeek`.
- LW es el mismo periodo siete días antes: un viernes se compara con el viernes anterior.
- **AOV y UPT de área van ponderados por tickets**: venta total ÷ tickets totales.
- La conversión de área solo usa los días con tickets y entradas a la vez.

---

## 9. Dónde está cada cosa en el código

| Qué hace | Función |
|---|---|
| Consolidación de un día | `mergeStoreDaySources` → `_mergeHistoryDayRows` |
| IVA | `_normalizaIva`, `IVA_SEGUIMIENTO` |
| Conversión | `_conversionFollowupDia`, `_parConversionFollowup` |
| Dato manual | `_estadoDatoManual` |
| Bloques | `_neutralizeCoveredBlocks`, `_fechasDeFila`, `_fechasAbiertasDeFila` |
| Semana y mes | `consolidateHistoryRows`, `_soloFilasDiarias`, `_totalMesDeTienda` |
| Comparabilidad | `_comparabilidadDeFilas`, `_marcarNoComparable` |
| KPI semanales que arrastran | `_latestWeeklyKpisForStore`, `_applyWeeklyKpiFallback` |
| Totales de área | `_areaTotalsFromRows`, `_areaTotalsLastWeek` |
| Lectura del comparativo | `_followupMap` |
| Guardado y recarga | `saveDailyHistory`, `loadHistoricalState` |
| Borrado de cargas | `_confirmFileDeletion` (hay que teclear el nombre) |

`consolidateHistoryRowsLegacy` y `extractFollowupCSVLegacy` son código muerto: no se llaman.

---

## 10. Rutina de carga

- **Cada día:** el KPIS del día anterior. El comparativo, descargado a la mañana siguiente (el de
  la tarde llega incompleto), para tener tickets, entradas y conversión.
- **Una semana sin comparativo no tiene conversión**, aunque el KPIS traiga entradas.
- Antes de cerrar la semana, comprobar que están el viernes y el sábado.
