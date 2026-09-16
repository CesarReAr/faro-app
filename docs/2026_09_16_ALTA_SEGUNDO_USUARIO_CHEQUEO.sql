-- FARO · Chequeo de alta de un usuario · 16/09/2026
--
-- SOLO LECTURA. No crea, modifica ni borra nada.
-- Se puede ejecutar antes y despues de dar de alta a alguien.
--
-- USO: sustituir el email de la primera linea por el de la persona.
--      SQL Editor -> Run -> una celda -> Ctrl+C.
--
-- Comprueba los cuatro puntos que tienen que cuadrar para que FARO funcione:
--   A  auth.users   la cuenta existe y esta confirmada
--   B  usuarios     hay fila, con rol valido, y su email CASA con el de Auth
--   C  profiles     hay fila (si no, firmara los mensajes como "Usuario")
--   D  tiendas      las asignadas existen en tiendas_faro y estan activas
--
-- El email de Auth y el de public.usuarios deben coincidir tras lower+trim:
-- es la unica forma que tiene FARO de casar las dos (usuarios NO tiene user_id).

with objetivo as (select lower(trim('PON_AQUI_EL_EMAIL@dominio.com')) as email)

select jsonb_pretty(jsonb_build_object(

  -- A · Supabase Auth
  'A_auth', (
    select coalesce(jsonb_build_object(
      'existe',            true,
      'user_id',           a.id,
      'email_en_auth',     a.email,
      'email_confirmado',  (a.email_confirmed_at is not null),
      'ultimo_acceso',     a.last_sign_in_at,
      'creada',            a.created_at,
      'bloqueada',         (a.banned_until is not null and a.banned_until > now())),
      jsonb_build_object('existe', false))
    from auth.users a, objetivo o
    where lower(a.email) = o.email),

  -- B · public.usuarios
  'B_usuarios', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'nombre',           u.nombre,
      'email_en_usuarios',u.email,
      'rol',              u.rol,
      'rol_normalizado',  regexp_replace(lower(trim(translate(coalesce(u.rol,''),
                            'áéíóúüñÁÉÍÓÚÜÑ','aeiounAEIOUN'))), '[[:space:]-]+','_','g'),
      'rol_valido_para_faro',
        regexp_replace(lower(trim(translate(coalesce(u.rol,''),
          'áéíóúüñÁÉÍÓÚÜÑ','aeiounAEIOUN'))), '[[:space:]-]+','_','g')
        in ('admin','visor_global','coordinador','coordinadora','coordinadores','coordinadoras'),
      'tiendas_texto',    u.tiendas,
      'n_tiendas',        coalesce(array_length(string_to_array(u.tiendas, ','), 1), 0))),
      '[]'::jsonb)
    from public.usuarios u, objetivo o
    where lower(trim(u.email)) = o.email),

  -- B2 · EL PUNTO CRITICO: ¿casan los dos emails?
  --      Si 'casan' es false, FARO dara motivo 'usuario_no_encontrado'
  --      y la persona entrara sin ninguna tienda.
  'B2_emails_casan', (
    select jsonb_build_object(
      'hay_fila_en_auth',     (select count(*) from auth.users a, objetivo o where lower(a.email)=o.email),
      'hay_fila_en_usuarios', (select count(*) from public.usuarios u, objetivo o where lower(trim(u.email))=o.email),
      'casan',                exists (
         select 1 from auth.users a
         join public.usuarios u on lower(trim(u.email)) = lower(a.email)
         , objetivo o where lower(a.email) = o.email),
      'filas_duplicadas_en_usuarios',
        (select count(*) from public.usuarios u, objetivo o where lower(trim(u.email))=o.email) > 1)),

  -- C · public.profiles
  --     Sin fila: fetchProfile() (index.html:11989) usa .single(), falla, y
  --     currentUser queda en "Usuario". No bloquea el acceso; solo la firma.
  'C_profiles', (
    select coalesce(jsonb_build_object(
      'existe',       true,
      'display_name', p.display_name,
      'role',         p.role),
      jsonb_build_object('existe', false, 'efecto', 'firmara los mensajes como "Usuario"'))
    from public.profiles p
    join auth.users a on a.id = p.id, objetivo o
    where lower(a.email) = o.email),

  -- D · Tiendas asignadas frente al catalogo real
  'D_tiendas', (
    with asignadas as (
      select distinct 'T' || lpad(substring(t from '(\d{1,3})'), 2, '0') as tienda
      from public.usuarios u, objetivo o
      cross join lateral unnest(string_to_array(coalesce(u.tiendas,''), ',')) as t
      where lower(trim(u.email)) = o.email
        and substring(t from '(\d{1,3})') is not null),
    catalogo as (
      select 'T' || lpad(substring(tienda from '(\d{1,3})'), 2, '0') as tienda,
             nombre, activa
      from public.tiendas_faro
      where substring(tienda from '(\d{1,3})') is not null)
    select jsonb_build_object(
      'asignadas',        (select count(*) from asignadas),
      'existen_y_activas',(select count(*) from asignadas a join catalogo c using (tienda)
                            where c.activa is not false),
      'existen_inactivas',(select count(*) from asignadas a join catalogo c using (tienda)
                            where c.activa is false),
      'NO_EXISTEN',       (select coalesce(jsonb_agg(a.tienda), '[]'::jsonb) from asignadas a
                            where not exists (select 1 from catalogo c where c.tienda = a.tienda)),
      'detalle',          (select coalesce(jsonb_agg(jsonb_build_object(
                              'tienda', a.tienda, 'nombre', c.nombre, 'activa', c.activa)
                            order by a.tienda), '[]'::jsonb)
                            from asignadas a left join catalogo c using (tienda))))

)) as chequeo_alta
from objetivo;
