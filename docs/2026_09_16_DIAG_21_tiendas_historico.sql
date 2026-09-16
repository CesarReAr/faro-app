-- FARO · Las 21 tiendas del historico · 16/09/2026
-- SOLO LECTURA. No modifica datos, no cambia user_id, no toca RLS, no borra.
-- Solo SELECT sobre datos_diarios_faro, usuarios, tiendas_faro y auth.users.
-- Devuelve UNA celda: clic y Ctrl+C.
--
-- POR QUE
-- Cesar tiene 287 filas en datos_diarios_faro repartidas en 21 tiendas, pero
-- solo 10 asignadas. Hoy no se nota: la RLS por user_id se las deja leer
-- porque son suyas, y _soloTiendasDelArea() esconde las sobrantes en pantalla.
-- En el PASO 3 la RLS pasara a filtrar por tienda y esas filas cambian de
-- dueño. Hay que saber a quien van ANTES de activarlo.
--
-- REGLA QUE SE APLICARA EN EL PASO 3 (ya escrita en faro_tiendas_autorizadas):
--   admin / visor_global -> todas las tiendas ACTIVAS de tiendas_faro
--   coordinador          -> sus tiendas de user_store_access
-- Consecuencia importante: una fila de una tienda INACTIVA, o de una tienda
-- que no este en tiendas_faro, no la vera NADIE, ni siquiera el admin.

with activas as (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda,
         nombre, activa
  from public.tiendas_faro
  where substring(tienda from '([0-9]{1,3})') is not null
),
asignadas as (
  select u.nombre as quien,
         'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0') as tienda
  from public.usuarios u
  cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
  where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
    and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0
),
porTienda as (
  select d.tienda,
         count(*)                                   as filas,
         count(distinct d.fecha)                    as dias,
         min(d.fecha)                               as desde,
         max(d.fecha)                               as hasta,
         min(d.created_at)::date                    as primera_carga,
         max(d.created_at)::date                    as ultima_carga,
         string_agg(distinct d.fuente, ', ')        as fuentes,
         string_agg(distinct coalesce(d.archivo_nombre,'(sin nombre)'), ' | ') as archivos,
         string_agg(distinct d.user_id::text, ', ') as user_ids
  from public.datos_diarios_faro d
  group by d.tienda
)
select jsonb_pretty(jsonb_build_object(

  -- Puntos 1, 2, 3 y 7 de un vistazo
  'resumen', jsonb_build_object(
    'filas_totales',            (select sum(filas) from porTienda),
    'tiendas_distintas',        (select count(*) from porTienda),
    'de_cesar',                 (select count(*) from porTienda p
                                  where exists (select 1 from asignadas s
                                                 where s.tienda = p.tienda
                                                   and s.quien in ('Cesar','César'))),
    'de_otro_coordinador',      (select count(*) from porTienda p
                                  where exists (select 1 from asignadas s where s.tienda = p.tienda)
                                    and not exists (select 1 from asignadas s where s.tienda = p.tienda
                                                      and s.quien in ('Cesar','César'))),
    'SIN_COORDINADOR',          (select count(*) from porTienda p
                                  where not exists (select 1 from asignadas s where s.tienda = p.tienda)),
    'INVISIBLES_TRAS_PASO3',    (select count(*) from porTienda p
                                  left join activas v on v.tienda = p.tienda
                                 where v.tienda is null or v.activa is false),
    'filas_invisibles_tras_paso3',(select coalesce(sum(p.filas),0) from porTienda p
                                  left join activas v on v.tienda = p.tienda
                                 where v.tienda is null or v.activa is false),
    'user_ids_distintos',       (select count(distinct user_id) from public.datos_diarios_faro)),

  -- Puntos 1 a 6 y 8, tienda por tienda. Las problematicas salen primero.
  'tiendas', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tienda',        p.tienda,
      'nombre',        v.nombre,
      'en_catalogo',   (v.tienda is not null),
      'activa',        v.activa,
      'filas',         p.filas,
      'dias',          p.dias,
      'desde',         p.desde,
      'hasta',         p.hasta,
      'primera_carga', p.primera_carga,
      'ultima_carga',  p.ultima_carga,
      'fuentes',       p.fuentes,
      'archivos',      p.archivos,
      'user_ids',      p.user_ids,
      -- punto 2 y 3
      'de_cesar',      exists (select 1 from asignadas s where s.tienda = p.tienda
                                 and s.quien in ('Cesar','César')),
      -- punto 7 y 8
      'TRAS_PASO3_LA_VERA', case
         when v.tienda is null      then 'NADIE · la tienda no esta en tiendas_faro'
         when v.activa is false     then 'NADIE · la tienda esta inactiva en el catalogo'
         else coalesce((select string_agg(s.quien, ' + ' order by s.quien) from asignadas s
                         where s.tienda = p.tienda), 'solo el ADMIN · sin coordinador asignado')
         end,
      'visible_para_admin_tras_paso3',
         (v.tienda is not null and v.activa is not false))
      order by
        (case when v.tienda is null or v.activa is false then 0
              when not exists (select 1 from asignadas s where s.tienda = p.tienda) then 1
              when not exists (select 1 from asignadas s where s.tienda = p.tienda
                                 and s.quien in ('Cesar','César')) then 2
              else 3 end),
        p.filas desc), '[]'::jsonb)
    from porTienda p
    left join activas v on v.tienda = p.tienda)

)) as diagnostico_21_tiendas;
