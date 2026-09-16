-- FARO · PASO 3a · prueba simulando la sesion de cada usuario · 16/09/2026
-- SOLO LECTURA. No modifica datos ni politicas.
-- La funcion se crea en pg_temp: existe solo en esta sesion del SQL Editor y
-- desaparece al cerrarla. No queda nada en la base.
--
-- ─── POR QUE HACE FALTA ESTO ────────────────────────────────
-- auth.uid() y auth.jwt() leen de request.jwt.claims. En el SQL Editor no hay
-- sesion, asi que valen NULL y faro_tiendas_autorizadas() devuelve vacio
-- SIEMPRE, este bien o mal. Para probarla hay que fingir el JWT.
--
-- ─── QUE PRUEBA Y QUE NO ────────────────────────────────────
-- SI prueba: que faro_tiendas_autorizadas() devuelve las tiendas correctas
--            para cada persona (coordinador por asignaciones, admin y
--            visor_global por rol).
-- SI prueba: cuantas filas dejaria ver el predicado de la politica nueva.
-- NO prueba: la RLS de verdad, porque esta consulta corre como postgres, que
--            se la salta. La prueba definitiva sigue siendo abrir FARO con una
--            sesion real y mirar la consola del navegador.

create or replace function pg_temp.faro_tiendas_de(p_nombre text)
returns setof text
language plpgsql
as $$
begin
  -- Finge el JWT de esa persona, solo para esta transaccion.
  perform set_config('request.jwt.claims',
    (select json_build_object('sub', a.id::text,
                              'email', a.email,
                              'role', 'authenticated')::text
       from public.usuarios u
       join auth.users a on lower(a.email) = lower(trim(u.email))
      where u.nombre = p_nombre
      limit 1), true);
  return query select * from public.faro_tiendas_autorizadas();
end
$$;

select u.nombre,
       u.rol,
       case when regexp_replace(lower(trim(coalesce(u.rol,''))), '[[:space:]-]+','_','g')
                 in ('admin','visor_global')
            then 'por ROL (todas las activas)'
            else 'por ASIGNACIONES' end                       as origen,
       (select count(*) from pg_temp.faro_tiendas_de(u.nombre)) as tiendas_autorizadas,
       (select count(*) from public.marcas_verdes_mensual m
         where m.tienda in (select * from pg_temp.faro_tiendas_de(u.nombre)))
                                                              as filas_mv_que_veria,
       (select string_agg(t, ',' order by t)
          from pg_temp.faro_tiendas_de(u.nombre) as t)        as tiendas
from public.usuarios u
where exists (select 1 from auth.users a
               where lower(a.email) = lower(trim(u.email)))
order by u.nombre;
