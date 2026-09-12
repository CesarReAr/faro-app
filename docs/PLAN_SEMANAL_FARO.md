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
