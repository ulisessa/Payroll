/*
    QUÉ HAY REALMENTE EN EL HISTORIAL DE FÓRMULAS

    "El cambio no se guardó" tiene tres causas distintas y desde la pantalla se ven iguales.
    Esta consulta las separa. Sólo LEE.

      a) SE AGRUPÓ. Las ediciones del mismo usuario sobre la misma fórmula dentro de una ventana
         de 15 MINUTOS actualizan la entrada que ya existe en vez de crear otra: avanza sólo
         "Fórmula Nueva" y la Fecha Hora. Es a propósito —el editor guarda mientras se escribe, y
         sin esto una fórmula de una línea dejaría quince entradas—. Se reconoce porque hay una
         entrada reciente cuya "Fórmula Nueva" YA es el texto nuevo, con Fecha Hora de hace un rato.

      b) QUEDÓ COMO ALTA, NO COMO MODIFICACIÓN. Si se creó una vigencia nueva, el cambio se
         registra con Tipo Cambio = 0 (Alta) bajo OTRA "Vigencia Desde". Buscando una Modificación
         no aparece.

      c) NO SE REGISTRÓ. No hay ninguna entrada con el texto nuevo. Recién ahí hay un problema.

    Ajustar @Concepto abajo.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa  sysname      = N'ArbuTest';
DECLARE @Concepto nvarchar(20) = N'4743';

DECLARE @THist sysname, @TCon sysname, @sql nvarchar(max);
SELECT @THist = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Historial F_rmula Concepto$%';
SELECT @TCon  = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Concepto Liquidaci_n$%';

IF @THist IS NULL OR @TCon IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%Historial%' OR name LIKE N'%Concepto Liquidaci%';
    RAISERROR(N'No se encontraron las tablas. Revisar la variable Empresa contra la lista de arriba.',16,1);
    RETURN;
END;

-- 0. ¿El historial funciona en general? Si TotalEntradas = 0, no es un problema de este concepto:
--    no se registró nunca nada y hay que mirar la versión publicada de la extensión.
SET @sql = N'
SELECT COUNT(*) AS TotalEntradas,
       COUNT(DISTINCT [Cód_ Concepto]) AS ConceptosConHistorial,
       MAX([Fecha Hora]) AS UltimaEntrada
FROM [dbo].' + @THist + N';';
EXEC sp_executesql @sql;

-- 1. Las vigencias del concepto y su fórmula actual.
--    MIRAR ESTO PRIMERO: si la fórmula que figura acá es la VIEJA, el cambio nunca llegó a la
--    base y el historial tiene razón en no registrar nada. El problema sería otro: la edición
--    se perdió.
SET @sql = N'
SELECT [Código], [Vigencia Desde], [Vigencia Hasta], [Activo], [Fórmula]
FROM [dbo].' + @TCon + N' WHERE [Código] = @c ORDER BY [Vigencia Desde];';
EXEC sp_executesql @sql, N'@c nvarchar(20)', @Concepto;

-- 1b. ¿La fórmula guardada es la vieja o la corregida?
--     Se comparan sin espacios ni saltos de línea, porque el formateador reacomoda el texto.
--     La diferencia entre las dos versiones es UN paréntesis: en la vieja "/ 30 * MIN" cuelga del
--     else (#2703) / 30 ...); en la corregida cuelga del IF entero (#2703) ) / 30 ...).
SET @sql = N'
SELECT [Código], [Vigencia Desde],
       CASE
         WHEN REPLACE(REPLACE(REPLACE([Fórmula],CHAR(13),''''),CHAR(10),''''),'' '','''')
              LIKE ''%#2703))/30*MIN%'' THEN ''CORREGIDA - el cambio SI esta en la base''
         WHEN REPLACE(REPLACE(REPLACE([Fórmula],CHAR(13),''''),CHAR(10),''''),'' '','''')
              LIKE ''%#2703)/30*MIN%''  THEN ''VIEJA - el cambio NO llego a la base''
         ELSE ''no reconocida - mirar la fórmula completa abajo''
       END AS Version,
       [Fórmula]
FROM [dbo].' + @TCon + N' WHERE [Código] = @c ORDER BY [Vigencia Desde];';
EXEC sp_executesql @sql, N'@c nvarchar(20)', @Concepto;

-- 2. El historial completo del concepto, lo más reciente arriba.
SET @sql = N'
SELECT TOP 20
       [No_ Entrada], [Fecha Hora], [Usuario], [Vigencia Desde],
       CASE [Tipo Cambio] WHEN 0 THEN ''0 Alta''
                          WHEN 1 THEN ''1 Modificación''
                          WHEN 2 THEN ''2 Eliminación''
                          WHEN 3 THEN ''3 Formato''
                          ELSE CAST([Tipo Cambio] AS nvarchar(10)) END AS TipoCambio,
       [Cambió Fórmula], [Cambió Condición],
       DATEDIFF(MINUTE, [Fecha Hora], GETUTCDATE()) AS MinutosAtras,
       LEFT([Fórmula Anterior], 200) AS FormulaAnterior,
       LEFT([Fórmula Nueva],    200) AS FormulaNueva
FROM [dbo].' + @THist + N'
WHERE [Cód_ Concepto] = @c
ORDER BY [Fecha Hora] DESC;';
EXEC sp_executesql @sql, N'@c nvarchar(20)', @Concepto;

-- 3. ¿Coincide la última entrada con la fórmula que hoy tiene el concepto?
--    Si CoincideConConcepto = 1, el cambio SÍ está registrado (caso a o b).
SET @sql = N'
SELECT h.[No_ Entrada], h.[Fecha Hora], h.[Vigencia Desde],
       CASE WHEN h.[Fórmula Nueva] = c.[Fórmula] THEN 1 ELSE 0 END AS CoincideConConcepto
FROM [dbo].' + @THist + N' h
JOIN [dbo].' + @TCon + N' c
  ON c.[Código] = h.[Cód_ Concepto] AND c.[Vigencia Desde] = h.[Vigencia Desde]
WHERE h.[Cód_ Concepto] = @c
  AND h.[Fecha Hora] = (SELECT MAX(x.[Fecha Hora]) FROM [dbo].' + @THist + N' x
                         WHERE x.[Cód_ Concepto] = h.[Cód_ Concepto]
                           AND x.[Vigencia Desde] = h.[Vigencia Desde]);';
EXEC sp_executesql @sql, N'@c nvarchar(20)', @Concepto;
GO
