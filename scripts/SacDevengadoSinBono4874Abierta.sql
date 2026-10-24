/* CORRECCIÓN DE SacDevengadoSinBono4874Marzo.sql: LA EXCLUSIÓN DEL 4874 NO NECESITA SER DE UN SOLO MES.
   Aquel script dejó 4750 y 4754 con la fórmula que resta #4874 sólo del 1/3 al 31/3, y la de febrero desde el 1/4, bajo la idea de que una referencia # a un concepto sin vigencia da error. No es así: ResolveConceptoCalculado
   (Cod50015) busca el concepto con Vigencia Desde <= fecha de cálculo y no mira Vigencia Hasta; sólo falla si el concepto no existía todavía (antes del 1/3 para el 4874). Si el concepto no corrió en la liquidación, la referencia vale 0.
   Por lo tanto la fórmula con "- #4874" sirve desde el 1/3 en adelante, con o sin bono.
   Cambio, para 4750 y 4754: la vigencia del 1/3 pasa a abierta (Vigencia Hasta 1753-01-01) y se borra la del 1/4 (copia de la de febrero, creada por el script anterior, sin liquidaciones calculadas con ella).
   Rollback: volver Vigencia Hasta del 1/3 a 2026-03-31 y reinsertar la fila del 1/4 con la fórmula de febrero.
   Después: reiniciar el servicio (recalcular marzo de los 12 empleados con 4874 sigue pendiente). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DELETE FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4750',N'4754') AND [Vigencia Desde]='20260401';
SELECT @@ROWCOUNT AS Borradas_esperado_2;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='17530101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN (N'4750',N'4754') AND [Vigencia Desde]='20260301' AND [Vigencia Hasta]='20260331';
SELECT @@ROWCOUNT AS Abiertas_esperado_2;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'#4874','')))/5 AS con_4874 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4750',N'4754') ORDER BY 1,2;
COMMIT;
