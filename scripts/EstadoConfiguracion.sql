/*
    ¿DÓNDE ESTOY PARADO? — estado de la configuración del motor de liquidación

    Correr después de restaurar un backup, para saber qué falta reaplicar en vez de suponerlo.
    Sólo LEE, no modifica nada.

    Cada bloque imprime el valor ESPERADO al lado del real.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';
DECLARE @sql nvarchar(max);
DECLARE @TCon sysname, @TFrac sysname, @TFil sysname, @TFte sysname, @TPar sysname, @THR sysname;

SELECT @TCon  = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Concepto Liquidaci_n$%';
SELECT @TFrac = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Fracci_n Acumulador$%';
SELECT @TFil  = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Filtro Fuente Datos Liq%';
SELECT @TFte  = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Fuente Datos Liquidaci%';
SELECT @TPar  = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Par_metro Vigente$%';
-- Los campos de una tableextension viven en una tabla aparte. El nombre de columna NO se escribe
-- a mano: BC le agrega sufijos y no siempre convierte el punto igual, así que se busca con LIKE
-- ("_" es comodín de un carácter y cubre el punto) y después se usa el nombre real que devuelva.
DECLARE @ColConcepto sysname, @ColAcum sysname;

SELECT TOP 1 @THR = QUOTENAME(t.name), @ColConcepto = QUOTENAME(c.name)
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name LIKE @Empresa + N'$Human Resources Setup%'
  AND c.name LIKE N'C_d_ Concepto Neto Garantizado%';

-- Se busca igual que la de arriba, uniendo sys.tables con sys.columns. NO por object_id derivado
-- de @THR: el nombre lleva corchetes y "$", y armarlo de vuelta con REPLACE + PARSENAME devuelve
-- un nombre inválido, OBJECT_ID da NULL y la búsqueda no mira ninguna tabla — sin error, sólo un
-- NULL que se lee como "el campo no existe".
SELECT TOP 1 @ColAcum = QUOTENAME(c.name)
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name LIKE @Empresa + N'$Human Resources Setup%'
  AND c.name LIKE N'C_d_ Acum_ Haberes Gravados%';

SELECT @TCon AS Conceptos, @TFrac AS Fracciones, @TFil AS Filtros,
       @TFte AS Fuentes, @TPar AS Parametros, @THR AS SetupExtendido,
       @ColConcepto AS ColumnaConcepto, @ColAcum AS ColumnaAcumulador;

-------------------------------------------------------------------------------
-- 1. ¿Está publicada la versión de la extensión con los campos nuevos?
-------------------------------------------------------------------------------
IF @THR IS NULL
    SELECT N'FALTA PUBLICAR' AS Extension,
           N'No existe el campo "Cód. Concepto Neto Garantizado" en ninguna tabla de Human Resources Setup. Publicar la extensión primero: sin eso no se puede configurar el grossing-up.' AS Detalle;
ELSE
BEGIN
    SET @sql = N'
    SELECT N''publicada'' AS Extension,
           ' + @ColConcepto + N' AS ConceptoNetoGarantizado, N''NETO_GARANT'' AS Esperado,
           ' + ISNULL(@ColAcum, N'NULL') + N' AS AcumHaberesGravados, N''BASE_IG4'' AS Esperado2
    FROM [dbo].' + @THR + N';';
    EXEC sp_executesql @sql;
END;

-------------------------------------------------------------------------------
-- 2. Concepto NETO_GARANT (objetivo del grossing-up)
-------------------------------------------------------------------------------
SET @sql = N'
SELECT [Código], [Vigencia Desde], [Tipo Concepto] AS Tipo, N''6 = Informativo'' AS TipoEsperado,
       [Activo], [Orden Cálculo], [Fórmula],
       N''NETO_GU * (1 + DIAS_VAC_INICIO / 150)'' AS FormulaEsperada
FROM [dbo].' + @TCon + N' WHERE [Código] = N''NETO_GARANT'';';
EXEC sp_executesql @sql;

SET @sql = N'SELECT COUNT(*) AS ConceptosTotales,
                    SUM(CASE WHEN [Código] = N''NETO_GARANT'' THEN 1 ELSE 0 END) AS TieneNetoGarant
             FROM [dbo].' + @TCon + N';';
EXEC sp_executesql @sql;

-------------------------------------------------------------------------------
-- 3. Filtros de Fuente Datos. Esperado: 76 filas, y ninguna fuente activa sin filtros.
--    Si esto da 0, toda fuente activa lee su tabla entera y liquidar tarda minutos.
-------------------------------------------------------------------------------
SET @sql = N'SELECT COUNT(*) AS FilasFiltro, 76 AS Esperado FROM [dbo].' + @TFil + N';';
EXEC sp_executesql @sql;

SET @sql = N'
SELECT f.[Nombre Variable] AS FuenteActivaSinFiltros, f.[Id_ Tabla]
FROM [dbo].' + @TFte + N' f
LEFT JOIN [dbo].' + @TFil + N' x ON x.[Nombre Variable] = f.[Nombre Variable]
WHERE f.[Activo] = 1 AND x.[Nombre Variable] IS NULL;';
EXEC sp_executesql @sql;

-------------------------------------------------------------------------------
-- 4. Fracción Acumulador. Esperado: 1208 filas, BASE_IG4 123.
-------------------------------------------------------------------------------
SET @sql = N'SELECT COUNT(*) AS FilasFraccion, 1208 AS Esperado FROM [dbo].' + @TFrac + N';';
EXEC sp_executesql @sql;

SET @sql = N'SELECT [Cód_ Acumulador], COUNT(*) AS Filas FROM [dbo].' + @TFrac + N'
             WHERE [Cód_ Acumulador] IN (N''BASE_IG4'',N''BASE_EXT_IG4'',N''BASE_HAB_IG4'')
             GROUP BY [Cód_ Acumulador] ORDER BY 1;';
EXEC sp_executesql @sql;

-- La doble contabilización: tiene que devolver CERO filas.
SET @sql = N'
SELECT a.[Cód_ Concepto] AS EnBaseIG4_yTambien_EnBaseEXTIG4
FROM [dbo].' + @TFrac + N' a
WHERE a.[Cód_ Acumulador] = N''BASE_IG4''
  AND EXISTS (SELECT 1 FROM [dbo].' + @TFrac + N' b
               WHERE b.[Cód_ Concepto] = a.[Cód_ Concepto] AND b.[Cód_ Acumulador] = N''BASE_EXT_IG4'');';
EXEC sp_executesql @sql;

-- Fracciones huérfanas (concepto o acumulador inexistente): tiene que devolver CERO filas.
SET @sql = N'
SELECT DISTINCT f.[Cód_ Concepto], f.[Cód_ Acumulador]
FROM [dbo].' + @TFrac + N' f
WHERE NOT EXISTS (SELECT 1 FROM [dbo].' + @TCon + N' c WHERE c.[Código] = f.[Cód_ Concepto])
   OR NOT EXISTS (SELECT 1 FROM [dbo].' + @TCon + N' a WHERE a.[Código] = f.[Cód_ Acumulador]);';
EXEC sp_executesql @sql;

-- "Invertir Signo" no viaja en el ConfigPackage: si todo está en 0, quedó por revisar a mano.
SET @sql = N'SELECT COUNT(*) AS FraccionesConInvertirSigno FROM [dbo].' + @TFrac + N'
             WHERE [Invertir Signo] = 1;';
EXEC sp_executesql @sql;

-------------------------------------------------------------------------------
-- 5. Parámetros de grossing-up
-------------------------------------------------------------------------------
SET @sql = N'SELECT [Cód_ Parámetro], [Vigencia Desde], [Valor], [Moneda], [Cód_ Parámetro Base]
             FROM [dbo].' + @TPar + N' WHERE [Cód_ Parámetro] LIKE N''NETO_GU%'' ORDER BY 1,2;';
EXEC sp_executesql @sql;

SET @sql = N'SELECT COUNT(*) AS ParametrosVigentes FROM [dbo].' + @TPar + N';';
EXEC sp_executesql @sql;

-------------------------------------------------------------------------------
-- 6. Conceptos activos sin fórmula: calculan cero en silencio.
-------------------------------------------------------------------------------
SET @sql = N'SELECT COUNT(*) AS ActivosSinFormula FROM [dbo].' + @TCon + N'
             WHERE [Activo] = 1 AND ISNULL([Fórmula],N'''') = N'''' AND [Es Acumulador] = 0;';
EXEC sp_executesql @sql;
GO
