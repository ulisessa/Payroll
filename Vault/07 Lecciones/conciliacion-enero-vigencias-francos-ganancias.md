---
aliases: ["Conciliación de enero: precio de francos y Ganancias final"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, francos, parametros-atributos, descuentos-ganancias-sipa, migracion-meta4]
fuente: [src/Codeunits/Cod50053.GestionFrancos.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod110031.RecalculoEnCadenaLiq.al, scripts/CorregirPrecioFrancoMerluza.sql, scripts/CorregirAcuerdoFrancoOF02.sql, scripts/CorregirAporteSolidarioFTIA.sql, scripts/CorregirGananciasFinalAnual.sql, scripts/CorregirSindicalSACDevengado.sql, scripts/SepararSindicalRealGananciasFinal.sql, test/Codeunits/Cod110061.TestCuentaFrancos.al]
actualizado: 2026-10-12
---

# Conciliación de enero: precio de francos y Ganancias final

Cambios aplicados en **ArbuTest**, versión **1.0.0.633** instalada. Se consultaron directamente
las fórmulas de Oracle, además del archivo importado. Los scripts quedan en preview por defecto;
sus guardas impiden repetir una migración aplicada. Ver [[Pendientes liquidación final]].

## Vigencia de la configuración del precio

`Gestión Francos.CargarConfigValuacion` tomaba el primer concepto histórico con parámetro de precio,
sin filtrar vigencia. Una nueva versión del concepto podía calcular su fórmula pero seguir usando
el atributo de precio de una versión anterior. Ahora filtra **Activo, Vigencia Desde y Vigencia Hasta**
para la fecha de valuación. El caché se invalida cuando esa fecha cambia, sin borrar cotizaciones.

Meta4 1062 tiene precio completo para marinería tanto en PT como en CG. El 1063 aplica reducción
sólo para CG. El catálogo compartido `TIPOACTIVIDAD` tenía ML con sufijo LAN, cuya tarifa ya está
reducida. Cambiarlo globalmente afectaría también parámetros de puerto y otros haberes.

Se creó **PESQ_FRANCO**, con catálogo y asignaciones vigentes de buques copiados de TIPOACTIVIDAD:
ML selecciona la tarifa plena CAL; PO sigue CAL y TA conserva LAN. CAL identifica aquí una **tarifa**,
no afirma que el buque sea potero. Sólo la nueva vigencia de 1063, desde 05/01/2026, usa ese atributo.
Fórmula, cantidad de matriz y nueve fracciones acumuladoras se conservaron.

> [!warning] Mantenimiento de buques
> PESQ_FRANCO y TIPOACTIVIDAD son configuraciones independientes. Al crear un buque o modificar
> su clasificación hay que mantener ambas asignaciones. No existe sincronización automática.

La cuenta corriente conserva selección de lotes y días; cambiar el precio no consume días extra.
Ver [[Cuenta corriente y matriz de francos]].

## Acuerdo de oficiales y aporte solidario

- Para OF02, Meta4 2083 toma el neto garantizado del puesto MQ01 dividido dos. Se corrigió el
  parámetro CAL/175/75/OF02 mediante una nueva vigencia, conservando USD y TC_COMPRADOR.
  El haber 2083 coincide al centavo; el comparativo agregado conserva un pequeño residuo.
- 8573 existía sin fórmula. Meta4 8571 fija 2 % para CA/JO salvo STI; 8573 aplica a SSI o SEC.
  En el encuadre 372/04 se configuró `ROUND(BASE_SINDICAL * 2 / 100, PRECISION_REDONDEO)`
  condicionado a SSI/SEC, con nueva vigencia y aporte a CUOTA_SINDICAL_RET. Los dos casos de
  enero que lo pagan en Meta4 se verificaron al centavo. Se agregó la afiliación del vínculo
  final de 2026 que estaba ausente; se conservó la asignación histórica de 2025.

## Ganancias final: impuesto anual y devolución

El total mensual cero de Meta4 **no significa que cada corrida retenga cero**: la final devuelve
retenciones realizadas en otras corridas del año. La fórmula anterior de BC usaba escala mensual
y `MAX(..., 0)`, que impedía la devolución.

La [RG4003, art.21b](https://www.argentina.gob.ar/normativa/nacional/272231/actualizacion) establece
montos **anuales** de deducciones y escala, actualizados al mes de la final. No se prorratean por
el mes de baja. Se corrige la indicación anterior del pendiente, que citaba art.11 y prorrateo.

Nueva rama del 5010 desde 05/01/2026, completada desde 06/01 con sindical real:

```text
IF(TIPO_LIQ = 'LIQ_FINAL',
 ROUND(TRAMO('TAB_IMP_4CAT_AN', MAX(
  YTD_HAB_GRAV_ANUAL + BASE_IG4 + YTD_HAB_EXTORD_ANUAL + BASE_EXT_IG4
  - YTD_SS_LIQUIDADO - SS_LIQUIDADO
  - YTD_CUOTA_SIND_REAL - CUOTA_SIND_REAL
  - (MNI_ANUAL + DESP_4CAT_ANUAL) * 12 - DEDUC_GANANCIAS, 0))
  - YTD_RETENIDO_ANUAL, PRECISION_REDONDEO),
 fórmula mensual anterior)
```

Los nombres MNI_ANUAL y DESP_4CAT_ANUAL son históricos: las filas cargadas contienen valores
mensuales. Las cargas de familia también están cargadas por mes; Contexto Liquidación las lleva
a monto anual sólo en LIQ_FINAL, respetando porcentaje de deducción. Los gastos declarados
con Importe Fijo se conservan. El detalle de Ganancias registra ese monto familiar anual.

SAC real ya integra BASE_IG4; los descuentos de SAC reales integran SS_LIQUIDADO. La final no suma
BASE_SAC_DEV/YTD_SAC_DEV ni descuenta aportes ficticios de devengo. CUOTA_SIND_REAL y su YTD
copian las fracciones de los descuentos efectivamente pagados y excluyen 4754–4757, también
en la historia del año. Son configuración del mecanismo existente de acumuladores y YTD_ACUM,
sin tablas ni campos nuevos. La rama mensual del 5010 conserva su fórmula.

## SAC sindical virtual y recálculo del mes

El 4754 omitía capacitación del SAC devengado para PAT y solidaridad del SAC para SSI/SEC en
372/04. Se completó su fórmula en una nueva vigencia, conservando la exclusión de LIQ_FINAL.
4755/4756/4757 ya representan los otros devengos; no se suman de nuevo al 4754.

La suma mensual de descuentos sindicales de Meta4 incluye esas partes virtuales. Su ausencia
elevaba Ganancias y el grossing-up aumentaba el complemento para conservar el neto. Corregida
la base fiscal, la diferencia principal del caso desapareció; quedan residuos menores.

Recalcular cierres individualmente mientras sus posteriores del mismo mes siguen Calculadas
puede anular aportes por tope. Se agregó EjecutarMesEmpleado al codeunit existente de cadena:
reabre todas las Calculadas del empleado/mes y las calcula en orden, en una transacción.
Ver [[Recálculo en cadena]] y `scripts/RecalcularMesEmpleado.ps1`.

## Verificación y límites

- Se recalcularon 41 documentos alcanzados por francos/finales y luego las ocho finales con 5010.
- La validación definitiva rehízo los meses completos de los empleados alcanzados por los
  cambios de francos/finales y sindical de SAC. Las 570 liquidaciones permanecen Calculadas.
- Ganancias agregado de enero de los ocho empleados con final: cero, igual al legado.
- Ocho pruebas AL pasaron con rollback: incluyen conservar importes/bases/saldo al repetir el
  cálculo, reversión y eliminación, alternar vigencias del precio sin cambiar días y conservar
  el tope mensual y los totales al repetir el recálculo de un mes con varios recibos.
- Todos los pagos de 1063 con cantidad positiva conservan enlace a lote; sin aplicaciones duplicadas.
- La fórmula original de antigüedad de Meta4, concepto 1048 vigente desde 2017, usa entero(años)
  en CA/JO antes de diez años. El caso discordante registra más de cinco años y paga cuatro:
  no se cambió BC para reproducir esa excepción de la corrida. Ver [[escala-antiguedad-meta4]].
- La diferencia principal de grossing-up quedó resuelta con capacitación del SAC virtual;
  los cinco casos corregidos conservan diferencias de centavos o pocos pesos por redondeo.
- La validación fiscal corresponde a enero de 2026; no sustituye pruebas de cierre anual,
  múltiples bajas o liquidaciones informativas.
