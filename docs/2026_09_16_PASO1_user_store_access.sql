-- FARO · PASO 1 · autorizacion por tienda, sin cambiar todavia la aplicacion
-- 16/09/2026 · NO EJECUTADO
--
-- QUE HACE
--   1. Crea public.user_store_access: la relacion usuario -> tiendas que hoy
--      no existe en la base de datos (vive en un campo de texto).
--   2. Crea public.faro_tiendas_autorizadas(): la funcion que a partir de aqui
--      responde "que tiendas puede ver quien esta conectado". Es la pieza que
--      permitira que las politicas RLS filtren por tienda sin recursion.
--   3. Copia las asignaciones que ya existen en usuarios.tiendas.
--   4. Cierra public.usuarios a la propia fila (lo que llamabamos 1C).
--
-- QUE NO HACE, A PROPOSITO
--   No toca ninguna tabla de datos. Ni una fila de ventas, objetivos, plan,
--   focos, promociones o archivos.
--   No cambia ninguna politica de esas tablas: siguen con auth.uid() = user_id.
--   No toca index.html: la aplicacion sigue leyendo usuarios.tiendas.
--   Es decir: al terminar, FARO funciona EXACTAMENTE igual que ahora.
--   La tabla nueva queda creada y poblada, pero todavia no la usa nadie.
--   Eso es deliberado: primero se monta la estructura, se comprueba que dice
--   lo mismo que el campo de texto, y solo despues se cambia la aplicacion.
--
-- CONTEXTO COMPROBADO EN ESTE PROYECTO (16/09/2026)
--   tiendas_faro        51 filas, 43 activas, T01..T86. Legible por authenticated.
--   usuarios            8 filas. RLS activa. Solo lectura para authenticated.
--                       Politica actual: usuarios_select_autenticados, using(true)
--                       -> hoy CUALQUIER usuario con sesion lee las 8 filas.
--   usuarios            NO tiene columna user_id: se casa por email.
--   auth.users          2 cuentas (Cesar y Joaquim). Las otras 6 filas de
--                       usuarios todavia no tienen cuenta.
--   _faroIdsTodasLasTiendas() (index.html:1473) es codigo inalcanzable porque
--                       tiendas_faro devuelve 43 activas: por eso se puede
--                       cerrar usuarios a la propia fila sin romper al admin.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · ENSAYO EN SECO · ejecutar SOLO esto primero
-- ═══════════════════════════════════════════════════════════
-- Solo lectura. Dos cosas:
--   a) quien seguiria viendo su fila de usuarios tras el cierre (bloque 3)
--   b) que asignaciones se van a copiar a la tabla nueva (bloque 2)
-- Si alguien sale en 'SE QUEDA SIN SU FILA', NO SIGAS: perderia sus tiendas.

select case when a.id is null then 'SE QUEDA SIN SU FILA · sin cuenta en auth.users'
            else 'OK' end                                            as tras_cerrar_usuarios,
       u.nombre,
       u.rol,
       coalesce(u.tiendas, '(ninguna)')                              as tiendas_texto,
       (select count(*)
          from regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
         where t ~ '^[Tt]?0*[0-9]{1,3}$'
           and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0)   as filas_que_se_copiaran
from public.usuarios u
left join auth.users a on lower(a.email) = lower(trim(u.email))
order by (a.id is null) desc, u.nombre;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · La tabla de asignaciones
-- ═══════════════════════════════════════════════════════════

begin;

create table if not exists public.user_store_access (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  tienda     text not null,
  nivel      text not null default 'coordinador'
             check (nivel in ('coordinador','lectura','carga')),
  activo     boolean not null default true,
  -- desde/hasta son el motivo de que una tienda pueda cambiar de coordinador
  -- sin migrar su historico: se cierra una fila y se abre otra. El dato de
  -- ventas sigue perteneciendo a la tienda, no a la persona.
  desde      date not null default current_date,
  hasta      date,
  created_at timestamptz not null default now(),
  unique (user_id, tienda, desde)
);

create index if not exists idx_usa_user
  on public.user_store_access(user_id) where activo;
create index if not exists idx_usa_tienda
  on public.user_store_access(tienda) where activo;

alter table public.user_store_access enable row level security;

revoke all    on public.user_store_access from anon;
revoke all    on public.user_store_access from authenticated;
grant  select on public.user_store_access to   authenticated;

-- Cada usuario ve sus propias asignaciones y nada mas. Las altas se hacen
-- desde el panel de Supabase (service_role, que se salta RLS y GRANT).
drop policy if exists usa_select_propio on public.user_store_access;
create policy usa_select_propio on public.user_store_access
  for select to authenticated
  using (user_id = auth.uid());

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · Copiar las asignaciones que ya existen
-- ═══════════════════════════════════════════════════════════
-- Reproduce exactamente _faroTiendasDelCampo() (index.html:1422):
--   trocea por lo que no sea letra o numero
--   acepta "T13", "13", "t013"; descarta lo demas y el cero
--   normaliza a 'T' + numero con dos digitos
-- Solo copia a quien ya tiene cuenta en auth.users (la FK lo exige).
-- Para las 6 filas sin cuenta, usuarios.tiendas sigue siendo el sitio donde
-- dejar preasignadas sus tiendas; se copian cuando se les invite.
-- Es idempotente: se puede repetir sin duplicar.

begin;

insert into public.user_store_access (user_id, tienda, nivel)
select distinct
       a.id,
       'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0'),
       'coordinador'
from public.usuarios u
join auth.users a on lower(a.email) = lower(trim(u.email))
cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
where t ~ '^[Tt]?0*[0-9]{1,3}$'
  and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0
on conflict (user_id, tienda, desde) do nothing;

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 3 · La funcion de autorizacion
-- ═══════════════════════════════════════════════════════════
-- Responde "que tiendas puede ver quien esta conectado".
--
-- SECURITY DEFINER es imprescindible: esta funcion la van a llamar las
-- politicas RLS de las tablas de datos, y necesita leer usuarios y
-- user_store_access sin que la RLS de esas tablas se aplique otra vez
-- (seria recursion infinita). Corre como su propietario, postgres.
-- Depende de que relforcerowsecurity siga en false, que hoy lo esta.
--
-- Los roles con todas las tiendas son los MISMOS que reconoce el frontend en
-- FARO_ROLES_TODAS_LAS_TIENDAS (index.html:1404): admin y visor_global.
-- Si algun dia se añade 'gerencia', hay que añadirlo EN LOS DOS SITIOS.

create or replace function public.faro_tiendas_autorizadas()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  -- a) rol con todas las tiendas -> todas las activas del catalogo
  select 'T' || lpad(substring(t.tienda from '([0-9]{1,3})'), 2, '0')
  from public.tiendas_faro t
  where t.activa is not false
    and substring(t.tienda from '([0-9]{1,3})') is not null
    and exists (
      select 1 from public.usuarios u
      where lower(trim(u.email)) = lower(auth.jwt() ->> 'email')
        and regexp_replace(lower(trim(translate(coalesce(u.rol,''),
              'áéíóúüñÁÉÍÓÚÜÑ','aeiounAEIOUN'))), '[[:space:]-]+','_','g')
            in ('admin','visor_global'))

  union

  -- b) el resto -> sus asignaciones vigentes
  select a.tienda
  from public.user_store_access a
  where a.user_id = auth.uid()
    and a.activo
    and a.desde <= current_date
    and (a.hasta is null or a.hasta >= current_date);
$$;

revoke all     on function public.faro_tiendas_autorizadas() from public, anon;
grant  execute on function public.faro_tiendas_autorizadas() to   authenticated;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 4 · Cerrar public.usuarios a la propia fila
-- ═══════════════════════════════════════════════════════════
-- Hoy la politica es using(true): cualquier usuario con sesion lee las 8
-- filas con los emails corporativos y el mapa de areas de todos. Con 8+
-- coordinadores entrando, eso sobra.
-- Se puede cerrar porque la unica lectura de la tabla entera que hace FARO
-- (_faroIdsTodasLasTiendas, index.html:1473) es inalcanzable.

begin;

drop policy if exists usuarios_select_autenticados on public.usuarios;

create policy usuarios_select_propio on public.usuarios
  for select to authenticated
  using (lower(trim(email)) = lower(auth.jwt() ->> 'email'));

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 5 · COMPROBACION · solo lectura, tras los commits
-- ═══════════════════════════════════════════════════════════

-- 5.1 ¿Dice la tabla nueva lo mismo que el campo de texto?
--     'IGUAL' en todas las filas de quien tenga cuenta.
--     Joaquim debe salir con 0 y 0: es Admin y sus tiendas salen del catalogo.
select u.nombre,
       u.rol,
       (select count(*) from regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
         where t ~ '^[Tt]?0*[0-9]{1,3}$'
           and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0)          as en_texto,
       (select count(*) from public.user_store_access x
         where x.user_id = a.id and x.activo)                               as en_tabla_nueva,
       case when (select count(*) from regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
                   where t ~ '^[Tt]?0*[0-9]{1,3}$'
                     and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0)
               = (select count(*) from public.user_store_access x
                   where x.user_id = a.id and x.activo)
            then 'IGUAL' else 'REVISAR' end                                 as resultado
from public.usuarios u
join auth.users a on lower(a.email) = lower(trim(u.email))
order by u.nombre;

-- 5.2 ¿Hay asignaciones que no existan en el catalogo? Debe salir vacio.
select x.tienda, count(*) as asignaciones
from public.user_store_access x
where not exists (
  select 1 from public.tiendas_faro t
  where 'T' || lpad(substring(t.tienda from '([0-9]{1,3})'), 2, '0') = x.tienda)
group by 1;

-- 5.3 La politica de usuarios: debe existir una sola, y ya no ser using(true).
select policyname, cmd, roles, qual
from pg_policies where schemaname='public' and tablename='usuarios';


-- ═══════════════════════════════════════════════════════════
-- DESPUES · comprobar en la aplicacion (nada deberia cambiar)
-- ═══════════════════════════════════════════════════════════
-- Cesar entra   -> consola: '... rol coordinador · 10 tienda(s) · tiendas_asignadas'
-- Joaquim entra -> consola: '... rol admin · 43 tienda(s) · rol_con_todas_las_tiendas'
-- Si alguno sale con 0 tiendas, deshacer el BLOQUE 4 (abajo) y avisar.


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- Volver a abrir usuarios a cualquier autenticado (revierte el bloque 4):
--   drop policy if exists usuarios_select_propio on public.usuarios;
--   create policy usuarios_select_autenticados on public.usuarios
--     for select to authenticated using (true);
--
-- Quitar del todo lo añadido (bloques 1, 2 y 3). No afecta a ningun dato de
-- negocio: user_store_access es una tabla nueva que todavia no usa nadie.
--   drop function if exists public.faro_tiendas_autorizadas();
--   drop table if exists public.user_store_access;
