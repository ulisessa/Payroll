/*
    ¿ESTÁ CORRIENDO EL BUILD NUEVO?

    Prueba directa, sin depender de la metadata del servidor: se busca en SQL una COLUMNA que
    sólo existe en el código nuevo. Si la columna está, la extensión con esos cambios se publicó
    y se sincronizó el esquema. Si no está, no se publicó — y eso explica que el OnModify de
    Concepto Liquidación no registre en el historial.

    Los campos elegidos son los dos que se agregaron a Config. Recursos Humanos en esta tanda
    (TabExt52001): "Cód. Concepto Neto Garantizado" y "Cód. Acum. Haberes Gravados".

    Sólo LEE.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';

-- 1. LA PRUEBA. Los campos de una tableextension viven en una tabla aparte, con el GUID de la
--    extensión, así que se busca la columna en cualquier tabla de Human Resources Setup.
SELECT t.name AS Tabla,
       MAX(CASE WHEN c.name LIKE N'C_d_ Concepto Neto Garantizado%'   THEN 1 ELSE 0 END) AS TieneConceptoNetoGarantizado,
       MAX(CASE WHEN c.name LIKE N'C_d_ Acum_ Haberes Gravados%' THEN 1 ELSE 0 END) AS TieneAcumHaberesGravados
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name LIKE @Empresa + N'$Human Resources Setup%'
GROUP BY t.name;

-- Veredicto en una línea.
SELECT CASE WHEN EXISTS (
            SELECT 1 FROM sys.tables t
            JOIN sys.columns c ON c.object_id = t.object_id
            WHERE t.name LIKE @Empresa + N'$Human Resources Setup%'
              AND c.name LIKE N'C_d_ Concepto Neto Garantizado%')
       THEN N'BUILD NUEVO PUBLICADO - el campo existe. El problema del historial es otro.'
       ELSE N'BUILD NUEVO **NO** PUBLICADO - el campo no existe. Eso explica el historial.'
       END AS Veredicto;
GO

-- 2. ¿La consulta vacía de objetos significaba algo? Cuántas filas tiene esa tabla en total.
--    Si da 0 o sólo cubre algunas apps, "no encontré los objetos" no era evidencia de nada.
SELECT COUNT(*) AS FilasTotales,
       COUNT(DISTINCT [App Package ID]) AS AppsConMetadata
FROM [dbo].[NAV App Object Metadata];

SELECT TOP 20 [App Package ID], COUNT(*) AS Objetos
FROM [dbo].[NAV App Object Metadata]
GROUP BY [App Package ID]
ORDER BY COUNT(*) DESC;
GO

-- 3. La extensión "Designer_..." está instalada en alcance Desarrollo (Published As = 2).
--    La crea el Diseñador en cliente. Conviene saber qué objetos toca: si toca alguno de los
--    nuestros, se superpone al publicado.
SELECT [Name], [Publisher], [Version Major], [Version Minor], [Version Build], [Version Revision],
       [Published As], [Package ID]
FROM [dbo].[NAV App Installed App]
WHERE [Published As] <> 0
ORDER BY [Name];
GO
