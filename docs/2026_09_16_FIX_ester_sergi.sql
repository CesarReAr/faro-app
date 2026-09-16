-- FARO · Ajuste de personas y asignaciones · 16/09/2026
-- NO EJECUTADO.
--
-- NO toca ninguna tabla de datos: ni ventas, ni objetivos, ni plan, ni focos,
-- ni promociones, ni archivos. Solo public.usuarios y user_store_access.
--
-- ─── QUE HACE ───────────────────────────────────────────────
--   Ester   se da de baja (sale de la empresa)
--   Sergi   CEO           -> ve todas por ROL, sin asignaciones
--   Oscar   dir. retail   -> alta nueva, ve todas por ROL
--   Marta   +T60 +T61 +T62
--
-- ─── POR QUE ────────────────────────────────────────────────
-- Mapa de solapamientos del 16/09/2026: las 10 tiendas de Cesar estaban
-- asignadas tambien a Ester, y 5 de ellas ademas a Sergi. Alvaro, Jose, Marta
-- y Cristina estaban limpios. T60, T61 y T62 estaban activas sin coordinador.
-- Cristina con 2 tiendas es correcto: confirmado.
--
-- Un CEO o un director de retail no son "el coordinador de T13, T26 y T30":
-- ven todo. Eso va por rol, no por asignaciones sueltas, igual que Joaquim.
--
-- Se usa visor_global y no admin a proposito: da visibilidad completa sin los
-- borrados de administrador (el candado de index.html:11809 mira
-- profiles.role = 'admin'). El rol YA esta reconocido en los dos sitios:
--   index.html:1404   FARO_ROLES_TODAS_LAS_TIENDAS = ['admin','visor_global']
--   faro_tiendas_autorizadas(), rama (a)
-- Cero cambios de codigo.
--
-- Tras esto ninguna tienda queda con dos responsables, y las 43 activas
-- tienen coordinador.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · ENSAYO EN SECO · ejecutar SOLO esto primero
-- ═══════════════════════════════════════════════════════════
-- Solo lectura. Estado actual de los implicados, si Ester dejaria algo
-- huerfano al borrarla, y que tiendas asignadas estan inactivas (esas no las
-- vera nadie tras el paso 3, porque la regla de admin dice "todas las activas").

select 'a. estado actual' as bloque, u.nombre, u.rol,
       coalesce(u.tiendas,'(ninguna)') as detalle,
       (select count(*) from auth.users a
         where lower(a.email) = lower(trim(u.email)))::text as tiene_cuenta
from public.usuarios u
where u.nombre in ('Ester','Sergi','Marta')

union all

select 'b. datos subidos por Ester', u.nombre, '',
       count(d.*)::text || ' filas', ''
from public.usuarios u
left join auth.users a on lower(a.email) = lower(trim(u.email))
left join public.datos_diarios_faro d on d.user_id = a.id
where u.nombre = 'Ester'
group by u.nombre

union all

select 'c. asignadas pero INACTIVAS', s.quien, c.nombre, s.tienda,
       'no la vera nadie tras el paso 3'
from (
  select u.nombre as quien,
         'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0') as tienda
  from public.usuarios u
  cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
  where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
) s
join (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda,
         nombre, activa
  from public.tiendas_faro
  where substring(tienda from '([0-9]{1,3})') is not null
) c on c.tienda = s.tienda
where c.activa is false;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · EL CAMBIO
-- ═══════════════════════════════════════════════════════════
-- Ejecutar solo si el bloque 0 confirma que Ester no ha subido ningun dato.
-- Si hubiera subido algo, sus filas quedarian con un user_id huerfano: en ese
-- caso NO borrar su fila, solo vaciarle las tiendas, y hablarlo antes.

begin;

-- 1. Ester: baja.
--    Su cuenta de Supabase Auth, si la tuviera, se borra aparte desde
--    Authentication -> Users. Esto solo la quita de los permisos de FARO.
delete from public.usuarios where nombre = 'Ester';

-- 2. Sergi, CEO: ve todo por rol, sin asignaciones sueltas.
update public.usuarios
   set rol = 'visor_global', tiendas = null
 where nombre = 'Sergi';

-- 3. Oscar, director de retail: alta nueva, ve todo por rol.
--    El email tiene que ser el MISMO con el que se le invite en
--    Authentication -> Users: public.usuarios no tiene user_id y el email es
--    el unico enlace. El "where not exists" lo hace repetible sin duplicar.
insert into public.usuarios (nombre, email, rol, tiendas)
select 'Óscar', 'oscar@perfumeriesfacial.com', 'visor_global', null
where not exists (
  select 1 from public.usuarios
   where lower(trim(email)) = 'oscar@perfumeriesfacial.com');

-- 4. Marta: se le añaden T60, T61 y T62, que estaban activas sin coordinador.
--    Lista completa y explicita, para no depender de concatenar texto.
update public.usuarios
   set tiendas = 'T14,T15,T16,T28,T29,T31,T32,T33,T55,T57,T60,T61,T62'
 where nombre = 'Marta';

-- 5. Limpiar de user_store_access lo que ya no corresponda a nadie.
--    Idempotente. Ester y Sergi no tienen cuenta de Auth, asi que el paso 1
--    no pudo copiarles nada; esto es por si acaso.
delete from public.user_store_access x
 where not exists (
   select 1
     from public.usuarios u
     join auth.users a on lower(a.email) = lower(trim(u.email))
    where a.id = x.user_id
      and position(x.tienda in coalesce(u.tiendas,'')) > 0);

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · Resincronizar user_store_access
-- ═══════════════════════════════════════════════════════════
-- Vuelve a copiar de usuarios.tiendas para quien tenga cuenta. Es el mismo
-- bloque 2 del PASO 1 y es idempotente: se repite cada vez que cambien las
-- asignaciones o se invite a alguien nuevo.

begin;

insert into public.user_store_access (user_id, tienda, nivel)
select distinct
       a.id,
       'T' || lpad(substring(t from '^[Tt]?0*([0-9]{1,3})$'), 2, '0'),
       'coordinador'
from public.usuarios u
join auth.users a on lower(a.email) = lower(trim(u.email))
cross join lateral regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
  and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0
on conflict (user_id, tienda, desde) do nothing;

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 3 · COMPROBACION · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Esperado:
--   solapamientos      -> []
--   activas_sin_nadie  -> []
--   Sergi y Óscar      -> visor_global, 0 tiendas
--   Marta              -> 13 tiendas
--   Ester              -> no aparece

with asignadas as (
  select u.nombre as quien,
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
)
select jsonb_pretty(jsonb_build_object(

  'solapamientos', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tienda', q.tienda, 'quienes', q.quienes) order by q.tienda), '[]'::jsonb)
    from (select tienda, string_agg(distinct quien, ' + ') as quienes
            from asignadas group by tienda having count(distinct quien) > 1) q),

  'activas_sin_nadie', (
    select coalesce(jsonb_agg(c.tienda order by c.tienda), '[]'::jsonb)
    from catalogo c
    where c.activa is not false
      and not exists (select 1 from asignadas s where s.tienda = c.tienda)),

  'personas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'nombre', p.nombre, 'rol', p.rol, 'n_tiendas', p.n,
             'tiene_cuenta', p.cuenta) order by p.nombre), '[]'::jsonb)
    from (select u.nombre, u.rol,
                 (select count(*) from asignadas s where s.quien = u.nombre) as n,
                 exists (select 1 from auth.users a
                          where lower(a.email) = lower(trim(u.email))) as cuenta
            from public.usuarios u) p)

)) as estado_final;


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- insert into public.usuarios (nombre, email, rol, tiendas)
--   values ('Ester','<su email>','coordinadora',
--           'T13,T26,T27,T30,T40,T53,T54,T56,T81,T85');
-- update public.usuarios set rol='coordinador', tiendas='T13,T26,T30,T40,T85'
--  where nombre='Sergi';
-- update public.usuarios set tiendas='T14,T15,T16,T28,T29,T31,T32,T33,T55,T57'
--  where nombre='Marta';
-- delete from public.usuarios where nombre='Óscar';
