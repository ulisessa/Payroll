/* PREVIEW por defecto. Publicar primero versión 631 (familia anual en finales).
   RG4003 art21b: deducciones y escala anuales. SAC y aportes reales ya integran IG4/SS.
   Conserva la rama mensual. Admite devolución de retenciones anteriores.
   MNI_ANUAL/DESP_4CAT_ANUAL son nombres históricos: sus filas contienen valores mensuales. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260105';
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Anterior datetime,@Formula nvarchar(max),@Original nvarchar(2048);
IF DB_NAME()<>N'Migr2013R2' THROW 51700,'Base incorrecta.',1;
SELECT TOP(1) @Anterior=[Vigencia Desde],@Original=Fórmula FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='5010' ORDER BY [Vigencia Desde] DESC;
IF @Anterior IS NULL OR @Anterior>=@Desde THROW 51701,'Existe vigencia posterior: revisar.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='TAB_IMP_4CAT_AN' AND [Vigencia Desde]='20260101' AND [No_ Tramo]=1 AND [Límite Inferior]=0 AND [Monto Fijo]=0) THROW 51702,'Falta escala anual.',1;
SET @Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND(TRAMO(''TAB_IMP_4CAT_AN'', MAX(YTD_HAB_GRAV_ANUAL + BASE_IG4 + YTD_HAB_EXTORD_ANUAL + BASE_EXT_IG4 - YTD_SS_LIQUIDADO - SS_LIQUIDADO - YTD_CUOTA_SINDICAL - CUOTA_SINDICAL_RET - (MNI_ANUAL + DESP_4CAT_ANUAL) * 12 - DEDUC_GANANCIAS, 0)) - YTD_RETENIDO_ANUAL, PRECISION_REDONDEO), '+@Original+N')';
IF LEN(@Formula)>2048 THROW 51703,'Fórmula demasiado larga.',1;
SELECT @Desde Vigencia,@Formula Fórmula;
IF @Aplicar=0 RETURN;
IF NOT EXISTS(SELECT 1 FROM [NAV App Installed App] WHERE [App ID]='d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890' AND [Version Revision]>=631) THROW 51705,'Publicar primero la versión 631 o posterior.',1;
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
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE Código=''5010'' AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 51704,''Plantilla cambió.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Anterior datetime,@Formula nvarchar(2048)',@Desde,@Anterior,@Formula;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código='5010' AND [Vigencia Desde]=@Anterior;
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
