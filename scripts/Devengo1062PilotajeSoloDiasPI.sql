/* DEVENGO DE FRANCOS DEL PILOTAJE: SÓLO LOS DÍAS PI (22/10/2026). Con DevengoFrancosEnPilotaje.sql el devengo del 1062 en PILOTAJE salió bien para A28 (proyecto PN-128-260424, 24 al 25/4: 1 día, como Meta4) pero 1 día de más para HF801 y HF802: sus
   proyectos de pilotaje (PN-801-260423 y PN-802-260423) empiezan el 23/4, el día de la llegada (PL), que el CIERRE ya devengó. DIAS_MAREA da 3 y el 1062 devengaba ROUND(0,5 x 3, 1) = 1,5 (se guarda 2): 04714 pasó de 62 a 64 días en la
   indemnización de francos contra 63 de Meta4. Meta4 devenga en la corrida de pilotaje 50 % de los DÍAS PI reales (DS_PILOT_REALES): 1 día.
   Cambio: 1062, vigencia nueva del 1/4/2026 (la del 1/1 se cierra el 31/3): IF(TIPO_LIQ = 'PILOTAJE', ROUND(COEF_FRANCOS * DIAS_PILOTAJE, 1), <fórmula anterior>). Las demás liquidaciones no cambian.
   Rollback: borrar la vigencia del 1/4 y reabrir la anterior (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular, en orden, el PILOTAJE de HF801 y HF802 (los empleados de PN-801-260423 y PN-802-260423) y las LIQ_FINAL de esos empleados. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1062' AND [Vigencia Desde]='20260401') BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @C nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max), @coma nvarchar(5)=N',';
DECLARE @f nvarchar(max) = (SELECT TOP 1 [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1062' AND [Vigencia Hasta]='17530101');
DECLARE @nf nvarchar(max) = N'IF(TIPO_LIQ = ''PILOTAJE'', ROUND(COEF_FRANCOS * DIAS_PILOTAJE, 1),' + CHAR(13) + CHAR(10) + @f + N')';
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Fórmula'));
SET @sql=N'INSERT '+@C+N' ([Vigencia Desde],[Fórmula],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',@nf,'+@cc+N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM '+@C+N' WHERE [Código]=N''1062'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@nf nvarchar(max)', @nf=@nf;
SELECT @@ROWCOUNT AS insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331',[$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='1062' AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
SELECT @@ROWCOUNT AS cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,LEFT(REPLACE([Fórmula],CHAR(13)+CHAR(10),' '),90) f,[Tipos Liq_ Aplicables] t FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1062' ORDER BY 1;
COMMIT;
