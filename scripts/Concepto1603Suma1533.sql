/* 1603 (CATEGORÍA SUPERIOR) SOBRE EL ADICIONAL ART. 23 (22/10/2026). 04826 es el único con 1533 (336.600) y 1603 en abril: la base de Meta4 para el 1603 del cierre incluye el 1533 (169.470 = 336.600 + ... / 85 % - ...)
   y la de BC no (110.070): -59.400 = 336.600 x 15/85, que baja también el precio del feriado (1023 del cierre: 93.078 contra 98.243). Se agrega #1533 a las dos bases de la vigencia del 1/4/2026 (la de este mes).
   Rollback: sacar '#1533 + ' de las dos bases.
   Después: reiniciar el servicio y recalcular el cierre de 04826. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1603' AND [Vigencia Desde]='20260401' AND [Fórmula] LIKE N'%#1533%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
   SET [Fórmula] = REPLACE([Fórmula], N'(#1013 + #1043 + #1083 + #1543', N'(#1013 + #1043 + #1083 + #1533 + #1543'), [$systemModifiedAt] = SYSUTCDATETIME()
 WHERE [Código]='1603' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS esperado_1;
SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1603' AND [Vigencia Desde]='20260401';
COMMIT;
