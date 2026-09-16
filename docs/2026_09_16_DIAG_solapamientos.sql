-- FARO · Mapa de solapamientos de tiendas · 16/09/2026 · SOLO LECTURA
-- No modifica nada.
--
-- POR QUE
-- El diagnostico de las 21 tiendas revelo que las 10 tiendas de Cesar estan
-- asignadas tambien a Ester, y 5 de ellas ademas a Sergi (CEO). Una
-- comprobacion anterior dijo que no habia solapamiento, pero aquella consulta
-- hacia join con auth.users y solo comparaba a las 2 personas con cuenta.
-- Esta lee public.usuarios entera, las 8 filas.
--
-- IMPORTA porque si dos personas con la misma tienda suben el mismo FollowUp,
-- quedan dos filas con igual (fecha, tienda, fuente) y distinto user_id, y
-- _mergeHistoryDayRows() (index.html) coge una arbitrariamente, por orden de
-- created_at.
--
-- Decidido ya: a Ester se le quitan las tiendas; Sergi pasa a rol visor_global
-- (ve las 43 activas por rol, sin asignaciones). Esta consulta sirve para ver
-- si hay MAS casos ademas de esos dos.

with asignadas as (
  select u.nombre as quien,
         coalesce(regexp_replace(lower(trim(u.rol)), '[[:space:]-]+','_','g'),'') as rol,
         'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0') as tienda
  from public.usuarios u
  cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
  where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
    and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0
),
catalogo as (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda,
         nombre, activa
  from public.tiendas_faro
  where substring(tienda from '([0-9]{1,3})') is not null
),
-- Se agrega AQUI, no dentro del jsonb_agg: anidar agregados no esta permitido.
por_persona as (
  select s.quien,
         s.rol,
         count(*)                                   as n_tiendas,
         string_agg(s.tienda, ',' order by s.tienda) as tiendas,
         (select coalesce(string_agg(distinct o.quien, ', '), '(nadie)')
            from asignadas o
           where o.quien <> s.quien
             and o.tienda in (select w.tienda from asignadas w where w.quien = s.quien)
         )                                          as comparte_con
  from asignadas s
  group by s.quien, s.rol
),
compartidas as (
  select tienda,
         count(distinct quien)              as personas,
         string_agg(distinct quien, ' + ')  as quienes
  from asignadas
  group by tienda
  having count(distinct quien) > 1
)
select jsonb_pretty(jsonb_build_object(

  -- 1 · Cuantas tiendas lleva cada persona y con quien las comparte
  'por_persona', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'quien',        p.quien,
             'rol',          p.rol,
             'n_tiendas',    p.n_tiendas,
             'comparte_con', p.comparte_con,
             'tiendas',      p.tiendas)
           order by p.n_tiendas desc, p.quien), '[]'::jsonb)
    from por_persona p),

  -- 2 · Tiendas con mas de un responsable. Son las que dan colision.
  'tiendas_compartidas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tienda',   z.tienda,
             'nombre',   c.nombre,
             'activa',   c.activa,
             'personas', z.personas,
             'quienes',  z.quienes)
           order by z.personas desc, z.tienda), '[]'::jsonb)
    from compartidas z
    left join catalogo c on c.tienda = z.tienda),

  -- 3 · Resumen
  'resumen', jsonb_build_object(
    'personas_con_tiendas',  (select count(*) from por_persona),
    'tiendas_asignadas',     (select count(distinct tienda) from asignadas),
    'tiendas_compartidas',   (select count(*) from compartidas),
    'tiendas_activas_total', (select count(*) from catalogo where activa is not false),
    'activas_sin_nadie',     (select count(*) from catalogo c
                               where c.activa is not false
                                 and not exists (select 1 from asignadas s
                                                  where s.tienda = c.tienda))),

  -- 4 · Las activas que no tiene nadie: se veran solo desde admin/CEO
  'activas_sin_coordinador', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tienda', c.tienda, 'nombre', c.nombre) order by c.tienda), '[]'::jsonb)
    from catalogo c
    where c.activa is not false
      and not exists (select 1 from asignadas s where s.tienda = c.tienda))

)) as mapa_solapamientos;
