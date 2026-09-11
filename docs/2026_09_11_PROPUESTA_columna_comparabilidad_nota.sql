-- FARO · Nota del día no comparable (por ejemplo: "Diada", "obras", "cierre por inventario")
-- PROPUESTA · NO EJECUTADA · 11/09/2026
--
-- El estado ya existe: columna comparabilidad (ejecutada el 11/09/2026).
-- Equivale a "comparability_status"; no se crea otra columna con ese nombre.
--
-- Tabla:   public.datos_diarios_faro
-- Columna: comparabilidad_nota  (text, opcional, sin valor por defecto)
--
-- Impacto:
--  - Las filas existentes quedan con la nota vacía (null). No cambia ningún número.
--  - No toca claves únicas ni políticas RLS.
--  - Solo interpreta: FARO la enseña junto a "No comparable" y en Rapport.
--  - Límite de 200 caracteres para que no se use como campo de texto libre largo.
--
-- Marcha atrás (solo se pierden las notas):
--   alter table public.datos_diarios_faro drop constraint if exists datos_diarios_faro_comparabilidad_nota_len;
--   alter table public.datos_diarios_faro drop column if exists comparabilidad_nota;

alter table public.datos_diarios_faro
  add column if not exists comparabilidad_nota text;

alter table public.datos_diarios_faro
  drop constraint if exists datos_diarios_faro_comparabilidad_nota_len;

alter table public.datos_diarios_faro
  add constraint datos_diarios_faro_comparabilidad_nota_len
  check (comparabilidad_nota is null or char_length(comparabilidad_nota) <= 200);

select count(*) filter (where comparabilidad_nota is not null) as filas_con_nota,
       count(*) as filas_totales
from public.datos_diarios_faro;
