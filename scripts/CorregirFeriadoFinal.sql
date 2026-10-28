/* Payroll / ArbuTest. PREVISUALIZACION por defecto.
   Cambiar @Aplicar a 1 sólo tras revisar la propuesta.
   Agrega vigencia; no pisa historia ni toca resultados calculados.
   Tras aplicar: recalcular en BC y contrastar enero. INSERT nuevo no exige reinicio. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0;
DECLARE @Tabla sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Formula nvarchar(2048)=N'round(
    (BASE_FERIADO - IF(TIPO_LIQ = 40,
        #1053 * DIAS_FRANCOS_PERIODO / IFZERO(
            DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO
                + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO, 1),
        0)) / IFZERO(DIAS_MAREA + DIAS_GP_PERIODO, 30),
    PRECISION_REDONDEO
) * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)';
IF DB_NAME()<>N'Migr2013R2' THROW 51000,'Base incorrecta.',1;
IF NOT EXISTS (SELECT 1 FROM [ArbuTest$Tipo Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='LIQ_FINAL' AND Orden=40)
 THROW 51001,'LIQ_FINAL ya no tiene orden 40.',1;
IF (SELECT COUNT(*) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='1023' AND [Vigencia Desde]='20230112' AND [Orden Cálculo]=450)<>1
 THROW 51002,'La vigencia de origen no coincide.',1;
IF EXISTS (SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='1023' AND [Vigencia Desde]>'20230112')
 THROW 51003,'Hay una vigencia posterior: revisar antes de aplicar.',1;
SELECT Código,[Vigencia Desde] VigenciaAnterior,Fórmula FormulaAnterior,
 CAST('20260101' AS date) VigenciaPropuesta,@Formula FormulaPropuesta
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='1023' AND [Vigencia Desde]='20230112';
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 IF EXISTS (SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH (UPDLOCK,HOLDLOCK) WHERE Código='1023' AND [Vigencia Desde]>'20230112')
  THROW 51004,'La configuración cambió desde la previsualización.',1;
 DECLARE @Columnas nvarchar(max),@Valores nvarchar(max),@SQL nvarchar(max);
 SELECT @Columnas=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Valores=STRING_AGG(CAST(CASE
  WHEN name=N'Vigencia Desde' THEN N'CONVERT(datetime,''20260101'',112)'
  WHEN name=N'Fórmula' THEN N'@Formula'
  WHEN name=N'$systemId' THEN N'NEWID()'
  WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
  WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
  ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@Tabla)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@Tabla)+N' ('+@Columnas+N') SELECT '+@Valores+N' FROM '+QUOTENAME(@Tabla)+N' WHERE Código=''1023'' AND [Vigencia Desde]=''20230112''; IF @@ROWCOUNT<>1 THROW 51005,''Cantidad inesperada de filas.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Formula nvarchar(2048)',@Formula;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;


