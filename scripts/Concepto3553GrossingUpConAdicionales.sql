/* 3553 (VACACIONES) EN GROSSING-UP: LA BASE INCLUYE LO QUE SE PAGA SOBRE EL BÁSICO (23/10/2026). Segunda mitad del arreglo del 4743: en grossing-up el 3553 paga COMPLEMENTO_GU / 25 x días y deja afuera #2703 (zona desfavorable), cuando la rama normal (y Meta4) paga (#1003 + #1053 + #4573 + #2703 + #2103) / 25 x días.
   Con el 4743 descontando el complemento y el 2703, el motor cerraba el neto subiendo el complemento hasta absorber el 2703: bruto y neto de 90212 daban (a 90 pesos) pero las líneas no: 1003 9.270.633 contra 7.725.581 de Meta4 y 2703 1.854.127 contra 1.545.116. Con la misma base en el 3553 el complemento vuelve al sueldo base.
   Vigencia nueva del 1/4/2026 (la del 1/3 se cierra el 31/3). Rollback: borrar la del 1/4 y reabrir la anterior (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular la regular de abril de 90212. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='3553' AND [Vigencia Desde]='20260401') BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = (SELECT TOP 1 [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='3553' AND [Vigencia Hasta]='17530101');
DECLARE @nf nvarchar(max) = REPLACE(@f, N'COMPLEMENTO_GU,', N'COMPLEMENTO_GU + #1053 + #4573 + #2703 + #2103,');
IF @nf = @f BEGIN PRINT 'La fórmula no tiene el texto esperado'; ROLLBACK; RETURN; END;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), N',') FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Fórmula'));
SET @sql=N'INSERT '+@C+N' ([Vigencia Desde],[Fórmula],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',@nf,'+@cc+N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM '+@C+N' WHERE [Código]=N''3553'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@nf nvarchar(max)', @nf=@nf;
SELECT @@ROWCOUNT AS insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331',[$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='3553' AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
SELECT @@ROWCOUNT AS cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='3553' ORDER BY 1;
COMMIT;
