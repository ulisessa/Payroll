/* 6000 (jubilación) y 6010 (Ley 19032) en VACACIONES. El 6003/6013 (vacaciones) y el 6030 (obra social) sí corren en
   Vacaciones, pero 6000 y 6010 no estaban en su lista de tipos. Una liquidación de Vacaciones puede traer un concepto
   de base ordinaria: 04096 tiene el 2043 (20.278,96) en BASE_SS_TRAB de su Vacaciones de enero y Meta4 le descuenta el
   11 % (2.230,69) y el 3 % (608,37) que BC no calculaba, las dos diferencias de su recibo. Con base 0 el resultado es 0.
   Corrige la vigencia 2026-01-01. Lista anterior: REGULAR|LIQ_FINAL|RELIQUIDACION|DEVENGADOS|CIERRE_MAREA.
   Después: reiniciar el servicio y recalcular la Vacaciones de enero de 04096. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Tipos Liq_ Aplicables] = N'REGULAR|VACACIONES|LIQ_FINAL|RELIQUIDACION|DEVENGADOS|CIERRE_MAREA', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] IN (N'6000', N'6010') AND [Vigencia Desde] = '20260101' AND [Tipos Liq_ Aplicables] = N'REGULAR|LIQ_FINAL|RELIQUIDACION|DEVENGADOS|CIERRE_MAREA';
SELECT @@ROWCOUNT AS esperado_2;
COMMIT;
