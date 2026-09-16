-- FARO · PASO 3a · RLS por tienda en marcas_verdes_mensual · 16/09/2026
-- NO EJECUTADO.
--
-- ES EL ENSAYO. Se hace primero en la tabla mas pequeña (1 sola lectura en
-- index.html) para validar el mecanismo antes de tocar datos_diarios_faro,
-- que tiene 10. Si algo va mal, se revierte en segundos y solo afecta a las
-- referencias LY de Marcas Verdes.
--
-- ─── QUE CAMBIA ─────────────────────────────────────────────
-- SOLO la politica de SELECT:
--   antes   using (auth.uid() = user_id)
--   ahora   using (tienda in (select public.faro_tiendas_autorizadas()))
--
-- INSERT, UPDATE y DELETE se quedan como estan, con auth.uid() = user_id.
--
-- ─── POR QUE ASI ────────────────────────────────────────────
-- "Leer por tienda, escribir por propietario."
-- Leer por tienda es lo que hace que la carga de Joaquim llegue a todos los
-- coordinadores. Escribir por propietario es lo que impide que uno modifique
-- o borre lo que subio otro, y conserva el rastro de quien cargo cada fila.
-- user_id deja de ser autorizacion y pasa a ser auditoria, que es el §25 del
-- planteamiento original.
--
-- ─── NO TOCA ────────────────────────────────────────────────
-- datos_diarios_faro, plan_semanal_faro, objetivos_semanales_faro,
-- focos_tienda_faro, focos_rapport_faro, promociones_faro, archivos_faro:
-- todas siguen exactamente igual.
-- No borra ni modifica ninguna fila de datos.
--
-- ─── CAMBIO DE FRONTEND QUE LO ACOMPAÑA ─────────────────────
-- index.html, loadMvMonthlyRefs(): se quita .eq('user_id', currentUserId).
-- Es seguro hacerlo en cualquier orden: mientras la RLS siga siendo por
-- user_id, quitar ese filtro no cambia nada porque la propia RLS lo aplica.


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 0 · ANTES · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Estado de partida, para poder comparar despues.

select 'politicas actuales' as que, policyname, cmd, qual as condicion
from pg_policies
where schemaname='public' and tablename='marcas_verdes_mensual'
order by cmd;

select 'contenido' as que,
       count(*)                as filas,
       count(distinct tienda)  as tiendas,
       count(distinct user_id) as propietarios,
       string_agg(distinct periodo::text, ', ' order by periodo::text) as periodos
from public.marcas_verdes_mensual;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 1 · EL CAMBIO · una sola politica
-- ═══════════════════════════════════════════════════════════

begin;

drop policy if exists mv_mes_select_own        on public.marcas_verdes_mensual;
-- Tambien la nueva, para que reejecutar el bloque no de error 42710.
drop policy if exists mv_mes_select_por_tienda on public.marcas_verdes_mensual;

create policy mv_mes_select_por_tienda on public.marcas_verdes_mensual
  for select to authenticated
  using (tienda in (select public.faro_tiendas_autorizadas()));

commit;


-- ═══════════════════════════════════════════════════════════
-- BLOQUE 2 · COMPROBACION · solo lectura
-- ═══════════════════════════════════════════════════════════
-- Esperado: 4 politicas. La de SELECT por tienda, las otras tres por user_id.

select policyname, cmd, qual as condicion_lectura, with_check as condicion_escritura
from pg_policies
where schemaname='public' and tablename='marcas_verdes_mensual'
order by cmd;


-- ═══════════════════════════════════════════════════════════
-- LA PRUEBA DE VERDAD · en el navegador, no aqui
-- ═══════════════════════════════════════════════════════════
-- auth.uid() y auth.jwt() son NULL en el SQL Editor (corre como postgres, sin
-- sesion), asi que faro_tiendas_autorizadas() devuelve vacio si se llama desde
-- aqui. Eso NO significa que este mal: hay que probarlo con una sesion real.
--
-- 1. CESAR, en la consola del navegador (F12):
--       await sb.from('marcas_verdes_mensual').select('tienda,periodo')
--    Debe devolver SOLO sus 10 tiendas. Igual que antes del cambio.
--
-- 2. JOAQUIM (admin), en su navegador:
--       await sb.from('marcas_verdes_mensual').select('tienda,periodo')
--    ANTES del cambio: [] (no ha subido nada).
--    DESPUES: debe ver las filas de Cesar.
--    >>> ESTA ES LA PRUEBA. Si Joaquim empieza a ver los datos de Cesar,
--        el mecanismo funciona y se puede aplicar a datos_diarios_faro.
--
-- 3. Que FARO siga funcionando igual para Cesar: entrar, Mi Area, y que el
--    indicador de Marcas Verdes LY no cambie.


-- ═══════════════════════════════════════════════════════════
-- COMO DESHACER
-- ═══════════════════════════════════════════════════════════
-- drop policy if exists mv_mes_select_por_tienda on public.marcas_verdes_mensual;
-- create policy mv_mes_select_own on public.marcas_verdes_mensual
--   for select to authenticated using (auth.uid() = user_id);
