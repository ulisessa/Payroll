/* Preview por defecto. Completa SAC sindical virtual para Ganancias, sin pagar descuentos.
   PAT: falta capacitación (8553). SSI/SEC 372/04: falta solidaridad (8573).
   Los otros devengos ya tienen conceptos 4755/4756/4757; no se duplican.
   LIQ_FINAL conserva exclusión de devengos y usa los descuentos reales. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260105';
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Anterior datetime=(SELECT MAX([Vigencia Desde]) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='4754');
DECLARE @Formula nvarchar(2048)=N'ROUND(BASE_SAC_DEV * (IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) + IF(PCT_SINDICATO = ''PAT'', PCT_CENTRO_CAPACIT, 0) + IF(CONVENIO = ''372/04'' AND (PCT_SINDICATO = ''SSI'' OR PCT_SINDICATO = ''SEC''), 2, 0)) / 100, 0.0001)';
IF DB_NAME()<>N'Migr2013R2' THROW 51800,'Base incorrecta.',1;
IF @Anterior IS NULL OR @Anterior>=@Desde THROW 51801,'Revisar vigencias de 4754.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='4754' AND [Vigencia Desde]=@Anterior AND [Es Devengo]=1 AND Condición=N'TIPO_LIQ <> ''LIQ_FINAL''') THROW 51802,'Falta exclusión de finales o cambió la configuración.',1;
SELECT @Desde Vigencia,@Formula Fórmula;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
 WHEN name=N'Fórmula' THEN N'@Formula'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE Código=''4754'' AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 51803,''Plantilla cambió.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Anterior datetime,@Formula nvarchar(2048)',@Desde,@Anterior,@Formula;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código='4754' AND [Vigencia Desde]=@Anterior;
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
