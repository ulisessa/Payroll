/* Meta4 8573: 2% para SSI, convenio 372/04. Preview por defecto.
   Nueva vigencia, sin modificar la fórmula histórica. Requiere reinicio de BC.
   Atributo de afiliación del caso final: conservar 2025 y agregar el vínculo 2026. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260105';
IF DB_NAME()<>N'Migr2013R2' THROW 51400,'Base incorrecta.',1;
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @A sysname=N'ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @F sysname=N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Formula nvarchar(2048)=N'ROUND(BASE_SINDICAL * 2 / 100, PRECISION_REDONDEO)';
DECLARE @Cond nvarchar(2048)=N'CONVENIO = ''372/04'' AND (PCT_SINDICATO = ''SSI'' OR PCT_SINDICATO = ''SEC'')';
DECLARE @Anterior datetime=(SELECT MAX([Vigencia Desde]) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='8573');
IF @Anterior IS NULL OR @Anterior>=@Desde THROW 51401,'Revisar las vigencias de 8573.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='8573' AND Fórmula<>'') THROW 51402,'8573 ya tiene fórmula; no sobrescribir.',1;
SELECT @Desde Vigencia,@Formula Fórmula,@Cond Condición;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
 WHEN name=N'Fórmula' THEN N'@Formula'
 WHEN name=N'Condición' THEN N'@Cond'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE Código=''8573'' AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 51403,''Plantilla no encontrada.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Anterior datetime,@Formula nvarchar(2048),@Cond nvarchar(2048)',@Desde,@Anterior,@Formula,@Cond;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código='8573' AND [Vigencia Desde]=@Anterior;
 /* El aporte sindical deducible usa el mismo acumulador que la cuota sindical. */
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Cód_ Concepto' THEN N'N''8573'''
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@F)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@F)+N' ('+@Cols+N') SELECT TOP(1) '+@Vals+N' FROM '+QUOTENAME(@F)+N' WHERE [Cód_ Concepto]=''8522'' AND [Cód_ Acumulador]=''CUOTA_SINDICAL_RET'' ORDER BY [Vigencia Desde] DESC; IF @@ROWCOUNT<>1 THROW 51404,''Falta acumulador sindical.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime',@Desde;
 /* Copia sólo la afiliación SSI del vínculo final, confirmado por el archivo Meta4. */
 IF EXISTS(SELECT 1 FROM [ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Entidad]='90448' AND [Cód_ Tipo Atributo]='SINDICATO' AND [Vigencia Desde]>='20260101') THROW 51405,'Revisar afiliación 2026 existente.',1;
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'CONVERT(datetime,''20260109'',112)'
 WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''20260124'',112)'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@A)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@A)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@A)+N' WHERE [Cód_ Entidad]=''90448'' AND [Cód_ Tipo Atributo]=''SINDICATO'' AND [Vigencia Desde]=''20250109'' AND [Vigencia Hasta]=''20250124'' AND [Cód_ Valor]=''SSI''; IF @@ROWCOUNT<>1 THROW 51406,''Afiliación plantilla cambió.'',1;';
 EXEC sys.sp_executesql @SQL;
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;

