-- FARO · Diagnóstico de seguridad (13/10/2026)
-- SOLO LECTURA. Pegar en Supabase → SQL Editor y ejecutar bloque a bloque.

-- 1) Tablas de public: ¿tienen RLS activa?  (rls_activa = false es un problema)
select c.relname as tabla, c.relrowsecurity as rls_activa, c.relforcerowsecurity as rls_forzada
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relrowsecurity, c.relname;

-- 2) Políticas. Revisar las que dicen "true" o no miran auth.uid() / faro_tiendas_autorizadas():
--    con el registro abierto, cualquiera que se dé de alta es "authenticated".
select tablename, policyname, cmd, roles, qual as usando, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd;

-- 3) Privilegios de anon y authenticated por tabla (anon debería no tener ninguno).
select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated')
group by table_name, grantee
order by table_name, grantee;

-- 4) Funciones SECURITY DEFINER: deben fijar search_path y no estar abiertas a anon.
select p.proname as funcion, p.prosecdef as security_definer, p.proconfig as config,
       has_function_privilege('anon', p.oid, 'execute') as anon_puede
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'faro%'
order by p.proname;

-- 5) Buckets de Storage y si son públicos.
select id, name, public from storage.buckets;

-- 6) Usuarios de Auth sin fila en public.usuarios (altas que nadie ha invitado).
select au.email, au.created_at, au.last_sign_in_at
from auth.users au left join public.usuarios u on lower(u.email) = lower(au.email)
where u.email is null
order by au.created_at desc;
