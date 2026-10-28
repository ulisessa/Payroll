/* 2013: SE RESTA EL SUBTOTAL DE HABERES GOZADOS (1990 DE META4), NO TODO EL REMUNERATIVO.
   Fórmula de Meta4 (explicada por el usuario, 15/10/2026): G = asegurado de puerto x TC comprador x días / 30 (x 1,4 cuando el indicador 2041 = 1);
   H = TOT_HAB_GZDO (1990); 2013 = MAX(0, G - H) en poteros. TOT_HAB_GZDO de 04582, 03196 y 00794 en febrero = 1.403.160, 1.262.250 y 2.025.000:
   es el sueldo de puerto (1083) + el feriado (1023) + la antigüedad (1053) y NO incluye el sueldo a órdenes (1073 = 45.000 en 04582).
   BC restaba REMUNERATIVO_BRUTO y por eso 04582 quedaba 45.000 abajo en el 2013 y 6.750 en el 2073 (15%).
   Cambio: vigencia nueva 2026-02-02 con "- (#1083 + #1023 + #1053)" en lugar de "- (REMUNERATIVO_BRUTO)"; la 2026-02-01 se cierra el 1/2.
   Queda pendiente el factor 1,4 por indicador 2041 (hoy lo aproxima TIPOACTIVIDAD = 1).
   Rollback: borrar la vigencia 2026-02-02 del 2013 y reabrir la 2026-02-01 (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular la regular de febrero de 04582. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260202')
BEGIN PRINT 'Ya existe la vigencia 2026-02-02 del 2013'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260201');
DECLARE @quitar nvarchar(100) = N'- (REMUNERATIVO_BRUTO)';
IF CHARINDEX(@quitar, @old) = 0 BEGIN PRINT 'No se encontró - (REMUNERATIVO_BRUTO)'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = REPLACE(@old, @quitar, N'- (#1083 + #1023 + #1053)');
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260202'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''2013'' AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260201', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'2013' AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' ORDER BY 1;
COMMIT;
