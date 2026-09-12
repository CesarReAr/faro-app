# Rapport del trabajo en FARO · 11 y 12 de septiembre de 2026

Estado al cierre: **todo guardado en Git, nada publicado en internet, un SQL pendiente de ejecutar.**

---

## 1. Lo primero: dónde está FARO ahora

Antes había copias de FARO en cinco sitios y no se sabía cuál era la buena. Ahora hay **una sola estructura**:

```
C:\Proyectos\FARO\
  LEEME.md          mapa de la carpeta
  app\              EL FARO MAESTRO. Aquí se trabaja
    index.html
    docs\           documentos y los SQL propuestos
  plantillas\       el Excel de objetivos y resultados
  archivo\          copias antiguas (Codex, la del 09/09, los html del Escritorio)
  pruebas\          las seis baterías de pruebas
```

**Para abrir FARO:** `Windows + R` → `C:\Proyectos\FARO\app\index.html`

No queda nada de FARO en Escritorio, Descargas ni en la carpeta antigua del usuario. Lo de OneDrive (presentación del comité, ventas de prueba) está en `Proyectos IA\04 Archivado\FARO`, y sigue en la nube.

---

## 2. Fallos que estaban rompiendo FARO y ya no

| Fallo | Desde cuándo | Efecto |
|---|---|---|
| Error de código en la subida de archivos | subida del 03/09 | **Toda** subida de CSV o Excel avisaba "No se ha podido leer" y no rellenaba la fecha sola |
| Se exigían ventas o tickets | siempre | Un CSV de solo entradas se rechazaba |
| "1.300" se leía como 1,3 | siempre | 1.300 entradas se guardaban como 1,3 |
| Una dirección se tomaba por tienda | siempre | "Av. Cerdanyola, 18" se leía como la tienda T18 |
| Tienda saltada en el Seguimiento | siempre | Si faltaba su fila en AYER o AYER LY, **no se guardaba nada suyo ese día** |
| Objetivo cargado que no salía en los mensajes | al crear el plan | El objetivo se cargaba pero no aparecía en ningún mensaje |
| Semana equivocada al cargar objetivos | al crear el plan | Los objetivos del día 14 podían guardarse en la semana del 7 |

---

## 3. Lo que se ha construido

### Lectura de archivos
- CSV con coma, punto y coma o tabulador, en cualquier codificación, incluidos los "Unicode" de Excel y los antiguos ANSI.
- Cabecera en cualquier fila, no solo la primera.
- **Se aceptan ficheros parciales**: solo entradas, solo ventas, solo tickets o KPI sueltos.
- **Una columna que no viene en el archivo nunca borra un dato ya guardado.**
- Selector "Qué contiene el archivo" para cuando FARO no lo reconoce, y la opción de guardar solo el archivo.
- Los errores dicen en qué paso falla: separador, cabecera, tienda, métrica o guardado.

### Borrados
- Se quitaron todos los botones que borraban histórico, incluido "Vaciar archivos".
- Después, a petición tuya, se repusieron **dos botones con seguridad**: "Quitar solo archivo" (no toca datos) y "Quitar carga y datos", que pide confirmar el resumen, escribir el nombre exacto del archivo y escribir `BORRAR` con el número de filas.
- No existe borrado masivo. Los borrados de promociones y FOCO siguen desactivados.

### Días no comparables (festivos y cierres)
- Selector al subir: día normal, LY cerrado, CY cerrado, apertura parcial y incidencia.
- **Regla que costó tres vueltas: no comparable no es no computable.** La venta real siempre suma al día, la semana, el mes y el área. La marca solo saca ese día del % frente a LY.
- Se muestran los dos resultados: **total real** y **comparable**, con la frase que explica la diferencia de calendario.
- Caso de control: 1.000/900 normal + 2.000/0 con LY cerrado + 0/1.800 con CY cerrado → real 3.000/2.700, comparable 1.000/900, **+11,11%**.

### Dato manual
- Formulario para meter a mano un día cuando la fuente oficial llega tarde, como T13 hasta el lunes.
- Suma como cualquier dato real y se marca "pendiente de validar".
- Al llegar el dato oficial manda el oficial **métrica a métrica**; si coincide queda validado, si difiere avisa con los dos valores, y **la fila manual nunca se borra**.

### Plan Semanal
Pestaña nueva con el ciclo completo: **resultado anterior → evaluación del foco → decisión → foco nuevo → objetivo → mensaje → cierre → memoria.**
- Evalúa el foco de la semana pasada: funcionó, funcionó parcialmente, no funcionó o sin datos, **sin atribuir causalidad**.
- Propone mantener, ajustar o cambiar, y la decisión final es tuya.
- Genera el mensaje de cada tienda y el del área. **No hay módulo de mensajes aparte: sale del análisis.**
- Objetivo de venta por tienda en % sobre la misma semana del año pasado, con veredicto **CONSEGUIDO / NO CONSEGUIDO** y lo que faltó.
- Objetivo de Selectivo **por las dos familias**: Color (03) y Tratamiento (08), nunca sumadas en una cifra.
- Cierre con cumplimiento de cada familia y del total.

### El Excel de objetivos
`C:\Proyectos\FARO\plantillas\FARO_Objetivos_y_Resultados.xlsx` (copia igual en `Retail Intelligence\_ENTRADA`)

| Hoja | Para qué |
|---|---|
| Instrucciones | La guía |
| Objetivos_Familias | Objetivo de Color y Tratamiento. Pones **LY** y **Pct objetivo** y FARO calcula los euros |
| Resultados_Familias | Lo vendido de esas familias; entra solo en el cierre |
| Objetivo_Ventas | **El objetivo de venta**, por semana o por mes, en euros o en % |

- Prellenado con tu PDF del área: 155 uds y 3.822,50 € en Color, 205 uds y 7.932,10 € en Tratamiento, **total 11.754,60 €**.
- Semana del **lunes 14/09/2026**.
- La columna Semana se entiende como fecha de Excel, `2026-09-14` o `14/09/2026`, y **manda la del fichero**.
- Se sube en Plan Semanal → "Objetivos de la semana", y FARO lee las cuatro hojas de una vez.

---

## 4. Pruebas

Seis baterías automáticas en `C:\Proyectos\FARO\pruebas`. Para lanzarlas: abre esa carpeta en una terminal y escribe `node` y el nombre del fichero.

| Batería | Qué comprueba |
|---|---|
| test_lectura.js | Lectura de CSV y Excel en todos los formatos |
| test_comparabilidad.js | Días no comparables y dato manual |
| test_plan_semanal.js | Los casos A a G del plan |
| test_plantilla_excel.js | El Excel de objetivos |
| test_fechas_plantilla.js | Fechas y el cálculo del objetivo |
| test_objetivos_pdf.js | Los objetivos sacados del PDF |

Incluyen **pruebas de regresión**: sin marcas de festivo y sin dato manual, FARO da exactamente los mismos números que antes de tocar nada.

---

## 5. Lo que queda pendiente

1. **Ejecutar un SQL.** `app\docs\2026_09_12_PROPUESTA_plan_semanal.sql` crea las dos tablas del plan. **Sin él, el plan y los objetivos viven solo en este navegador.** Se pega entero en supabase.com → SQL Editor → Run. Yo no puedo ejecutarlo: no hay credencial de administrador en el equipo, y es mejor así.
2. **Publicar.** La web `cesarrear.github.io/faro-app` sigue con la versión del 10/09. Todo el trabajo está en la rama local `fase-puente-lectura-archivos`, en siete commits.
3. **Borrar un Excel sobrante.** En `plantillas` hay un `FARO_Objetivos_y_Resultados_nuevo.xlsx` que sobra y que tenías abierto en Excel. Cierra Excel y se borra.
4. **Dos SQL opcionales**, solo si los echas en falta: la nota del día no comparable y las observaciones del dato manual.
5. **Pendientes menores anotados:** el resultado real por familia habría que cargarlo de una fuente en vez de teclearlo; conectar las señales del motor de tendencias con la propuesta de foco; y los porcentajes ya no se guardarían solo en el navegador.

---

## 6. Dos avisos importantes

- **El repositorio de GitHub es público** y el `index.html` lleva dentro datos de tus tiendas. Antes de subir algo nuevo con datos, se pregunta.
- **`C:\Proyectos` no está en OneDrive.** La copia de seguridad del maestro es GitHub y los commits locales; si formatearas el equipo, se perdería lo no publicado.

---

Documentos de detalle, en `C:\Proyectos\FARO\app\docs`:
`FASE_PUENTE_A_B_LECTURA_ARCHIVOS_FARO.md` y `PLAN_SEMANAL_FARO.md`.
