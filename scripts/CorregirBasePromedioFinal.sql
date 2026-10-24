/* Ajuste autorizado de BASE_PROMEDIO para finales con coeficiente de pesquería.
   PREVISUALIZACION por defecto. No altera haberes ni bases fiscales/contributivas.
   La porción de 1603 se distribuye según sus componentes: el franco ya viene completo.
   No incluye importes manuales sin regla verificable, enfermedades/accidentes con historia
   separada ni conceptos exclusivos de cierres. Nueva configuración desde enero 2026. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0;
DECLARE @Codigo nvarchar(20)=N'AJ_PROM_PESQUERIA';
DECLARE @Concepto sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Fraccion sysname=N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Formula nvarchar(2048)=N'ROUND(
    (
        #1013 + #1073 + #1076 + #1083 + #1053 + #1543 + #1547 + #1023 + #2043
        + #1603 * (#1013 + #1083 + #1543 + #1053 + #1547 + #1076)
            / IFZERO(#1013 + #1083 + #1543 + #1053 + #1547 + #1076 + #1063, 1)
    ) / IFZERO(#COEF_PESQUERIA, 1) * (1 - #COEF_PESQUERIA),
    PRECISION_REDONDEO
)';
IF DB_NAME()<>N'Migr2013R2' THROW 51100,'Base incorrecta.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código=@Codigo)
 THROW 51101,'Ya existe el concepto. No se pisa su configuración.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='COEF_PESQUERIA' AND [Vigencia Desde]='20230112')
 THROW 51102,'No existe la plantilla.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='1083' AND [Cód_ Acumulador]='BASE_PROMEDIO' AND [Vigencia Desde]='20230112' AND Porcentaje=100 AND [Invertir Signo]=0)
 THROW 51103,'La plantilla de distribución cambió.',1;
SELECT @Codigo CodigoNuevo,CONVERT(date,'20260101',112) Vigencia,469 Orden,
 N'LIQ_FINAL' TiposAplicables,N'Informativo' Tipo,@Formula FormulaPropuesta,
 N'BASE_PROMEDIO:100%; ningún otro acumulador' Distribucion;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH(UPDLOCK,HOLDLOCK) WHERE Código=@Codigo)
  THROW 51104,'El concepto se creó durante la operación.',1;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Código' THEN N'@Codigo'
 WHEN name=N'Vigencia Desde' THEN N'CONVERT(datetime,''20260101'',112)'
 WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
 WHEN name=N'Descripción' THEN N'N''Reconstrucción base promedio por pesquería'''
 WHEN name=N'Nombre Impresión' THEN N'N''Ajuste base promedio'''
 WHEN name=N'Fórmula' THEN N'@Formula'
 WHEN name=N'Condición' THEN N'N''#COEF_PESQUERIA > 0 AND #COEF_PESQUERIA < 1'''
 WHEN name=N'Orden Cálculo' THEN N'469'
 WHEN name=N'Tipo Concepto' THEN N'6'
 WHEN name=N'Tipos Liq_ Aplicables' THEN N'N''LIQ_FINAL'''
 WHEN name IN (N'Es Acumulador',N'Es Devengo',N'Imprime en Recibo',N'Rol Franco',N'Divisor Valor',N'Aplica A',N'Aplica Tipo Liq_',N'Par CCT a Usar',N'Grupo Costo Laboral') THEN N'0'
 WHEN name=N'Activo' THEN N'1'
 WHEN name IN (N'Variable Cantidad',N'Unidad Cantidad',N'Variable Base',N'Etiqueta Det_ Ganancias',N'Cód_ Tipo Atributo Detalle',N'Cód_ Parámetro Valor',N'Cód_ Tipo Atributo Precio') THEN N'N'''''
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@Concepto)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@Concepto)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@Concepto)+N' WHERE Código=''COEF_PESQUERIA'' AND [Vigencia Desde]=''20230112''; IF @@ROWCOUNT<>1 THROW 51105,''Filas de concepto inesperadas.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Codigo nvarchar(20),@Formula nvarchar(2048)',@Codigo,@Formula;
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Cód_ Concepto' THEN N'@Codigo'
 WHEN name=N'Vigencia Desde' THEN N'CONVERT(datetime,''20260101'',112)'
 WHEN name=N'Descripción' THEN N'N''Reconstrucción base promedio por pesquería'''
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@Fraccion)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@Fraccion)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@Fraccion)+N' WHERE [Cód_ Concepto]=''1083'' AND [Cód_ Acumulador]=''BASE_PROMEDIO'' AND [Vigencia Desde]=''20230112''; IF @@ROWCOUNT<>1 THROW 51106,''Filas de distribución inesperadas.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Codigo nvarchar(20)',@Codigo;
 IF (SELECT COUNT(*) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=@Codigo)<>1
  THROW 51107,'El ajuste no tiene una distribución única.',1;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
