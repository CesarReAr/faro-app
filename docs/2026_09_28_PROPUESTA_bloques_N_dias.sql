-- FARO · PROPUESTA · bloques de N días en datos_diarios_faro · 28/09/2026
-- SIN EJECUTAR. Solo cuando César lo autorice.
--
-- ESTADO ACTUAL (leído el 28/09/2026 con una consulta de solo lectura):
--   datos_diarios_faro_tipo_periodo_check:
--     tipo_periodo IN ('dia','viernes_sabado','mes')
--   datos_diarios_faro_dias_incluidos_check:
--     (dia AND dias_incluidos=1) OR (viernes_sabado AND =2) OR (mes AND 1..31)
--   fuente: text NOT NULL, default 'SEGUIMIENTO_DIARIO', SIN restricción de valores.
--   Clave única: (user_id, fecha, tienda, fuente). Sin triggers.
--   RLS: insert/update/select por faro_tiendas_autorizadas(); no mira la fuente.
--   Filas: FOLLOWUP_CSV/dia 117 · SEGUIMIENTO_DIARIO/dia 213 ·
--          SEGUIMIENTO_DIARIO/viernes_sabado 50 · SEGUIMIENTO_MES/mes 153.
--
-- QUÉ CAMBIA: se admite tipo_periodo 'bloque' con dias_incluidos de 2 a 31
-- (días naturales de FECHA INICIO a FECHA FIN; la fila va con la fecha del
-- primer día). Un bloque de 1 día no existe: es 'dia'.
-- La fuente 'KPIS_TIENDAS_FARO' NO necesita migración (no hay restricción).
--
-- IMPACTO SOBRE EL HISTÓRICO: ninguno. No se toca ni una fila. Las reglas
-- nuevas son un superconjunto de las actuales: todas las filas existentes las
-- cumplen (el paso 0 lo comprueba antes). 'dia', 'viernes_sabado' y 'mes'
-- quedan exactamente igual.

-- ── PASO 0 · comprobación (solo lectura). Debe devolver 0. ──────────────
select count(*) as filas_que_no_cumplirian
from public.datos_diarios_faro
where not (
  (tipo_periodo='dia' and dias_incluidos=1)
  or (tipo_periodo='viernes_sabado' and dias_incluidos=2)
  or (tipo_periodo='mes' and dias_incluidos between 1 and 31)
  or (tipo_periodo='bloque' and dias_incluidos between 2 and 31)
);

-- ── PASO 1 · el cambio (una transacción: o entra todo o nada) ───────────
begin;
alter table public.datos_diarios_faro drop constraint datos_diarios_faro_tipo_periodo_check;
alter table public.datos_diarios_faro add constraint datos_diarios_faro_tipo_periodo_check
  check (tipo_periodo = any (array['dia','viernes_sabado','mes','bloque']));
alter table public.datos_diarios_faro drop constraint datos_diarios_faro_dias_incluidos_check;
alter table public.datos_diarios_faro add constraint datos_diarios_faro_dias_incluidos_check
  check (
    (tipo_periodo='dia' and dias_incluidos=1)
    or (tipo_periodo='viernes_sabado' and dias_incluidos=2)
    or (tipo_periodo='mes' and dias_incluidos between 1 and 31)
    or (tipo_periodo='bloque' and dias_incluidos between 2 and 31)
  );
commit;

-- ── PASO 2 · verificación (solo lectura) ─────────────────────────────────
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid='public.datos_diarios_faro'::regclass
  and conname in ('datos_diarios_faro_tipo_periodo_check','datos_diarios_faro_dias_incluidos_check');

-- ── ROLLBACK (solo si hiciera falta volver atrás) ────────────────────────
-- Antes: debe haber 0 filas 'bloque'. Si hay, NO borrar: avisar primero.
-- select count(*) from public.datos_diarios_faro where tipo_periodo='bloque';
-- begin;
-- alter table public.datos_diarios_faro drop constraint datos_diarios_faro_tipo_periodo_check;
-- alter table public.datos_diarios_faro add constraint datos_diarios_faro_tipo_periodo_check
--   check (tipo_periodo = any (array['dia','viernes_sabado','mes']));
-- alter table public.datos_diarios_faro drop constraint datos_diarios_faro_dias_incluidos_check;
-- alter table public.datos_diarios_faro add constraint datos_diarios_faro_dias_incluidos_check
--   check (
--     (tipo_periodo='dia' and dias_incluidos=1)
--     or (tipo_periodo='viernes_sabado' and dias_incluidos=2)
--     or (tipo_periodo='mes' and dias_incluidos between 1 and 31)
--   );
-- commit;
