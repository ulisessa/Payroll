/*
    LAS DOS MODIFICACIONES QUE EL CHANGE LOG SÍ REGISTRÓ

    BC registró dos cambios de Fórmula sobre 4743 a las 12:07 y nuestro historial ninguno.
    Esto muestra el valor viejo y el nuevo de cada una, completos, para ver qué hizo cada Modify.

    Lo que se busca: si la PRIMERA modificación ya llega con "valor viejo" = "valor nuevo", o si
    el valor viejo de la primera no es el texto original, entonces algo escribió la fila antes —y
    esa escritura previa es la que dejaría a xRec contaminado, haciendo que RegistrarModificacion
    salga por su primera guarda.

    Sólo LEE.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';
DECLARE @TLog sysname, @sql nvarchar(max);

SELECT TOP 1 @TLog = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Change Log Entry$%';

IF @TLog IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%Change Log%';
    RAISERROR(N'No se encontró Change Log Entry. Revisar la lista de arriba.',16,1);
    RETURN;
END;

SELECT @TLog AS TablaChangeLog;

-- Columnas disponibles, por si algún nombre no es el esperado. Se une por sys.tables y NO por un
-- object_id derivado de @TLog: ese nombre lleva corchetes y "$", y rearmarlo con REPLACE +
-- PARSENAME devuelve un nombre inválido, con lo cual OBJECT_ID da NULL y la grilla sale vacía
-- sin ningún error que lo explique.
SELECT c.name AS Columna, ty.name AS Tipo
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.name LIKE @Empresa + N'$Change Log Entry$%'
ORDER BY c.column_id;
GO

DECLARE @Empresa sysname = N'ArbuTest';
DECLARE @TLog sysname, @sql nvarchar(max);
SELECT TOP 1 @TLog = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Change Log Entry$%';

-- Las entradas de 4743, completas. Ordenadas de la más vieja a la más nueva para leer la
-- secuencia de escrituras tal como ocurrió.
SET @sql = N'
SELECT [Entry No_], [Date and Time], [User ID], [Table No_], [Field No_],
       [Primary Key Field 1 Value], [Primary Key Field 2 Value],
       [Type of Change],
       LEN([Old Value]) AS LargoViejo, LEN([New Value]) AS LargoNuevo,
       CASE WHEN [Old Value] = [New Value] THEN 1 ELSE 0 END AS ViejoIgualNuevo,
       [Old Value], [New Value]
FROM [dbo].' + @TLog + N'
WHERE [Primary Key Field 1 Value] = N''4743''
ORDER BY [Entry No_];';
EXEC sp_executesql @sql;
GO
