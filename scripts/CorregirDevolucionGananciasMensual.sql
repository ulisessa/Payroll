/* Ejecutar mediante AplicarDevolucionGananciasMensual.ps1.
   Preview con escritura transaccional y rollback por defecto.
   @FormulaAnterior y @FormulaNueva son parámetros, nunca texto concatenado.
   Sólo agrega una vigencia del 5010 desde febrero; enero conserva su fórmula. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0,@Desde datetime='20260201',@Anterior datetime,@Original nvarchar(2048);
DECLARE @T sysname=N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @F sysname=N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
IF DB_NAME()<>N'Migr2013R2' THROW 52300,'Base incorrecta.',1;
IF LEN(@FormulaNueva)>2048 OR @FormulaNueva=@FormulaAnterior THROW 52301,'Cambio de fórmula inválido.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 SELECT TOP(1) @Anterior=[Vigencia Desde],@Original=Fórmula
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH(UPDLOCK,HOLDLOCK)
 WHERE Código='5010' ORDER BY [Vigencia Desde] DESC;
 IF @Anterior<>'20260101' OR @Original COLLATE Latin1_General_100_BIN2<>@FormulaAnterior COLLATE Latin1_General_100_BIN2
 THROW 52302,'La plantilla cambió desde la revisión.',1;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Fecha Liquidación]>=@Desde AND [Cód_ Tipo Liq_]<>'HIST_REMUN' AND Estado>1)
 THROW 52303,'Hay resultados protegidos que usan esta fórmula.',1;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Fecha Liquidación]>='20260301' AND [Cód_ Tipo Liq_]<>'HIST_REMUN' AND Estado<>0)
 THROW 52304,'Hay meses posteriores calculados; revisar la cadena completa.',1;
 -- Los cinco catálogos fueron importados como acumulados enero..mes, aunque
 -- Contexto Liquidación y las fórmulas los consumen como importes mensuales.
 -- Sólo normalizar el patrón confirmado: vigente = enero * número de mes.
 DECLARE @Normalizar TABLE(Base nvarchar(20),Clave nvarchar(50),Desde datetime,Original decimal(38,20),Mensual decimal(38,20));
 INSERT @Normalizar
 SELECT p.[Cód_ Parámetro Base],p.[Cód_ Parámetro],p.[Vigencia Desde],p.Valor,j.Valor
 FROM [ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p WITH(UPDLOCK,HOLDLOCK)
 JOIN [ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] j ON j.[Cód_ Parámetro Base]=p.[Cód_ Parámetro Base]
 AND j.[Cód_ Parámetro]=p.[Cód_ Parámetro] AND j.[Vigencia Desde]='20260101'
 WHERE p.[Cód_ Parámetro Base] IN ('MNI_ANUAL','DESP_4CAT','CONYUGE','HIJO','HIJO_INC')
 AND p.[Vigencia Desde] BETWEEN '20260201' AND '20260601'
 AND p.[No_ Empleado]='' AND p.[Cód_ Convenio]='' AND p.[Cód_ Categoría]=''
 AND p.Valor=j.Valor*MONTH(p.[Vigencia Desde]);
 IF (SELECT COUNT(*) FROM @Normalizar)<>24 THROW 52308,'Las vigencias fiscales no coinciden con los acumulados revisados.',1;
 UPDATE p SET Valor=n.Mensual,[$systemModifiedAt]=SYSUTCDATETIME()
 FROM [ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p JOIN @Normalizar n
 ON n.Base=p.[Cód_ Parámetro Base] AND n.Clave=p.[Cód_ Parámetro] AND n.Desde=p.[Vigencia Desde];
 IF (SELECT COUNT(*) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Concepto]='5010' AND [Vigencia Desde]=@Anterior)<>1 OR
 NOT EXISTS(SELECT 1 FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Concepto]='5010' AND [Vigencia Desde]=@Anterior AND [Cód_ Acumulador]='RETENIDO_IG'
 AND Porcentaje=100 AND [Invertir Signo]=0 AND [Filtro Convenio]='')
 THROW 52305,'La distribución del impuesto cambió.',1;
 DECLARE @Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'',112)'
 WHEN name=N'Fórmula' THEN N'@FormulaNueva'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@T)
 +N' WHERE Código=''5010'' AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 52306,''Plantilla inválida.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Anterior datetime,@FormulaNueva nvarchar(2048)',@Desde,@Anterior,@FormulaNueva;
 SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
 @Vals=STRING_AGG(CAST(CASE
 WHEN name=N'Vigencia Desde' THEN N'@Desde'
 WHEN name=N'$systemId' THEN N'NEWID()'
 WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
 ELSE QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
 FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@F)) AND system_type_id<>189 AND is_computed=0;
 SET @SQL=N'INSERT INTO '+QUOTENAME(@F)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+QUOTENAME(@F)
 +N' WHERE [Cód_ Concepto]=''5010'' AND [Vigencia Desde]=@Anterior; IF @@ROWCOUNT<>1 THROW 52307,''Fracciones cambiaron.'',1;';
 EXEC sys.sp_executesql @SQL,N'@Desde datetime,@Anterior datetime',@Desde,@Anterior;
 UPDATE [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 SET [Vigencia Hasta]=DATEADD(day,-1,@Desde),[$systemModifiedAt]=SYSUTCDATETIME()
 WHERE Código='5010' AND [Vigencia Desde]=@Anterior;
 INSERT INTO [ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],Usuario,[Tipo Cambio],
 [Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],
 [Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 SELECT '5010',@Desde,Descripción,SYSDATETIME(),'DEVOLUCION MENSUAL META4',0,
 @FormulaAnterior,@FormulaNueva,Condición,Condición,1,0,SYSDATETIME(),NEWID(),SYSUTCDATETIME(),
 '00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000'
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código='5010' AND [Vigencia Desde]=@Desde;
 IF @Aplicar=1 COMMIT TRANSACTION ELSE ROLLBACK TRANSACTION;
 SELECT @Aplicar Aplicado,@Desde Desde;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
