/* 4743 (DESCUENTO DÍAS DE VACACIONES) EN GROSSING-UP: TAMBIÉN DESCUENTA LO QUE SE PAGA SOBRE EL BÁSICO (23/10/2026). 90212 (EUR 6.000, grossing-up) tuvo vacaciones en abril: Meta4 descuenta -9.270.697 =
   -(1003 7.725.581 + 2703 1.545.116) / 30 x 30 días y BC -7.664.831: en grossing-up la fórmula tomaba COMPLEMENTO_GU en lugar de la suma entera (#1003 + #1053 + #4573 + #2703 + #2103) y dejaba afuera el adicional
   por zona desfavorable (2703, 20 % del básico). Se reemplaza COMPLEMENTO_GU por COMPLEMENTO_GU + #1053 + #4573 + #2703 + #2103 (el complemento ocupa el lugar del #1003).
   Vigencia nueva del 1/4/2026; la del 2/1/2026 se cierra el 31/3. Rollback: borrar la del 1/4 y reabrir la anterior (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular la regular de abril de 90212 (y verificar que 90016 y 90302 no cambien: no tuvieron vacaciones). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='4743' AND [Vigencia Desde]='20260401') BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = (SELECT TOP 1 [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='4743' AND [Vigencia Hasta]='17530101');
DECLARE @nf nvarchar(max) = REPLACE(@f, N'COMPLEMENTO_GU,', N'COMPLEMENTO_GU + #1053 + #4573 + #2703 + #2103,');
IF @nf = @f BEGIN PRINT 'La fórmula no tiene el texto esperado'; ROLLBACK; RETURN; END;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), N',') FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Fórmula'));
SET @sql=N'INSERT '+@C+N' ([Vigencia Desde],[Fórmula],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',@nf,'+@cc+N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM '+@C+N' WHERE [Código]=N''4743'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@nf nvarchar(max)', @nf=@nf;
SELECT @@ROWCOUNT AS insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331',[$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='4743' AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
SELECT @@ROWCOUNT AS cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='4743' ORDER BY 1;
COMMIT;
