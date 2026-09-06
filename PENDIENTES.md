# FARO · Pendientes y decisiones

Recogido el 06/09/2026 sobre el commit `e14234b`.
Documento hermano de `FUNCIONAMIENTO.md`, que explica cómo trata los datos.

---

## 1. Estado de las ocho pestañas

| Pestaña | Estado | Qué pasa |
|---|---|---|
| Mi Área | Funciona | Datos reales. Le falta el orden y el diagnóstico. |
| Rapport | A medias | Secciones duplicadas y listados recortados. |
| Ranking | Funciona | Ordena por el KPI elegido. |
| Semanas | Funciona | Evolución semanal desde el histórico. |
| Mi Posición | Recién hecha | Conectada al cierre de agosto. Se actualiza a mano. |
| Mensajes | Funciona | Mensaje por tienda, periodo y tono. |
| Promociones | Funciona | Alta, edición, imagen y estado por fechas. |
| Ficheros | Funciona | Carga, guardado y borrado por confirmación escrita. |

---

## 2. Arreglos pendientes

### 2.1 «Sin diagnóstico cargado» no se quita nunca

Es HTML fijo en la línea 264, dentro de `#areaAlerts`. **Ninguna función escribe
ahí.** El aviso se queda puesto tengas datos o no.

**Qué hacer:** que `renderSG` escriba las alertas reales del área cuando hay
datos, y deje el aviso solo cuando de verdad no hay nada cargado.

### 2.2 Tiendas prioritarias y Riesgos detectados son lo mismo

Las dos salen de la lista `enriched` ordenada por `score`. Riesgos es
`enriched.filter(score>=3).slice(0,3)`, un subconjunto de prioritarias. La misma
tienda aparece dos veces con distinto título.

**Qué hacer:** una sola sección, o separarlas de verdad. Prioritarias por
resultado y riesgos por señal concreta —conversión, UPT, tráfico— que no es lo
mismo.

### 2.3 El rapport recorta tiendas

- **Diagnóstico KPI:** `enriched.slice(0,7)`, solo 7 de 10.
- **Acciones recomendadas:** `priorities`, y si no hay, `enriched.slice(0,3)`.

**Qué hacer:** las diez tiendas en las dos secciones. Es quitar los dos `slice`.
El rapport es de área, no de las que peor van.

### 2.4 Orden de las tiendas

`renderSG` hace `stores.map(...)` sin ordenar: salen en el orden de declaración,
T13, T26, T27… Sin criterio comercial.

**Qué hacer:** ordenar por resultado. **Falta decidir el sentido.**

### 2.5 Mi Posición no se actualiza sola

Las cifras están en la constante `posicionCierre`, con el periodo etiquetado.
Hay que tocarla cada mes cuando llegue el informe del CEO.

**Qué hacer:** o avisar cada mes para cambiarla a mano, o añadir el informe de
cierre como un tipo de fichero más para que se cargue como los otros.

### 2.6 La oferta de la semana no existe

«Promociones activas en el periodo» funciona y filtra por solape de fechas. Pero
**no hay concepto de oferta de la semana** distinto de una promoción: hoy habría
que darla de alta como promoción de siete días.

**Falta decidir** si debe ser otra cosa y en qué se diferencia.

### 2.7 Política de archivos subidos

Los archivos se guardan en Supabase y se listan en Ficheros. Se pueden borrar de
tres formas. **No hay política.** Con un comparativo diario, en un año son unas
250 entradas.

**Propuesta:** no borrar nunca los datos y limpiar solo el listado de archivos
pasados unos meses. Los datos viven en `datos_diarios_faro` y no dependen del
archivo.

### 2.8 `dias_incluidos` se guarda y no se lee

Hoy no molesta porque los totales de semana y mes salen bien. Molestará el día
que se calculen medias diarias: trataría el bloque de viernes+sábado como un
solo día y la media de T13 saldría inflada.

---

## 3. Preguntas ya resueltas

**¿Una promoción nueva borra la actual?** No. Conviven. `_activePromosForArea`
devuelve todas las que solapan con el periodo y cada una lleva su estado. Solo
desaparece la que borres a mano.

**¿La contraseña de borrado?** Ya no existe. Se sustituyó por teclear el nombre
del archivo. Vaciar la biblioteca sigue pidiendo rol `admin`.

---

## 4. Decisiones que dependen de César

1. **Orden de las tiendas:** ¿peor primero, para atacar lo urgente, o mejor
   primero? ¿Fijo o con selector?
2. **Oferta de la semana:** ¿es una promoción de siete días o un concepto
   propio? Si es propio, en qué se diferencia.
3. **Archivos:** ¿se acepta la propuesta de conservar datos y limpiar solo el
   listado?
4. **Mi Posición:** ¿aviso mensual para actualizarla a mano, o cargarla como
   fichero?
5. **Calculadora de Foco:** ¿se enlaza desde FARO o se queda aparte?

---

## 5. Orden de trabajo propuesto

1. Quitar los recortes del rapport. Las diez tiendas. Es lo que más se nota.
2. Arreglar «Sin diagnóstico cargado».
3. Fundir prioritarias y riesgos, o separarlas con criterios distintos.
4. Ordenar las tiendas, cuando esté decidido el sentido.
5. Decidir oferta de la semana y política de archivos.

---

## 6. Herramientas del área que no están en FARO

**Calculadora de Foco.** Responde a qué KPI tocar para llegar al objetivo: dado
un objetivo y el nivel de partida de la tienda, calcula las tres vías —solo
tickets, solo ticket medio, o las dos— y dice cuál cabe dentro del techo real de
esa tienda. Lee el Seguimiento Diario y el comparativo, saca el lastre positivo
y negativo y genera rapport de área o de una tienda.

- Copia autónoma: `Retail Intelligence\01_Maestro\2026_09_04_CALCULADORA_FOCO_TIENDAS.html`
- **No está subida a GitHub** por decisión de César del 04/09/2026.
