-- FARO · Mapa del equipo y cobertura de tiendas · 16/09/2026 · SOLO LECTURA
-- No modifica nada. Devuelve UNA celda.
--
-- POR QUE
-- El equipo son Cesar, Marta, Cristina, Alvaro y Jose (coordinadores),
-- Joaquim (carga) y gerencia. En public.usuarios hay 8 filas pero solo 2
-- tienen cuenta en auth.users. Antes del paso 3 hay que saber:
--   1. quien esta dado de alta y quien no
--   2. cuantas de las 43 tiendas activas tienen coordinador
--   3. a quien pertenecen realmente las tiendas sueltas del historico de Cesar
--      (287 filas en 21 tiendas, con solo 10 asignadas). Al activar la RLS por
--      tienda esas filas cambian de dueño: hay que saber a quien van.

with activas as (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda, nombre
  from public.tiendas_faro
  where activa is not false and substring(tienda from '([0-9]{1,3})') is not null
),
-- Asignaciones segun el campo de texto, que es lo que hay para todos
-- (user_store_access solo tiene a quien ya tiene cuenta).
asignadas as (
  select u.nombre as quien,
         'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0') as tienda
  from public.usuarios u
  cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
  where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
    and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0
)
select jsonb_pretty(jsonb_build_object(

  -- 1 · El equipo
  'equipo', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'nombre',        u.nombre,
      'rol',           u.rol,
      'tiene_cuenta',  (a.id is not null),
      'ha_entrado',    (a.last_sign_in_at is not null),
      'n_tiendas',     (select count(*) from asignadas s where s.quien = u.nombre),
      'tiendas',       (select string_agg(s.tienda, ',' order by s.tienda)
                          from asignadas s where s.quien = u.nombre),
      'en_user_store_access', case when a.id is null then 0
                              else (select count(*) from public.user_store_access x
                                     where x.user_id = a.id and x.activo) end)
      order by (a.id is null), u.nombre), '[]'::jsonb)
    from public.usuarios u
    left join auth.users a on lower(a.email) = lower(trim(u.email))),

  -- 2 · Cobertura del catalogo
  'cobertura', jsonb_build_object(
    'tiendas_activas',      (select count(*) from activas),
    'con_coordinador',      (select count(*) from activas v
                              where exists (select 1 from asignadas s where s.tienda = v.tienda)),
    'SIN_COORDINADOR',      (select coalesce(jsonb_agg(jsonb_build_object(
                                'tienda', v.tienda, 'nombre', v.nombre) order by v.tienda), '[]'::jsonb)
                              from activas v
                             where not exists (select 1 from asignadas s where s.tienda = v.tienda)),
    'asignadas_a_dos_o_mas',(select coalesce(jsonb_agg(t), '[]'::jsonb) from (
                               select tienda as t from asignadas
                               group by tienda having count(distinct quien) > 1) z)),

  -- 3 · Las tiendas sueltas del historico: a quien iran en el paso 3
  'historico_por_tienda', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tienda',        d.tienda,
      'filas',         d.filas,
      'desde',         d.desde,
      'hasta',         d.hasta,
      'ultima_carga',  d.ultima_carga,
      'ira_a',         coalesce((select string_agg(s.quien, ' + ') from asignadas s
                                  where s.tienda = d.tienda), 'NADIE · quedara invisible'))
      order by (select count(*) from asignadas s where s.tienda = d.tienda), d.filas desc), '[]'::jsonb)
    from (select tienda, count(*) as filas, min(fecha) as desde, max(fecha) as hasta,
                 max(created_at)::date as ultima_carga
            from public.datos_diarios_faro group by tienda) d)

)) as mapa_equipo;
