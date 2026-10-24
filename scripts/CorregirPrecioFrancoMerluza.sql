/* Preview por defecto. Meta4 1062: precio pleno para PT y CG; 1063 sólo reduce CG.
   PESQ_FRANCO separa la clasificación del precio de TIPOACTIVIDAD, compartida por puerto.
   PO y ML usan tarifa plena CAL; TA conserva LAN. No cambia días, fórmula ni fracciones.
   Al crear/cambiar un buque debe mantenerse PESQ_FRANCO además de TIPOACTIVIDAD. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260105',@Tipo nvarchar(20)=N'PESQ_FRANCO';
IF DB_NAME()<>N'Migr2013R2' THROW 51500,'Base incorrecta.',1;
DECLARE @Suffix nvarchar(100)=N'$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Pasos TABLE(Id int,Tabla sysname,Filtro nvarchar(1000));
INSERT @Pasos VALUES
(1,N'ArbuTest$Tipo Atributo Liq_'+@Suffix,N'Código=''TIPOACTIVIDAD'''),
(2,N'ArbuTest$Valor Atributo Liq_'+@Suffix,N'[Cód_ Tipo Atributo]=''TIPOACTIVIDAD'''),
(3,N'ArbuTest$Atributo Entidad Liq_'+@Suffix,N'[Cód_ Tipo Atributo]=''TIPOACTIVIDAD'''),
(4,N'ArbuTest$Concepto Liquidación'+@Suffix,N'Código=''1063'' AND [Vigencia Desde]=''20260104'''),
(5,N'ArbuTest$Fracción Acumulador'+@Suffix,N'[Cód_ Concepto]=''1063'' AND [Vigencia Desde]=(SELECT MAX(p.[Vigencia Desde]) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p WHERE p.[Cód_ Concepto]=''1063'' AND p.[Cód_ Acumulador]=[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890].[Cód_ Acumulador] AND p.[Vigencia Desde]<@Desde)');
IF EXISTS(SELECT 1 FROM [ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código=@Tipo) THROW 51501,'El atributo ya existe; revisar antes de repetir.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='1063' AND [Vigencia Desde]>=@Desde) THROW 51502,'Existe vigencia posterior de 1063.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='1063' AND [Vigencia Desde]='20260104' AND [Fuente Matriz]='FRANCOS_FIFO') THROW 51503,'Falta la matriz vigente.',1;
SELECT @Desde Vigencia,@Tipo [Atributo de precio],N'ML: CAL; restantes sufijos intactos' Cambio;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Id int,@T sysname,@Filtro nvarchar(1000),@Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max),@Filas int;
 DECLARE pasos CURSOR LOCAL FAST_FORWARD FOR SELECT Id,Tabla,Filtro FROM @Pasos ORDER BY Id;
 OPEN pasos;
 FETCH NEXT FROM pasos INTO @Id,@T,@Filtro;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
  @Vals=STRING_AGG(CAST(CASE
   WHEN @Id=1 AND name=N'Código' THEN N'@Tipo'
   WHEN @Id=1 AND name=N'Descripción' THEN N'N''Clasificación del precio de francos'''
   WHEN @Id=1 AND name=N'Nombre Variable' THEN N'@Tipo'
   WHEN @Id IN (2,3) AND name=N'Cód_ Tipo Atributo' THEN N'@Tipo'
   WHEN @Id=2 AND name=N'Sufijo Parámetro' THEN N'CASE WHEN Código=''ML'' THEN N''CAL'' ELSE [Sufijo Parámetro] END'
   WHEN @Id=4 AND name=N'Cód_ Tipo Atributo Precio' THEN N'@Tipo'
   WHEN @Id IN (4,5) AND name=N'Vigencia Desde' THEN N'@Desde'
   WHEN @Id=4 AND name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
   WHEN name=N'$systemId' THEN N'NEWID()'
   WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
   ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
  FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
  SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE '+@Filtro+N'; SET @Filas=@@ROWCOUNT;';
  EXEC sys.sp_executesql @SQL,N'@Tipo nvarchar(20),@Desde datetime,@Filas int OUTPUT',@Tipo,@Desde,@Filas OUTPUT;
  IF @Filas=0 THROW 51504,'Falta una plantilla necesaria; se revierte todo.',1;
  SELECT @Id Paso,@Filas Copiados;
  FETCH NEXT FROM pasos INTO @Id,@T,@Filtro;
 END;
 CLOSE pasos;
 DEALLOCATE pasos;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código='1063' AND [Vigencia Desde]='20260104';
 COMMIT TRANSACTION;
 SELECT N'Aplicado' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;

