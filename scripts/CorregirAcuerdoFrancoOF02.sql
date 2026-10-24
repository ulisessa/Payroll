/* Preview por defecto. Meta4 2083: neto garantizado MQ01 / 2 = USD 3500.
   Nueva vigencia; conserva TC_COMPRADOR, moneda, categoría y demás metadatos. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260105';
DECLARE @T sysname=N'ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Codigo nvarchar(50)=N'VALOR_FRANCO_EMP_CAL_175/75_OF02';
IF DB_NAME()<>N'Migr2013R2' THROW 51600,'Base incorrecta.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=@Codigo AND [Vigencia Desde]>=@Desde) THROW 51601,'Existe una vigencia posterior.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=@Codigo AND [Vigencia Desde]='20260101' AND Valor=3600 AND Moneda='USD' AND [Cód_ Variable TC]='TC_COMPRADOR') THROW 51602,'La plantilla cambió.',1;
SELECT @Codigo Parámetro,@Desde Vigencia,3500 Valor,N'USD' Moneda;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'Valor' THEN N'3500'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE [Cód_ Parámetro]=@Codigo AND [Vigencia Desde]=''20260101''; IF @@ROWCOUNT<>1 THROW 51603,''Plantilla incorrecta.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Codigo nvarchar(50)',@Desde,@Codigo;
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
