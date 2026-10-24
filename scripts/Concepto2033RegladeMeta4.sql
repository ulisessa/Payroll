/* 2033 (A CUENTA DE FUTUROS AUMENTOS PILOTAJE) CON LA REGLA DE META4 (22/10/2026). Antes comparaba contra las novedades cargadas y no contra el 2033 que sale de la fórmula: las novedades reemplazan
   a la fórmula, así que "coincidía" por construcción. Columnas reales de Meta4 (corrida de pilotaje del 21/4, M4_ACUMULADO_RL3): A_CT_FUT_AUM_PI (2033) = BRUTO_PRORRAT (2002) - TOT_HAB_GZDO (1990), mínimo cero.
   BRUTO_PRORRAT = NTO_GARANTIZADO (USD, el garantizado de navegación del empleado) x TC / 30 x DIAS_PILOTAJE (los días PI reales: 2, no los 5 que se pagan). 03664: 15.000 x 1.370 / 30 x 2 = 1.370.000;
   TOT_HAB_GZDO = 1043 + 1053 + 1083 + 1603 = 685.200; 2033 = 684.800 (exacto). 04455: 502.333 - 667.200 < 0 => 0, que es lo que paga Meta4. Los otros seis 2033 de Meta4 (04163, 04724, 04826, 04836, 04868, 04921) dan
   cero con esta regla y son incidencias manuales: siguen por novedad.
   Cambios: (1) fórmula en el lugar (la vigencia del 1/4/2026 es nueva de este mes): IF(VALOR_NAV_EMP * DIAS_PILOTAJE = 0, 0, MAX(0, round(VALOR_NAV_EMP / 30 * DIAS_PILOTAJE - (#1043 + #1053 + #1083 + #1603), PRECISION_REDONDEO)));
   (2) se anulan la novedad de importe cero de 04455 (11756) y la de 03664 (10884): ya las reproduce la fórmula.
   Rollback: la fórmula anterior (con DIAS_PILOT_PAGO) y las dos novedades en Estado 0 con tipo PILOTAJE. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'IF(VALOR_NAV_EMP * DIAS_PILOTAJE = 0, 0, MAX(0, round(VALOR_NAV_EMP / 30 * DIAS_PILOTAJE - (#1043 + #1053 + #1083 + #1603), PRECISION_REDONDEO)))', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'2033' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS c2033_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Estado]=2, [Motivo No Aplicada]=N'Anulada: la fórmula del 2033 reproduce el valor de Meta4 (BRUTO_PRORRAT - TOT_HAB_GZDO).', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (10884,11756) AND [Cód_ Concepto]='2033' AND [Estado]=0;
SELECT @@ROWCOUNT AS novedades_anuladas_esperado_2;
COMMIT;
