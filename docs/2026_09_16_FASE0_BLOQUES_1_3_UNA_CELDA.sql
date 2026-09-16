-- FARO · FASE 0 · bloques 1, 2 y 3 en UNA sola consulta · 16/09/2026
--
-- SOLO LECTURA. No crea, modifica ni borra nada.
--
-- Por que este fichero, si ya existe 2026_09_16_FASE0_DIAGNOSTICO_MULTIUSUARIO.sql:
-- el SQL Editor de Supabase solo muestra el resultado de la ULTIMA sentencia.
-- Ese fichero tiene 8 consultas sueltas, asi que hay que ejecutarlas de una en
-- una (seleccionar el bloque y Run ejecuta solo la seleccion).
-- Esta version devuelve los tres bloques urgentes en UNA celda de texto.
--
-- Uso: SQL Editor -> pegar -> Run -> clic en la celda del resultado -> Ctrl+C.
--
-- Responde:
--   1_rls        RLS activa/forzada y numero de politicas por tabla.
--   2_politicas  Todas las politicas, con el rol al que aplican. 'usuarios'
--                primero. Aqui se ve si anon puede LEER y si puede ESCRIBIR.
--   3_grants     Privilegios por rol. La otra mitad de la pregunta de escritura,
--                y si authenticated tiene SELECT sobre tiendas_faro.

select jsonb_pretty(jsonb_build_object(

  '1_rls', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla',       relname,
             'rls_activa',  relrowsecurity,
             'rls_forzada', relforcerowsecurity,
             'n_politicas', n_pol)
           order by relrowsecurity, relname), '[]'::jsonb)
    from (
      select c.relname, c.relrowsecurity, c.relforcerowsecurity,
             count(p.policyname) as n_pol
      from pg_class c
      left join pg_policies p
        on p.schemaname = 'public' and p.tablename = c.relname
      where c.relnamespace = 'public'::regnamespace
        and c.relkind = 'r'
      group by 1, 2, 3
    ) s),

  '2_politicas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla',     tablename,
             'politica',  policyname,
             'roles',     array_to_string(roles, ','),
             'cmd',       cmd,
             'permissive',permissive,
             'lectura',   qual,
             'escritura', with_check)
           order by (tablename = 'usuarios') desc, tablename, cmd), '[]'::jsonb)
    from pg_policies
    where schemaname = 'public'),

  '3_grants', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla',       table_name,
             'rol',         grantee,
             'privilegios', privs)
           order by (grantee = 'anon') desc, table_name), '[]'::jsonb)
    from (
      select table_name, grantee,
             string_agg(privilege_type, ',' order by privilege_type) as privs
      from information_schema.role_table_grants
      where table_schema = 'public'
        and grantee in ('anon', 'authenticated', 'public')
      group by 1, 2
    ) g)

)) as diagnostico_faro_fase0;
