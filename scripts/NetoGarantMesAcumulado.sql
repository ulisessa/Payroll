/* NETO ACORDADO DEL MES: LO QUE EL CIERRE PAGÓ DE MÁS SE DESCUENTA DEL OBJETIVO DE LA LIQUIDACIÓN SIGUIENTE.
   Meta4 (04724, febrero de 2026): el objetivo de neto de un oficial con neto pactado es del mes (12.750 USD x 1.370 x 0,70 / 30 x 28 días
   = 11.412.100). El cierre del 1 al 12/2 pagó 5.388.440 (neto 5.138.440 + anticipo 250.000) contra 4.873.050 de objetivo de sus 12 días, porque
   el premio 1534 ya lo superaba y el tapón 2003 no suma nada; el devengado del 13 al 28/2 pagó lo que faltaba, 6.004.710, no los 6.521.200 de
   sus 16 días. BC pagaba los 6.521.200 enteros: 516 mil de neto y 942.686 de bruto de más.
   Medido en las 33 liquidaciones con NETO_GARANT de enero y febrero de los siete oficiales de neto pactado: neto + exclusión - objetivo da 0 en todas
   (±10 pesos) menos en ese cierre (+515.390). La regla no toca a nadie más.
   Variable de sistema nueva EXCESO_NETO_GU_MES (Cod50016, sembrada en Cod50077): suma, de las liquidaciones ANTERIORES del mes con línea NETO_GARANT,
   (Neto a Pagar + exclusión - objetivo). NETO_GARANT, vigencia 2026-02-01, resta MAX(0, EXCESO_NETO_GU_MES) sólo cuando hay NETO_GU_MAREA.
   Hace falta publicar (código nuevo). Después: sembrar la variable (la siembra corre desde la página de variables de sistema; este script la
   inserta directo) y recalcular el devengado de 04724 (cierre primero ya está calculado; el devengado lee al cierre).
   Rollback: DELETE de la variable y de la fila 2026-02-01 de NETO_GARANT, y reabrir la vigencia anterior (Vigencia Hasta = 1753-01-01). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- 1. Variable de sistema (copia de SALDO_FRANCOS)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Cálculo]=N'EXCESO_NETO_GU_MES')
BEGIN
  SELECT * INTO #vs FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Cálculo]=N'SALDO_FRANCOS';
  UPDATE #vs SET [Cód_ Cálculo]=N'EXCESO_NETO_GU_MES', [Nombre Variable]=N'EXCESO_NETO_GU_MES', [Descripción]=N'Neto pagado de más sobre el objetivo en las liquidaciones anteriores del mes con grossing-up', [$systemId]=NEWID();
  DECLARE @cv nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  DECLARE @sqlv nvarchar(max) = N'INSERT dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cv + N') SELECT ' + @cv + N' FROM #vs';
  EXEC (@sqlv);
END
SELECT COUNT(*) AS Variable_esperado_1 FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Cálculo]=N'EXCESO_NETO_GU_MES';

-- 2. NETO_GARANT: vigencia nueva 2026-02-01
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'NETO_GARANT' AND [Vigencia Desde]='20260201')
BEGIN PRINT 'Ya existe la vigencia 2026-02-01'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'NETO_GARANT' AND [Vigencia Desde]='20260101');
DECLARE @f nvarchar(max) = @old + N'
    - IF(NETO_GU_MAREA > 0, MAX(0, EXCESO_NETO_GU_MES), 0)';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260201'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''NETO_GARANT'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'NETO_GARANT' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Tipos Liq_ Aplicables],[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'NETO_GARANT' ORDER BY 1;
COMMIT;
