-- FARO · GESTIÓN SEMANAL · FASE A
-- Foco propuesto por la tienda: una fila por usuario, semana y tienda.
-- PROPUESTA · NO EJECUTADA · 13/09/2026
--
-- Por qué una tabla nueva y no focos_rapport_faro:
--  - focos_rapport_faro es el rapport FOCO del coordinador y alimenta el cruce
--    de la pestaña FOCO. Mezclar ahí lo que propone la tienda rompe ese cruce.
--  - focos_rapport_faro no tiene clave única (admite duplicados), guarda el KPI
--    como texto libre y su borrado está desactivado en el código.
--  - Aquí el KPI va normalizado (aov, upt, conversion...) y además se conserva
--    el texto original que escribió la tienda.
--
-- Qué NO toca:
--  - Ninguna tabla existente. Ni datos_diarios_faro, ni archivos_faro, ni
--    focos_rapport_faro, ni plan_semanal_faro, ni sus políticas RLS.
--
-- Trazabilidad del fichero:
--  - archivo_nombre y archivo_hash (SHA-256 del fichero subido) en cada fila.
--    Con el hash FARO avisa si un fichero ya se había subido.
--  - No hay clave foránea a archivos_faro a propósito: esa tabla no se toca en
--    esta fase y el fichero original no se guarda todavía en Storage (hoy no
--    existe código de subida y el bucket no está verificado).
--
-- Multiusuario: igual que el resto de FARO, cada usuario ve y escribe lo suyo;
-- el borrado queda al administrador (public.faro_is_admin, ya usada por las
-- tablas del plan semanal).
--
-- Marcha atrás (no afecta a nada más):
--   drop table if exists public.focos_tienda_faro;

create table if not exists public.focos_tienda_faro (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  semana_inicio date not null,               -- lunes de la semana del foco
  semana_fin date not null,                  -- domingo
  tienda text not null,                      -- 'T13', 'T26'...
  kpi_principal text,                        -- normalizado: aov, upt, conversion, entradas, tickets, ventas, selectivo, mv, club, oportunidad, unidades, otro
  kpi_texto_original text,                   -- tal como lo escribió la tienda: 'TM (Ticket Medio)'
  cumplio_anterior text,                     -- lo que declara la tienda sobre la semana anterior
  problema text,
  accion_principal text,
  accion_secundaria text,
  foco_secundario text,
  prioridad text,
  accion_club text,
  observaciones text,
  responsable text,
  fecha_envio date,
  formato_origen text,                       -- DRIVE_FOCO_SEMANAL · TABLA
  archivo_nombre text,
  archivo_hash text,                         -- SHA-256 del fichero
  fila_origen integer,                       -- fila del Excel de la que sale
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, semana_inicio, tienda)
);

create index if not exists focos_tienda_faro_user_semana_idx
  on public.focos_tienda_faro (user_id, semana_inicio);
create index if not exists focos_tienda_faro_user_hash_idx
  on public.focos_tienda_faro (user_id, archivo_hash);

alter table public.focos_tienda_faro enable row level security;

drop policy if exists focos_tienda_select_own on public.focos_tienda_faro;
create policy focos_tienda_select_own on public.focos_tienda_faro
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists focos_tienda_insert_own on public.focos_tienda_faro;
create policy focos_tienda_insert_own on public.focos_tienda_faro
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists focos_tienda_update_own on public.focos_tienda_faro;
create policy focos_tienda_update_own on public.focos_tienda_faro
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists focos_tienda_delete_admin on public.focos_tienda_faro;
create policy focos_tienda_delete_admin on public.focos_tienda_faro
  for delete to authenticated using (auth.uid() = user_id and public.faro_is_admin());

-- Comprobación: la tabla vacía y con 4 políticas.
select table_name,
       (select count(*) from pg_policies p where p.tablename = t.table_name) as politicas
from information_schema.tables t
where table_schema = 'public' and table_name = 'focos_tienda_faro';
