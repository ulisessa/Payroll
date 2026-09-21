/*
    Borra las filas de "Fracción Acumulador" que apuntan a conceptos que ya no existen.

    Origen: hasta la versión 1.0.0.374 el OnDelete de "Concepto Liquidación" no limpiaba el
    fraccionamiento. Al borrar un acumulador (BASE_SS, BASE_OS) quedaron cientos de filas apuntando a
    un código inexistente, que siguen saliendo en las exportaciones y en la subpágina de cada concepto
    como si la configuración estuviera viva. Desde 374 el borrado limpia solo; esto es para lo que ya
    quedó.

    ANTES DE CORRER
      1. Backup. Esto borra filas y no hay undo.
      2. Con nadie liquidando: Business Central cachea configuración por sesión.
      3. Correr los pasos 1 y 2 y MIRAR la salida. El paso 3 borra exactamente eso.
      4. Después de borrar, reiniciar el service tier para vaciar la caché.

    ESTO NO ALCANZA. Una fórmula que nombra un acumulador borrado resuelve la variable como CERO sin
    dar error: hay que corregir 4751, 4752, 4753 e IMPO_CNT_SS aparte. El paso 4 los lista.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

------------------------------------------------------------------------------------------------
-- 1. Detalle: qué filas sobran y por qué
--    El código se compara contra TODAS las vigencias: un concepto existe mientras le quede al menos
--    una versión, así que alcanza con que el código aparezca una vez.
------------------------------------------------------------------------------------------------
SELECT
    f.[Cód_ Acumulador]  AS Acumulador,
    f.[Cód_ Concepto]    AS Concepto,
    f.[Vigencia Desde]   AS VigenciaFraccion,
    CASE
        WHEN a.[Código] IS NULL AND c.[Código] IS NULL THEN 'No existen ni el acumulador ni el concepto'
        WHEN a.[Código] IS NULL                        THEN 'No existe el acumulador'
        ELSE                                                'No existe el concepto que aporta'
    END AS Motivo
FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) a
       ON a.[Código] = f.[Cód_ Acumulador]
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) c
       ON c.[Código] = f.[Cód_ Concepto]
WHERE a.[Código] IS NULL OR c.[Código] IS NULL
ORDER BY Motivo, Acumulador, Concepto;

------------------------------------------------------------------------------------------------
-- 2. Resumen por código inexistente — es el número que hay que reconocer antes de borrar
------------------------------------------------------------------------------------------------
SELECT
    CASE WHEN a.[Código] IS NULL THEN f.[Cód_ Acumulador] ELSE f.[Cód_ Concepto] END AS CodigoInexistente,
    CASE WHEN a.[Código] IS NULL THEN 'acumulador' ELSE 'concepto que aporta'      END AS Rol,
    COUNT(*)                                                                          AS FilasABorrar
FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) a
       ON a.[Código] = f.[Cód_ Acumulador]
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) c
       ON c.[Código] = f.[Cód_ Concepto]
WHERE a.[Código] IS NULL OR c.[Código] IS NULL
GROUP BY
    CASE WHEN a.[Código] IS NULL THEN f.[Cód_ Acumulador] ELSE f.[Cód_ Concepto] END,
    CASE WHEN a.[Código] IS NULL THEN 'acumulador' ELSE 'concepto que aporta'      END
ORDER BY FilasABorrar DESC;

------------------------------------------------------------------------------------------------
-- 3. BORRADO — descomentar recién después de revisar los pasos 1 y 2
------------------------------------------------------------------------------------------------
/*
BEGIN TRANSACTION;

DELETE f
FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) a
       ON a.[Código] = f.[Cód_ Acumulador]
LEFT JOIN (SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) c
       ON c.[Código] = f.[Cód_ Concepto]
WHERE a.[Código] IS NULL OR c.[Código] IS NULL;

PRINT 'Filas borradas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- Si el número coincide con el paso 2:   COMMIT TRANSACTION;
-- Si no coincide:                        ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 4. Lo que el borrado NO arregla: fórmulas y condiciones que nombran un concepto inexistente.
--    Es una búsqueda por texto, así que puede traer coincidencias parciales — BASE_SS aparece
--    dentro de BASE_SS_TRAB. Sirve para saber dónde mirar, no para decidir sola.
------------------------------------------------------------------------------------------------
WITH Existentes AS (
    SELECT DISTINCT [Código] FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
),
Borrados AS (
    SELECT DISTINCT f.[Cód_ Acumulador] AS Código
    FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE NOT EXISTS (SELECT 1 FROM Existentes e WHERE e.[Código] = f.[Cód_ Acumulador])
)
SELECT
    c.[Código]         AS ConceptoQueLoUsa,
    c.[Vigencia Desde] AS Vigencia,
    b.[Código]         AS CodigoInexistente,
    c.[Fórmula],
    c.[Condición]
FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
CROSS JOIN Borrados b
WHERE c.[Fórmula]   LIKE '%' + b.[Código] + '%'
   OR c.[Condición] LIKE '%' + b.[Código] + '%'
ORDER BY b.[Código], c.[Código];
