-- FARO · Limpieza de las filas ajenas del historico · 16/09/2026
-- NO EJECUTADO. PRIMERA VEZ QUE SE TOCAN DATOS DE NEGOCIO: leer entero.
--
-- ─── QUE BORRA ──────────────────────────────────────────────
-- 33 filas de datos_diarios_faro: 11 tiendas x 3 dias (2 al 5 de septiembre).
-- Son tiendas que NO son de Cesar y que se colaron en su historico:
--   Marta     T14 T15 T16 T28 T29 T31 T32 T33 T57
--   Cristina  T52
--   nadie     T55 (BONAVISTA, inactiva en el catalogo)
--
-- NO toca las 254 filas de las 10 tiendas de Cesar.
-- NO toca objetivos, plan, focos, promociones, archivos ni marcas verdes.
--
-- ─── POR QUE SE COLARON ─────────────────────────────────────
-- El FollowUp es un export corporativo con las 20 tiendas de Facial. Estos
-- tres ficheros se subieron entre el 3 y el 6 de septiembre:
--   2026-09-03_1616_export.csv
--   2026-09-04_ventas.csv
--   2026-09-05_ventas.csv
-- ANTES de que existiera el filtro de area al guardar (soloMias,
-- index.html:10330). Por eso entraron las 11 tiendas que no son del area.
-- Son ventas reales, no pruebas ni demo.
--
-- ─── POR QUE BORRARLAS Y NO DEJARLAS ────────────────────────
-- En el PASO 3 la RLS pasa a filtrar por tienda y estas filas dejan de ser
-- "de Cesar": las verian Marta y Cristina. Pero son TRES DIAS SUELTOS del 2 al
-- 5 de septiembre, sin la semana anterior ni la posterior ni acumulado de mes.
-- Marta abriria FARO y veria una isla de datos de hace dos semanas, y sus
-- medias, su comparativa y su Plan Semanal se calcularian sobre eso.
-- Es mas limpio que su historico empiece el dia que Joaquim cargue de verdad.
--
-- Son recuperables: los tres CSV estan identificados por nombre.
-- Y ademas el bloque 1 guarda una copia antes de borrar.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · QUE SE VA A BORRAR · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Ejecutar SOLO esto primero. Esperado: 11 tiendas, 33 filas, todas con
-- es_de_su_coordinador = false y fuente FOLLOWUP_CSV.

select d.tienda,
       c.nombre                                as nombre_tienda,
       c.activa,
       count(*)                                as filas_a_borrar,
       min(d.fecha)                            as desde,
       max(d.fecha)                            as hasta,
       string_agg(distinct d.fuente, ', ')     as fuentes,
       coalesce((select string_agg(u.nombre, ' + ')
                   from public.usuarios u
                  where position(d.tienda in coalesce(u.tiendas,'')) > 0),
                '(nadie)')                     as coordinador_real
from public.datos_diarios_faro d
left join (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda,
         nombre, activa
  from public.tiendas_faro
  where substring(tienda from '([0-9]{1,3})') is not null
) c on c.tienda = d.tienda
where not exists (
  select 1
    from public.usuarios u
    join auth.users a on lower(a.email) = lower(trim(u.email))
   where a.id = d.user_id
     and position(d.tienda in coalesce(u.tiendas,'')) > 0)
group by d.tienda, c.nombre, c.activa
order by d.tienda;

-- Y el total, que debe dar 33:
select count(*) as total_filas_a_borrar
from public.datos_diarios_faro d
where not exists (
  select 1
    from public.usuarios u
    join auth.users a on lower(a.email) = lower(trim(u.email))
   where a.id = d.user_id
     and position(d.tienda in coalesce(u.tiendas,'')) > 0);


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · COPIA DE SEGURIDAD
-- ═══════════════════════════════════════════════════════════
-- Guarda las filas enteras en una tabla aparte antes de borrar nada.
-- No la ve nadie desde FARO: no tiene GRANT para anon ni authenticated.

create table if not exists public.copia_20260916_filas_ajenas
  (like public.datos_diarios_faro including defaults);

revoke all on public.copia_20260916_filas_ajenas from anon, authenticated;

insert into public.copia_20260916_filas_ajenas
select d.*
from public.datos_diarios_faro d
where not exists (
  select 1
    from public.usuarios u
    join auth.users a on lower(a.email) = lower(trim(u.email))
   where a.id = d.user_id
     and position(d.tienda in coalesce(u.tiendas,'')) > 0);

-- Comprobar que la copia tiene las 33 ANTES de seguir:
select count(*) as filas_copiadas from public.copia_20260916_filas_ajenas;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · EL BORRADO
-- ═══════════════════════════════════════════════════════════
-- Ejecutar solo si el bloque 1 dice 33.
-- Borra por id, contra la copia: asi es imposible que se lleve por delante
-- una fila que no este respaldada.

begin;

delete from public.datos_diarios_faro d
 where d.id in (select id from public.copia_20260916_filas_ajenas);

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 3 · COMPROBACION · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Esperado: 254 filas, 10 tiendas, todas de Cesar.

select count(*)                  as filas,
       count(distinct tienda)    as tiendas,
       count(distinct user_id)   as propietarios,
       min(fecha)                as desde,
       max(fecha)                as hasta
from public.datos_diarios_faro;

select string_agg(distinct tienda, ',' order by tienda) as tiendas_restantes
from public.datos_diarios_faro;


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- insert into public.datos_diarios_faro
-- select * from public.copia_20260916_filas_ajenas
-- on conflict do nothing;
--
-- Cuando ya no haga falta la copia (semanas, no dias):
-- drop table public.copia_20260916_filas_ajenas;
