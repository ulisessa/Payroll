/* 1023 (FERIADO) EN LA REGULAR: LA ANTIGÜEDAD DE LOS DÍAS DE FRANCO Y ÓRDENES NO ENTRA EN LA BASE (22/10/2026). Los 24 REGULAR de abril con 1023: los 16 sin días de franco/órdenes en el mes coinciden con Meta4
   al centavo y los 7 con ellos difieren (00406, 00794, 04001, 04347, 04542, 04672, 04710). Meta4 resta de la base del precio del feriado #1053 x (días de franco [+ órdenes]) / días de la antigüedad: 00406 resta
   225.000 x 8/30 = 60.000 (precio 67.500 = (1.545.000 - 60.000)/22); 00794 resta 37.500 x 1/5; 04710 resta 72.000 x 19/30 (9 de franco + 10 de órdenes). La fórmula ya hacía esa resta en LIQ_FINAL (con los días de
   franco); acá se extiende a REGULAR, sumando los días de órdenes al numerador. CIERRE_MAREA sigue sin restar. Se edita la vigencia del 1/4/2026, que es de este mes.
   Rollback: devolver las dos reemplazos (ver abajo) o copiar la fórmula guardada en la tabla temporal del script.
   Después: reiniciar el servicio y recalcular la REGULAR de abril de los 7 y verificar que los otros 17 no cambien. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1023' AND [Vigencia Desde]='20260401' AND [Fórmula] LIKE N'%DIAS_ORD_PERIODO, 0)) /%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
   SET [Fórmula] = REPLACE(REPLACE([Fórmula],
        N'TIPO_LIQ = ''LIQ_FINAL'',', N'TIPO_LIQ = ''LIQ_FINAL'' OR TIPO_LIQ = ''REGULAR'','),
        N'#1053 * DIAS_FRANCOS_PERIODO /', N'#1053 * (DIAS_FRANCOS_PERIODO + IF(TIPO_LIQ = ''REGULAR'', DIAS_ORD_PERIODO, 0)) /'),
       [$systemModifiedAt] = SYSUTCDATETIME()
 WHERE [Código]='1023' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101'
   AND [Fórmula] LIKE N'%TIPO_LIQ = ''LIQ_FINAL'',%' AND [Fórmula] LIKE N'%#1053 * DIAS_FRANCOS_PERIODO /%';
SELECT @@ROWCOUNT AS actualizadas_esperado_1;
SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1023' AND [Vigencia Desde]='20260401';
COMMIT;
