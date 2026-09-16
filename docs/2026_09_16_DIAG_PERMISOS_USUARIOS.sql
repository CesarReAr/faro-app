-- FARO · DIAGNOSTICO de permisos sobre public.usuarios · 16/09/2026
--
-- SOLO LECTURA. No crea, modifica ni borra nada: sin insert, update, delete,
-- alter, drop, create, grant ni revoke. Solo consulta catalogos del sistema.
-- Se puede ejecutar las veces que haga falta.
--
-- Devuelve UNA celda de texto: clic en ella y Ctrl+C.
--
-- Responde:
--   1_rls        si RLS esta activa y forzada en public.usuarios
--   2_politicas  que politicas existen sobre esa tabla (vacio = ninguna)
--   3_grants     que privilegios tiene CADA rol, incluido anon
--   4_resumen    lectura/escritura efectiva de anon y authenticated
--   5_columnas   estructura de la tabla (existe user_id?)

select jsonb_pretty(jsonb_build_object(

  '1_rls', (
    select jsonb_build_object(
             'tabla',       relname,
             'rls_activa',  relrowsecurity,
             'rls_forzada', relforcerowsecurity)
    from pg_class
    where relnamespace = 'public'::regnamespace and relname = 'usuarios'),

  '2_politicas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'politica',  policyname,
             'roles',     array_to_string(roles, ','),
             'cmd',       cmd,
             'permissive',permissive,
             'lectura',   qual,
             'escritura', with_check) order by cmd), '[]'::jsonb)
    from pg_policies
    where schemaname = 'public' and tablename = 'usuarios'),

  '3_grants', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'rol',         grantee,
             'privilegios', privs) order by grantee), '[]'::jsonb)
    from (
      select grantee,
             string_agg(privilege_type, ',' order by privilege_type) as privs
      from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'usuarios'
      group by grantee) g),

  '4_resumen', (
    select jsonb_build_object(
      'anon_puede_leer',           bool_or(grantee='anon'          and privilege_type='SELECT'),
      'anon_puede_escribir',       bool_or(grantee='anon'          and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')),
      'authenticated_puede_leer',  bool_or(grantee='authenticated' and privilege_type='SELECT'),
      'authenticated_puede_escribir', bool_or(grantee='authenticated' and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')))
    from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'usuarios'),

  '5_columnas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'columna', column_name,
             'tipo',    data_type,
             'nulos',   is_nullable) order by ordinal_position), '[]'::jsonb)
    from information_schema.columns
    where table_schema = 'public' and table_name = 'usuarios')

)) as diag_permisos_usuarios;
