/* Preview por defecto. El acumulador mensual incluye devengos de SAC por diseño.
   La final anual debe deducir sólo descuentos reales, también en los períodos anteriores.
   Se reutilizan conceptos acumuladores, fracciones y YTD_ACUM existentes; sin esquema nuevo. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260106';
DECLARE @Suffix nvarchar(100)=N'$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Nuevo nvarchar(20)=N'CUOTA_SIND_REAL',@Var nvarchar(30)=N'YTD_CUOTA_SIND_REAL';
DECLARE @Anterior datetime,@Formula nvarchar(2048);
IF DB_NAME()<>N'Migr2013R2' THROW 51900,'Base incorrecta.',1;
SELECT TOP(1) @Anterior=[Vigencia Desde],@Formula=Fórmula FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='5010' ORDER BY [Vigencia Desde] DESC;
IF @Anterior IS NULL OR @Anterior>=@Desde OR CHARINDEX(N'YTD_CUOTA_SINDICAL - CUOTA_SINDICAL_RET',@Formula)=0 THROW 51901,'Revisar versión anual de 5010.',1;
SET @Formula=REPLACE(@Formula,N'YTD_CUOTA_SINDICAL - CUOTA_SINDICAL_RET',N'YTD_CUOTA_SIND_REAL - CUOTA_SIND_REAL');
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código=@Nuevo) OR EXISTS(SELECT 1 FROM [ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=@Var) THROW 51902,'La configuración ya existe.',1;
SELECT @Nuevo Acumulador,@Var Variable,@Desde Vigencia;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Pasos TABLE(Id int,Tabla sysname,Filtro nvarchar(2000));
 INSERT @Pasos VALUES
 (1,N'ArbuTest$Concepto Liquidación'+@Suffix,N'Código=''CUOTA_SINDICAL_RET'' AND [Vigencia Desde]=(SELECT MAX([Vigencia Desde]) FROM [ArbuTest$Concepto Liquidación'+@Suffix+N'] WHERE Código=''CUOTA_SINDICAL_RET'')'),
 (2,N'ArbuTest$Fracción Acumulador'+@Suffix,N'[Cód_ Acumulador]=''CUOTA_SINDICAL_RET'' AND [Cód_ Concepto] NOT IN (''4754'',''4755'',''4756'',''4757'') AND [Vigencia Desde]=(SELECT MAX(p.[Vigencia Desde]) FROM [ArbuTest$Fracción Acumulador'+@Suffix+N'] p WHERE p.[Cód_ Concepto]=[ArbuTest$Fracción Acumulador'+@Suffix+N'].[Cód_ Concepto] AND p.[Cód_ Acumulador]=''CUOTA_SINDICAL_RET'' AND p.[Vigencia Desde]<@Desde)'),
 (3,N'ArbuTest$Variable Sistema Liq_'+@Suffix,N'[Nombre Variable]=''YTD_CUOTA_SINDICAL'' AND [Cód_ Cálculo]=''YTD_ACUM'''),
 (4,N'ArbuTest$Concepto Liquidación'+@Suffix,N'Código=''5010'' AND [Vigencia Desde]=@Anterior');
 DECLARE @Id int,@T sysname,@Filtro nvarchar(2000),@Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max),@Filas int;
 DECLARE pasos CURSOR LOCAL FAST_FORWARD FOR SELECT Id,Tabla,Filtro FROM @Pasos ORDER BY Id;
 OPEN pasos;
 FETCH NEXT FROM pasos INTO @Id,@T,@Filtro;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
  @Vals=STRING_AGG(CAST(CASE
   WHEN @Id=1 AND name=N'Código' THEN N'@Nuevo'
   WHEN @Id=1 AND name=N'Descripción' THEN N'N''Acum: descuentos sindicales reales'''
   WHEN @Id IN (2,3) AND name=N'Cód_ Acumulador' THEN N'@Nuevo'
   WHEN @Id=3 AND name=N'Nombre Variable' THEN N'@Var'
   WHEN @Id=3 AND name=N'Descripción' THEN N'N''Sindical real del año, excluye devengos de SAC'''
   WHEN @Id IN (1,2,4) AND name=N'Vigencia Desde' THEN N'@Desde'
   WHEN @Id IN (1,4) AND name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
   WHEN @Id=4 AND name=N'Fórmula' THEN N'@Formula'
   WHEN name=N'$systemId' THEN N'NEWID()'
   WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
   ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
  FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
  SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE '+@Filtro+N'; SET @Filas=@@ROWCOUNT;';
  EXEC sys.sp_executesql @SQL,N'@Nuevo nvarchar(20),@Var nvarchar(30),@Desde datetime,@Anterior datetime,@Formula nvarchar(2048),@Filas int OUTPUT',@Nuevo,@Var,@Desde,@Anterior,@Formula,@Filas OUTPUT;
  IF @Filas=0 THROW 51903,'Falta configuración plantilla.',1;
  SELECT @Id Paso,@Filas Copiados;
  FETCH NEXT FROM pasos INTO @Id,@T,@Filtro;
 END;
 CLOSE pasos;
 DEALLOCATE pasos;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código='5010' AND [Vigencia Desde]=@Anterior;
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
