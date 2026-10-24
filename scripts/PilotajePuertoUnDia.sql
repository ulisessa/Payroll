/* PILOTAJE: EL PUERTO ES SIEMPRE 1 DÍA (22/10/2026). Comparación de abril contra Meta4 (TP_IMPUT 12): en los proyectos de 24 a 25/4 el 1083 da 1 día, igual que Meta4, pero en los de 23 a 25/4 (PN-801 y PN-802) DIAS_PUERTO da 2 y el 1083
   y la antigüedad (1053) salen al doble / con un día de más. Meta4 paga 1 día de puerto (el arribo) en toda la historia del pilotaje, sin importar la duración del proyecto.
   Cambio, en el lugar (las dos vigencias del 1/4/2026 son de este mes): en PILOTAJE el 1083 cuenta MIN(DIAS_PUERTO, 1) y el 1053 MIN(DIAS_PUERTO, 1) + #DIAS_PILOT_PAGO.
   Rollback: volver a DIAS_PUERTO en ambos. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=REPLACE([Fórmula], N'DIAS_PUERTO + IF(TIPO_LIQ = ''PILOTAJE'', 0, DIAS_GP_PERIODO)', N'IF(TIPO_LIQ = ''PILOTAJE'', MIN(DIAS_PUERTO, 1), DIAS_PUERTO + DIAS_GP_PERIODO)'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1083' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS c1083_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=REPLACE([Fórmula], N'(DIAS_PUERTO + #DIAS_PILOT_PAGO)', N'(MIN(DIAS_PUERTO, 1) + #DIAS_PILOT_PAGO)'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1053' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS c1053_esperado_1;
SELECT [Código], CASE WHEN [Fórmula] LIKE N'%MIN(DIAS_PUERTO, 1)%' THEN 'ok' ELSE 'SIN CAMBIO' END r FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1053','1083') AND [Vigencia Desde]='20260401';
