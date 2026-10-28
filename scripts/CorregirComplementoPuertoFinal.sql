/* Complemento de puerto y francos de la final. Preview por defecto; nueva vigencia 03/01/2026. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0, @Desde datetime='20260103';
IF DB_NAME()<>N'Migr2013R2' THROW 51200,'Base incorrecta.',1;
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Cambios TABLE(Codigo nvarchar(20),Anterior datetime,Formula nvarchar(2048),Factor nvarchar(2048));
INSERT @Cambios
SELECT Código,[Vigencia Desde],Fórmula,N'' FROM (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY Código ORDER BY [Vigencia Desde] DESC) rn
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código IN ('3554') AND [Vigencia Desde]<@Desde
) c WHERE rn=1;
IF (SELECT COUNT(*) FROM @Cambios)<>1 THROW 51201,'Faltan plantillas.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN @Cambios p ON c.Código=p.Codigo WHERE c.[Vigencia Desde]>=@Desde)
 THROW 51202,'Existe una versión posterior: revisar, no pisar.',1;
/* BASE_PROMEDIO ya recibe este complemento por AJ_PROM_PESQUERIA.
   Aquí se paga; no se agrega ninguna fracción nueva a BASE_PROMEDIO. */
DECLARE @Complemento nvarchar(2048);
SELECT @Complemento=Fórmula FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='AJ_PROM_PESQUERIA' AND [Vigencia Desde]='20260102';
IF @Complemento IS NULL THROW 51206,'Falta la reconstrucción coordinada de la base.',1;
DECLARE @Original nvarchar(2048);
SELECT @Original=Fórmula FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='3554' AND [Vigencia Desde]='20230112';
IF @Original IS NULL THROW 51207,'Falta la fórmula histórica para otros tipos.',1;
UPDATE @Cambios SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', '+@Complemento+N', '+@Original+N')' WHERE Codigo='3554';
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


