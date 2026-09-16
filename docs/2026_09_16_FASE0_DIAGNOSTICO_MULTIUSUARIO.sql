-- FARO · FASE 0 del plan multiusuario · 16/09/2026
--
-- SOLO LECTURA. Ninguna sentencia de este fichero crea, modifica ni borra nada:
-- no hay insert, update, delete, alter, drop, create, grant ni revoke.
-- Se puede ejecutar entero, y las veces que haga falta, sin riesgo.
--
-- Cómo: Supabase → SQL Editor → pegar → Run. Devuelve 8 tablas de resultados.
-- Guardar la salida: es la foto de partida antes de tocar nada de RLS.
--
-- QUÉ SE SABE YA, comprobado el 16/09/2026 contra la API REST con la anon key
-- (la misma que viaja en claro en index.html:1204; o sea, la que tiene cualquiera):
--
--  - public.usuarios SE LEE ENTERA SIN INICIAR SESION. HTTP 200, 8 filas, con
--    nombre, email corporativo, rol y la lista de tiendas de cada coordinador.
--    Es la tabla que decide los permisos y es la unica abierta.
--  - Las otras 9 tablas de negocio devuelven [] a un anonimo: su RLS deniega bien.
--  - public.tiendas_faro existe pero da 401 permission denied: le falta el GRANT
--    a anon. Falta saber si tampoco lo tiene authenticated (bloques 3 y 4).
--  - public.user_store_access no existe (HTTP 404).
--  - El endpoint OpenAPI (/rest/v1/) esta cerrado: no se puede introspeccionar.
--  - Sondeados 20 nombres mas de tabla: ninguna otra esta expuesta a anon.
--  - OPTIONS devuelve el mismo Allow en usuarios que en una tabla protegida:
--    en esta version de PostgREST la cabecera es generica y no dice nada.
--
-- LO QUE ESTE SCRIPT VIENE A RESPONDER, que no se puede saber desde fuera:
--   A. Por que usuarios esta abierta: RLS apagada, o politica permisiva? (1 y 2)
--   B. PUEDE UN ANONIMO ESCRIBIR EN usuarios? Si puede, cualquiera se pone rol
--      admin y se asigna todas las tiendas. Es la pregunta mas urgente de las 8.
--      Se responde leyendo cmd/roles/with_check y los GRANT, sin intentar
--      ninguna escritura contra la tabla de produccion. (2 y 3)
--   C. tiendas_faro es legible por los usuarios con sesion? (3 y 4)
--   D. Los 8 de usuarios existen en auth.users y en profiles? (5)
--   E. Cuantos se quedan hoy con cero tiendas por el rol en femenino? (6)
--   F. usuarios y profiles dicen el mismo rol del mismo usuario? (7)
--   G. Hay historico de tiendas que ya no estan asignadas a nadie, o subido
--      por mas de un usuario? Mide el tamaño real de la FASE 5. (8)


-- ─── 1. RLS activa en cada tabla ───────────────────────────
-- rls_activa = false en usuarios explicaria la fuga sin mas.
-- rls_forzada importa porque el propietario de la tabla se salta la RLS si no lo esta.
select c.relname             as tabla,
       c.relrowsecurity      as rls_activa,
       c.relforcerowsecurity as rls_forzada,
       count(p.policyname)   as n_politicas
from pg_class c
left join pg_policies p on p.schemaname = 'public' and p.tablename = c.relname
where c.relnamespace = 'public'::regnamespace
  and c.relkind = 'r'
group by 1, 2, 3
order by c.relrowsecurity asc, c.relname;   -- las desprotegidas, arriba


-- ─── 2. Todas las politicas, con el rol al que aplican ─────
-- LO MAS IMPORTANTE DEL SCRIPT. Buscar en la salida:
--   * cualquier fila con tablename = 'usuarios'
--   * cualquier fila con 'anon' o 'public' en roles   -> abierta a no autenticados
--   * cmd INSERT/UPDATE/ALL con condicion_escritura nula o 'true' -> escritura libre
--   * condicion_lectura = 'true' en un select          -> lectura libre
select tablename,
       policyname,
       roles,
       cmd,
       permissive,
       qual       as condicion_lectura,
       with_check as condicion_escritura
from pg_policies
where schemaname = 'public'
order by (tablename = 'usuarios') desc,       -- usuarios primero
         ('anon'   = any(roles)) desc,        -- luego lo abierto a anonimos
         ('public' = any(roles)) desc,
         tablename, cmd;


-- ─── 3. Privilegios de tabla por rol ───────────────────────
-- La RLS solo llega a evaluarse si antes hay GRANT. Un GRANT INSERT a anon
-- sobre usuarios es la otra mitad de la pregunta B.
-- Aqui se ve tambien si authenticated tiene SELECT sobre tiendas_faro.
select table_name as tabla,
       grantee    as rol,
       string_agg(privilege_type, ', ' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'public')
group by 1, 2
order by (grantee = 'anon') desc, table_name;


-- ─── 4. tiendas_faro: existe y con cuantas filas ───────────
-- Si authenticated no sale con SELECT en el bloque 3, entonces
-- _faroLeerTablaTiendas() (index.html:1446) falla SIEMPRE, cae al catch y
-- devuelve null: nadie ve nunca los nombres reales de tienda desde la BD, y
-- el admin depende de _faroIdsTodasLasTiendas(), que lee usuarios entera.
select count(*)                                    as filas,
       count(*) filter (where activa is not false) as activas,
       min(tienda)                                 as primera,
       max(tienda)                                 as ultima
from public.tiendas_faro;


-- ─── 5. usuarios vs auth.users vs profiles ─────────────────
-- Un usuario sin fila en auth.users no puede entrar.
-- Uno sin fila en profiles entra, pero fetchProfile() (index.html:11989) usa
-- .single(), falla, y firma todos sus mensajes como "Usuario".
-- Solo el recuento por estado: sin sacar emails ni nombres.
select case
         when a.id is null then 'SIN CUENTA auth.users · no puede entrar'
         when p.id is null then 'SIN FILA profiles · firmara como Usuario'
         else 'completo'
       end      as estado,
       count(*) as usuarios
from public.usuarios u
left join auth.users     a on lower(a.email) = lower(trim(u.email))
left join public.profiles p on p.id = a.id
group by 1
order by 2 desc;


-- ─── 6. El rol en femenino: cuantos se quedan sin tiendas ──
-- resolverPermisosTiendas() (index.html:1436) compara con IGUALDAD EXACTA
-- contra 'coordinador'. _faroRol() normaliza mayusculas, acentos y espacios,
-- pero 'Coordinadora' -> 'coordinadora', que NO es igual a 'coordinador': cae
-- al ultimo return y se queda con cero tiendas. Esto reproduce esa
-- normalizacion en SQL, para contar exactamente a quien afecta.
-- Se espera ver 3 usuarios en 'CERO TIENDAS'.
with normalizado as (
  select rol,
         regexp_replace(
           lower(trim(translate(rol,
             'áéíóúüñÁÉÍÓÚÜÑàèìòùÀÈÌÒÙ',
             'aeiounAEIOUNaeiouAEIOU'))),
           '[[:space:]-]+', '_', 'g') as rol_normalizado
  from public.usuarios
)
select rol             as rol_en_la_tabla,
       rol_normalizado,
       count(*)        as usuarios,
       case
         when rol_normalizado in ('admin', 'visor_global') then 'TODAS las tiendas'
         when rol_normalizado = 'coordinador'              then 'sus tiendas asignadas'
         else 'CERO TIENDAS · FARO vacio'
       end             as que_ve_hoy
from normalizado
group by 1, 2
order by 4, 3 desc;


-- ─── 7. Dos fuentes de rol que pueden contradecirse ────────
-- usuarios.rol decide las tiendas (faroPermisos.rol, index.html:1516).
-- profiles.role decide currentRol, que gobierna el adminOnly de index.html:11778.
-- Si discrepan, alguien puede ser admin para una cosa y no para la otra.
select coalesce(regexp_replace(lower(trim(u.rol)), '[[:space:]-]+', '_', 'g'), '(vacio)') as rol_en_usuarios,
       coalesce(lower(trim(p.role)), '(sin fila en profiles)')                     as rol_en_profiles,
       count(*)                                                                    as usuarios
from public.usuarios u
left join auth.users     a on lower(a.email) = lower(trim(u.email))
left join public.profiles p on p.id = a.id
group by 1, 2
order by 3 desc;


-- ─── 8. Historico frente a tiendas asignadas ───────────────
-- Mide el tamaño real del problema de la FASE 5 (propiedad vs permiso):
--   n_propietarios > 1   -> el mismo hecho de negocio duplicado por usuario
--   asignada_a_alguien=f -> tienda con historico que ya no ve nadie
select d.tienda,
       count(*)                  as filas_historico,
       count(distinct d.user_id) as n_propietarios,
       min(d.fecha)              as desde,
       max(d.fecha)              as hasta,
       (a.tienda is not null)    as asignada_a_alguien
from public.datos_diarios_faro d
left join (
  select distinct 'T' || lpad(substring(t from '(\d{1,3})'), 2, '0') as tienda
  from public.usuarios u
  cross join lateral unnest(string_to_array(coalesce(u.tiendas, ''), ',')) as t
  where substring(t from '(\d{1,3})') is not null
) a on a.tienda = d.tienda
group by d.tienda, a.tienda
order by asignada_a_alguien asc, count(distinct d.user_id) desc, d.tienda;
