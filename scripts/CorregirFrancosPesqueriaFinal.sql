/* Corrección coordinada. PREVIEW por defecto. Aplicar sólo después de publicar el campo
   Factor Importe Consumo. Nueva vigencia 02/01/2026: conserva las versiones del 01/01;
   las finales de enero verificadas tienen Fecha Liquidación 31/01/2026. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0, @Desde datetime='20260102';
IF DB_NAME()<>N'Migr2013R2' THROW 51200,'Base incorrecta.',1;
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Cambios TABLE(Codigo nvarchar(20),Anterior datetime,Formula nvarchar(2048),Factor nvarchar(2048));
INSERT @Cambios
SELECT Código,[Vigencia Desde],Fórmula,N'' FROM (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY Código ORDER BY [Vigencia Desde] DESC) rn
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código IN ('1063','3554','1603','2083','2803','AJ_PROM_PESQUERIA') AND [Vigencia Desde]<@Desde
) c WHERE rn=1;
IF (SELECT COUNT(*) FROM @Cambios)<>6 THROW 51201,'Faltan plantillas.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN @Cambios p ON c.Código=p.Codigo WHERE c.[Vigencia Desde]>=@Desde)
 THROW 51202,'Existe una versión posterior: revisar, no pisar.',1;
UPDATE @Cambios SET Factor=N'IF(TIPO_LIQ = ''LIQ_FINAL'', #COEF_PESQUERIA, 1)' WHERE Codigo='1063';
UPDATE @Cambios SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND(#1063 / IFZERO(#COEF_PESQUERIA, 1) * (1 - #COEF_PESQUERIA), PRECISION_REDONDEO), '+Formula+N')' WHERE Codigo='3554';
/* Los consumidores que antes leían el franco completo conservan esa semántica. */
UPDATE @Cambios SET Formula=REPLACE(Formula,N'#1063',N'IF(TIPO_LIQ = ''LIQ_FINAL'', #1063 / IFZERO(#COEF_PESQUERIA, 1), #1063)') WHERE Codigo IN ('1603','2083','2803');
UPDATE @Cambios SET Formula=N'ROUND(
 (#1013 + #1073 + #1076 + #1083 + #1053 + #1543 + #1547 + #1023 + #2043
 + #1603 * (#1013 + #1083 + #1543 + #1053 + #1547 + #1076)
 / IFZERO(#1013 + #1083 + #1543 + #1053 + #1547 + #1076 + #1063 / IFZERO(#COEF_PESQUERIA, 1), 1)
 + #1063) / IFZERO(#COEF_PESQUERIA, 1) * (1 - #COEF_PESQUERIA), PRECISION_REDONDEO)' WHERE Codigo='AJ_PROM_PESQUERIA';
SELECT Codigo,Anterior,@Desde NuevaVigencia,Formula,Factor FROM @Cambios;
IF @Aplicar=0 RETURN;
IF COL_LENGTH(@T,'Factor Importe Consumo') IS NULL THROW 51203,'Publicar primero el cambio AL. No se modificó configuración.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Codigo nvarchar(20),@Anterior datetime,@Formula nvarchar(2048),@Factor nvarchar(2048),@Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 DECLARE versiones CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo,Anterior,Formula,Factor FROM @Cambios;
 OPEN versiones;
 FETCH NEXT FROM versiones INTO @Codigo,@Anterior,@Formula,@Factor;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH(UPDLOCK,HOLDLOCK) WHERE Código=@Codigo AND [Vigencia Desde]>=@Desde)
   THROW 51204,'La configuración cambió durante la operación.',1;
  SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
  @Vals=STRING_AGG(CAST(CASE
   WHEN name=N'Vigencia Desde' THEN N'@Desde'
   WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
   WHEN name=N'Fórmula' THEN N'@Formula'
   WHEN name=N'Factor Importe Consumo' THEN N'@Factor'
   WHEN name=N'$systemId' THEN N'NEWID()'
   WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
   WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
   ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
  FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
  SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE Código=@Codigo AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 51205,''Plantilla inexistente o duplicada.'',1;';
  EXEC sys.sp_executesql @SQL,N'@Codigo nvarchar(20),@Anterior datetime,@Desde datetime,@Formula nvarchar(2048),@Factor nvarchar(2048)',@Codigo,@Anterior,@Desde,@Formula,@Factor;
  /* Replica el encadenado de OnInsert AL; no altera las fórmulas históricas. */
  UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde)
  WHERE Código=@Codigo AND [Vigencia Desde]=@Anterior AND ([Vigencia Hasta]='17530101' OR [Vigencia Hasta]>=@Desde);
  FETCH NEXT FROM versiones INTO @Codigo,@Anterior,@Formula,@Factor;
 END;
 CLOSE versiones;
 DEALLOCATE versiones;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
