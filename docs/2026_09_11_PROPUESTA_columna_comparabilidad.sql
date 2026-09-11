-- FARO · Día no comparable (festivos, cierres, aperturas parciales)
-- PROPUESTA · NO EJECUTADA · 11/09/2026
--
-- Tabla:   public.datos_diarios_faro
-- Columna: comparabilidad  (text, obligatoria, por defecto 'normal')
-- Valores: normal · ly_cerrado · cy_cerrado · ly_parcial · cy_parcial · incidencia
--
-- Impacto:
--  - Las filas que ya existen quedan como 'normal': no cambia ningún número.
--  - No toca datos, claves únicas ni políticas RLS (son por fila, no por columna).
--  - Añadir una columna con valor por defecto constante no reescribe la tabla.
--  - La web publicada ahora mismo sigue funcionando: no envía la columna y el
--    upsert no la sobrescribe.
--  - El FARO maestro detecta la columna solo y activa el selector al subir.
--
-- Marcha atrás (solo se pierden las marcas, nunca los datos):
--   alter table public.datos_diarios_faro drop constraint if exists datos_diarios_faro_comparabilidad_check;
--   alter table public.datos_diarios_faro drop column if exists comparabilidad;

alter table public.datos_diarios_faro
  add column if not exists comparabilidad text not null default 'normal';

alter table public.datos_diarios_faro
  drop constraint if exists datos_diarios_faro_comparabilidad_check;

alter table public.datos_diarios_faro
  add constraint datos_diarios_faro_comparabilidad_check
  check (comparabilidad in ('normal','ly_cerrado','cy_cerrado','ly_parcial','cy_parcial','incidencia'));

-- Comprobación: todas las filas existentes deben salir como 'normal'.
select comparabilidad, count(*) as filas
from public.datos_diarios_faro
group by comparabilidad;
