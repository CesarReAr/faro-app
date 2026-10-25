# FARO · Pendientes y decisiones

Al día a 25/10/2026. Documento hermano de `FUNCIONAMIENTO.md`, que explica cómo trata los datos.
La lista del 06/09 (ocho pestañas, recortes del rapport, orden de tiendas) está superada y se ha
quitado: lo que quedaba vivo está aquí.

---

## 1. Decisiones tomadas

1. **Orden de las tiendas** (12/10/2026): peor primero, fijo. Fichas de Mi Área por % de ventas
   vs LY, de menor a mayor; sin % comparable, al final. El Rapport ordena por nivel de riesgo y,
   a igual nivel, la que más cae. El Ranking sigue de mejor a peor.
2. **Oferta de la semana:** tipo propio «Oferta semanal» en Promociones, con bloque aparte en
   Mi Área y Rapport, una por semana.
3. **Archivos** (12/10/2026): los datos no se borran nunca. Del listado de Ficheros salen solas
   las cargas anteriores a los tres meses previos al actual; la casilla «Ver cargas antiguas y de
   meses cerrados» las enseña.
4. **Mi Posición:** pestaña oculta desde el lanzamiento multiusuario.
5. **Calculadora de Foco** (13/10/2026): se queda aparte, sin enlace desde FARO.
6. **Entradas y conversión** (14/10/2026): solo del comparativo, nunca del KPIS.
7. **Campañas** (24/10/2026): se archivan en vez de borrarse; el historial se descarga en Excel.

---

## 2. Mejoras propuestas (revisión del 25/10/2026)

Por impacto:

1. **Evaluar el foco al cerrar la semana.** ¿El foco atacaba el KPI más flojo de la semana
   anterior? ¿Mejoró ese KPI? ¿La autoevaluación de la tienda («Sí cumplió») cuadra con los
   datos? Y un campo de evidencia en el FOCO (visita, tickets revisados) para poder hablar de
   ejecución demostrada y no solo de resultado.
2. **Semáforo de carga antes de cerrar o generar el plan:** días de la semana cargados (sobre todo
   viernes y sábado), comparativo de la semana, focos y objetivos. Hoy se puede cerrar una semana
   a la que le falta el fin de semana.
3. **Importación sin guardar:** avisar al cambiar de pestaña o dejar un aviso fijo cuando hay una
   importación de objetivos leída y sin guardar.
4. **Cifras raras en objetivos:** avisar si un objetivo se separa mucho del de la semana anterior
   o del resto de tiendas.
5. **Festivos en la base del año pasado:** avisar cuando la semana del año pasado que da la base
   del objetivo tenía un festivo y la de este año no (o al revés).
6. **Foco de la tienda frente a foco propuesto:** distinguirlos siempre en el plan y avisar si hay
   focos nuevos en Drive después de la última importación.
7. **Base técnica:**
   - arreglar las pruebas que fallan desde hace tiempo (lista en la skill de pruebas), y poner al
     día `test_kpis_faro`, que se salta porque le falta un fichero y, con él, da 17 fallos por la
     regla de entradas del 14/10;
   - borrar las funciones que nadie llama (unas 22, ~460 líneas), comprobando una a una;
   - más adelante, partir `index.html` en ficheros (CSS y un script por pestaña), adaptando antes
     la extracción de las pruebas.

---

## 3. Formación + reto · fase 2

Fase 1 (24/10/2026): en Promociones, una formación con uno o varios retos por tienda y resultado
tecleado a mano. Se guarda en `promociones_faro` con tipo `formacion_reto` y la columna jsonb
`reto`. La tienda cumple solo si cumple todos los retos.

Pendiente:

1. **Resultado automático.** FARO no tiene venta por SKU ni por categoría de marca. Hace falta un
   fichero que la traiga; el importador añadiría filas con `fuente:'auto'` y el manual seguiría
   ganando.
2. **Impacto de la formación.** Unidades 7 días antes frente a 7 días después, para responder qué
   formaciones generan resultado. Depende del punto 1.
3. **Vista de empresa y Dirección.** Hoy cada coordinador ve solo las que da de alta y sus tiendas.
4. **Objetivo distinto por tienda.** El cálculo ya lo admite (`objetivos_tienda`); falta la casilla
   en el formulario.

---

## 4. Limitaciones conocidas

- **`dias_incluidos` solo lo usan los bloques.** Una media diaria tendría que contar los días del
  bloque, no las filas.
- **Mi Área («Ayer») se construye con la fecha más alta del histórico.** Si las fuentes quedan en
  fechas distintas, la venta es la de la fecha más reciente.

---

## 5. Herramientas del área que no están en FARO

**Calculadora de Foco.** Dado un objetivo y el nivel de partida de la tienda, calcula las tres
vías (solo tickets, solo ticket medio o las dos) y dice cuál cabe dentro del techo real de la
tienda. No está en GitHub por decisión del 04/09/2026.
