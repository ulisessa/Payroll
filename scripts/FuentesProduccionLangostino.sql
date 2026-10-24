/* FUENTES DE DATOS DE PRODUCCIÓN DEL LANGOSTINO POR CLASIFICACIÓN (tabla 50562, Lín. descarga).
   Criterio del usuario (15/10/2026): el código del ítem no cambia entre mareas, cada marea captura distintas clasificaciones; la producción se valúa por
   CLASIFICACIÓN (L1, L2, L3, C1, C2, CR...), no por presentación, y la que valúa es la de PESO NETO (campo 8, KN); el peso bruto (campo 9, KB) acompaña.
   El código del ítem es LTBP-<serie>-<clasificación>-<presentación> (LTBP-AA21-L1-12 K): se filtra el ÍTEM (campo 4) por LTBP-*-<clasificación>-*, así que
   no importa la serie ni la presentación. Sólo producción propia: los LTBT (3ROS, de terceros) quedan afuera, como en las fuentes actuales.
   Clasificaciones con datos en las mareas 114 a 119: L1, L2, L3, L4, L5, LV (varios), LX, C1, C2, C3, CR. Total del langostino de la marea (sin merluza): PROD_KN_LAN y
   PROD_KB_LAN, por Actividad (campo 50000) = LAN y ítem LTBP-*. Campos de Lín. descarga (confirmados con el AL de la tabla): 4 Item no., 8 Net weight, 9 Gross weight, 50000 Actividad, 50002 Subfamilia.
   Estas fuentes reemplazan las seis de la primera versión de este script (por subfamilia y mal rotuladas como cajas), que se borran.
   Las fuentes existentes (PROD_KN_L1.., PROD_KB_L1..) NO se tocan. Diferencias encontradas en ellas, sin corregir:
     - PROD_KN_L2 filtra LTBP-AA23-L3-12 K y PROD_KN_L3 filtra LTBP-AA22-L2-12 K: están cruzadas (las KB sí están bien). El 2498 valúa L2 a 5.500 y L3 a 4.500.
     - PROD_KN_L4, L5, L6 y C3 apuntan a ítems que no existen (AA23-L4, AA23-L5, AA23-L6, AB22-C3); los reales son AA24-L4, AA25-L5 y AB23-C3, y no hay L6.
     - PROD_KB_LANG_COLA filtra el campo 4 con 'L-COLA' (que es una subfamilia, campo 50002).
   Rollback: borrar las fuentes PROD_K[NB]_LAN y PROD_K[NB]_LAN_* con sus filtros. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- Fuera las de la primera versión
DELETE FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] IN (N'PROD_KN_LANG_ENT', N'PROD_KN_LANG_COLA', N'PROD_KN_LANG_ROTO', N'PROD_KB_LANG_ROTO', N'PROD_KN_LANG', N'PROD_KB_LANG');
DELETE FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] IN (N'PROD_KN_LANG_ENT', N'PROD_KN_LANG_COLA', N'PROD_KN_LANG_ROTO', N'PROD_KB_LANG_ROTO', N'PROD_KN_LANG', N'PROD_KB_LANG');
SELECT @@ROWCOUNT AS Borradas_de_la_primera_version;

CREATE TABLE #c (clase nvarchar(4) COLLATE DATABASE_DEFAULT);
INSERT #c VALUES (N'L1'), (N'L2'), (N'L3'), (N'L4'), (N'L5'), (N'LV'), (N'LX'), (N'C1'), (N'C2'), (N'C3'), (N'CR');
CREATE TABLE #n (nombre nvarchar(30) COLLATE DATABASE_DEFAULT, descr nvarchar(100) COLLATE DATABASE_DEFAULT, molde nvarchar(30) COLLATE DATABASE_DEFAULT, campo int, filtro nvarchar(40) COLLATE DATABASE_DEFAULT);
INSERT #n SELECT N'PROD_KN_LAN_' + clase, N'KN descargados de langostino ' + clase + N' (peso neto, cualquier presentación)', N'PROD_KN_L1', 4, N'LTBP-*-' + clase + N'-*' FROM #c;
INSERT #n SELECT N'PROD_KB_LAN_' + clase, N'KB descargados de langostino ' + clase + N' (peso bruto, cualquier presentación)', N'PROD_KB_L1', 4, N'LTBP-*-' + clase + N'-*' FROM #c;
INSERT #n VALUES (N'PROD_KN_LAN', N'KN descargados de langostino de la marea (peso neto, sin merluza)', N'PROD_KN_L1', 50000, N'LAN'),
                 (N'PROD_KB_LAN', N'KB descargados de langostino de la marea (peso bruto, sin merluza)', N'PROD_KB_L1', 50000, N'LAN');

DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @nombre nvarchar(30), @descr nvarchar(100), @molde nvarchar(30), @campo int, @filtro nvarchar(40), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT nombre, descr, molde, campo, filtro FROM #n;
OPEN cur; FETCH cur INTO @nombre, @descr, @molde, @campo, @filtro;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = @nombre)
    BEGIN
        IF OBJECT_ID('tempdb..#f') IS NOT NULL DROP TABLE #f;
        SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = @molde;
        UPDATE #f SET [Nombre Variable] = @nombre, [Descripción] = @descr, [$systemId] = NEWID();
        SET @sql = N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f';
        EXEC (@sql);
        INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES (@nombre, 1, N'{JOB_NO}'), (@nombre, @campo, @filtro);
        IF @campo = 50000
            INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES (@nombre, 4, N'LTBP-*');
    END
    FETCH cur INTO @nombre, @descr, @molde, @campo, @filtro;
END
CLOSE cur; DEALLOCATE cur;
SELECT f.[Nombre Variable] n, f.[No_ Campo Valor] v, x.[No_ Campo] c, x.[Filtro Valor] fv
FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f JOIN dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x ON x.[Nombre Variable] = f.[Nombre Variable]
WHERE f.[Nombre Variable] IN (SELECT nombre FROM #n) AND x.[No_ Campo] <> 1 ORDER BY 1, x.[No_ Línea];
-- Control: lo que sumarán las fuentes nuevas en la marea 119 más reciente (kilos netos y brutos por clasificación)
SELECT SUBSTRING(l.[Item no_], CHARINDEX('-', l.[Item no_], 6) + 1, 2) clase, CAST(SUM(l.[Cantidad]) AS bigint) cajas, CAST(SUM(l.[Net weight]) AS bigint) col_net, CAST(SUM(l.[Gross weight]) AS bigint) col_gross
FROM dbo.[ArbuTest$Lín_ descarga$a423950b-02e9-4ee0-ab32-61517ce330cb] l
WHERE l.[No_ proyecto] = (SELECT MAX([No_ proyecto]) FROM dbo.[ArbuTest$Lín_ descarga$a423950b-02e9-4ee0-ab32-61517ce330cb] WHERE [No_ proyecto] LIKE N'PP-119-%') AND l.[Item no_] LIKE N'LTBP-%' GROUP BY SUBSTRING(l.[Item no_], CHARINDEX('-', l.[Item no_], 6) + 1, 2) ORDER BY 1;
COMMIT;
