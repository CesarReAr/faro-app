-- FARO · PASO 1 · comprobacion de paridad · 16/09/2026 · SOLO LECTURA
--
-- ¿Dice user_store_access lo mismo que el campo de texto usuarios.tiendas?
-- Tienen que coincidir ANTES de tocar la RLS de los datos (paso 3): si no,
-- alguien veria tiendas en pantalla para las que la base no devuelve nada.
--
-- Se espera:
--   Cesar    coordinador   en_texto 10   en_tabla 10   IGUAL
--   Joaquim  admin         en_texto  0   en_tabla  0   IGUAL (sus 43 salen del rol)

select u.nombre,
       u.rol,
       (select count(*)
          from regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
         where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
           and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0)   as en_texto,
       (select count(*) from public.user_store_access x
         where x.user_id = a.id and x.activo)                        as en_tabla,
       case when (select count(*)
                    from regexp_split_to_table(coalesce(u.tiendas,''), '[^A-Za-z0-9]+') as t
                   where substring(t from '^[Tt]?0*([0-9]{1,3})$') is not null
                     and substring(t from '^[Tt]?0*([0-9]{1,3})$')::int > 0)
               = (select count(*) from public.user_store_access x
                   where x.user_id = a.id and x.activo)
            then 'IGUAL' else 'REVISAR' end                          as resultado,
       (select string_agg(x.tienda, ',' order by x.tienda)
          from public.user_store_access x
         where x.user_id = a.id and x.activo)                        as tiendas_en_tabla
from public.usuarios u
join auth.users a on lower(a.email) = lower(trim(u.email))
order by u.nombre;
