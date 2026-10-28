/* SAC DE EGRESO DE LOS ADMINISTRATIVOS (CONVENIO FA): MITAD DE LA MEJOR REMUNERACIÓN MENSUAL DEL SEMESTRE x DÍAS DE ALTA / 180 (REGLA DE META4).
   Fórmula original (Oracle, 16/10/2026): 3813 = 3811 x 3605 para quien no es MR / OF / FE; 3811 = días calendario de alta del semestre / 180 (acotado a 1); 3605 (PR_AGUINALDO) para el tipo AD
   (administrativos) es max(mejor total mensual de los 6 meses, total del mes) / 2. El "total" es TOTAL_P_SAC (3600): la suma de los haberes antes de descontar ausencias.
   90331 (FA35, alta 5/1, baja 6/2, sueldo 1.155.795): 1.155.795 / 2 x 33 / 180 = 105.947,88 (Meta4). BC usaba lo acumulado / 12 = 102.737,33 (el día 31 de enero no se paga: -3.210). El resto de las
   finales de enero y febrero (MR, OF, un jornal 372/04) coincide con la regla de BC y no se toca.
   Cambio:
     1. Variable de sistema MEJOR_REM_SAC_SEMESTRE: Cód. Cálculo MEJOR_MES_ACUM_SEMESTRE (nuevo, Cod50016), Cód. Acumulador BASE_SAC y Cód. Concepto 4703 (ausencias): para cada mes del semestre,
        BASE_SAC menos el 4703 (que resta) = la remuneración sin la ausencia; la variable es el máximo de esos meses sin contar la liquidación en curso.
     2. 3813: vigencia nueva 2026-01-02 (la 2026-01-01 se cierra el mismo día): para CONVENIO = 'FA' en LIQ_FINAL,
          ROUND(MAX(MEJOR_REM_SAC_SEMESTRE, BASE_SAC - #4703) / 2 * MIN(1, DIAS_ALTA_SEMESTRE / 180), PRECISION_REDONDEO);   en cualquier otro caso, la fórmula de siempre.
   Supuesto que falta confirmar con más casos: que TODO el convenio FA sea el tipo AD de Meta4 (hoy hay un solo final FA para comprobarlo).
   Rollback: borrar la vigencia 2026-01-02 del 3813 (con fracciones) y la variable, y reabrir la 2026-01-01 (Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular la final de febrero de 90331. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @V nvarchar(300) = N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'3813' AND [Vigencia Desde]='20260102')
 OR EXISTS (SELECT 1 FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'MEJOR_REM_SAC_SEMESTRE')
BEGIN PRINT 'Ya existe la vigencia 2026-01-02 del 3813 o la variable'; ROLLBACK; RETURN; END;

-- 1. Variable de sistema (molde MES_BASE_SINDICAL)
DECLARE @vc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @vs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Nombre Variable' THEN N'N''MEJOR_REM_SAC_SEMESTRE''' WHEN N'Cód_ Cálculo' THEN N'N''MEJOR_MES_ACUM_SEMESTRE'''
    WHEN N'Descripción' THEN N'N''Mejor remuneración mensual del semestre (BASE_SAC sin las ausencias) sin la liquidación en curso''' WHEN N'Cód_ Acumulador' THEN N'N''BASE_SAC''' WHEN N'Cód_ Concepto' THEN N'N''4703'''
    ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @V + N' (' + @vc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @vs + @sys + N' FROM ' + @V + N' WHERE [Nombre Variable]=N''MES_BASE_SINDICAL'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Variable_esperado_1;

-- 2. 3813
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'3813' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101');
IF @old IS NULL BEGIN PRINT 'Falta la vigencia abierta 2026-01-01 del 3813'; ROLLBACK; RETURN; END;
DECLARE @fnew nvarchar(max) = N'IF(CONVENIO = ''FA'' AND TIPO_LIQ = ''LIQ_FINAL'', ROUND(MAX(MEJOR_REM_SAC_SEMESTRE, BASE_SAC - #4703) / 2 * MIN(1, DIAS_ALTA_SEMESTRE / 180), PRECISION_REDONDEO), ' + @old + N')';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''3813'' AND [Vigencia Desde]=''20260101'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@fnew nvarchar(max)', @fnew=@fnew;
SELECT @@ROWCOUNT AS Vigencia_3813_esperado_1;
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''3813'' AND [Vigencia Desde]=''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fracciones_3813;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'3813' AND [Vigencia Desde]='20260101';
SELECT [Código],[Vigencia Desde],[Vigencia Hasta],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'3813' AND [Vigencia Desde]>='20260101' ORDER BY 2;
SELECT [Nombre Variable],[Cód_ Cálculo],[Cód_ Acumulador],[Cód_ Concepto],Activo FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'MEJOR_REM_SAC_SEMESTRE';
COMMIT;
