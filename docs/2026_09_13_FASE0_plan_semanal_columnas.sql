-- SUSTITUIDO el 13/09/2026 por 2026_09_13_EJECUTADO_plan_objetivos_focos.sql (este se quedaba corto: faltaban claves únicas y faro_is_admin no existe). No ejecutar.
-- FARO · GESTIÓN SEMANAL · FASE 0
-- Completar plan_semanal_faro con las columnas que el código ya usa.
-- PROPUESTA · NO EJECUTADA · 13/09/2026
--
-- Por qué:
--  La tabla plan_semanal_faro existe en Supabase, pero se creó sin tres columnas
--  que FARO envía al guardar el plan: evaluacion_explicacion, observaciones y
--  cierre. Comprobado el 13/09/2026 consultando la base: "column
--  plan_semanal_faro.cierre does not exist". Resultado: el guardado del plan
--  falla entero y el plan, los mensajes y el cierre (la memoria de gestión)
--  quedan solo en el navegador.
--
-- Qué hace:
--  - Añade las tres columnas. Nada más.
--  - No borra, no renombra y no modifica ninguna fila ni ninguna columna existente.
--  - No toca claves únicas ni políticas RLS: las políticas son por fila.
--  - objetivos_semanales_faro ya está completa: no se toca.
--
-- Impacto:
--  - Las filas que ya existan quedan con las tres columnas vacías (null).
--  - La web publicada sigue funcionando igual.
--  - Desde la rama gestion-semanal/desarrollo, FARO comprueba estas columnas por
--    su nombre y, en cuanto existan, guarda el plan en Supabase.
--
-- Marcha atrás (solo se pierde lo guardado en esas tres columnas):
--   alter table public.plan_semanal_faro drop column if exists cierre;
--   alter table public.plan_semanal_faro drop column if exists observaciones;
--   alter table public.plan_semanal_faro drop column if exists evaluacion_explicacion;

alter table public.plan_semanal_faro
  add column if not exists evaluacion_explicacion text;

alter table public.plan_semanal_faro
  add column if not exists observaciones text;

alter table public.plan_semanal_faro
  add column if not exists cierre jsonb;

-- Comprobación: deben salir las 18 columnas, incluidas las tres nuevas.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'plan_semanal_faro'
order by ordinal_position;
