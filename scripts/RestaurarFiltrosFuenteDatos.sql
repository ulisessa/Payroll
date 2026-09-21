/*
    RESTAURA LOS FILTROS DE FUENTE DATOS LIQUIDACIÓN   (tabla 60029)

    Los 76 filtros de "Filtro Fuente Datos Liq." desaparecieron de la base. Sin ellos cada Fuente
    Datos activa resuelve SIN acotar y lee la tabla entera.

    Medido con el Performance Profiler sobre una liquidación de 123 segundos:
      ResolveFuente     65,5 s
      CalcFinEfectivo   26,6 s
      RunConceptos       0,22 s   <- el cálculo real
    O sea que el 75% del tiempo era leer tablas sin filtrar.

    Los datos salen del export Genérico07_09_2026_23_24_04, donde las 76 filas todavía estaban.

    POR QUÉ ESTÁ ARMADO ASÍ
      El nombre SQL de la tabla depende del GUID de la extensión y de cómo BC transforma el punto
      final de "Filtro Fuente Datos Liq.", así que se DESCUBRE en sys.tables en vez de construirse.
      Eso obliga a SQL dinámico para el nombre — pero los datos NO van ahí dentro: van a una tabla
      temporal con SQL estático. Si fueran dinámicos, cada comilla del dato ('CATEGORIA', o el
      ''|{PERIODO_DESDE}.. de FAM_ADIC_OS) habría que duplicarla dos veces, una por capa.

    OJO: [No_ Línea] es IDENTITY (AutoIncrement en el AL). De ahí el IDENTITY_INSERT y el RESEED
    de más abajo; si los sacás, vuelve el Msg 544.

    ANTES DE CORRER
      1. Backup.
      2. Con nadie liquidando.
      3. Revisar @Empresa.
      4. Después, reiniciar el service tier o Sync-NAVTenant para vaciar la caché.

    POR QUÉ SE BORRARON: revisar en la ficha del paquete la columna "Eliminar los registros de
    tablas antes del procesamiento" para la tabla 60029. Si está tildada, cada importación vacía
    la tabla antes de aplicar, y si el apply no llega a esa tabla las filas quedan borradas.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';   -- ajustar si la empresa es otra
DECLARE @Tabla   sysname;
DECLARE @TFuente sysname;
DECLARE @sql     nvarchar(max);

SELECT @Tabla   = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Filtro Fuente Datos%';
SELECT @TFuente = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Fuente Datos Liquidaci%';

IF @Tabla IS NULL OR @TFuente IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%Fuente Datos%';
    RAISERROR(N'No se encontraron las tablas para esa empresa. Mirar la lista de arriba y ajustar la variable Empresa.',16,1);
    RETURN;
END;

SELECT @Tabla AS TablaFiltros, @TFuente AS TablaFuentes;

-- Los 76 filtros, en SQL estático.
CREATE TABLE #Filtros (
    [Nombre Variable] nvarchar(30)  NOT NULL,
    [No_ Línea]       int           NOT NULL,
    [No_ Campo]       int           NOT NULL,
    [Filtro Valor]    nvarchar(250) NOT NULL
);

INSERT INTO #Filtros ([Nombre Variable],[No_ Línea],[No_ Campo],[Filtro Valor]) VALUES
    (N'A_CUENTA_MAREA',46,3,N'{EMP_NO}'),(N'A_CUENTA_MAREA',47,5,N'{JOB_NO}'),(N'A_CUENTA_MAREA',48,30,N'DEVENGADOS'),(N'A_CUENTA_MAREA',49,9,N'<>0'),
    (N'CAT_LEG',80,3,N'''CATEGORIA'''),(N'CAT_LEG',81,1,N'Empleado'),(N'CAT_LEG',82,2,N'{EMP_NO}'),(N'CAT_LEG',83,4,N'<={FECHA_REF}'),
    (N'CAT_LEG',84,5,N'>={FECHA_REF}'),(N'CAT_MAREA',78,1,N'{EMP_NO}'),(N'CAT_MAREA',79,2,N'{JOB_NO}'),(N'DIAS_ENF_PERIODO',75,1,N'{EMP_NO}'),
    (N'DIAS_ENF_PERIODO',76,3,N'AU1'),(N'DIAS_ENF_PERIODO',77,9,N'Empleado'),(N'DIAS_MAR',17,1,N'{JOB_NO}'),(N'DIAS_ORD_PERIODO',72,1,N'{EMP_NO}'),
    (N'DIAS_ORD_PERIODO',73,3,N'OR'),(N'DIAS_ORD_PERIODO',74,9,N'Empleado'),(N'DIAS_VAC',10,1,N'{EMP_NO}'),(N'DIAS_VAC',11,3,N'FC-VAC'),
    (N'DIAS_VAC_INICIO',8,1,N'{EMP_NO}'),(N'DIAS_VAC_INICIO',9,3,N'FC-VAC'),(N'FAM_ADIC_OS',85,1,N'{EMP_NO}'),(N'FAM_ADIC_OS',86,50216,N'true'),
    (N'FAM_ADIC_OS',87,50000,N'..{FECHA_REF}'),(N'FAM_ADIC_OS',88,50001,N'''''|{PERIODO_DESDE}..'),(N'INCID_VACACIONES',12,1,N'{LIQ_NO}'),(N'INCID_VACACIONES',13,2,N'FC-VAC'),
    (N'MEJOR_REM_SEM',1,16,N'{EMP_NO}'),(N'MEJOR_REM_SEM',2,23,N'{SEM_DESDE}..{SEM_HASTA}'),(N'MEJOR_REM_SEM',3,30,N'REGULAR'),(N'MEJOR_REM_SEM',4,22,N'<>0'),
    (N'MEJOR_REM_SEM',5,3,N'BASE_PROMEDIO'),(N'MESES_TRAB_SEM',14,3,N'{EMP_NO}'),(N'MESES_TRAB_SEM',15,8,N'{SEM_DESDE}..{SEM_HASTA}'),(N'MESES_TRAB_SEM',16,30,N'REGULAR'),
    (N'PROD_KB_C1',24,1,N'{JOB_NO}'),(N'PROD_KB_C1',25,4,N'LTBP-AB21-C1-12 K'),(N'PROD_KB_C2',26,1,N'{JOB_NO}'),(N'PROD_KB_C2',27,4,N'LTBP-AB22-C2-12 K'),
    (N'PROD_KB_CR',32,1,N'{JOB_NO}'),(N'PROD_KB_CR',33,4,N'LTBP-AC21-CR-12 K'),(N'PROD_KB_L1',18,1,N'{JOB_NO}'),(N'PROD_KB_L1',19,4,N'LTBP-AA21-L1-12 K'),
    (N'PROD_KB_L2',20,1,N'{JOB_NO}'),(N'PROD_KB_L2',21,4,N'LTBP-AA22-L2-12 K'),(N'PROD_KB_L3',22,1,N'{JOB_NO}'),(N'PROD_KB_L3',23,4,N'LTBP-AA23-L3-12 K'),
    (N'PROD_KB_LANG_COLA',28,1,N'{JOB_NO}'),(N'PROD_KB_LANG_COLA',29,4,N'L-COLA'),(N'PROD_KB_LANG_ENT',30,1,N'{JOB_NO}'),(N'PROD_KB_LANG_ENT',31,50002,N'L-ENTERO'),
    (N'PROD_KN_C1',34,1,N'{JOB_NO}'),(N'PROD_KN_C1',35,4,N'LTBP-AB21-C1-12 K'),(N'PROD_KN_C2',36,1,N'{JOB_NO}'),(N'PROD_KN_C2',37,4,N'LTBP-AB22-C2-12 K'),
    (N'PROD_KN_C3',59,1,N'{JOB_NO}'),(N'PROD_KN_C3',60,4,N'LTBP-AB22-C3-12 K'),(N'PROD_KN_CR',38,1,N'{JOB_NO}'),(N'PROD_KN_CR',39,4,N'LTBP-AC21-CR-12 K'),
    (N'PROD_KN_L1',40,1,N'{JOB_NO}'),(N'PROD_KN_L1',41,4,N'LTBP-AA21-L1-12 K'),(N'PROD_KN_L2',42,1,N'{JOB_NO}'),(N'PROD_KN_L2',43,4,N'LTBP-AA22-L2-12 K'),
    (N'PROD_KN_L3',44,1,N'{JOB_NO}'),(N'PROD_KN_L3',52,4,N'LTBP-AA23-L3-12 K'),(N'PROD_KN_L4',53,1,N'{JOB_NO}'),(N'PROD_KN_L4',54,4,N'LTBP-AA23-L4-12 K'),
    (N'PROD_KN_L5',55,1,N'{JOB_NO}'),(N'PROD_KN_L5',56,4,N'LTBP-AA23-L5-12 K'),(N'PROD_KN_L6',57,1,N'{JOB_NO}'),(N'PROD_KN_L6',58,4,N'LTBP-AA23-L6-12 K'),
    (N'PROD_KN_MAREA',50,1,N'{JOB_NO}'),(N'PROD_KN_MAREA',71,10,N'<={FECHA_REF}'),(N'TC_CERCANO',6,1,N'{MONEDA}'),(N'TC_CERCANO',7,2,N'<={FECHA_REF}');

IF (SELECT COUNT(*) FROM #Filtros) <> 76
BEGIN
    RAISERROR(N'El bloque de datos no cargó las 76 filas.',16,1);
    RETURN;
END;

SET @sql = N'SELECT ''ANTES'' AS Momento, COUNT(*) AS Filas FROM [dbo].' + @Tabla + N';';
EXEC sp_executesql @sql;

BEGIN TRAN;

SET @sql = N'DELETE FROM [dbo].' + @Tabla + N';';
EXEC sp_executesql @sql;

-- [No_ Línea] es AutoIncrement en el AL (Tab60029, field 2), o sea IDENTITY en SQL. Sin
-- IDENTITY_INSERT ON, SQL lo rechaza con "Msg 544, Cannot insert explicit value for identity
-- column". Los tres statements tienen que ir en el MISMO batch dinámico.
SET @sql = N'SET IDENTITY_INSERT [dbo].' + @Tabla + N' ON;
              INSERT INTO [dbo].' + @Tabla + N' ([Nombre Variable],[No_ Línea],[No_ Campo],[Filtro Valor])
              SELECT [Nombre Variable],[No_ Línea],[No_ Campo],[Filtro Valor] FROM #Filtros;
              SET IDENTITY_INSERT [dbo].' + @Tabla + N' OFF;';
EXEC sp_executesql @sql;

COMMIT;

DROP TABLE #Filtros;

-- Resembrar el contador: insertamos líneas explícitas hasta la 88, y si el identity quedara por
-- debajo el próximo alta de un filtro desde BC chocaría con una fila existente. RESEED sin valor
-- lo reajusta al máximo actual de la columna.
SET @sql = N'DBCC CHECKIDENT (''[dbo].' + @Tabla + N''', RESEED);';
EXEC sp_executesql @sql;

-- Verificación: 76 filas, y ninguna fuente activa sin filtros.
SET @sql = N'SELECT ''DESPUES'' AS Momento, COUNT(*) AS Filas FROM [dbo].' + @Tabla + N';';
EXEC sp_executesql @sql;

SET @sql = N'SELECT [Nombre Variable], COUNT(*) AS Filtros FROM [dbo].' + @Tabla + N'
              GROUP BY [Nombre Variable] ORDER BY 1;';
EXEC sp_executesql @sql;

-- Fuentes activas que quedarían SIN filtro: no debería devolver nada.
SET @sql = N'SELECT f.[Nombre Variable], f.[Id_ Tabla]
              FROM [dbo].' + @TFuente + N' f
              LEFT JOIN [dbo].' + @Tabla + N' x ON x.[Nombre Variable] = f.[Nombre Variable]
              WHERE f.[Activo] = 1 AND x.[Nombre Variable] IS NULL;';
EXEC sp_executesql @sql;
GO
