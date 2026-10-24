/*
    Base separada de enfermedad inculpable desde febrero de 2026.

    El llamador declara, en ESTE MISMO lote (sin GO):
      @Aplicar bit (0 = ensayo con ROLLBACK; 1 = aplicar),
      @FormulaAnterior nvarchar(2048), @FormulaNueva nvarchar(2048),
      @FormulaPromEnf nvarchar(2048), @Payload nvarchar(max).
    Payload: array JSON de {empleado, periodo, documento, base, objetivo, ajuste, nuevo?}.
    El objetivo debe haber sido conciliado contra TOT_PROMEDIOS original de Meta4.
    Sólo agrega el delta a HIST_REMUN existente; nuevo=true admite exclusivamente los tres
    meses omitidos de la migración y verificados contra el archivo literal y Oracle.

    BASE_PROMEDIO, PROM_AUS_MES, accidentes, enero y los parámetros quedan intactos.
    La nueva 4110 se acompaña de sus ocho fracciones; la versión de enero termina el 31/1.
    Las fuentes no remunerativas excluyen históricos y finales: ambos ya contienen esa porción.
    Después de aplicar SQL, el llamador debe renovar la caché del service tier antes de recalcular.
    No ejecutar dentro de otra transacción ni en paralelo con cálculos/publicaciones.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51000, N'La corrección requiere una conexión sin transacción previa.', 1;
IF DB_NAME() <> N'Migr2013R2' THROW 51000, N'Base SQL distinta de Migr2013R2.', 1;
IF @Aplicar IS NULL OR @FormulaAnterior IS NULL OR @FormulaNueva IS NULL OR @FormulaPromEnf IS NULL
    THROW 51000, N'Faltan los parámetros explícitos de fórmula o modo.', 1;
IF LEN(@FormulaAnterior) = 0 OR LEN(@FormulaNueva) = 0 OR LEN(@FormulaPromEnf) = 0
    OR LEN(@FormulaAnterior) > 2048 OR LEN(@FormulaNueva) > 2048 OR LEN(@FormulaPromEnf) > 2048
    THROW 51000, N'Fórmula vacía o mayor que el campo de BC.', 1;
IF ISJSON(@Payload) <> 1 OR LEFT(LTRIM(@Payload), 1) <> N'['
    THROW 51000, N'El payload debe ser un array JSON.', 1;
IF EXISTS (SELECT 1 FROM OPENJSON(@Payload) WHERE [type] <> 5)
    THROW 51000, N'Cada elemento del payload debe ser un objeto.', 1;

CREATE TABLE #Alcance (empleado nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
INSERT #Alcance VALUES
 (N'00191'),(N'00949'),(N'01404'),(N'01767'),(N'01961'),(N'02048'),(N'02297'),(N'02670'),
 (N'02728'),(N'02737'),(N'02854'),(N'02879'),(N'02924'),(N'02937'),(N'03488'),(N'03952'),
 (N'03986'),(N'04185'),(N'04216'),(N'04279'),(N'04315'),(N'04850'),(N'80668');

SELECT empleado COLLATE DATABASE_DEFAULT empleado, periodo COLLATE DATABASE_DEFAULT periodo,
       documento COLLATE DATABASE_DEFAULT documento, base, objetivo, ajuste, ISNULL(nuevo,0) nuevo INTO #Datos
FROM OPENJSON(@Payload) WITH
 (empleado nvarchar(4000), periodo nvarchar(4000), documento nvarchar(4000),
  base decimal(38,20), objetivo decimal(38,20), ajuste decimal(38,20), nuevo bit);
IF NOT EXISTS (SELECT 1 FROM #Datos) OR (SELECT COUNT(*) FROM #Datos) > 552
    THROW 51000, N'Cantidad de meses históricos fuera del alcance auditado.', 1;
IF EXISTS (SELECT 1 FROM #Datos d WHERE empleado IS NULL OR periodo IS NULL OR documento IS NULL
    OR LEN(empleado) <> 5 OR LEN(periodo) <> 6 OR LEN(documento) > 20 OR LEN(documento) = 0
    OR base IS NULL OR objetivo IS NULL OR ajuste IS NULL
    OR NOT EXISTS (SELECT 1 FROM #Alcance a WHERE a.empleado = d.empleado)
    OR TRY_CONVERT(date, periodo + N'01', 112) IS NULL
    OR TRY_CONVERT(date, periodo + N'01', 112) < CONVERT(date, '20240101', 112)
    OR TRY_CONVERT(date, periodo + N'01', 112) >= CONVERT(date, '20260101', 112)
    OR ABS(objetivo - base - ajuste) > 0.0001)
    THROW 51000, N'Fila histórica inválida o ajuste distinto de objetivo menos base.', 1;
IF EXISTS (SELECT documento FROM #Datos GROUP BY documento HAVING COUNT(*) <> 1)
    OR EXISTS (SELECT empleado, periodo FROM #Datos GROUP BY empleado, periodo HAVING COUNT(*) <> 1)
    THROW 51000, N'Documento o empleado/mes duplicado en el payload.', 1;
IF EXISTS (SELECT 1 FROM #Datos WHERE nuevo=1 AND
    (base<>0 OR objetivo<=0 OR ajuste<>objetivo OR NOT
      ((empleado=N'02737' AND periodo=N'202411' AND documento=N'AUS-02737-202411')
       OR (empleado=N'03986' AND periodo=N'202411' AND documento=N'AUS-03986-202411')
       OR (empleado=N'03986' AND periodo=N'202412' AND documento=N'AUS-03986-202412'))))
    THROW 51000, N'Sólo se admiten las tres cabeceras ausentes verificadas y con base previa cero.', 1;

DECLARE @Concepto nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Fuente nvarchar(300) = N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Filtro nvarchar(300) = N'dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Fraccion nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Linea nvarchar(300) = N'dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Cabecera nvarchar(300) = N'dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Columnas nvarchar(max), @Proyeccion nvarchar(max), @Sql nvarchar(max),
        @CabecerasAntes nvarchar(max), @CabecerasDespues nvarchar(max),
        @MaxLinea int = 0, @LineasCreadas int = 0, @FiltrosCreados int = 0, @CabecerasCreadas int = 0;

CREATE TABLE #Fuentes (original nvarchar(30) COLLATE DATABASE_DEFAULT PRIMARY KEY,
                       nueva nvarchar(30) COLLATE DATABASE_DEFAULT UNIQUE,
                       codigo nvarchar(20) COLLATE DATABASE_DEFAULT, meses int, excluirTipos bit);
INSERT #Fuentes VALUES
 (N'PROM_AUS_6',N'AUS_AJUSTE_HIST_6',N'AJ_HIST_AUS',6,0),
 (N'PROM_AUS_12',N'AUS_AJUSTE_HIST_12',N'AJ_HIST_AUS',12,0),
 (N'PROM_AUS_6_NR',N'AUS_NO_REM_ACT_6',N'BASE_PROMEDIO_NR',6,1),
 (N'PROM_AUS_12_NR',N'AUS_NO_REM_ACT_12',N'BASE_PROMEDIO_NR',12,1);

CREATE TABLE #Conceptos (original nvarchar(20) COLLATE DATABASE_DEFAULT,
                         nuevo nvarchar(20) COLLATE DATABASE_DEFAULT, desde datetime, hasta datetime,
                         descripcion nvarchar(100) COLLATE DATABASE_DEFAULT,
                         formula nvarchar(2048) COLLATE DATABASE_DEFAULT, clase int);
INSERT #Conceptos VALUES
 (N'PROM_AUS_MES',N'AJ_HIST_AUS','20240101','20251231',N'Ajuste histórico de base de enfermedad',N'',0),
 (N'PROM_AUS_MES',N'PROM_ENF_MES','20260201','17530101',N'Promedio mensual de enfermedad inculpable',@FormulaPromEnf,1),
 (N'4110',N'4110','20260201','17530101',N'',@FormulaNueva,2);

BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
               WITH (UPDLOCK, HOLDLOCK)
               WHERE Código IN (N'AJ_HIST_AUS',N'PROM_ENF_MES')
                  OR (Código = N'4110' AND [Vigencia Desde] >= '20260201'))
        THROW 51000, N'Ya existe una vigencia o concepto destino; detener y revisar, sin duplicar.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WITH (UPDLOCK, HOLDLOCK) JOIN #Fuentes m ON m.nueva = f.[Nombre Variable])
        OR EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WITH (UPDLOCK, HOLDLOCK) JOIN #Fuentes m ON m.nueva = f.[Nombre Variable])
        THROW 51000, N'Ya existe una fuente o filtro destino.', 1;

    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH (UPDLOCK, HOLDLOCK) WHERE Código IN (N'4110',N'PROM_AUS_MES') AND [Vigencia Desde] = '20260101') <> 2
        THROW 51000, N'Faltan las plantillas de enero de 4110 o PROM_AUS_MES.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE Código = N'4110' AND [Vigencia Desde] = '20260101'
          AND [Fórmula] COLLATE Latin1_General_100_BIN2 = @FormulaAnterior COLLATE Latin1_General_100_BIN2
          AND DATALENGTH([Fórmula]) = DATALENGTH(@FormulaAnterior)
          AND [Variable Base] = N'#PROM_AUS_MES'
          AND [Vigencia Hasta] IN ('17530101','20260131') AND Activo = 1)
        THROW 51000, N'4110 cambió desde el respaldo o no tiene la base esperada.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE Código = N'PROM_AUS_MES' AND [Vigencia Desde] = '20260101'
          AND [Orden Cálculo] = 360 AND [Tipo Concepto] = 6 AND [Es Acumulador] = 0 AND Activo = 1)
        THROW 51000, N'La plantilla del promedio dejó de ser un virtual de orden 360.', 1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH (UPDLOCK, HOLDLOCK) WHERE [Cód_ Concepto] = N'4110' AND [Vigencia Desde] = '20260101') <> 8
        THROW 51000, N'4110 no tiene sus ocho fracciones de enero.', 1;

    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WITH (UPDLOCK, HOLDLOCK) JOIN #Fuentes m ON m.original = f.[Nombre Variable]
        WHERE [Id_ Tabla] = 60012 AND [No_ Campo Valor] = 7 AND [Función Agregado] = 0 AND Activo = 1
          AND [No_ Filtro 1] = 0 AND [No_ Filtro 2] = 0 AND [No_ Filtro 3] = 0) <> 4
        THROW 51000, N'Las cuatro fuentes originales no son las sumas esperadas de líneas.', 1;
    IF EXISTS (SELECT 1 FROM #Fuentes m WHERE
        (SELECT COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
         WITH (UPDLOCK, HOLDLOCK) WHERE f.[Nombre Variable] = m.original) <> 4
        OR (SELECT COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
            WHERE f.[Nombre Variable] = m.original AND
              (([No_ Campo] = 3 AND [Filtro Valor] = CASE WHEN m.excluirTipos = 1 THEN N'BASE_PROMEDIO_NR' ELSE N'BASE_PROMEDIO' END)
               OR ([No_ Campo] = 16 AND [Filtro Valor] = N'{EMP_NO}')
               OR ([No_ Campo] = 22 AND [Filtro Valor] = N'<>0')
               OR ([No_ Campo] = 23 AND [Filtro Valor] = CASE WHEN m.meses = 12
                   THEN N'{AUS_PROM12_DESDE}..{AUS_PROM_HASTA}' ELSE N'{AUS_PROM6_DESDE}..{AUS_PROM_HASTA}' END))) <> 4)
        THROW 51000, N'Los filtros originales no coinciden con empleado, estado, concepto y ventana auditados.', 1;

    IF EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
        WITH (UPDLOCK, HOLDLOCK) JOIN #Alcance a ON a.empleado = h.[No_ Empleado]
        WHERE [Cód_ Tipo Liq_] <> N'HIST_REMUN' AND
           (([Cód_ Período] = N'202602' AND Estado > 1)
            OR ([Fecha Liquidación] >= '20260301' AND Estado >= 1)))
        THROW 51000, N'Hay febrero protegido o liquidaciones posteriores calculadas en el alcance.', 1;
    IF EXISTS (SELECT 1 FROM #Datos d LEFT JOIN [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
        WITH (UPDLOCK, HOLDLOCK) ON h.No_ = d.documento
        OUTER APPLY (SELECT COUNT(*) n, SUM(l.Importe) importe
          FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l WITH (UPDLOCK, HOLDLOCK)
          WHERE l.[No_ Liquidación] = d.documento AND l.[Cód_ Concepto] = N'BASE_PROMEDIO') b
        WHERE d.nuevo=0 AND (h.No_ IS NULL OR h.[No_ Empleado] <> d.empleado OR h.[Cód_ Período] <> d.periodo
          OR h.[Cód_ Tipo Liq_] <> N'HIST_REMUN' OR h.Estado <> 2
          OR h.[Fecha Liquidación] < '20240101' OR h.[Fecha Liquidación] >= '20260101'
          OR CONVERT(char(6), h.[Fecha Liquidación],112) <> d.periodo
          OR b.n <> 1 OR b.importe IS NULL OR ABS(b.importe - d.base) > 0.0001))
        THROW 51000, N'La cabecera histórica o su BASE_PROMEDIO ya no coincide con el payload.', 1;
    IF EXISTS (SELECT 1 FROM #Datos d JOIN [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
        WITH (UPDLOCK,HOLDLOCK) ON h.No_=d.documento OR
          (h.[No_ Empleado]=d.empleado AND h.[Cód_ Período]=d.periodo AND h.[Cód_ Tipo Liq_]=N'HIST_REMUN')
        WHERE d.nuevo=1)
        THROW 51000, N'Un mes nuevo ya tiene cabecera histórica o su número está ocupado.', 1;
    IF EXISTS (SELECT 1 FROM #Datos d OUTER APPLY
      (SELECT COUNT(DISTINCT h.[No_ Entrada]) n,SUM(ISNULL(v.Valor,0)) objetivo
       FROM [dbo].[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
       LEFT JOIN [dbo].[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
         ON c.[Nombre Columna]=N'TOT_PROMEDIOS'
       LEFT JOIN [dbo].[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
         ON v.[No_ Entrada]=h.[No_ Entrada] AND v.[No_ Columna]=c.No_
       WHERE h.[No_ Empleado]=d.empleado AND h.[Año]=CONVERT(int,LEFT(d.periodo,4))
         AND h.Mes=CONVERT(int,RIGHT(d.periodo,2)) AND h.[Tipo Imputación] IN (1,10,11,12,13,14,15,3)) a
      WHERE a.n=0 OR a.objetivo IS NULL OR ABS(a.objetivo-d.objetivo)>0.0001)
        THROW 51000, N'El objetivo histórico difiere del archivo literal TOT_PROMEDIOS o no tiene corridas válidas.', 1;

    SELECT d.documento destino,d.documento origen INTO #Plantillas FROM #Datos d WHERE d.nuevo=0;
    INSERT #Plantillas(destino,origen)
      SELECT d.documento,p.No_ FROM #Datos d CROSS APPLY
        (SELECT TOP(1) h.No_ FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
           WITH (UPDLOCK,HOLDLOCK)
         WHERE h.[No_ Empleado]=d.empleado AND h.[Cód_ Tipo Liq_]=N'HIST_REMUN' AND h.Estado=2
           AND h.[Fecha Liquidación]>='20240101' AND h.[Fecha Liquidación]<'20260101'
           AND (SELECT COUNT(*) FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
              WITH (UPDLOCK,HOLDLOCK) WHERE l.[No_ Liquidación]=h.No_ AND l.[Cód_ Concepto]=N'BASE_PROMEDIO')=1
         ORDER BY ABS(DATEDIFF(day,h.[Fecha Liquidación],CONVERT(date,d.periodo+N'01',112))),h.No_) p
      WHERE d.nuevo=1;
    IF (SELECT COUNT(*) FROM #Plantillas)<>(SELECT COUNT(*) FROM #Datos)
        THROW 51000, N'Falta una plantilla histórica del mismo empleado para un mes ausente.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
        WITH (UPDLOCK, HOLDLOCK) JOIN #Datos d ON d.documento = l.[No_ Liquidación]
        WHERE l.[Cód_ Concepto] = N'AJ_HIST_AUS')
        THROW 51000, N'Ya existe un ajuste histórico en un documento destino.', 1;

    SELECT @CabecerasAntes = (SELECT h.* FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
       JOIN #Datos d ON d.documento = h.No_ WHERE d.nuevo=0 ORDER BY h.No_ FOR JSON PATH, INCLUDE_NULL_VALUES);

    -- Clonación por las columnas reales: conserva también campos agregados por otros cambios.
    SELECT @Columnas = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(name)), N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion = STRING_AGG(CONVERT(nvarchar(max), CASE name
        WHEN N'Código' THEN N'm.nuevo' WHEN N'Vigencia Desde' THEN N'm.desde' WHEN N'Vigencia Hasta' THEN N'm.hasta'
        WHEN N'Descripción' THEN N'CASE WHEN m.clase=2 THEN c.[Descripción] ELSE m.descripcion END'
        WHEN N'Nombre Impresión' THEN N'CASE WHEN m.clase=2 THEN c.[Nombre Impresión] ELSE N'''' END'
        WHEN N'Fórmula' THEN N'm.formula'
        WHEN N'Condición' THEN N'CASE WHEN m.clase=0 THEN N'''' WHEN m.clase=1 THEN N''DIAS_ENFERMEDAD > 0'' ELSE c.[Condición] END'
        WHEN N'Tipo Concepto' THEN N'CASE WHEN m.clase=2 THEN c.[Tipo Concepto] ELSE 6 END'
        WHEN N'Orden Cálculo' THEN N'CASE WHEN m.clase=0 THEN 0 ELSE c.[Orden Cálculo] END'
        WHEN N'Fórmula Orden Cálculo' THEN N'CASE WHEN m.clase=0 THEN N''0'' ELSE c.[Fórmula Orden Cálculo] END'
        WHEN N'Activo' THEN N'1' WHEN N'Es Acumulador' THEN N'0'
        WHEN N'Imprime en Recibo' THEN N'CASE WHEN m.clase=2 THEN c.[Imprime en Recibo] ELSE 0 END'
        WHEN N'Es Devengo' THEN N'CASE WHEN m.clase=2 THEN c.[Es Devengo] ELSE 0 END'
        WHEN N'Tipos Liq_ Aplicables' THEN N'CASE WHEN m.clase=0 THEN N''HIST_REMUN'' ELSE c.[Tipos Liq_ Aplicables] END'
        WHEN N'Variable Base' THEN N'CASE WHEN m.clase=2 THEN N''#PROM_ENF_MES'' ELSE N'''' END'
        WHEN N'Variable Cantidad' THEN N'CASE WHEN m.clase=2 THEN c.[Variable Cantidad] ELSE N'''' END'
        WHEN N'Columna SICOSS' THEN N'CASE WHEN m.clase=2 THEN c.[Columna SICOSS] ELSE 0 END'
        WHEN N'$systemId' THEN N'NEWID()'
        WHEN N'$systemCreatedAt' THEN N'GETUTCDATE()' WHEN N'$systemModifiedAt' THEN N'GETUTCDATE()'
        WHEN N'$systemCreatedBy' THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        WHEN N'$systemModifiedBy' THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        ELSE N'c.' + QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id = OBJECT_ID(@Concepto) AND system_type_id <> 189 AND is_identity = 0 AND is_computed = 0;
    SET @Sql = N'INSERT '+@Concepto+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Concepto+
      N' c JOIN #Conceptos m ON m.original=c.Código WHERE c.[Vigencia Desde]=''20260101'';';
    EXEC sys.sp_executesql @Sql;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
        JOIN #Conceptos m ON m.nuevo=c.Código AND m.desde=c.[Vigencia Desde]) <> 3
        THROW 51000, N'No se crearon las tres configuraciones de concepto.', 1;

    UPDATE [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
      SET [Vigencia Hasta] = '20260131', [$systemModifiedAt] = GETUTCDATE()
      WHERE Código = N'4110' AND [Vigencia Desde] = '20260101';

    SELECT @Columnas = STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion = STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Vigencia Desde' THEN N'CONVERT(datetime,''20260201'')'
        WHEN N'$systemId' THEN N'NEWID()'
        WHEN N'$systemCreatedAt' THEN N'GETUTCDATE()' WHEN N'$systemModifiedAt' THEN N'GETUTCDATE()'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Fraccion) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Fraccion+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Fraccion+
      N' f WHERE f.[Cód_ Concepto]=N''4110'' AND f.[Vigencia Desde]=''20260101'';';
    EXEC sys.sp_executesql @Sql;

    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Nombre Variable' THEN N'm.nueva' WHEN N'Descripción' THEN N'CASE WHEN m.excluirTipos=1 THEN N''Porción no remunerativa real, sin históricos ni finales'' ELSE N''Corrección histórica de la base de enfermedad'' END'
        WHEN N'$systemId' THEN N'NEWID()'
        WHEN N'$systemCreatedAt' THEN N'GETUTCDATE()' WHEN N'$systemModifiedAt' THEN N'GETUTCDATE()'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Fuente) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Fuente+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Fuente+
      N' f JOIN #Fuentes m ON m.original=f.[Nombre Variable];';
    EXEC sys.sp_executesql @Sql;

    IF COLUMNPROPERTY(OBJECT_ID(@Filtro),N'No_ Línea','IsIdentity')<>1
        THROW 51000, N'La clave autoincremental de filtros cambió: revisar el esquema antes de clonar.', 1;
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Nombre Variable' THEN N'm.nueva'
        WHEN N'Filtro Valor' THEN N'CASE WHEN f.[No_ Campo]=3 THEN m.codigo ELSE f.[Filtro Valor] END'
        WHEN N'$systemId' THEN N'NEWID()'
        WHEN N'$systemCreatedAt' THEN N'GETUTCDATE()' WHEN N'$systemModifiedAt' THEN N'GETUTCDATE()'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Filtro) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Filtro+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Filtro+
      N' f JOIN #Fuentes m ON m.original=f.[Nombre Variable];';
    EXEC sys.sp_executesql @Sql;
    INSERT [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
      ([Nombre Variable],[No_ Campo],[Filtro Valor],[$systemId],[$systemCreatedAt],[$systemModifiedAt])
      SELECT nueva,30,N'<>HIST_REMUN&<>LIQ_FINAL',NEWID(),GETUTCDATE(),GETUTCDATE() FROM #Fuentes WHERE excluirTipos=1;
    SELECT @FiltrosCreados=COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
      JOIN #Fuentes m ON m.nueva=f.[Nombre Variable];
    IF @FiltrosCreados<>18 THROW 51000, N'No quedaron los dieciocho filtros esperados.', 1;

    -- Los tres meses faltantes contienen solamente información para el promedio de enfermedad.
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE
        WHEN name=N'No_' THEN N'd.documento'
        WHEN name=N'Cód_ Período' THEN N'd.periodo'
        WHEN name=N'No_ Empleado' THEN N'd.empleado'
        WHEN name=N'Fecha Liquidación' THEN N'CONVERT(datetime,EOMONTH(CONVERT(date,d.periodo+N''01'',112)))'
        WHEN name=N'Estado' THEN N'2'
        WHEN name=N'Cód_ Tipo Liq_' THEN N'N''HIST_REMUN'''
        WHEN name IN (N'No_ Proyecto',N'No_ Liq_ Origen',N'No_ Serie',N'No_ Series') THEN N'N'''''
        WHEN name IN (N'Cobertura Desde',N'Cobertura Hasta') THEN N'CONVERT(datetime,''17530101'')'
        WHEN name=N'$systemId' THEN N'NEWID()'
        WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'GETUTCDATE()'
        WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy')
          THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        WHEN system_type_id IN (106,108,60,122) THEN N'0'
        ELSE N'h.'+QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Cabecera) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Cabecera+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Cabecera+
      N' h JOIN #Plantillas p ON p.origen=h.No_ JOIN #Datos d ON d.documento=p.destino WHERE d.nuevo=1;';
    EXEC sys.sp_executesql @Sql;
    SELECT @CabecerasCreadas=COUNT(*) FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
      JOIN #Datos d ON d.documento=h.No_ WHERE d.nuevo=1;
    IF @CabecerasCreadas<>(SELECT COUNT(*) FROM #Datos WHERE nuevo=1)
        THROW 51000, N'Cantidad inesperada de cabeceras históricas informativas.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
      JOIN #Datos d ON d.documento=h.No_ WHERE d.nuevo=1 AND
        (h.[Total Haberes]<>0 OR h.[Total Descuentos]<>0 OR h.[Total Contribuciones]<>0
         OR h.[Neto a Pagar]<>0 OR h.[Haberes Ordinarios Gravados]<>0 OR h.Estado<>2
         OR h.[No_ Proyecto]<>N'' OR h.[No_ Liq_ Origen]<>N''))
        THROW 51000, N'La cabecera nueva debe ser exclusivamente informativa y sin vínculos económicos.', 1;

    -- No_ Línea es IDENTITY en la BD observada. Se contempla la variante sin IDENTITY bajo bloqueo.
    IF COLUMNPROPERTY(OBJECT_ID(@Linea),N'No_ Línea','IsIdentity')=0
        SELECT @MaxLinea=ISNULL(MAX([No_ Línea]),0) FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WITH (TABLOCKX,HOLDLOCK);
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP (ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'No_ Liquidación' THEN N'd.documento'
        WHEN N'No_ Línea' THEN N'@MaxLinea+ROW_NUMBER() OVER(ORDER BY d.documento)'
        WHEN N'Cód_ Concepto' THEN N'N''AJ_HIST_AUS'''
        WHEN N'Descripción Concepto' THEN N'N''Ajuste histórico de base de enfermedad'''
        WHEN N'Nombre Impresión' THEN N'N'''''
        WHEN N'Tipo Concepto' THEN N'6' WHEN N'Importe' THEN N'd.ajuste'
        WHEN N'Orden Cálculo' THEN N'0' WHEN N'Cantidad' THEN N'0' WHEN N'Base Cálculo' THEN N'0'
        WHEN N'Unidad Cantidad' THEN N'N'''''
        WHEN N'Fórmula Aplicada' THEN N'N''Meta4 TOT_PROMEDIOS menos BASE_PROMEDIO histórico'''
        WHEN N'Fuente Parámetros' THEN N'CASE WHEN d.nuevo=1 THEN N''META4:TOT_PROMEDIOS; mes omitido de migración, sin BASE_PROMEDIO previa'' ELSE N''META4:TOT_PROMEDIOS; HIST_REMUN:BASE_PROMEDIO; revisión febrero 2026'' END'
        WHEN N'Fórmula Evaluada' THEN N'N'''''
        WHEN N'Vigencias Distribución' THEN N'N'''''
        WHEN N'Vigencia Concepto' THEN N'CONVERT(datetime,''20240101'')'
        WHEN N'No_ Empleado' THEN N'd.empleado'
        WHEN N'Cód_ Período' THEN N'd.periodo'
        WHEN N'Cód_ Tipo Liq_' THEN N'N''HIST_REMUN'''
        WHEN N'No_ Proyecto' THEN N'N'''''
        WHEN N'Fecha Liquidación' THEN N'CONVERT(datetime,EOMONTH(CONVERT(date,d.periodo+N''01'',112)))'
        WHEN N'Estado' THEN N'2'
        WHEN N'Imprime en Recibo' THEN N'0' WHEN N'Es Devengo' THEN N'0' WHEN N'Grupo Costo Laboral' THEN N'0'
        WHEN N'No_ Lote Franco' THEN N'0'
        WHEN N'Id_ Selección Francos' THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        WHEN N'$systemId' THEN N'NEWID()'
        WHEN N'$systemCreatedAt' THEN N'GETUTCDATE()' WHEN N'$systemModifiedAt' THEN N'GETUTCDATE()'
        WHEN N'$systemCreatedBy' THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        WHEN N'$systemModifiedBy' THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
        ELSE N'l.'+QUOTENAME(name) END),N',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Linea) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Linea+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Linea+
      N' l JOIN #Plantillas p ON p.origen=l.[No_ Liquidación] JOIN #Datos d ON d.documento=p.destino WHERE l.[Cód_ Concepto]=N''BASE_PROMEDIO'';';
    EXEC sys.sp_executesql @Sql,N'@MaxLinea int',@MaxLinea=@MaxLinea;
    SELECT @LineasCreadas=COUNT(*) FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
      JOIN #Datos d ON d.documento=l.[No_ Liquidación] WHERE l.[Cód_ Concepto]=N'AJ_HIST_AUS';
    IF @LineasCreadas<>(SELECT COUNT(*) FROM #Datos)
        THROW 51000, N'Cantidad de líneas históricas distinta del payload.', 1;
    IF EXISTS (SELECT 1 FROM #Datos d
      OUTER APPLY (SELECT SUM(Importe) importe FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [No_ Liquidación]=d.documento AND [Cód_ Concepto]=N'BASE_PROMEDIO') b
      OUTER APPLY (SELECT COUNT(*) n,SUM(Importe) importe,
          SUM(CASE WHEN [Tipo Concepto]<>6 OR [Es Devengo]<>0 OR [Imprime en Recibo]<>0 THEN 1 ELSE 0 END) invalidas
        FROM [dbo].[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [No_ Liquidación]=d.documento AND [Cód_ Concepto]=N'AJ_HIST_AUS') a
      WHERE (d.nuevo=0 AND b.importe IS NULL) OR (d.nuevo=1 AND b.importe IS NOT NULL)
        OR a.importe IS NULL OR a.n<>1 OR a.invalidas<>0
        OR ABS(COALESCE(b.importe,0)-d.base)>0.0001 OR ABS(a.importe-d.ajuste)>0.0001
        OR ABS(COALESCE(b.importe,0)+a.importe-d.objetivo)>0.0002)
        THROW 51000, N'Falló la conciliación del histórico corregido o cambió la base previa.', 1;
    SELECT @CabecerasDespues=(SELECT h.* FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
      JOIN #Datos d ON d.documento=h.No_ WHERE d.nuevo=0 ORDER BY h.No_ FOR JSON PATH, INCLUDE_NULL_VALUES);
    IF @CabecerasAntes COLLATE Latin1_General_100_BIN2 <> @CabecerasDespues COLLATE Latin1_General_100_BIN2
      OR DATALENGTH(@CabecerasAntes)<>DATALENGTH(@CabecerasDespues)
        THROW 51000, N'Se alteró una cabecera histórica; se revierte toda la operación.', 1;

    INSERT INTO [ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
      ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],[Usuario],[Tipo Cambio],
       [Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],
       [Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
    SELECT N'4110','20260201',c.Descripción,SYSDATETIME(),N'BASE ENFERMEDAD META4',0,
       @FormulaAnterior,@FormulaNueva,c.Condición,c.Condición,1,0,SYSDATETIME(),NEWID(),GETUTCDATE(),
       '00000000-0000-0000-0000-000000000000',GETUTCDATE(),'00000000-0000-0000-0000-000000000000'
    FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
    WHERE c.Código=N'4110' AND c.[Vigencia Desde]='20260201';
    IF @Aplicar=1 COMMIT TRANSACTION; ELSE ROLLBACK TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SELECT @Aplicar Aplicado,3 ConceptosNuevos,4 FuentesNuevas,@FiltrosCreados FiltrosNuevos,
           8 FraccionesCopiadas,@LineasCreadas LineasHistoricasVerificadas;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    THROW;
END CATCH;
