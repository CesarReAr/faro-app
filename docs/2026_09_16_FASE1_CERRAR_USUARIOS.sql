-- FARO · FASE 1 · cerrar public.usuarios · 16/09/2026
--
-- ESTE FICHERO SI ESCRIBE: cambia RLS, GRANT y politicas.
-- NO toca ni una fila de datos. No hay insert, update, delete ni truncate.
-- No toca ninguna tabla de negocio, ni el histórico, ni index.html.
--
-- ─── POR QUE ────────────────────────────────────────────────
-- Diagnostico FASE 0, ejecutado el 16/09/2026 (bloques 1, 2 y 3):
--
--   public.usuarios  ->  rls_activa = false, n_politicas = 0
--   anon             ->  DELETE, INSERT, REFERENCES, SELECT, TRIGGER,
--                        TRUNCATE, UPDATE  sobre public.usuarios
--
-- Sin RLS, el GRANT es la unica barrera, y no hay ninguna. Con la anon key,
-- que viaja en claro en index.html:1204, cualquiera desde internet y sin
-- cuenta puede hoy leer la tabla entera (8 filas con emails corporativos),
-- ponerse rol admin, insertarse con las tiendas que quiera, o vaciarla.
-- Es la tabla que decide los permisos de toda FARO.
--
-- Las 9 tablas de negocio y profiles SI tienen RLS y politicas correctas
-- (auth.uid() = user_id). tiendas_faro tambien esta bien montada.
--
-- ─── QUE HACE ───────────────────────────────────────────────
-- 1A. Corta el acceso anonimo a usuarios y le activa RLS.
-- 1B. Quita a anon el DML que le sobra en el resto de tablas (defensa en
--     profundidad: hoy las tapa la RLS, pero el dia que alguien la desactive
--     por error quedan abiertas, que es justo lo que paso con usuarios).
--
-- ─── QUE NO HACE, A PROPOSITO ───────────────────────────────
-- No restringe todavia la lectura de usuarios a la propia fila.
-- Motivo: _faroIdsTodasLasTiendas() (index.html:1467) lee la tabla ENTERA
-- para calcular las tiendas del admin. Restringirla ahora romperia al admin
-- si tiendas_faro estuviera vacia. Eso es la FASE 1C, y antes hay que
-- ejecutar el bloque 4 del diagnostico para saber cuantas filas tiene.
-- Lo de aqui deja a FARO funcionando EXACTAMENTE igual que ahora.
--
-- ─── COMO DESHACER ──────────────────────────────────────────
--   alter table public.usuarios disable row level security;
--   grant select, insert, update, delete on public.usuarios to anon;
-- (no hara falta: ningun codigo de FARO escribe en usuarios ni la lee sin sesion)

begin;

-- ═══ 1A · public.usuarios ═══════════════════════════════════

-- anon no debe tocar esta tabla de ninguna manera.
revoke all on public.usuarios from anon;

-- FARO solo LEE usuarios, en dos sitios, los dos con .select():
--   index.html:1470  select('tiendas')            -> tiendas del admin
--   index.html:1516  select('email,rol,tiendas')  -> permisos del usuario
-- Ningun punto del codigo escribe. Las altas se hacen desde el panel de
-- Supabase, que usa la service_role y se salta RLS y GRANT.
-- Asi, un coordinador con sesion tampoco puede ascenderse a admin.
revoke insert, update, delete, truncate on public.usuarios from authenticated;
grant  select on public.usuarios to authenticated;

alter table public.usuarios enable row level security;

-- Con RLS activa y cero politicas nadie veria nada y FARO dejaria de
-- funcionar: hace falta esta politica de lectura.
-- De momento, cualquier usuario CON SESION lee la tabla. Es lo mismo que
-- pasa hoy, asi que no cambia ningun comportamiento; lo que se corta es el
-- acceso anonimo, que es el agujero real. La FASE 1C la reduce a la propia
-- fila una vez confirmado el bloque 4.
drop policy if exists usuarios_select_autenticados on public.usuarios;
create policy usuarios_select_autenticados on public.usuarios
  for select to authenticated
  using (true);


-- ═══ 1B · quitar a anon el DML del resto ════════════════════
-- La RLS de estas tablas ya deniega a los anonimos: esto no cambia nada
-- funcional. Es para que un despiste con RLS no vuelva a exponer datos.
-- No se toca authenticated: es el rol con el que trabaja FARO.

revoke all on public.datos_diarios_faro       from anon;
revoke all on public.archivos_faro            from anon;
revoke all on public.objetivos_semanales_faro from anon;
revoke all on public.plan_semanal_faro        from anon;
revoke all on public.focos_tienda_faro        from anon;
revoke all on public.focos_rapport_faro       from anon;
revoke all on public.promociones_faro         from anon;
revoke all on public.marcas_verdes_mensual    from anon;
revoke all on public.profiles                 from anon;
-- tiendas_faro no aparece: anon ya no tenia ningun GRANT sobre ella.

commit;


-- ═══ COMPROBACION ═══════════════════════════════════════════
-- Ejecutar DESPUES del commit. Solo lectura.

-- 1. usuarios con RLS activa y 1 politica.
select relname as tabla, relrowsecurity as rls_activa,
       (select count(*) from pg_policies
         where schemaname='public' and tablename='usuarios') as n_politicas
from pg_class
where relnamespace='public'::regnamespace and relname='usuarios';

-- 2. anon no debe salir en esta lista NI UNA VEZ.
--    authenticated debe tener SELECT (y solo SELECT) sobre usuarios.
select table_name as tabla, grantee as rol,
       string_agg(privilege_type, ',' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema='public' and grantee in ('anon','public')
   or (table_schema='public' and table_name='usuarios')
group by 1,2
order by (grantee='anon') desc, table_name;


-- ═══ DESPUES: comprobar en la aplicacion ════════════════════
-- 1. Recargar FARO y entrar. Debes seguir viendo tus 10 tiendas.
--    En la consola: "[FARO] Permisos de tienda · ... · 10 tienda(s) ·
--    tiendas_asignadas".
-- 2. La fuga, cerrada. Esto debe devolver [] en vez de las 8 filas:
--      curl "https://hkbilhpsvnklumidcmjy.supabase.co/rest/v1/usuarios?select=*" \
--        -H "apikey: sb_publishable_SEjX00w-4l3NOxNcuF9OHw_Ce8TU-l6"
