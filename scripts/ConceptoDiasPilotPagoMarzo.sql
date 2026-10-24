/* DIAS_PILOT_PAGO TAMBIÉN EN MARZO (23/10/2026). El 2073 tiene vigencia desde el 1/3/2026 y su fórmula lee #DIAS_PILOT_PAGO, pero ese concepto informativo sólo existe desde el 1/4/2026 (pilotaje aparte): todas las liquidaciones de
   marzo con 2073 (cierres, devengados, regulares y la vacaciones de los 175/75) cortaban con "Variable desconocida: ... #DIAS_PILOT_PAGO ... no existe ningún concepto vigente" y quedaban en Borrador al recalcular enero a abril.
   Se agrega una vigencia del 1/3 al 31/3/2026 copia de la del 1/4 (vale 0 salvo en el tipo PILOTAJE, que no existe en marzo). Rollback: borrar esa fila.
   Después: reiniciar el servicio y recalcular marzo y abril de los oficiales 175/75, en orden. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='DIAS_PILOT_PAGO' AND [Vigencia Desde]='20260301') BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), N',') FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Vigencia Hasta'));
SET @sql=N'INSERT '+@C+N' ([Vigencia Desde],[Vigencia Hasta],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''20260331'','+@cc+N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM '+@C+N' WHERE [Código]=N''DIAS_PILOT_PAGO'' AND [Vigencia Desde]=''20260401'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS insertada_esperado_1;
SELECT [Código] c,CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,LEFT([Fórmula],120) f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='DIAS_PILOT_PAGO' ORDER BY 2;
COMMIT;
