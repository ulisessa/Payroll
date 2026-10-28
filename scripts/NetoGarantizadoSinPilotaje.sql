/* NETO GARANTIZADO: NO APLICA EN LA LIQUIDACIÓN DE PILOTAJE. Primera corrida de PILOTAJE de abril de 2026 (22/10/2026): 5 liquidaciones de oficiales no guardadas ("el grossing-up no convergió en 20 iteraciones").
   Causa: NETO_GARANT corre en toda liquidación (Tipos Liq. Aplicables vacío) y el motor evalúa su fórmula sin mirar los tipos (ResolverNetoGarantizado), así que PILOTAJE
   encendía el grossing-up con el neto mensual pactado (1.534.400, etc.). El pilotaje paga fijo (5 días de pilotaje + 1 de puerto, como Meta4) y no calcula el complemento (1003, 3553, 4743 no aplican a PILOTAJE),
   así que el neto nunca llegaba.
   Cambio: vigencia nueva del 1/4/2026 de NETO_GARANT con la misma fórmula envuelta en IF(TIPO_LIQ = 'PILOTAJE', 0, ...). La anterior (1/2/2026) se cierra el 31/3.
   Rollback: borrar la vigencia del 1/4/2026 y volver el "Vigencia Hasta" de la anterior a 1753-01-01.
   Después: reiniciar el servicio y volver a crear y calcular el PILOTAJE de abril. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='NETO_GARANT' AND [Vigencia Desde]='20260401')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = (SELECT TOP 1 [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='NETO_GARANT' AND [Vigencia Hasta]='17530101');
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Fórmula'));
SET @sql = N'INSERT ' + @TC + N' ([Vigencia Desde],[Fórmula],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',@nf,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código]=''NETO_GARANT'' AND [Vigencia Hasta]=''17530101'';';
DECLARE @nf nvarchar(max) = N'IF(TIPO_LIQ = ''PILOTAJE'', 0,' + CHAR(13) + CHAR(10) + @f + N')';
EXEC sp_executesql @sql, N'@nf nvarchar(max)', @nf=@nf;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]='NETO_GARANT' AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='NETO_GARANT' ORDER BY [Vigencia Desde];
COMMIT;
