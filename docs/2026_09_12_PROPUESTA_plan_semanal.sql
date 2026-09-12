-- FARO · PLAN SEMANAL · dos tablas nuevas
-- PROPUESTA · NO EJECUTADA · 12/09/2026
--
-- Qué se reutiliza y no se toca:
--  - datos_diarios_faro: resultado de la semana anterior (ventas, tickets, AOV,
--    UPT, entradas, conversión y las cuatro palancas). No se modifica.
--  - focos_rapport_faro: el foco de la semana anterior ya vive aquí
--    (tienda, semana, prioridad_foco, motivo_foco, accion_recomendada, estado).
--    El plan semanal lo LEE; no se duplica ni se cambia esa tabla.
--  - El mensaje se guarda dentro del propio plan: no hay tabla de mensajes.
--
-- Nuevo:
--  1) plan_semanal_faro       · un plan por usuario, semana y tienda
--  2) objetivos_semanales_faro · objetivos por usuario, semana, tienda y familia
--
-- Multiusuario: todo va por user_id y por tienda, sin listas fijas de tiendas.
-- Las políticas RLS copian el patrón que ya usa FARO: cada usuario ve y escribe
-- lo suyo, y el borrado queda reservado al administrador.
--
-- El mensaje del área se guarda como una fila más con tienda = 'AREA'.
--
-- Marcha atrás (no toca ninguna tabla existente):
--   drop table if exists public.objetivos_semanales_faro;
--   drop table if exists public.plan_semanal_faro;

-- ───────────────────────── 1. PLAN SEMANAL ─────────────────────────
create table if not exists public.plan_semanal_faro (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  semana_inicio date not null,
  semana_fin date not null,
  tienda text not null,                      -- 'T13'... o 'AREA' para el mensaje del área
  foco_anterior text,
  evaluacion_foco_anterior text,             -- FUNCIONO · FUNCIONO_PARCIALMENTE · NO_FUNCIONO · SIN_DATOS
  evaluacion_explicacion text,
  decision_nueva_semana text,                -- MANTENER · AJUSTAR · CAMBIAR
  foco_nuevo text,
  kpi_objetivo text,
  accion text,
  observaciones text,
  mensaje_semanal text,
  estado text not null default 'BORRADOR',   -- BORRADOR · PREPARADO · ENVIADO · CERRADO
  cierre jsonb,                              -- memoria del cierre: objetivo, real, cumplimiento, lectura
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, semana_inicio, tienda)
);

alter table public.plan_semanal_faro
  drop constraint if exists plan_semanal_faro_estado_check;
alter table public.plan_semanal_faro
  add constraint plan_semanal_faro_estado_check
  check (estado in ('BORRADOR','PREPARADO','ENVIADO','CERRADO'));

alter table public.plan_semanal_faro
  drop constraint if exists plan_semanal_faro_evaluacion_check;
alter table public.plan_semanal_faro
  add constraint plan_semanal_faro_evaluacion_check
  check (evaluacion_foco_anterior is null or evaluacion_foco_anterior in
    ('FUNCIONO','FUNCIONO_PARCIALMENTE','NO_FUNCIONO','SIN_DATOS'));

alter table public.plan_semanal_faro
  drop constraint if exists plan_semanal_faro_decision_check;
alter table public.plan_semanal_faro
  add constraint plan_semanal_faro_decision_check
  check (decision_nueva_semana is null or decision_nueva_semana in
    ('MANTENER','AJUSTAR','CAMBIAR'));

create index if not exists plan_semanal_faro_user_semana_idx
  on public.plan_semanal_faro (user_id, semana_inicio);

alter table public.plan_semanal_faro enable row level security;

drop policy if exists plan_semanal_select_own on public.plan_semanal_faro;
create policy plan_semanal_select_own on public.plan_semanal_faro
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists plan_semanal_insert_own on public.plan_semanal_faro;
create policy plan_semanal_insert_own on public.plan_semanal_faro
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists plan_semanal_update_own on public.plan_semanal_faro;
create policy plan_semanal_update_own on public.plan_semanal_faro
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists plan_semanal_delete_admin on public.plan_semanal_faro;
create policy plan_semanal_delete_admin on public.plan_semanal_faro
  for delete to authenticated using (auth.uid() = user_id and public.faro_is_admin());

-- ────────────────────── 2. OBJETIVOS SEMANALES ─────────────────────
create table if not exists public.objetivos_semanales_faro (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  semana_inicio date not null,
  semana_fin date not null,
  tienda text not null,
  familia text not null,                     -- '03', '08'...
  descripcion_familia text,                  -- 'Maquillaje Selectivo', 'Tratamiento Selectivo'
  unidades_objetivo numeric,
  euros_objetivo numeric,
  regla_objetivo text,                       -- p. ej. 'LY_MISMA_SEMANA_MAS_10'
  fuente_archivo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, semana_inicio, tienda, familia)
);

create index if not exists objetivos_semanales_faro_user_semana_idx
  on public.objetivos_semanales_faro (user_id, semana_inicio);

alter table public.objetivos_semanales_faro enable row level security;

drop policy if exists objetivos_semanales_select_own on public.objetivos_semanales_faro;
create policy objetivos_semanales_select_own on public.objetivos_semanales_faro
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists objetivos_semanales_insert_own on public.objetivos_semanales_faro;
create policy objetivos_semanales_insert_own on public.objetivos_semanales_faro
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists objetivos_semanales_update_own on public.objetivos_semanales_faro;
create policy objetivos_semanales_update_own on public.objetivos_semanales_faro
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists objetivos_semanales_delete_admin on public.objetivos_semanales_faro;
create policy objetivos_semanales_delete_admin on public.objetivos_semanales_faro
  for delete to authenticated using (auth.uid() = user_id and public.faro_is_admin());

-- Comprobación final: las dos tablas vacías y con RLS activo.
select table_name,
       (select count(*) from pg_policies p where p.tablename = t.table_name) as politicas
from information_schema.tables t
where table_schema = 'public'
  and table_name in ('plan_semanal_faro','objetivos_semanales_faro');
