-- FARO · SEGURIDAD de public.usuarios · 16/09/2026
--
-- Sustituye a 2026_09_16_FASE1_CERRAR_USUARIOS.sql (aquel dejaba la lectura
-- abierta a cualquier autenticado; el bloque 4 del diagnostico demostro que
-- se puede restringir ya a la propia fila sin romper nada).
--
-- NO EJECUTADO todavia.
-- NO toca ni una fila de datos: sin insert, update, delete ni truncate.
-- NO toca el parser, el historico, el Plan Semanal ni ningun otro modulo.
-- NO toca index.html.
-- Solo GRANT, RLS y una politica, sobre una unica tabla.
--
-- ─── POR QUE ────────────────────────────────────────────────
-- Diagnostico ejecutado el 16/09/2026 en este proyecto:
--
--   public.usuarios          rls_activa = false, n_politicas = 0
--   anon                     DELETE, INSERT, REFERENCES, SELECT, TRIGGER,
--                            TRUNCATE, UPDATE   sobre public.usuarios
--   authenticated            los mismos privilegios
--   /auth/v1/settings        disable_signup = false  (registro publico abierto)
--
-- Comprobado ademas contra la API REST con la anon key, que viaja en claro en
-- index.html:1204: la tabla se lee entera sin iniciar sesion (HTTP 200, 8 filas
-- con nombre, email corporativo, rol y tiendas de cada coordinador).
--
-- Escalada posible hoy, sin cuenta previa:
--   1. registro publico con cualquier email
--   2. insert en usuarios: {email propio, rol 'admin', tiendas 'T01..T86'}
--   3. entra en FARO como admin con las 43 tiendas activas
-- Y sin cuenta siquiera: truncate de la tabla deja a TODOS los coordinadores
-- sin tiendas, sin error visible y sin copia en ningun otro sitio.
--
-- Las ventas NO se filtran por esta via: la RLS de datos_diarios_faro va por
-- user_id y aguanta. El daño es de datos personales y de disponibilidad.
--
-- ─── QUE NECESITA FARO DE ESTA TABLA ────────────────────────
-- Dos lecturas en todo index.html, ninguna escritura:
--   index.html:1516  select('email,rol,tiendas').ilike('email', email)  -> SU fila
--   index.html:1470  select('tiendas') de TODAS las filas
--                    -> dentro de _faroIdsTodasLasTiendas(), que es codigo
--                       INALCANZABLE: _faroLeerTablaTiendas() (index.html:1446)
--                       devuelve las 43 activas de tiendas_faro y el operador
--                       || nunca cae al fallback. Confirmado con el bloque 4
--                       del diagnostico: 51 filas, 43 activas, T01..T86.
-- Por tanto: basta con SELECT sobre la propia fila.
-- Un admin tampoco necesita mas: sus tiendas salen de tiendas_faro.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · ENSAYO EN SECO · EJECUTAR SOLO, Y ANTES DE NADA
-- ═══════════════════════════════════════════════════════════
-- Solo lectura. Responde: con la politica puesta, ¿quien seguiria viendo su
-- propia fila? Si alguien sale en 'SE QUEDA SIN SU FILA', NO SIGAS: esa
-- persona se quedaria con cero tiendas. Emails enmascarados.
--
-- Se espera: las 8 filas en 'OK'.

select case when a.id is null then 'SE QUEDA SIN SU FILA · sin cuenta en auth.users'
            else 'OK · seguira viendo su fila' end                  as resultado,
       left(u.email, 2) || '***@' || split_part(u.email, '@', 2)     as email_enmascarado,
       u.rol,
       (u.email is distinct from lower(trim(u.email)))               as email_con_espacios_o_mayusculas,
       coalesce(array_length(string_to_array(u.tiendas, ','), 1), 0) as n_tiendas
from public.usuarios u
left join auth.users a on lower(a.email) = lower(trim(u.email))
order by (a.id is null) desc, u.email;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · EL CAMBIO · ejecutar solo si el bloque 0 da todo OK
-- ═══════════════════════════════════════════════════════════
-- Las tres cosas van juntas a proposito: activar RLS sin politica dejaria a
-- FARO sin permisos para nadie.

begin;

-- 1. anon no debe poder tocar esta tabla de ninguna manera.
--    Ningun punto de FARO la consulta sin sesion.
revoke all on public.usuarios from anon;

-- 2. authenticated: solo lectura. FARO nunca escribe aqui; las altas se hacen
--    desde el panel de Supabase, que usa service_role y se salta RLS y GRANT.
--    Asi, un coordinador con sesion tampoco puede ascenderse a admin.
revoke all    on public.usuarios from authenticated;
grant  select on public.usuarios to   authenticated;

-- 3. RLS.
alter table public.usuarios enable row level security;

-- 4. La unica politica: cada usuario ve SU fila y solo la suya.
--    Sin politicas de insert/update/delete: con RLS activa, lo que no tiene
--    politica queda denegado. Doble barrera con el revoke de arriba.
--    lower+trim en los dos lados: la tabla tiene valores con espacios
--    (el rol 'coordinador ' de la fila de Cesar lo demuestra).
drop policy if exists usuarios_select_propio on public.usuarios;
create policy usuarios_select_propio on public.usuarios
  for select to authenticated
  using (lower(trim(email)) = lower(auth.jwt() ->> 'email'));

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · COMPROBACION · solo lectura, tras el commit
-- ═══════════════════════════════════════════════════════════

-- 2.1  RLS activa y exactamente 1 politica.
select relrowsecurity as rls_activa,
       (select count(*) from pg_policies
         where schemaname='public' and tablename='usuarios') as n_politicas
from pg_class
where relnamespace='public'::regnamespace and relname='usuarios';

-- 2.2  anon NO debe aparecer. authenticated debe tener SELECT y solo SELECT.
select grantee as rol,
       string_agg(privilege_type, ',' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema='public' and table_name='usuarios'
group by 1 order by 1;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 3 · OPCIONAL · defensa en profundidad en el resto
-- ═══════════════════════════════════════════════════════════
-- Estas 9 tablas YA tienen RLS y politicas correctas (auth.uid() = user_id),
-- asi que esto no cambia nada funcional: es para que un despiste con RLS no
-- vuelva a exponer datos, que es justo lo que paso con usuarios.
-- No se toca authenticated: es el rol con el que trabaja FARO.

-- revoke all on public.datos_diarios_faro       from anon;
-- revoke all on public.archivos_faro            from anon;
-- revoke all on public.objetivos_semanales_faro from anon;
-- revoke all on public.plan_semanal_faro        from anon;
-- revoke all on public.focos_tienda_faro        from anon;
-- revoke all on public.focos_rapport_faro       from anon;
-- revoke all on public.promociones_faro         from anon;
-- revoke all on public.marcas_verdes_mensual    from anon;
-- revoke all on public.profiles                 from anon;
-- tiendas_faro no aparece: anon ya no tenia ningun GRANT sobre ella.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 4 · NO EJECUTAR HOY · para cuando haya pantalla de admin
-- ═══════════════════════════════════════════════════════════
-- Hoy NO hace falta: un admin saca sus tiendas de tiendas_faro y de usuarios
-- solo necesita su propia fila, igual que un coordinador.
--
-- El dia que exista una pantalla para asignar tiendas, el admin tendra que
-- leer las filas de los demas. Una politica sobre usuarios NO PUEDE consultar
-- usuarios (recursion infinita), asi que hace falta una funcion SECURITY
-- DEFINER, que corre como su propietario y se salta la RLS.
--
-- Depende de que relforcerowsecurity siga en false (hoy lo esta): con
-- 'force row level security' la funcion dejaria de saltarse la RLS.
--
-- create or replace function public.faro_es_admin()
-- returns boolean
-- language sql stable security definer set search_path = public as $$
--   select exists (
--     select 1 from public.usuarios
--      where lower(trim(email)) = lower(auth.jwt() ->> 'email')
--        and regexp_replace(lower(trim(rol)), '[[:space:]-]+', '_', 'g')
--            in ('admin', 'visor_global'));
-- $$;
--
-- revoke all on function public.faro_es_admin() from public, anon;
-- grant execute on function public.faro_es_admin() to authenticated;
--
-- drop policy if exists usuarios_select_propio on public.usuarios;
-- create policy usuarios_select_propio_o_admin on public.usuarios
--   for select to authenticated
--   using (lower(trim(email)) = lower(auth.jwt() ->> 'email')
--          or public.faro_es_admin());


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- Deja la tabla como estaba antes. No se pierde ningun dato en ningun momento:
-- este script nunca los toca.
--
-- drop policy if exists usuarios_select_propio on public.usuarios;
-- alter table public.usuarios disable row level security;
-- grant select, insert, update, delete on public.usuarios to anon, authenticated;
