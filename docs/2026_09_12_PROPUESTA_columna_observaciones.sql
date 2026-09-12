-- FARO · Observaciones de una fila diaria (sobre todo para el dato manual)
-- PROPUESTA · NO EJECUTADA · 12/09/2026
--
-- Tabla:   public.datos_diarios_faro
-- Columna: observaciones (text, opcional, máximo 500 caracteres)
--
-- Para qué:
--  - Dejar escrito por qué se metió un dato a mano ("Seguimiento sin llegar por
--    la fiesta del viernes", "venta confirmada por la encargada"...).
--  - Se enseña junto a la etiqueta "Dato manual pendiente de validar".
--
-- Impacto:
--  - Las filas que ya existen quedan con la observación vacía (null).
--  - No cambia ningún número, ninguna clave ni ninguna política RLS.
--  - La web publicada sigue funcionando: no envía la columna.
--  - Hasta que se ejecute, el formulario manual funciona sin ese campo.
--
-- Marcha atrás (solo se pierden las observaciones):
--   alter table public.datos_diarios_faro drop constraint if exists datos_diarios_faro_observaciones_len;
--   alter table public.datos_diarios_faro drop column if exists observaciones;

alter table public.datos_diarios_faro
  add column if not exists observaciones text;

alter table public.datos_diarios_faro
  drop constraint if exists datos_diarios_faro_observaciones_len;

alter table public.datos_diarios_faro
  add constraint datos_diarios_faro_observaciones_len
  check (observaciones is null or char_length(observaciones) <= 500);

-- Comprobación: debe salir 0 filas con observación y el total de filas de la tabla.
select count(*) filter (where observaciones is not null) as filas_con_observacion,
       count(*) as filas_totales
from public.datos_diarios_faro;
