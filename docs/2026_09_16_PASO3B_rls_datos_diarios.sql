-- FARO · PASO 3b · RLS por tienda en datos_diarios_faro · 16/09/2026
-- NO EJECUTADO.
--
-- ES EL PASO QUE IMPORTA: el que hace que la carga de Joaquim llegue a todos
-- los coordinadores. Hasta ahora cada usuario solo veia lo que el mismo habia
-- subido, asi que centralizar la carga era imposible.
--
-- Se hace despues del PASO 3a, que valido el mecanismo en
-- marcas_verdes_mensual: faro_tiendas_autorizadas() devolvio las 43 activas a
-- Joaquim por rol y las 10 asignadas a Cesar.
--
-- ─── QUE CAMBIA ─────────────────────────────────────────────
-- SOLO la politica de SELECT:
--   antes   using (auth.uid() = user_id)
--   ahora   using (tienda in (select public.faro_tiendas_autorizadas()))
--
-- INSERT, UPDATE y DELETE se quedan con auth.uid() = user_id.
-- Eso es deliberado: cada uno solo puede modificar o retirar lo que subio el.
-- Un coordinador no puede borrar la carga de Joaquim, ni al reves.
--
-- ─── CAMBIOS DE FRONTEND QUE LO ACOMPAÑAN ───────────────────
-- Solo DOS lecturas pierden el .eq('user_id', currentUserId):
--   refreshWeekFromHistory()   index.html
--   loadHistoricalState()      index.html
-- Las demas referencias a user_id sobre esta tabla se quedan como estan:
--   _fusionarParcialConExistente  fusiona con TU propia carga anterior
--   saveDailyHistory              conserva TUS KPI semanales confirmados
--   quitarCargaConDatos           solo retiras lo que TU subiste
--   deleteHistoricalUpload        idem
--   deleteFileAndImportedData     idem
--   _comprobarColumnaComparabilidad / _comprobarColumnaObservaciones  sondas
--
-- _soloTiendasDelArea() sigue filtrando en el frontend. No sobra: la RLS es la
-- seguridad y ese filtro es la interfaz. Para un admin con 43 tiendas, las dos
-- coinciden; para un coordinador tambien. Si algun dia divergen, manda la RLS.
--
-- ─── NO TOCA ────────────────────────────────────────────────
-- plan_semanal_faro, objetivos_semanales_faro, focos_tienda_faro,
-- focos_rapport_faro, promociones_faro, archivos_faro: siguen igual. Eso es
-- el paso 4.
-- No borra ni modifica ninguna fila.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · ANTES · solo lectura
-- ═══════════════════════════════════════════════════════════

select 'politicas actuales' as que, policyname, cmd, qual as condicion
from pg_policies
where schemaname='public' and tablename='datos_diarios_faro'
order by cmd;

select 'contenido' as que,
       count(*)                as filas,
       count(distinct tienda)  as tiendas,
       count(distinct user_id) as propietarios,
       min(fecha)              as desde,
       max(fecha)              as hasta
from public.datos_diarios_faro;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · EL CAMBIO · una sola politica
-- ═══════════════════════════════════════════════════════════

begin;

drop policy if exists datos_diarios_faro_select_own        on public.datos_diarios_faro;
-- Tambien la nueva, para que reejecutar no de error 42710.
drop policy if exists datos_diarios_select_por_tienda      on public.datos_diarios_faro;

create policy datos_diarios_select_por_tienda on public.datos_diarios_faro
  for select to authenticated
  using (tienda in (select public.faro_tiendas_autorizadas()));

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · COMPROBACION · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Esperado: 4 politicas. SELECT por tienda; INSERT, UPDATE y DELETE por user_id.

select policyname, cmd,
       qual       as condicion_lectura,
       with_check as condicion_escritura
from pg_policies
where schemaname='public' and tablename='datos_diarios_faro'
order by cmd;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 3 · PRUEBA SIMULADA · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Misma tecnica que en el 3a. La funcion vive en pg_temp y desaparece al
-- cerrar la sesion del SQL Editor.
-- Esperado: Cesar 254 filas (las suyas, como antes).
--           Joaquim 254 filas -> ANTES veia 0. Esa es la prueba.

create or replace function pg_temp.faro_tiendas_de(p_nombre text)
returns setof text
language plpgsql
as $$
begin
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
       (select count(*) from pg_temp.faro_tiendas_de(u.nombre)) as tiendas_autorizadas,
       (select count(*) from public.datos_diarios_faro d
         where d.tienda in (select * from pg_temp.faro_tiendas_de(u.nombre)))
                                                                as filas_que_veria
from public.usuarios u
where exists (select 1 from auth.users a
               where lower(a.email) = lower(trim(u.email)))
order by u.nombre;


-- ═══════════════════════════════════════════════════════════
-- LA PRUEBA DE VERDAD · en el navegador
-- ═══════════════════════════════════════════════════════════
-- 1. CESAR: entrar en FARO. Mi Area, Histórico, Rapport y Plan Semanal deben
--    mostrar EXACTAMENTE lo mismo que antes. Es el control: si algo cambia
--    para el, algo esta mal.
--
-- 2. JOAQUIM: entrar en FARO. Antes veia 43 tiendas vacias.
--    Ahora debe ver los datos de las 10 tiendas de Cesar, y las otras 33
--    vacias hasta que el cargue.
--    >>> ESA ES LA PRUEBA DEL PASO 3b.
--
-- 3. Cuando Joaquim suba el fichero corporativo, Cesar debe ver esos datos
--    sin haber subido nada. Ese es el objetivo de todo el trabajo.


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- drop policy if exists datos_diarios_select_por_tienda on public.datos_diarios_faro;
-- create policy datos_diarios_faro_select_own on public.datos_diarios_faro
--   for select to authenticated using (auth.uid() = user_id);
--
-- Y en index.html, devolver .eq('user_id',currentUserId) a
-- refreshWeekFromHistory() y loadHistoricalState().
