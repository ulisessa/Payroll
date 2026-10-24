/* Corrección coordinada de finales de enero. PREVIEW por defecto.
   Publicar primero el campo Fórmula Orden Cálculo. Nuevas versiones desde 04/01/2026.
   Los descuentos reutilizan códigos existentes. 3814 representa un pago REAL de Meta4
   (EGRESO_EXT_1_NR), ausente del catálogo BC; no agrega un descuento nuevo. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260104';
IF DB_NAME()<>N'Migr2013R2' THROW 51300,'Base incorrecta.',1;
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @F sysname=N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @C TABLE(Codigo nvarchar(20),Plantilla nvarchar(20),Anterior datetime,Formula nvarchar(2048),Condicion nvarchar(2048),Tipos nvarchar(250),TipoAlt nvarchar(20),ConvAlt nvarchar(20),OrdenAlt int,Orden int);
INSERT @C SELECT Código,Código,[Vigencia Desde],Fórmula,Condición,[Tipos Liq_ Aplicables],N'',N'',0,[Orden Cálculo] FROM (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY Código ORDER BY [Vigencia Desde] DESC) rn
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código IN ('3573','3813','6000','6010','6030','8522','6002','6012','6034','8523','4751','4752','4753','4754') AND [Vigencia Desde]<@Desde
) c WHERE rn=1;
IF (SELECT COUNT(*) FROM @C)<>14 THROW 51301,'Faltan conceptos plantilla.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='3814') THROW 51302,'3814 ya existe: revisar su configuración.',1;
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND((#3553 + #3973) * 0.1, PRECISION_REDONDEO), '+Formula+N')',
 Condicion=N'(TIPO_LIQ = ''LIQ_FINAL'' AND (#3553 + #3973) <> 0) OR (TIPO_LIQ <> ''LIQ_FINAL'' AND ('+Condicion+N'))',TipoAlt='LIQ_FINAL',ConvAlt='372/04',OrdenAlt=667 WHERE Codigo='3573';
UPDATE @C SET Formula=N'ROUND((BASE_SAC_SEMESTRE + #BASE_PROMEDIO - IF(TIPO_LIQ = ''LIQ_FINAL'' AND #3573 <> 0, ROUND(#3973 * 0.1, PRECISION_REDONDEO) * (1 - DIAS_ALTA_30 / 30), 0)) / 12 * #COEF_PESQUERIA, PRECISION_REDONDEO)',TipoAlt='LIQ_FINAL',ConvAlt='372/04',OrdenAlt=668 WHERE Codigo='3813';
DECLARE @BaseSS nvarchar(700)=N'MAX(0, BASE_SS_TRAB + BASE_SS_VAC - #3813 - #3823 + PERIODO_BASE_SS_TRAB + PERIODO_BASE_SS_VAC)';
DECLARE @BaseOS nvarchar(700)=N'MAX(0, BASE_OS_TRAB + BASE_OS_VAC - #3813 - #3823 + PERIODO_BASE_OS_TRAB + PERIODO_BASE_OS_VAC)';
DECLARE @SacBase nvarchar(1000)=N'MAX(0, MIN(#3813 + #3823, MIN('+@BaseSS+N', TOPE_SIPA * DIAS_ALTA_30 / 30) / 12))';
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND((MIN('+@BaseSS+N', TOPE_SIPA * DIAS_ALTA_30 / 30) - MIN(PERIODO_BASE_SS_TRAB + PERIODO_BASE_SS_VAC, TOPE_SIPA)) * '+CASE Codigo WHEN '6000' THEN 'PCT_JUB' ELSE 'PCT_19032' END+N' / 100, PRECISION_REDONDEO), '+Formula+N')',
 Condicion=CASE Codigo WHEN '6000' THEN N'TIPO_LIQ = ''LIQ_FINAL'' OR BASE_SS_TRAB > 0' ELSE N'(TIPO_LIQ = ''LIQ_FINAL'' OR BASE_SS_TRAB > 0) AND ES_JUBILADO = 0' END WHERE Codigo IN ('6000','6010');
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND((MIN('+@BaseOS+N', TOPE_SIPA_OS * DIAS_ALTA_30 / 30) - MIN(PERIODO_BASE_OS_TRAB + PERIODO_BASE_OS_VAC, TOPE_SIPA_OS)) * PCT_OS / 100, PRECISION_REDONDEO), '+Formula+N')',
 Condicion=N'(TIPO_LIQ = ''LIQ_FINAL'' OR BASE_OS_TRAB > 0) AND ES_JUBILADO = 0' WHERE Codigo='6030';
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND((BASE_SINDICAL - #3813 - #3823) * IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) / 100, PRECISION_REDONDEO), '+Formula+N')' WHERE Codigo='8522';
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND('+CASE WHEN Codigo='6034' THEN REPLACE(@SacBase,N'TOPE_SIPA *',N'TOPE_SIPA_OS *') ELSE @SacBase END+N' * '+CASE Codigo WHEN '6002' THEN 'PCT_JUB' WHEN '6012' THEN 'PCT_19032' ELSE 'PCT_OS' END+N' / 100 - '+CASE Codigo WHEN '6002' THEN 'SAC_JUB_PAGADO_MES' WHEN '6012' THEN 'SAC_LEY_PAGADO_MES' ELSE 'SAC_OS_PAGADO_MES' END+N', PRECISION_REDONDEO), '+Formula+N')',Tipos=N'AGUINALDO|LIQ_FINAL' WHERE Codigo IN ('6002','6012','6034');
UPDATE @C SET Formula=N'IF(TIPO_LIQ = ''LIQ_FINAL'', ROUND((#3813 + #3823) * IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) / 100 - SAC_SIND_PAGADO_MES, PRECISION_REDONDEO), 0)',Tipos=N'AGUINALDO|LIQ_FINAL' WHERE Codigo='8523';
UPDATE @C SET Condicion=N'TIPO_LIQ <> ''LIQ_FINAL'''+CASE WHEN Condicion<>'' THEN N' AND ('+Condicion+N')' ELSE N'' END WHERE Codigo IN ('4751','4752','4753','4754');
INSERT @C SELECT '3814','3554',[Vigencia Desde],N'ROUND(ROUND(#3813 + #3823, 0.01) / IFZERO(#COEF_PESQUERIA, 1) * (1 - #COEF_PESQUERIA), 0.01)',N'#COEF_PESQUERIA > 0 AND #COEF_PESQUERIA < 1',N'LIQ_FINAL',N'LIQ_FINAL',N'',669,478
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='3554' AND [Vigencia Desde]=(SELECT MAX([Vigencia Desde]) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='3554' AND [Vigencia Desde]<@Desde);
IF (SELECT COUNT(*) FROM @C)<>15 THROW 51303,'Falta plantilla de SAC no remunerativo.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] t JOIN @C c ON t.Código=c.Codigo WHERE t.[Vigencia Desde]>=@Desde) THROW 51304,'Existe versión posterior: no se pisa.',1;
SELECT Codigo,@Desde Vigencia,Orden,CASE WHEN TipoAlt='' THEN CONVERT(nvarchar(12),Orden) ELSE N'IF(TIPO_LIQ = '''+REPLACE(TipoAlt,N'''',N'''''')+N''''+CASE WHEN ConvAlt<>'' THEN N' AND CONVENIO = '''+REPLACE(ConvAlt,N'''',N'''''')+N'''' ELSE N'' END+N', '+CONVERT(nvarchar(12),OrdenAlt)+N', '+CONVERT(nvarchar(12),Orden)+N')' END [Fórmula Orden Cálculo],Formula,Condicion,Tipos FROM @C;
IF @Aplicar=0 RETURN;
IF COL_LENGTH(@T,'Fórmula Orden Cálculo') IS NULL THROW 51305,'Publicar primero Fórmula Orden Cálculo.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Codigo nvarchar(20),@Plantilla nvarchar(20),@Anterior datetime,@Formula nvarchar(2048),@Cond nvarchar(2048),@Tipos nvarchar(250),@TipoAlt nvarchar(20),@ConvAlt nvarchar(20),@OrdenAlt int,@Orden int,@FormulaOrden nvarchar(2048),@Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 DECLARE cambios CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @C;
 OPEN cambios;
 FETCH NEXT FROM cambios INTO @Codigo,@Plantilla,@Anterior,@Formula,@Cond,@Tipos,@TipoAlt,@ConvAlt,@OrdenAlt,@Orden;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH(UPDLOCK,HOLDLOCK) WHERE Código=@Codigo AND [Vigencia Desde]>=@Desde) THROW 51306,'La configuración cambió durante la operación.',1;
  SET @FormulaOrden=CASE WHEN @TipoAlt='' THEN CONVERT(nvarchar(12),@Orden) ELSE N'IF(TIPO_LIQ = '''+REPLACE(@TipoAlt,N'''',N'''''')+N''''+CASE WHEN @ConvAlt<>'' THEN N' AND CONVENIO = '''+REPLACE(@ConvAlt,N'''',N'''''')+N'''' ELSE N'' END+N', '+CONVERT(nvarchar(12),@OrdenAlt)+N', '+CONVERT(nvarchar(12),@Orden)+N')' END;
  SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
  @Vals=STRING_AGG(CAST(CASE
   WHEN name=N'Código' THEN N'@Codigo'
   WHEN name=N'Vigencia Desde' THEN N'@Desde'
   WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
   WHEN name=N'Fórmula' THEN N'@Formula'
   WHEN name=N'Condición' THEN N'@Cond'
   WHEN name=N'Tipos Liq_ Aplicables' THEN N'@Tipos'
   WHEN name=N'Fórmula Orden Cálculo' THEN N'@FormulaOrden'
   WHEN name=N'Tipo Liq_ Orden Alternativo' THEN N'N'''''
   WHEN name=N'Convenio Orden Alternativo' THEN N'N'''''
   WHEN name=N'Orden Cálculo Alternativo' THEN N'0'
   WHEN name=N'Orden Cálculo' THEN N'@Orden'
   WHEN name=N'Descripción' AND @Codigo='3814' THEN N'N''SAC de egreso no remunerativo'''
   WHEN name=N'Nombre Impresión' AND @Codigo='3814' THEN N'N''SAC egreso no remunerativo'''
   WHEN name=N'$systemId' THEN N'NEWID()'
   WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
   WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
   ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
  FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
  SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)+N' WHERE Código=@Plantilla AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 51307,''Plantilla incorrecta.'',1;';
  EXEC sys.sp_executesql @SQL,N'@Codigo nvarchar(20),@Plantilla nvarchar(20),@Anterior datetime,@Desde datetime,@Formula nvarchar(2048),@Cond nvarchar(2048),@Tipos nvarchar(250),@TipoAlt nvarchar(20),@ConvAlt nvarchar(20),@OrdenAlt int,@Orden int,@FormulaOrden nvarchar(2048)',@Codigo,@Plantilla,@Anterior,@Desde,@Formula,@Cond,@Tipos,@TipoAlt,@ConvAlt,@OrdenAlt,@Orden,@FormulaOrden;
  IF @Codigo=@Plantilla
   UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=DATEADD(day,-1,@Desde) WHERE Código=@Codigo AND [Vigencia Desde]=@Anterior AND ([Vigencia Hasta]='17530101' OR [Vigencia Hasta]>=@Desde);
  FETCH NEXT FROM cambios INTO @Codigo,@Plantilla,@Anterior,@Formula,@Cond,@Tipos,@TipoAlt,@ConvAlt,@OrdenAlt,@Orden;
 END;
 CLOSE cambios;
 DEALLOCATE cambios;
 /* SAC NR: copia el reparto del acuerdo, salvo la base de promedio NR; el SAC no vuelve a
    alimentar su propio promedio. OS y sindicato sí reciben el SAC NR, como en Meta4. */
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
  WHEN name=N'Cód_ Concepto' THEN N'@Destino'
  WHEN name=N'Vigencia Desde' THEN N'@Desde'
  WHEN name=N'$systemId' THEN N'NEWID()'
  WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
  WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
  ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@F)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@F)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@F)+N' f WHERE [Cód_ Concepto]=@Origen AND [Vigencia Desde]=(SELECT MAX(p.[Vigencia Desde]) FROM '+QUOTENAME(@F)+N' p WHERE p.[Cód_ Concepto]=f.[Cód_ Concepto] AND p.[Cód_ Acumulador]=f.[Cód_ Acumulador] AND p.[Vigencia Desde]<@Desde) AND '+N'(([Cód_ Concepto]=''3554'' AND [Cód_ Acumulador]<>''BASE_PROMEDIO_NR'') OR ([Cód_ Concepto]=''4754'' AND [Cód_ Acumulador] IN (''GAN_NETA_MES'',''GAN_NETA_A_DEDUC'')));';
 EXEC sys.sp_executesql @SQL,N'@Destino nvarchar(20),@Origen nvarchar(20),@Desde datetime',N'3814',N'3554',@Desde;
 EXEC sys.sp_executesql @SQL,N'@Destino nvarchar(20),@Origen nvarchar(20),@Desde datetime',N'8523',N'4754',@Desde;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='3814' AND [Cód_ Acumulador] IN ('BASE_PROMEDIO','BASE_PROMEDIO_NR','BASE_SS_TRAB')) THROW 51308,'El SAC NR no debe alimentar promedio ni jubilación.',1;
 UPDATE [ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Concepto BC]='3814', [Mapeo Verificado]=1, [Clasificación Meta4]='DV' WHERE [Nombre Columna]='EGRESO_EXT_1_NR' AND [Cód_ Concepto BC]='';
 IF @@ROWCOUNT<>1 THROW 51309,'El mapeo de SAC NR cambió o no existe.',1;
 /* Las variables normalmente se siembran al publicar; también se asegura el registro si
    el upgrade no ejecutó Sembrar. Nunca se pisa un mapeo existente. */
 DECLARE @Vars TABLE(Nombre nvarchar(30),Concepto nvarchar(20));
 INSERT @Vars VALUES ('SAC_JUB_PAGADO_MES','6002'),('SAC_LEY_PAGADO_MES','6012'),('SAC_OS_PAGADO_MES','6034'),('SAC_SIND_PAGADO_MES','8523');
 IF EXISTS(SELECT 1 FROM @Vars n JOIN [ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[Nombre Variable]=n.Nombre WHERE v.[Cód_ Cálculo]<>'PERIODO_CONCEPTO' OR v.[Cód_ Concepto]<>n.Concepto OR v.Activo<>1) THROW 51310,'Una variable de descuentos está configurada distinto.',1;
 DECLARE @VS sysname=N'ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
  WHEN name=N'Nombre Variable' THEN N'n.Nombre'
  WHEN name=N'Cód_ Concepto' THEN N'n.Concepto'
  WHEN name=N'Descripción' THEN N'N''Descuento SAC pagado en el mes'''
  WHEN name=N'$systemId' THEN N'NEWID()'
  WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
  WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
  ELSE N'v.'+QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@VS)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@VS)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@VS)+N' v CROSS JOIN (VALUES (''SAC_JUB_PAGADO_MES'',''6002''),(''SAC_LEY_PAGADO_MES'',''6012''),(''SAC_OS_PAGADO_MES'',''6034''),(''SAC_SIND_PAGADO_MES'',''8523'')) n(Nombre,Concepto) WHERE v.[Nombre Variable]=''PERIODO_APORTE_JUB_SAC'' AND NOT EXISTS(SELECT 1 FROM '+QUOTENAME(@VS)+N' x WHERE x.[Nombre Variable]=n.Nombre);';
 EXEC sys.sp_executesql @SQL;
 IF (SELECT COUNT(*) FROM @Vars n JOIN [ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[Nombre Variable]=n.Nombre)<>4 THROW 51311,'Falta plantilla de variables de descuentos.',1;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;





