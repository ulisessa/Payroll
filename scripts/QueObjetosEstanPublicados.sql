/*
    ¿QUÉ ESTÁ REALMENTE INSTALADO EN BC?

    El código fuente dice que Concepto Liquidación registra en el historial desde su OnModify, y
    la base dice que no registró. Cuando el código y el comportamiento no coinciden, hay que
    verificar la premisa: que el objeto que corre sea el que se compiló.

    Le pregunta a la metadata del servidor, no al repo. Sólo LEE.

    Los nombres de columna de las tablas de sistema cambian entre versiones, así que NINGUNO se
    escribe a mano: se leen de sys.columns y la consulta se arma con los que existan, salteando
    los blobs (la metadata compilada pesa y no aporta). Cada bloque va en su propio batch porque
    T-SQL parsea el batch entero antes de ejecutarlo: una columna inexistente aborta todo.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

-- 1. Qué tablas de sistema hay para preguntar, y qué columnas tiene cada una.
SELECT t.name AS Tabla, c.column_id AS Orden, c.name AS Columna, ty.name AS Tipo
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.name LIKE N'%NAV App Installed%'
   OR t.name LIKE N'%NAV App Object Metadata%'
ORDER BY t.name, c.column_id;
GO

-- 2. Extensiones instaladas, con su versión.
DECLARE @cols nvarchar(max), @sql nvarchar(max), @tabla sysname;

SELECT TOP 1 @tabla = name FROM sys.tables WHERE name LIKE N'%NAV App Installed App%';
IF @tabla IS NOT NULL
BEGIN
    SELECT @cols = STUFF((
        SELECT ',' + QUOTENAME(c.name)
        FROM sys.columns c
        JOIN sys.types ty ON ty.user_type_id = c.user_type_id
        WHERE c.object_id = OBJECT_ID('dbo.' + QUOTENAME(@tabla))
          AND ty.name NOT IN ('varbinary','image','binary','xml','text','ntext')
        ORDER BY c.column_id
        FOR XML PATH('')), 1, 1, '');

    SET @sql = N'SELECT ' + @cols + N' FROM [dbo].' + QUOTENAME(@tabla) + N';';
    EXEC sp_executesql @sql;
END
ELSE SELECT N'No se encontró la tabla de apps instaladas — mirar la lista del punto 1' AS Aviso;
GO

-- 3. Los objetos publicados que importan.
--    Esperado: Table 60007 (Concepto Liquidación), Table 110002 (Historial Fórmula Concepto),
--    Codeunit 50070 (Historial Fórmulas Liq.), Page 110004, Pages 50145 y 50107.
--    Si falta alguno, ahí está la explicación.
DECLARE @cols2 nvarchar(max), @sql2 nvarchar(max), @tabla2 sysname, @colId sysname;

SELECT TOP 1 @tabla2 = name FROM sys.tables WHERE name LIKE N'%NAV App Object Metadata%';
IF @tabla2 IS NOT NULL
BEGIN
    SELECT @cols2 = STUFF((
        SELECT ',' + QUOTENAME(c.name)
        FROM sys.columns c
        JOIN sys.types ty ON ty.user_type_id = c.user_type_id
        WHERE c.object_id = OBJECT_ID('dbo.' + QUOTENAME(@tabla2))
          AND ty.name NOT IN ('varbinary','image','binary','xml','text','ntext')
        ORDER BY c.column_id
        FOR XML PATH('')), 1, 1, '');

    -- La columna del ID de objeto también se descubre.
    SELECT TOP 1 @colId = c.name FROM sys.columns c
    WHERE c.object_id = OBJECT_ID('dbo.' + QUOTENAME(@tabla2))
      AND c.name LIKE N'%Object ID%';

    IF @colId IS NULL
        SELECT N'No se encontró una columna de Object ID — mirar la lista del punto 1' AS Aviso;
    ELSE
    BEGIN
        SET @sql2 = N'SELECT ' + @cols2 + N' FROM [dbo].' + QUOTENAME(@tabla2) +
                    N' WHERE ' + QUOTENAME(@colId) + N' IN (60007,110002,110004,50070,50145,50107)' +
                    N' ORDER BY ' + QUOTENAME(@colId) + N';';
        EXEC sp_executesql @sql2;
    END
END
ELSE SELECT N'No se encontró la tabla de metadata de objetos — mirar la lista del punto 1' AS Aviso;
GO
