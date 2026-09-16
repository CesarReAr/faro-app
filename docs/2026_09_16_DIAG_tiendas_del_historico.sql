-- FARO · Que tiendas hay en el historico y de quien son · 16/09/2026
-- SOLO LECTURA. No modifica nada.
--
-- POR QUE
-- El diagnostico del 16/09/2026 dio: Cesar tiene 287 filas en
-- datos_diarios_faro repartidas en 21 tiendas distintas, pero solo tiene 10
-- asignadas. Hoy no se nota: _soloTiendasDelArea() (index.html) esconde las
-- sobrantes en pantalla, y la RLS por user_id se las deja leer porque son
-- suyas.
--
-- En el PASO 3, cuando la RLS pase a filtrar por tienda, esas filas dejan de
-- ser "de Cesar" y pasan a verlas los coordinadores de esas tiendas. Si son
-- datos buenos, perfecto. Si son restos de pruebas o de cuando
-- _soloTiendasDelArea devolvia todas las filas, apareceran como cifras reales
-- en el FARO de otra persona.
--
-- Esta consulta dice, tienda por tienda, si esta asignada a quien la subio,
-- cuantas filas hay, de que fechas, de que fuente y cuando se cargaron.
--
-- COMO LEERLO
--   asignada_al_que_la_subio = false  -> revisar. Son las que cambiaran de
--                                        dueño en el paso 3.
--   ultima_carga antigua + pocas filas -> probablemente restos de pruebas.
--   en_catalogo = false               -> tienda que ni siquiera existe.

select d.tienda,
       exists (select 1
                 from public.user_store_access x
                where x.user_id = d.user_id
                  and x.tienda  = d.tienda
                  and x.activo)                     as asignada_al_que_la_subio,
       (c.tienda is not null)                       as en_catalogo,
       c.nombre                                     as nombre_catalogo,
       c.activa                                     as tienda_activa,
       count(*)                                     as filas,
       count(distinct d.fecha)                      as dias,
       min(d.fecha)                                 as desde,
       max(d.fecha)                                 as hasta,
       string_agg(distinct d.fuente, ', ')          as fuentes,
       max(d.created_at)::date                      as ultima_carga
from public.datos_diarios_faro d
left join (
  select 'T' || lpad(substring(tienda from '([0-9]{1,3})'), 2, '0') as tienda,
         nombre, activa
  from public.tiendas_faro
  where substring(tienda from '([0-9]{1,3})') is not null
) c on c.tienda = d.tienda
group by d.tienda, d.user_id, c.tienda, c.nombre, c.activa
order by asignada_al_que_la_subio asc, count(*) desc;
