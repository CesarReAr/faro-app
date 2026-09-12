# PLAN SEMANAL FARO

Fecha: 12/09/2026 · Estado: aplicado en local, **sin publicar** · SQL de las dos tablas: **propuesto, sin ejecutar**

El módulo reproduce el ciclo real de la semana:

**resultado anterior → evaluación del foco → nuevo foco → objetivo → comunicación → resultado → aprendizaje → semana siguiente**

La comunicación no es un módulo aparte: sale del análisis y del plan.

## 1. Qué se reutiliza y qué es nuevo

| Pieza | Origen |
|---|---|
| Resultado de la semana anterior | `_realWeeksForStore` sobre `datos_diarios_faro`, ya consolidado. **No se toca** |
| Foco anterior | el `foco_nuevo` del plan de la semana pasada; si no hay, la línea de `focos_rapport_faro` de esa semana |
| Mensaje | generador propio del plan (formato fijo del encargo), no el de la pestaña Mensajes |
| Plan y objetivos | **dos tablas nuevas**: `plan_semanal_faro` y `objetivos_semanales_faro` |

No se ha creado ninguna tabla de mensajes: el mensaje vive en el propio plan. El mensaje del área se guarda como una fila con `tienda = 'AREA'`.

## 2. Ficheros modificados

- `app/index.html`:
  - pestaña nueva **Plan Semanal** en la barra de navegación y en `showTab`,
  - pantalla `tab-plan`: cabecera de semana, regla del objetivo, carga de objetivos, mensaje del área y una ficha por tienda,
  - bloque de lógica **16C. PLAN SEMANAL** (evaluación, decisión, objetivos, mensajes, estados, cierre y persistencia).
- `app/docs/2026_09_12_PROPUESTA_plan_semanal.sql`: las dos tablas, con índices y RLS. **Sin ejecutar.**
- `pruebas/test_plan_semanal.js`: 28 pruebas, casos A a E del encargo.

**No se ha tocado**: parser del Seguimiento Diario, parser del FollowUp, consolidación multisource (`_mergeHistoryDayRows`, `consolidateHistoryRows`), histórico, motor de tendencias, promociones, FOCO, Auth ni RLS existente.

## 3. Cómo evalúa el foco anterior

- Reconoce el KPI dentro del texto del foco: ventas, tickets, AOV, UPT, conversión, entradas, Selectivo, Marcas Verdes, Club y Marcas de Oportunidad.
- Compara cada KPI entre **la semana en la que se trabajó el foco** y la semana anterior a esa, con un umbral de 0,5.
- Estados: **FUNCIONÓ** (todos mejoran), **FUNCIONÓ PARCIALMENTE** (unos sí y otros no), **NO FUNCIONÓ** (ninguno mejora y alguno empeora), **SIN DATOS SUFICIENTES**.
- La explicación nunca atribuye causalidad: *"En la semana en la que se trabajó este foco: UPT mejora (+6,8 puntos); Selectivo empeora (-1,0 puntos), y sigue por debajo del año pasado. Es lo que ocurrió durante esa semana, no una causa demostrada."*

## 4. Cómo propone la decisión

| Situación | Propuesta |
|---|---|
| Mejora pero sigue por debajo de LY | **MANTENER FOCO** |
| Parte del foco se mueve y parte no | **AJUSTAR FOCO** |
| El KPI no se mueve o empeora | **CAMBIAR FOCO** |
| Cumplido y ya en positivo | **CAMBIAR FOCO**, al KPI más flojo de la semana |
| Sin datos | **MANTENER**, avisando de que falta semana cerrada |

Siempre **editable**: la decisión final es del coordinador. Al cambiar el foco a mano, el mensaje se regenera con el foco nuevo.

## 5. Ejemplo de plan de una tienda

```
T53 · Nou Masnou                                     [Preparado]
Semana anterior: ventas +4.3% vs LY · tickets +2.0% · AOV +2.0% ·
UPT +9.1% · conversión 48,0 · Selectivo -6.0% · Club 62
Venta de la semana anterior: 12.000€ · LY 11.500€

Foco anterior (plan de la semana anterior): UPT + Selectivo
FUNCIONÓ PARCIALMENTE
En la semana en la que se trabajó este foco: UPT mejora (+6,8 puntos);
Selectivo empeora (-1,0 puntos), y sigue por debajo del año pasado.
Propuesta de FARO: AJUSTAR FOCO. KPI más flojo: Selectivo (-6.0%).

Decisión:  AJUSTAR FOCO
Foco:      Selectivo
Objetivo:  Familia 08 · Tratamiento Selectivo: 1437,70 € · 120 uds
Acción:    reforzar propuesta de tratamiento selectivo en cada venta relevante
```

## 6. Ejemplo del mensaje generado

```
Buenos días, equipo.

La semana pasada cerró con ventas +4.3% vs LY, tickets +2.0%, AOV +2.0%,
UPT +9.1%, conversión 48.0%. En la semana en la que se trabajó este foco:
UPT mejora (+6,8 puntos); Selectivo empeora (-1,0 puntos), y sigue por
debajo del año pasado. Es lo que ocurrió durante esa semana, no una causa
demostrada.

Esta semana vamos a poner el foco en Selectivo.

Objetivo:
Familia 08 · Tratamiento Selectivo: 1437,70 € · 120 uds

Acción:
reforzar propuesta de tratamiento selectivo en cada venta relevante

Revisaremos la evolución al cierre de la semana.

Un saludo
César
```

El **mensaje de área** añade la lectura del área, el foco general (el más repetido), el objetivo total sumando los objetivos cargados, las tres tiendas más flojas y el foco específico por tienda.

## 7. Ejemplo de cierre semanal

```
T40 · Foco: Tratamiento Selectivo
Objetivo:     1.437,70 €
Resultado:    1.310,00 €
Desviación:   -127,70 €
Cumplimiento: 91,1%

Lectura FARO: El objetivo no se alcanza, aunque la tienda queda cerca:
1.310€ frente a 1.438€ (-128€, 91,1% de cumplimiento). Conviene mantener
el foco una semana más y revisar unidades.
```

**Importante:** el resultado real por familia (03 y 08) **no existe hoy en FARO**, porque el histórico no guarda venta por familia. Por eso el cierre pide ese importe en la ficha de la tienda. Cuando exista una fuente de familias, se conecta ahí sin cambiar el resto.

## 8. Estados y memoria de gestión

- **BORRADOR** → editable. **PREPARADO** → foco y objetivo definidos. **ENVIADO** → comunicación enviada. **CERRADO** → resultado comparado.
- Al cerrar se guarda en el campo `cierre`: objetivo, resultado, desviación, cumplimiento, foco, acción, evaluación del foco anterior, decisión tomada, mensaje enviado, KPI de la semana y la lectura. Esa es la memoria que la semana siguiente lee como "foco anterior".
- **No hay aprendizaje automático.** Solo memoria bien guardada.

## 8-bis. Las dos familias de Selectivo (12/09)

César manda **siempre dos familias**: **03 Maquillaje Selectivo** y **08 Tratamiento Selectivo**. El plan las trataba como una sola línea de texto. Corregido:

- **Objetivo por familia**, con importe y unidades, más el total de Selectivo. **Nunca se suman en una sola cifra.**
- **Mensaje de tienda** con las dos líneas y su total:
  ```
  Objetivo:
  Maquillaje Selectivo (F03): 454,30 € · 21 uds
  Tratamiento Selectivo (F08): 491,70 € · 16 uds
  Total Selectivo: 946,00 €
  ```
- **Mensaje del área**: objetivo total desglosado por familia.
- **Cierre por familia**: un campo de resultado real por familia, con su desviación y su cumplimiento, y además el total. Ejemplo de T40: Maquillaje 470,00 € de 445,50 € (**105,5%, cumplido**) y Tratamiento 1.310,00 € de 1.437,70 € (**91,1%**), total 94,5%. Si falta el resultado de una familia, lo dice; no lo inventa.
- **Al cargar los objetivos se regeneran los mensajes** que no están en ENVIADO ni CERRADO. **Ese era el fallo**: el objetivo quedaba cargado pero no aparecía en ningún mensaje.

### Objetivos de esta semana, sacados del PDF del área

El PDF `Objetivos_Selectivo_FARO_Semana_2026.pdf` trae las 10 tiendas y las dos familias: **155 uds y 3.822,50 €** en Maquillaje, **205 uds y 7.932,10 €** en Tratamiento, **total 11.754,60 €**, con la regla "semana equivalente 2025 +10%".

**FARO no lee PDF todavía.** Está convertido a CSV en `Downloads\Objetivos_Selectivo_S38_2026.csv` (copia en `pruebas\`), que es lo que carga la pantalla. Comprobado con 11 pruebas: 20 filas, 10 tiendas, las dos familias, importes y totales exactos del PDF.

## 8-ter. Objetivo de venta y "conseguido o no" (12/09)

Además del Selectivo, cada tienda tiene **objetivo de venta**, en % sobre la venta de **la misma semana del año anterior**.

- **Porcentaje por tienda**, con los objetivos anuales ya cargados: T13 +2%, T26 0%, T27 +3%, T30 +3%, T40 +2,5%, T53 +2,5%, T54 +4%, T56 +3,5%, T81 +5%, T85 +3%. **Editable por semana** en la ficha de la tienda, por si esa semana va otro (el semanal de +10%, o un plan puntual).
- **Objetivo en euros** = venta LY comparable × (1 + %). Se usa la **venta comparable**: sin los días no comparables, ni de este año ni del anterior. Si falta la venta LY, **no se inventa objetivo**: lo dice.
- **Veredicto**: desviación en euros, cumplimiento en % y **CONSEGUIDO / NO CONSEGUIDO**, con lo que faltó.

Ejemplo (T81, objetivo +5%):

```
Venta LY misma semana:  9.500,00 €
Objetivo de la semana:  9.975,00 €
Venta real:            10.240,00 €
=> CONSEGUIDO · +265,00 € · 102,7%
```

**Dónde se ve:**

- **En el mensaje de la tienda**: la venta de la semana pasada con su veredicto, y el objetivo de venta de la semana que empieza, antes de las dos familias de Selectivo.
- **En el mensaje del área**: cuántas tiendas lo consiguieron, el total del área frente a su objetivo, las conseguidas y las pendientes con lo que falta a cada una.
- **En la ficha del plan**: una línea en verde o rojo con el resultado, y el campo para editar el % de esa tienda.

**Límite:** los porcentajes se guardan **en el navegador**. No hay columna para ellos en Supabase todavía; cuando se decida, van en el plan o en una tabla de objetivos de venta.

## 8-quater. La plantilla de Excel (12/09)

Fichero: **`C:\Proyectos\FARO\plantillas\FARO_Objetivos_y_Resultados.xlsx`**

Aclaración de César: **el +10% es de las dos familias de Selectivo, no de la venta general**, y la familia 03 se llama **Color Selectivo** (antes puesta como "Maquillaje"; se sigue reconociendo ese nombre en ficheros antiguos).

Cuatro hojas:

| Hoja | Para qué |
|---|---|
| **Instrucciones** | Qué rellenar y cómo. FARO la ignora al leer |
| **Objetivos_Familias** | Objetivo de la semana de las dos familias. Viene prellenada con el PDF del área |
| **Resultados_Familias** | Lo vendido de cada familia. Se rellena al cerrar la semana |
| **Objetivo_Ventas** | Objetivo de **venta** de la tienda, por semana o por mes, en euros o en % sobre LY |

- Se sube en **Plan Semanal → Objetivos de la semana**, y FARO lee **las cuatro hojas de una vez**: objetivos, resultados y objetivo de venta.
- Los **resultados** rellenados entran solos en el cierre de cada familia; el campo manual de la ficha queda como respaldo.
- La tienda vale como `13`, `T13` o `13 - Horta`. La familia, como `03`, `Color Selectivo` o `Colorido selectivo`.
- Una celda vacía es "sin dato": **nunca se convierte en 0**.
- La fila TOTAL del Excel no se cuela como tienda.

Validado con 20 pruebas sobre el fichero real: `pruebas/test_plantilla_excel.js`.

### FARO calcula el objetivo (12/09, tarde)

En `Objetivos_Familias` hay dos columnas más: **LY** y **Pct objetivo**.

- Rellenas lo que vendió esa familia el año pasado y el porcentaje (normalmente **10**), y **FARO calcula el objetivo en euros**: `LY × (1 + %)`.
- Si escribes una cifra en **Objetivo**, manda esa y no se calcula nada.
- En la regla del objetivo queda escrito de dónde sale: del fichero o calculado por FARO.
- Comprobado contra el PDF: T40 Color, LY 405 € + 10% = **445,50 €**; T40 Tratamiento, LY 1.307 € + 10% = **1.437,70 €**.

**Las cabeceras son `Pct objetivo` y `Pct sobre LY`, sin el símbolo `%`.** Al normalizar los nombres se pierde el `%`, y entonces "% objetivo" chocaba con la columna "Objetivo" (el importe) y "% sobre LY" con la columna "LY". Los dos campos de porcentaje se buscan antes que los de importe.

### La semana del fichero manda

- La columna **Semana** se entiende venga como venga: **fecha de Excel**, número de serie, `2026-09-14` o `14/09/2026`. Si Excel convierte la columna en fecha, no pasa nada.
- **Si el fichero trae una semana distinta de la del selector, FARO cambia el plan a la semana del fichero y lo avisa.** Antes cargaba todo en la semana que estuviera en pantalla, con el riesgo de meter los objetivos del día 14 en la semana del 7.
- Si el fichero mezcla varias semanas, cada fila se guarda en la suya y se avisa.

Validado con 20 pruebas: `pruebas/test_fechas_plantilla.js`.

## 9. Objetivos semanales

- Se cargan desde CSV o Excel con el lector robusto de FARO. Columnas reconocidas: tienda, familia, unidades y euros.
- Se guarda además **semana, regla de cálculo, fuente y fecha**. La regla es un campo de texto editable, por defecto *"Semana equivalente 2025 +10%"*: **no se asume que sea siempre la misma**.
- Familias conocidas: **03 Maquillaje Selectivo** y **08 Tratamiento Selectivo**.

## 10. Multiusuario

- Todo se consulta y guarda por `user_id` y por tienda. **No hay listas fijas de tiendas** en el módulo: recorre las tiendas disponibles.
- Las dos tablas llevan RLS con el mismo patrón que el resto de FARO: cada usuario ve y escribe lo suyo, y el borrado queda al administrador.
- Cuando exista `authorizedStoreIds`, basta cambiar el origen de la lista de tiendas. `calculateAreaTrends` ya recibe ese parámetro.

## 11. Relación futura con tendencias

El motor de tendencias ya devuelve, por tienda y KPI, un estado (`MEJORA`, `DETERIORO`, `VIGILANCIA`…), la variación reciente y el `vsLY`. La conexión pendiente es de una pieza: en `_planDecision`, cuando llegue una señal de deterioro o vigilancia en un KPI, proponerlo como foco antes que el "KPI más flojo de la semana". Hoy **no** se usa: nada de riesgo ni de predicción.

## 12. Pruebas realizadas

`node pruebas/test_plan_semanal.js` · **28 de 28**:

- **Caso A**: foco "UPT + Selectivo" con UPT mejorando y Selectivo no → FUNCIONÓ PARCIALMENTE, decisión AJUSTAR y sugerencia de seguir con Selectivo. Más las variantes MANTENER, CAMBIAR y SIN DATOS.
- **Caso B**: objetivo 1.883,20 € y resultado 1.620,40 € → **cumplimiento 86,0% y desviación -262,80 €**. Sin resultado cargado no inventa cumplimiento.
- **Caso C**: plan preparado → mensaje generado con el formato exacto, con cifras y sin causalidad.
- **Caso D**: foco editado a mano → el mensaje se regenera con el foco nuevo y conserva el objetivo.
- **Caso E**: semana cerrada → guarda foco, objetivo, resultado, cumplimiento, evaluación, decisión y mensaje. Cumplimiento 91,1% del ejemplo.
- **Extra**: un KPI ausente se muestra como "Sin dato", nunca como 0.

Sin regresiones: 87 de 87 en comparabilidad y dato manual, 67 de 67 en lectura de archivos.

## 13. Pendiente

1. **Ejecutar el SQL de las dos tablas.** Mientras no existan, el plan y los objetivos se guardan **solo en este navegador** y la pantalla lo avisa.
2. Resultado real por familia para cerrar objetivos sin teclearlo.
3. Conectar las señales del motor de tendencias con la propuesta de foco.
4. `fmt()` escribe los porcentajes con punto decimal ("+4.3%") en toda la app, también en los mensajes. Cambiarlo es transversal: queda anotado.
