/* DIAS_PILOT_PAGO CORRÍA TARDE: heredó del molde 5802 el "Fórmula Orden Cálculo" = 883, que pisa al "Orden Cálculo" 26. El 1043 (orden 27) lo leía antes de calcularse y pagaba cero en las 40 liquidaciones de PILOTAJE de abril (22/10/2026).
   Cambio: "Fórmula Orden Cálculo" = 26. Rollback: volver a 883. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula Orden Cálculo]=N'26', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'DIAS_PILOT_PAGO' AND [Vigencia Hasta]='17530101' AND [Fórmula Orden Cálculo]=N'883';
SELECT @@ROWCOUNT AS esperado_1;
