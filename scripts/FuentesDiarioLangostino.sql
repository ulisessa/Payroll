/* FUENTES DE DATOS DEL LANGOSTINO SOBRE EL DIARIO DE A BORDO (tabla 50502, On board capture lines): LA PRODUCCIÓN DEL QUE NO TERMINA LA MAREA.
   Quien se baja a mitad de marea no tiene descarga a su nombre: su producción sale del diario de a bordo hasta su día de desembarque, igual que en el calamar
   (DIARIO_KN_CAL_ENT/REJ/VAI sobre {ASIG_DESDE}..{ASIG_HASTA}). Se agregan las gemelas de PROD_KN_LAN_* (scripts/FuentesProduccionLangostino.sql), por clasificación:
     DIARIO_KN_LAN_<L1|L2|L3|L4|L5|LV|LX|C1|C2|C3|CR>   kilos (campo 18) del producto (campo 7) LTBP-*-<clasificación>-*, en la ventana de la asignación
     DIARIO_KN_LAN                                       todo el langostino del diario (Actividad, campo 50007, = LAN y producto LTBP-*), sin merluza
   Campos de On board capture lines (del AL de la tabla): 1 Fecha registro, 7 No. (producto), 16 Cód. proyecto, 18 Kilos, 50007 Actividad, 50014 Subfamilia.
   Medido en PP-119-000315: los kilos del diario por producto (C1 7.576, L1 46.086, L2 31.144, L3 876) coinciden con el neto de la descarga (46.080 de L1 en la
   marea cargada), así que valúan igual que las de descarga. Igual que las del calamar no filtran por Concepto: PESCA, PUERTO, CAPA y EXPLORANDO traen kilos.
   Rollback: borrar las fuentes DIARIO_KN_LAN y DIARIO_KN_LAN_* con sus filtros. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
CREATE TABLE #c (clase nvarchar(4) COLLATE DATABASE_DEFAULT);
INSERT #c VALUES (N'L1'), (N'L2'), (N'L3'), (N'L4'), (N'L5'), (N'LV'), (N'LX'), (N'C1'), (N'C2'), (N'C3'), (N'CR');
CREATE TABLE #n (nombre nvarchar(30) COLLATE DATABASE_DEFAULT, descr nvarchar(100) COLLATE DATABASE_DEFAULT, campo int, filtro nvarchar(40) COLLATE DATABASE_DEFAULT);
INSERT #n SELECT N'DIARIO_KN_LAN_' + clase, N'Kilos del diario de a bordo de langostino ' + clase + N' en la ventana de la asignación', 7, N'LTBP-*-' + clase + N'-*' FROM #c;
INSERT #n VALUES (N'DIARIO_KN_LAN', N'Kilos del diario de a bordo de langostino (sin merluza) en la ventana de la asignación', 50007, N'LAN');
DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @nombre nvarchar(30), @descr nvarchar(100), @campo int, @filtro nvarchar(40), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT nombre, descr, campo, filtro FROM #n;
OPEN cur; FETCH cur INTO @nombre, @descr, @campo, @filtro;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = @nombre)
    BEGIN
        IF OBJECT_ID('tempdb..#f') IS NOT NULL DROP TABLE #f;
        SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = N'DIARIO_KN_CAL_ENT';
        UPDATE #f SET [Nombre Variable] = @nombre, [Descripción] = @descr, [$systemId] = NEWID();
        SET @sql = N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f';
        EXEC (@sql);
        INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES (@nombre, 16, N'{JOB_NO}'), (@nombre, 1, N'{ASIG_DESDE}..{ASIG_HASTA}'), (@nombre, @campo, @filtro);
        IF @campo = 50007
            INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES (@nombre, 7, N'LTBP-*');
    END
    FETCH cur INTO @nombre, @descr, @campo, @filtro;
END
CLOSE cur; DEALLOCATE cur;
SELECT f.[Nombre Variable] n, f.[Id_ Tabla] t, f.[No_ Campo Valor] v, x.[No_ Campo] c, x.[Filtro Valor] fv
FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f JOIN dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x ON x.[Nombre Variable] = f.[Nombre Variable]
WHERE f.[Nombre Variable] IN (SELECT nombre FROM #n) AND x.[No_ Campo] IN (7, 50007) ORDER BY 1, x.[No_ Línea];
COMMIT;
