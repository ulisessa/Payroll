/* PRODUCCIÓN DEL LANGOSTINO: FUENTES POR CLASIFICACIÓN CORREGIDAS Y, PARA QUIEN NO TERMINA LA MAREA, LECTURA DEL DIARIO DE A BORDO.
   Decisión del usuario (15/10/2026): se corrigen las fuentes PROD_KN_ y PROD_KB_ existentes y los conceptos de producción leen el diario cuando la asignación no cubre la marea.
   1. Fuentes existentes (se corrige el filtro del ítem, campo 4, a LTBP-*-<clasificación>-*: sin serie ni presentación):
        PROD_KN_L1..L6, C1, C2, C3, CR   (peso neto, la que valúa)   PROD_KB_L1, L2, L3, C1, C2, CR   (peso bruto)
      Antes: PROD_KN_L2 filtraba AA23-L3 y PROD_KN_L3 AA22-L2 (cruzadas); L4, L5, L6 y C3 apuntaban a ítems inexistentes (AA23-L4, AA23-L5, AA23-L6, AB22-C3).
      PROD_KB_LANG_COLA filtraba el ítem con 'L-COLA' (es una subfamilia, campo 50002): pasa al 50002.
   2. Fuente nueva DIARIO_KN_LAN_L6 (las demás están en scripts/FuentesDiarioLangostino.sql).
   3. Conceptos 1393, 2403, 2413, 2423, 2433, 2443, 2453, 2463, 2473, 2483 y 2499: vigencia nueva 2026-02-02 con cada PROD_KN_<clase> reemplazado por
        IF(MAREA_COMPLETA, PROD_KN_<clase>, DIARIO_KN_LAN_<clase>)
      (la marea completa se paga por descarga; la asignación que se baja o sube a mitad de marea, por el diario de su ventana), como el calamar con DIARIO_KN_CAL_*.
   4. Concepto 2498: vigencia nueva 2026-02-02 con el mismo reemplazo en la rama de tangonero, y la condición del devengado de baja sin TIPOACTIVIDAD = 1
      (TIPO_LIQ = 'CIERRE_MAREA' OR BAJA_EN_COBERTURA > 0): la baja a mitad de marea vale también para tangoneros.
   Todas las vigencias anteriores se cierran el 2026-02-01 (la del 2498, que arrancaba el 2/1, también). Enero no cambia.
   Sin mareas de tangoneros en enero ni febrero de 2026 no hay contra qué comparar: se verifica con el primer cierre.
   Rollback: borrar las filas 2026-02-02 de esos conceptos, reabrir las anteriores (Vigencia Hasta = 1753-01-01), borrar DIARIO_KN_LAN_L6 y volver a poner
   en los filtros del campo 4 los ítems viejos (PROD_KN_L2 AA23-L3, PROD_KN_L3 AA22-L2, L4 AA23-L4, L5 AA23-L5, L6 AA23-L6, C3 AB22-C3, KB_LANG_COLA L-COLA).
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- 1. Filtros del ítem por clasificación
UPDATE x SET [Filtro Valor] = N'LTBP-*-' + SUBSTRING(x.[Nombre Variable], 9, 2) + N'-*'
FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
WHERE x.[No_ Campo] = 4 AND x.[Nombre Variable] IN (N'PROD_KN_L1', N'PROD_KN_L2', N'PROD_KN_L3', N'PROD_KN_L4', N'PROD_KN_L5', N'PROD_KN_L6', N'PROD_KN_C1', N'PROD_KN_C2', N'PROD_KN_C3', N'PROD_KN_CR',
                                                     N'PROD_KB_L1', N'PROD_KB_L2', N'PROD_KB_L3', N'PROD_KB_C1', N'PROD_KB_C2', N'PROD_KB_CR');
SELECT @@ROWCOUNT AS Filtros_corregidos_esperado_16;
UPDATE dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [No_ Campo] = 50002 WHERE [Nombre Variable] = N'PROD_KB_LANG_COLA' AND [No_ Campo] = 4 AND [Filtro Valor] = N'L-COLA';
SELECT @@ROWCOUNT AS KB_LANG_COLA_esperado_1;
SELECT x.[Nombre Variable] n, x.[Filtro Valor] v FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Campo] = 4 AND (x.[Nombre Variable] LIKE N'PROD_KN[_]%' OR x.[Nombre Variable] LIKE N'PROD_KB[_]%') AND x.[Nombre Variable] NOT LIKE N'%LAN%' ORDER BY 1;

-- 2. DIARIO_KN_LAN_L6 (molde DIARIO_KN_LAN_L5)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = N'DIARIO_KN_LAN_L6')
BEGIN
  SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = N'DIARIO_KN_LAN_L5';
  UPDATE #f SET [Nombre Variable] = N'DIARIO_KN_LAN_L6', [Descripción] = N'Kilos del diario de a bordo de langostino L6 en la ventana de la asignación', [$systemId] = NEWID();
  DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f');
  INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES
   (N'DIARIO_KN_LAN_L6', 16, N'{JOB_NO}'), (N'DIARIO_KN_LAN_L6', 1, N'{ASIG_DESDE}..{ASIG_HASTA}'), (N'DIARIO_KN_LAN_L6', 7, N'LTBP-*-L6-*');
END

-- 3 y 4. Conceptos: vigencia nueva 2026-02-02
CREATE TABLE #k (cod nvarchar(20) COLLATE DATABASE_DEFAULT, base date);
INSERT #k VALUES (N'1393', '20260101'), (N'2403', '20260101'), (N'2413', '20260101'), (N'2423', '20260101'), (N'2433', '20260101'), (N'2443', '20260101'),
                 (N'2453', '20260101'), (N'2463', '20260101'), (N'2473', '20260101'), (N'2483', '20260101'), (N'2499', '20260101'), (N'2498', '20260201');
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260202'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   WHEN N'Condición' THEN N'@cond'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cod nvarchar(20), @base date, @f nvarchar(max), @cond nvarchar(max), @sql nvarchar(max);
DECLARE cur2 CURSOR FOR SELECT cod, base FROM #k;
OPEN cur2; FETCH cur2 INTO @cod, @base;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = @cod AND [Vigencia Desde] = '20260202')
    BEGIN
        SELECT @f = [Fórmula], @cond = [Condición] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = @cod AND [Vigencia Desde] = @base;
        DECLARE @k int = 0;
        DECLARE @clases TABLE (c nvarchar(2));
        DELETE FROM @clases; INSERT @clases VALUES (N'L1'), (N'L2'), (N'L3'), (N'L4'), (N'L5'), (N'L6'), (N'C1'), (N'C2'), (N'C3'), (N'CR');
        DECLARE @c nvarchar(2);
        DECLARE cur3 CURSOR FOR SELECT c FROM @clases;
        OPEN cur3; FETCH cur3 INTO @c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @f = REPLACE(@f, N'PROD_KN_' + @c, N'IF(MAREA_COMPLETA, PROD_KN_' + @c + N', DIARIO_KN_LAN_' + @c + N')');
            FETCH cur3 INTO @c;
        END
        CLOSE cur3; DEALLOCATE cur3;
        IF @cod = N'2498' SET @cond = N'TIPO_LIQ = ''CIERRE_MAREA'' OR BAJA_EN_COBERTURA > 0';
        SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=@base;';
        EXEC sp_executesql @sql, N'@f nvarchar(max), @cond nvarchar(max), @cod nvarchar(20), @base date', @f = @f, @cond = @cond, @cod = @cod, @base = @base;
        UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta] = '20260201', [$systemModifiedAt] = SYSUTCDATETIME()
        WHERE [Código] = @cod AND [Vigencia Desde] = @base AND [Vigencia Hasta] = '17530101';
    END
    FETCH cur2 INTO @cod, @base;
END
CLOSE cur2; DEALLOCATE cur2;
SELECT [Código], CONVERT(varchar(10), [Vigencia Desde], 120) d, CONVERT(varchar(10), [Vigencia Hasta], 120) h, LEN([Fórmula]) len_f, LEFT(REPLACE([Condición], CHAR(10), N' '), 70) cond
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (SELECT cod FROM #k) AND [Vigencia Desde] >= '20260101' ORDER BY 1, 2;
SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'2403' AND [Vigencia Desde] = '20260202';
COMMIT;
