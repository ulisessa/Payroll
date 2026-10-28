/* DEVENGO DE FRANCOS CON LA METODOLOGÍA DE META4 (paralelo, 13/10/2026).
   Meta4 devenga POR TRAMO MENSUAL y redondea cada tramo: la marea en curso a fin de mes devenga en esa
   corrida (REGULAR en Meta4, DEVENGADOS en BC) y el cierre devenga sólo lo que le toca de su mes.
   Base = DIAS_MAREA de la corrida (en 87 de 90 cierres de enero el devengo es ROUND(0,5 * DIAS_MAREA)),
   más un día por feriado a bordo del tramo. Sin marea: días de tierra que devengan + feriados de guardia.
   1. 1062: la base pasa de DIAS_ENROLAMIENTO (marea entera) a DIAS_MAREA (el tramo de esta liquidación),
      y se habilita en DEVENGADOS.
   2. COEF_FRANCOS_175/75 = 0,50: los oficiales no devengaban nada (el coeficiente no existía; Meta4
      aplica PORC_FRANCO_DEV = 50).
   Fórmula anterior del 1062:
     IF(DIAS_ENROLAMIENTO > 0, ROUND(COEF_FRANCOS * DIAS_ENROLAMIENTO, 1) + DIAS_FERIADOS_MAREA,
        ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA)
   Tipos anteriores: CIERRE_MAREA|LIQ_FINAL|REGULAR.
   Recalcular enero y febrero: cierres, devengados, regulares y finales. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'IF(
    DIAS_MAREA > 0,
    ROUND(COEF_FRANCOS * DIAS_MAREA, 1) + DIAS_FERIADOS_MAREA,
    ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA
)',
    [Tipos Liq_ Aplicables] = N'CIERRE_MAREA|LIQ_FINAL|REGULAR|DEVENGADOS',
    [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'1062' AND [Vigencia Desde] = '20260101' AND [Tipos Liq_ Aplicables] = N'CIERRE_MAREA|LIQ_FINAL|REGULAR';
SELECT @@ROWCOUNT AS Concepto1062_esperado_1;

DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
        WHEN N'Cód_ Parámetro' THEN N'N''COEF_FRANCOS_175/75'''
        WHEN N'Cód_ Convenio' THEN N'N''175/75'''
        WHEN N'Valor' THEN N'0.5'
        ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'IF NOT EXISTS (SELECT 1 FROM ' + @P + N' WHERE [Cód_ Parámetro] = N''COEF_FRANCOS_175/75'' AND [Vigencia Desde] = ''20260101'')
INSERT ' + @P + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @P + N' WHERE [Cód_ Parámetro] = N''COEF_FRANCOS_729/15'' AND [Vigencia Desde] = ''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Coef175_esperado_1;

SELECT [Cód_ Parámetro], [Cód_ Convenio], [Valor], [Vigencia Desde] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] = N'COEF_FRANCOS' ORDER BY 1;
COMMIT;
