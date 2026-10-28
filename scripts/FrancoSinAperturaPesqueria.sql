/*
    VALOR_FRANCO SIN APERTURA POR PESQUERÍA (convenio 729/15), 13/10/2026.

    El 30% del franco de tangoneros estaba metido en el IMPORTE del parámetro (VALOR_FRANCO_LAN_729/15_*)
    y por eso en febrero, cuando Meta4 pasó a pagar el 100%, BC seguía pagando el 30%. El recorte vive en
    COEF_PESQUERIA (COEF_TANGONERO_729/15 = 0,30 desde 2026-01-01; el genérico en 1 desde 2026-02-01 lo
    pisa en febrero). Entonces:
      1. Se cargan los genéricos VALOR_FRANCO_729/15_<cat> copiando los _CAL (el 100%), sin sufijo.
      2. Se borran los _LAN y los _CAL de 729/15: sin ellos el motor cae al genérico.
      3. El 1063 multiplica siempre por #COEF_PESQUERIA (antes sólo en LIQ_FINAL).

    RESPALDO: respaldo-francos-20261013/ (los 90 parámetros en JSON y la fórmula anterior del 1063).
    Después de aplicar: reiniciar el service tier y recalcular enero y febrero.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
        WHEN N'Cód_ Parámetro' THEN N'REPLACE([Cód_ Parámetro], N''VALOR_FRANCO_CAL_'', N''VALOR_FRANCO_'')'
        WHEN N'Sufijo Atributo 1' THEN N'N'''''
        WHEN N'Notas' THEN N'N'''''
        ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @P + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @P + N' s WHERE s.[Cód_ Convenio] = N''729/15'' AND s.[Cód_ Parámetro] LIKE N''VALOR_FRANCO_CAL_%''
AND NOT EXISTS (SELECT 1 FROM ' + @P + N' g WHERE g.[Cód_ Parámetro] = REPLACE(s.[Cód_ Parámetro], N''VALOR_FRANCO_CAL_'', N''VALOR_FRANCO_'') AND g.[Vigencia Desde] = s.[Vigencia Desde]);';
EXEC (@sql);
SELECT @@ROWCOUNT AS Genericos_esperado_45;

DELETE FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Cód_ Convenio] = N'729/15' AND ([Cód_ Parámetro] LIKE N'VALOR_FRANCO_LAN_%' OR [Cód_ Parámetro] LIKE N'VALOR_FRANCO_CAL_%');
SELECT @@ROWCOUNT AS Borrados_esperado_90;

UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'ROUND(FILA_CANTIDAD * FILA_VALOR_FRANCO * #COEF_PESQUERIA, PRECISION_REDONDEO)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'1063' AND [Vigencia Desde] = '20260101';
SELECT @@ROWCOUNT AS Formula1063_esperado_1;

SELECT [Cód_ Parámetro], [Vigencia Desde], [Valor], [En Uso] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Cód_ Convenio] = N'729/15' AND [Cód_ Parámetro] LIKE N'VALOR_FRANCO%' AND [Cód_ Categoría] = N'MR04' ORDER BY 2;
COMMIT;
