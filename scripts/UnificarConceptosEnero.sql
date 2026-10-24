/* Vista previa por defecto. Requiere enero completo en Borrador y backup local previo.
   Consolida la configuración final de enero en 01/01; conserva historia anterior y vigencias posteriores.
   No recalcula importes. Las referencias de las líneas borrador se actualizan a la configuración consolidada.
   Las versiones de prueba intermedias quedan en el backup, no como vigencias de enero. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0, @Desde datetime='20260101', @Hasta datetime='20260131';
IF DB_NAME()<>N'Migr2013R2' THROW 51800,'Base incorrecta.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 SELECT c.* INTO #Conceptos FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c WITH (TABLOCKX,HOLDLOCK)
 WHERE c.[Vigencia Desde]=(SELECT MAX(x.[Vigencia Desde]) FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.Código=c.Código AND x.[Vigencia Desde]<=@Hasta)
 AND (c.[Vigencia Hasta]='17530101' OR c.[Vigencia Hasta]>=@Desde);
 SELECT f.* INTO #Fracciones FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WITH (TABLOCKX,HOLDLOCK)
 WHERE EXISTS(SELECT 1 FROM #Conceptos c WHERE c.Código=f.[Cód_ Concepto])
 AND f.[Vigencia Desde]=(SELECT MAX(x.[Vigencia Desde]) FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Concepto]=f.[Cód_ Concepto] AND x.[Cód_ Acumulador]=f.[Cód_ Acumulador] AND x.[Vigencia Desde]<=@Hasta);
 SELECT N'Conceptos desde 01/01' Cambio,COUNT(*) Cantidad FROM #Conceptos
 UNION ALL SELECT N'Fracciones desde 01/01',COUNT(*) FROM #Fracciones;
 IF @Aplicar=0 BEGIN ROLLBACK TRANSACTION; RETURN; END;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH (TABLOCKX,HOLDLOCK) WHERE [Cód_ Período]='202601' AND Estado<>0)
 THROW 51801,'Reabrir todas las liquidaciones de enero antes de consolidar.',1;
 IF EXISTS(SELECT 1 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH (TABLOCKX,HOLDLOCK) WHERE [Cód_ Período]<>'202601' AND [Vigencia Concepto]>@Desde AND [Vigencia Concepto]<=@Hasta)
 THROW 51802,'Hay referencias fuera de enero a las vigencias intermedias; revisar.',1;
 /* Conserva SystemId del registro canónico si ya existía. */
 SELECT Código,[$systemId] INTO #IdsConceptos FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde]=@Desde;
 SELECT [Cód_ Concepto],[Cód_ Acumulador],[$systemId] INTO #IdsFracciones FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde]=@Desde;
 DELETE c FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c WHERE c.[Vigencia Desde] BETWEEN @Desde AND @Hasta AND EXISTS(SELECT 1 FROM #Conceptos x WHERE x.Código=c.Código);
 DELETE f FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WHERE f.[Vigencia Desde] BETWEEN @Desde AND @Hasta AND EXISTS(SELECT 1 FROM #Conceptos x WHERE x.Código=f.[Cód_ Concepto]);
 DECLARE @T sysname,@Temp sysname,@Cols nvarchar(max),@Vals nvarchar(max),@SQL nvarchar(max);
 DECLARE pasos CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM (VALUES
 (N'ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890',N'#Conceptos'),
 (N'ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890',N'#Fracciones')) p(Tabla,Temporal);
 OPEN pasos; FETCH NEXT FROM pasos INTO @T,@Temp;
 WHILE @@FETCH_STATUS=0 BEGIN
  SELECT @Cols=STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id),
  @Vals=STRING_AGG(CAST(CASE
   WHEN name=N'Vigencia Desde' THEN N'@Desde'
   WHEN name=N'$systemId' AND @Temp=N'#Conceptos' THEN N'COALESCE((SELECT i.[$systemId] FROM #IdsConceptos i WHERE i.Código=s.Código),NEWID())'
   WHEN name=N'$systemId' THEN N'COALESCE((SELECT i.[$systemId] FROM #IdsFracciones i WHERE i.[Cód_ Concepto]=s.[Cód_ Concepto] AND i.[Cód_ Acumulador]=s.[Cód_ Acumulador]),NEWID())'
   WHEN name IN(N'$systemCreatedAt',N'$systemModifiedAt') THEN N'SYSUTCDATETIME()'
   ELSE N's.'+QUOTENAME(name) END AS nvarchar(max)),N',') WITHIN GROUP(ORDER BY column_id)
  FROM sys.columns WHERE object_id=OBJECT_ID(QUOTENAME(@T)) AND system_type_id<>189 AND is_computed=0;
  SET @SQL=N'INSERT INTO '+QUOTENAME(@T)+N' ('+@Cols+N') SELECT '+@Vals+N' FROM '+@Temp+N' s;';
  EXEC sys.sp_executesql @SQL,N'@Desde datetime',@Desde;
  FETCH NEXT FROM pasos INTO @T,@Temp;
 END;
 CLOSE pasos; DEALLOCATE pasos;
 UPDATE c SET [Vigencia Hasta]='20251231',[$systemModifiedAt]=SYSUTCDATETIME()
 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
 WHERE c.[Vigencia Desde]<@Desde AND (c.[Vigencia Hasta]='17530101' OR c.[Vigencia Hasta]>=@Desde)
 AND EXISTS(SELECT 1 FROM #Conceptos x WHERE x.Código=c.Código);
 UPDATE l SET [Vigencia Concepto]=@Desde,[$systemModifiedAt]=SYSUTCDATETIME()
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
 WHERE l.[Cód_ Período]='202601' AND EXISTS(SELECT 1 FROM #Conceptos x WHERE x.Código=l.[Cód_ Concepto]);
 IF EXISTS(SELECT 1 FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde]>@Desde AND [Vigencia Desde]<=@Hasta)
 THROW 51803,'Quedaron vigencias intermedias de enero.',1;
 IF EXISTS(SELECT 1 FROM #Conceptos s JOIN [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.Código=s.Código AND c.[Vigencia Desde]=@Desde WHERE c.Fórmula<>s.Fórmula OR c.Condición<>s.Condición OR c.[Fuente Matriz]<>s.[Fuente Matriz] OR c.[Cantidad Matriz]<>s.[Cantidad Matriz])
 THROW 51804,'Cambió una fórmula al consolidar.',1;
 COMMIT TRANSACTION;
 SELECT N'Aplicado; reiniciar BC252 antes de calcular.' Resultado;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
