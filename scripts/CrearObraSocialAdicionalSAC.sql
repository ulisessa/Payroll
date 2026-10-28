/* Preview por defecto. Meta4 5397 (vigencia 01/12/2023), rama mensual normal:
   (@6032 + @6037) / 12 si existe base de SAC devengado.
   Configura 5397 desde 01/01/2026 como devengo fiscal, sin descuento real.
   Conserva 4753 y su consumo mensual. Reiniciar BC tras aplicar por SQL.
   Ejecutar mediante AplicarObraSocialAdicionalSAC.ps1 para respaldo y recálculo. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260101';
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @F sysname=N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @Formula nvarchar(2048)=N'ROUND((#6032 + #6037) / 12, 0.0001)';
DECLARE @Cond nvarchar(2048)=N'TIPO_LIQ <> ''LIQ_FINAL'' AND ES_JUBILADO = 0 AND BASE_SAC_DEV <> 0';
IF DB_NAME()<>N'Migr2013R2' THROW 52100,'Base incorrecta.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='5397')
 THROW 52101,'5397 ya existe: revisar, no sobrescribir.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='5397')
 OR EXISTS(SELECT 1 FROM [ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='5397')
 THROW 52102,'Hay configuración previa de 5397; revisar.',1;
IF NOT EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código='4753' AND [Vigencia Desde]=@Desde AND [Vigencia Hasta]='17530101'
 AND [Es Devengo]=1 AND [Imprime en Recibo]=0 AND [Tipo Concepto]=5
 AND [Es Acumulador]=0 AND [Aplica A]=0
 AND Condición=N'TIPO_LIQ <> ''LIQ_FINAL'' AND (ES_JUBILADO = 0)')
 THROW 52103,'La plantilla de devengo 4753 cambió.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='4753')
 THROW 52104,'Revisar restricciones de convenio de la plantilla.',1;
IF (SELECT COUNT(*) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Concepto]='4753' AND [Vigencia Desde]=@Desde)<>3
 OR (SELECT COUNT(*) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Concepto]='4753' AND [Vigencia Desde]=@Desde
 AND [Cód_ Acumulador] IN ('SS_SAC_DEV','GAN_NETA_MES','GAN_NETA_A_DEDUC')
 AND Porcentaje=100 AND [Invertir Signo]=0 AND [Filtro Convenio]='')<>3
 THROW 52105,'Revisar distribuciones de la plantilla.',1;
IF (SELECT COUNT(*) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código IN ('6032','6037') AND [Vigencia Desde]=@Desde AND [Orden Cálculo]<934
 AND [Fórmula Orden Cálculo]=CONVERT(varchar(20),[Orden Cálculo]))<>2
 OR NOT EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE Código='5010' AND [Vigencia Desde]=@Desde AND [Orden Cálculo]>934 AND [Fórmula Orden Cálculo]='950')
 THROW 52106,'Revisar precedencia de obra social y Ganancias.',1;
IF EXISTS(SELECT 1 FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Fecha Liquidación]>=@Desde AND Estado>1)
 THROW 52107,'Hay liquidaciones aprobadas o contabilizadas: revisar alcance.',1;
SELECT N'5397' Concepto,@Desde Vigencia,@Formula Fórmula,@Cond Condición,934 Orden;
IF @Aplicar=0 RETURN;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Código' THEN N'N''5397'''
 WHEN name IN (N'Descripción',N'Nombre Impresión') THEN N'N''Adicional obra social SAC devengado'''
 WHEN name=N'Fórmula' THEN N'@Formula'
 WHEN name=N'Condición' THEN N'@Cond'
 WHEN name=N'Orden Cálculo' THEN N'934'
 WHEN name=N'Fórmula Orden Cálculo' THEN N'N''934'''
 WHEN name IN (N'Variable Cantidad',N'Unidad Cantidad',N'Variable Base') THEN N'N'''''
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)
 +N' WHERE Código=''4753'' AND [Vigencia Desde]=@Desde; IF @@ROWCOUNT<>1 THROW 52108,''Plantilla cambió.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Formula nvarchar(2048),@Cond nvarchar(2048)',@Desde,@Formula,@Cond;
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Cód_ Concepto' THEN N'N''5397'''
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@F)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@F)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@F)
 +N' WHERE [Cód_ Concepto]=''4753'' AND [Vigencia Desde]=@Desde; IF @@ROWCOUNT<>3 THROW 52109,''Distribuciones cambiaron.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime',@Desde;
 INSERT INTO [ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],[Usuario],[Tipo Cambio],
 [Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],
 [Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 VALUES(N'5397',@Desde,N'Adicional obra social SAC devengado',SYSDATETIME(),N'MIGRACION META4 5397',0,
 N'',@Formula,N'',@Cond,1,1,SYSDATETIME(),NEWID(),SYSUTCDATETIME(),
 '00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000');
 COMMIT TRANSACTION;
 SELECT N'Devengo 5397 creado; conservar 4753. Reiniciar BC antes de recalcular.' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
