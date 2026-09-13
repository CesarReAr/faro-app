-- FARO · EJECUTADO en Supabase (proyecto faro-app) el 13/09/2026 desde el SQL Editor.
-- Sustituye a 2026_09_13_FASE0_plan_semanal_columnas.sql y 2026_09_13_FASEA_focos_tienda.sql,
-- que se quedaron cortos. Diagnóstico previo (solo lectura) del mismo día:
--  - plan_semanal_faro y objetivos_semanales_faro tenían 0 filas.
--  - Ninguna de las dos tenía clave única (solo la primaria por id). FARO guarda con
--    upsert onConflict, que exige esa clave: por eso NUNCA se había guardado nada,
--    ni plan ni objetivos, aunque las columnas hubieran existido.
--  - objetivos_semanales_faro.familia era NOT NULL: un objetivo de venta no cabía.
--  - public.faro_is_admin() no existe. Las tablas reales usan políticas *_own
--    (cada usuario borra lo suyo); focos_tienda_faro sigue ese mismo patrón.
-- Resultado comprobado: plan 18 columnas; objetivos 21 columnas y familia opcional;
-- focos_tienda_faro 23 columnas, RLS activo y 4 políticas; cuatro claves únicas.

begin;

-- 1. plan_semanal_faro
alter table public.plan_semanal_faro add column if not exists evaluacion_explicacion text;
alter table public.plan_semanal_faro add column if not exists observaciones text;
alter table public.plan_semanal_faro add column if not exists cierre jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='plan_semanal_faro_user_semana_tienda_key') then
    alter table public.plan_semanal_faro add constraint plan_semanal_faro_user_semana_tienda_key unique (user_id, semana_inicio, tienda);
  end if;
end $$;

-- 2. objetivos_semanales_faro: modelo genérico
alter table public.objetivos_semanales_faro add column if not exists tipo_objetivo text;   -- VENTA · SELECTIVO · ...
alter table public.objetivos_semanales_faro add column if not exists categoria text;       -- GENERAL · FAMILIA_03 · FAMILIA_08 · ...
alter table public.objetivos_semanales_faro add column if not exists valor_objetivo numeric;
alter table public.objetivos_semanales_faro add column if not exists unidad text;          -- EUR · UDS · PCT
alter table public.objetivos_semanales_faro add column if not exists valor_base numeric;   -- p. ej. LY
alter table public.objetivos_semanales_faro add column if not exists pct_aplicado numeric;
alter table public.objetivos_semanales_faro add column if not exists fuente text;          -- IMPORT_EXCEL · MANUAL · FUTURA_INTEGRACION
alter table public.objetivos_semanales_faro add column if not exists observaciones text;
alter table public.objetivos_semanales_faro alter column familia drop not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='objetivos_semanales_faro_user_semana_tienda_familia_key') then
    alter table public.objetivos_semanales_faro add constraint objetivos_semanales_faro_user_semana_tienda_familia_key unique (user_id, semana_inicio, tienda, familia);
  end if;
  if not exists (select 1 from pg_constraint where conname='objetivos_semanales_faro_clave_generica_key') then
    alter table public.objetivos_semanales_faro add constraint objetivos_semanales_faro_clave_generica_key unique (user_id, semana_inicio, tienda, tipo_objetivo, categoria);
  end if;
end $$;

-- 3. focos_tienda_faro
create table if not exists public.focos_tienda_faro (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  semana_inicio date not null, semana_fin date not null, tienda text not null,
  kpi_principal text, kpi_texto_original text, cumplio_anterior text, problema text,
  accion_principal text, accion_secundaria text, foco_secundario text, prioridad text,
  accion_club text, observaciones text, responsable text, fecha_envio date,
  formato_origen text, archivo_nombre text, archivo_hash text, fila_origen integer,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint focos_tienda_faro_user_semana_tienda_key unique (user_id, semana_inicio, tienda)
);
create index if not exists focos_tienda_faro_user_semana_idx on public.focos_tienda_faro (user_id, semana_inicio);
create index if not exists focos_tienda_faro_user_hash_idx on public.focos_tienda_faro (user_id, archivo_hash);
alter table public.focos_tienda_faro enable row level security;
drop policy if exists focos_tienda_select_own on public.focos_tienda_faro;
create policy focos_tienda_select_own on public.focos_tienda_faro for select to authenticated using (auth.uid() = user_id);
drop policy if exists focos_tienda_insert_own on public.focos_tienda_faro;
create policy focos_tienda_insert_own on public.focos_tienda_faro for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists focos_tienda_update_own on public.focos_tienda_faro;
create policy focos_tienda_update_own on public.focos_tienda_faro for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists focos_tienda_delete_own on public.focos_tienda_faro;
create policy focos_tienda_delete_own on public.focos_tienda_faro for delete to authenticated using (auth.uid() = user_id);

commit;
