-- FARO · FASE 1C · prechequeo antes de restringir public.usuarios · 16/09/2026
--
-- SOLO LECTURA. No crea, modifica ni borra nada.
-- Devuelve UNA celda de texto: clic en ella y Ctrl+C.
--
-- ─── POR QUE ────────────────────────────────────────────────
-- La FASE 1C restringiria la lectura de public.usuarios a la propia fila:
--
--   using (lower(trim(email)) = lower(auth.jwt() ->> 'email'))
--
-- public.usuarios NO tiene columna user_id: el email es la unica forma de
-- casar una fila con su cuenta de Auth. Si el email de alguna fila no
-- coincide EXACTAMENTE (tras lower+trim) con el de auth.users, esa persona
-- pierde su propia fila y se queda con CERO tiendas. Es justo el fallo que
-- la fase quiere evitar, asi que se comprueba antes.
--
-- Ya confirmado con el bloque 4: tiendas_faro tiene 51 filas, 43 activas,
-- T01..T86. Por tanto _faroLeerTablaTiendas() (index.html:1446) devuelve
-- siempre un array no vacio, _faroIdsTodasLasTiendas() (index.html:1467) es
-- inalcanzable, y era la unica funcion que leia usuarios entera. 1C no
-- rompe ningun modulo. Falta solo el emparejamiento por email.
--
-- Sin emails ni nombres en la salida: solo recuentos y estructura.

select jsonb_pretty(jsonb_build_object(

  -- 1. Columnas de usuarios. Se busca si ya existe user_id (haria innecesario
  --    casar por email) y el tipo real de la columna tiendas.
  '1_columnas_usuarios', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'columna', column_name, 'tipo', data_type, 'nulos', is_nullable)
           order by ordinal_position), '[]'::jsonb)
    from information_schema.columns
    where table_schema='public' and table_name='usuarios'),

  -- 2. Columnas de tiendas_faro. Decide si CANONICAL_STORES (index.html:8978)
  --    puede salir de la BD: hacen falta direccion/alias, no solo el nombre.
  '2_columnas_tiendas_faro', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'columna', column_name, 'tipo', data_type)
           order by ordinal_position), '[]'::jsonb)
    from information_schema.columns
    where table_schema='public' and table_name='tiendas_faro'),

  -- 3. EL BLOQUEANTE DE 1C: emparejamiento usuarios <-> auth.users por email.
  --    sin_cuenta_auth > 0  -> esas filas no corresponden a nadie que entre.
  --    email_con_espacios_o_mayusculas > 0 -> el trim/lower de la politica es
  --                                           imprescindible (ya lo lleva).
  '3_emparejamiento_email', (
    select jsonb_build_object(
      'filas_en_usuarios',              count(*),
      'con_cuenta_auth',                count(*) filter (where a.id is not null),
      'sin_cuenta_auth',                count(*) filter (where a.id is null),
      'con_fila_profiles',              count(*) filter (where p.id is not null),
      'sin_fila_profiles',              count(*) filter (where a.id is not null and p.id is null),
      'email_con_espacios_o_mayusculas',count(*) filter (where u.email is distinct from lower(trim(u.email))),
      'emails_duplicados',              count(*) - count(distinct lower(trim(u.email))))
    from public.usuarios u
    left join auth.users      a on lower(a.email) = lower(trim(u.email))
    left join public.profiles p on p.id = a.id),

  -- 4. Cuentas de Auth que NO tienen fila en usuarios: entrarian con cero
  --    tiendas y sin motivo visible (motivo 'usuario_no_encontrado').
  '4_auth_sin_fila_en_usuarios', (
    select count(*)
    from auth.users a
    where not exists (select 1 from public.usuarios u
                       where lower(trim(u.email)) = lower(a.email))),

  -- 5. El rol en femenino. resolverPermisosTiendas() (index.html:1436) compara
  --    con igualdad exacta contra 'coordinador'; 'Coordinadora' normaliza a
  --    'coordinadora' y cae en rol_sin_permiso_de_tiendas: CERO tiendas.
  '5_roles', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'rol_en_la_tabla', rol,
             'normalizado',     norm,
             'usuarios',        n,
             'que_ve_hoy', case
               when norm in ('admin','visor_global') then 'TODAS las tiendas'
               when norm = 'coordinador'             then 'sus tiendas asignadas'
               else 'CERO TIENDAS · FARO vacio' end)
           order by n desc), '[]'::jsonb)
    from (
      select rol,
             regexp_replace(lower(trim(translate(rol,
               'áéíóúüñÁÉÍÓÚÜÑ','aeiounAEIOUN'))), '[[:space:]-]+','_','g') as norm,
             count(*) as n
      from public.usuarios group by 1,2) r),

  -- 6. usuarios.rol frente a profiles.role: las dos fuentes de rol de FARO.
  --    usuarios.rol decide las tiendas; profiles.role decide el adminOnly
  --    de index.html:11778. Si discrepan, alguien es admin para una cosa y no
  --    para la otra.
  '6_rol_usuarios_vs_profiles', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'en_usuarios', ru, 'en_profiles', rp, 'usuarios', n)
           order by n desc), '[]'::jsonb)
    from (
      select regexp_replace(lower(trim(coalesce(u.rol,''))), '[[:space:]-]+','_','g') as ru,
             coalesce(lower(trim(p.role)), '(sin fila)')                              as rp,
             count(*) as n
      from public.usuarios u
      left join auth.users      a on lower(a.email) = lower(trim(u.email))
      left join public.profiles p on p.id = a.id
      group by 1,2) s),

  -- 7. Cobertura del catalogo: de las 43 tiendas activas, cuantas tienen
  --    coordinador asignado, y si alguien tiene asignada una tienda que no
  --    existe en el maestro (error de tecleo en el texto libre).
  '7_cobertura_catalogo', (
    with asignadas as (
      select distinct 'T' || lpad(substring(t from '(\d{1,3})'), 2, '0') as tienda
      from public.usuarios u
      cross join lateral unnest(string_to_array(coalesce(u.tiendas,''), ',')) as t
      where substring(t from '(\d{1,3})') is not null),
    catalogo as (
      select 'T' || lpad(substring(tienda from '(\d{1,3})'), 2, '0') as tienda, activa
      from public.tiendas_faro
      where substring(tienda from '(\d{1,3})') is not null)
    select jsonb_build_object(
      'tiendas_en_catalogo',        (select count(*) from catalogo),
      'activas',                    (select count(*) from catalogo where activa is not false),
      'activas_con_coordinador',    (select count(*) from catalogo c where c.activa is not false
                                       and exists (select 1 from asignadas a where a.tienda=c.tienda)),
      'activas_sin_coordinador',    (select count(*) from catalogo c where c.activa is not false
                                       and not exists (select 1 from asignadas a where a.tienda=c.tienda)),
      'asignadas_que_no_existen',   (select count(*) from asignadas a
                                       where not exists (select 1 from catalogo c where c.tienda=a.tienda))))

)) as prechequeo_fase1c;
