/*
    QUITA LA DOBLE CONTABILIZACIÓN ENTRE BASE_IG4 Y BASE_EXT_IG4

    EL PROBLEMA
    Las fórmulas suman las dos bases:
        4750 SAC Devengado          (BASE_IG4 + BASE_EXT_IG4) / 12
        7000 Contrib. patronal      MAX(0, BASE_IG4 + BASE_EXT_IG4 - DED_CONT_PATR) * PCT
        5010 Retención del período  ... + BASE_IG4 + ... + BASE_EXT_IG4 + ...
    Eso sólo cierra si son DISJUNTAS: BASE_IG4 = habituales, BASE_EXT_IG4 = extraordinarios.
    Que sea así lo confirman dos cosas: el campo que alimenta BASE_IG4 en la cabecera se llama
    "Haberes Ordinarios Gravados", y la 5010 lleva en paralelo YTD_HAB_GRAV_ANUAL junto a
    YTD_HAB_EXTORD_ANUAL.

    Hoy 9 de los 13 conceptos de BASE_EXT_IG4 son disjuntos de BASE_IG4 —o sea, el diseño es ese—
    pero 4 están en las dos y se cuentan dos veces:

        3553  Vacaciones
        3573
        4243
        4743  Descuento días de vacaciones

    Son exactamente los 4 que la especificación de Meta4 marca para BASE_IG4, y entraron cuando
    Fracción Acumulador se recargó desde esa especificación (CargarFraccionesMeta4.sql). El Excel
    de Meta4 no describe BASE_EXT_IG4 —tiene cero conceptos ahí—, así que su BASE_IG4 es la base
    total y no la habitual. Al cargarla tal cual sobre un esquema que sí separa las dos, los
    extraordinarios quedaron en ambas.

    POR QUÉ SE VE SOBRE TODO EN UNA LIQUIDACIÓN CON VACACIONES Y GROSSING-UP
    La 5010 (retención) entra en el neto, y el grossing-up ajusta el bruto hasta que el neto llega
    al objetivo. Una retención inflada por la base duplicada obliga al bucle a subir el bruto para
    compensar, así que el error no se queda en la retención: aparece amplificado en el Total de
    Haberes. Sin vacaciones los 4 conceptos valen cero y no se nota; sin grossing-up el error se
    queda contenido en la retención.

    Caso medido (Guillermo Re, enero 2026):
        BASE_IG4     = 1003 + 3553 + 4743 = 20.937.420,49 + 29.312.388,68 - 20.937.420,00
                     = 29.312.389,17
        BASE_EXT_IG4 =        3553 + 4743 =                 29.312.388,68 - 20.937.420,00
                     =  8.374.968,68      <- se suma de nuevo, ya estaba adentro de BASE_IG4

    ANTES DE CORRER
      1. Backup.
      2. Con nadie liquidando.
      3. Revisar @Empresa.
      4. Después, reiniciar el service tier y volver a liquidar el período.

    SI RESULTA QUE BASE_IG4 SÍ TENÍA QUE SER LA BASE TOTAL, el arreglo es el otro: sacar el
    "+ BASE_EXT_IG4" de las fórmulas 4750, 7000 y 5010. No hacer las dos cosas.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';   -- ajustar si la empresa es otra
DECLARE @Tabla   sysname;
DECLARE @sql     nvarchar(max);

SELECT @Tabla = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Fracci_n Acumulador$%';

IF @Tabla IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%Fracci%';
    RAISERROR(N'No se encontró la tabla. Revisar la variable Empresa contra la lista de arriba.',16,1);
    RETURN;
END;

SELECT @Tabla AS TablaFracciones;

-- Estado actual: los conceptos que están en las dos bases.
SET @sql = N'
SELECT a.[Cód_ Concepto], a.[Vigencia Desde], a.[Porcentaje] AS PctEnBaseIG4
FROM [dbo].' + @Tabla + N' a
WHERE a.[Cód_ Acumulador] = N''BASE_IG4''
  AND EXISTS (SELECT 1 FROM [dbo].' + @Tabla + N' b
               WHERE b.[Cód_ Concepto] = a.[Cód_ Concepto]
                 AND b.[Cód_ Acumulador] = N''BASE_EXT_IG4'')
ORDER BY a.[Cód_ Concepto];';
EXEC sp_executesql @sql;

BEGIN TRAN;

-- Se borra la pertenencia a BASE_IG4 (la habitual) y se deja la de BASE_EXT_IG4 (la
-- extraordinaria). La condición es genérica a propósito: si mañana se agrega otro concepto
-- extraordinario a las dos bases, este mismo script lo corrige.
SET @sql = N'
DELETE a
FROM [dbo].' + @Tabla + N' a
WHERE a.[Cód_ Acumulador] = N''BASE_IG4''
  AND EXISTS (SELECT 1 FROM [dbo].' + @Tabla + N' b
               WHERE b.[Cód_ Concepto] = a.[Cód_ Concepto]
                 AND b.[Cód_ Acumulador] = N''BASE_EXT_IG4'');
SELECT @@ROWCOUNT AS FilasBorradas;';
EXEC sp_executesql @sql;

COMMIT;

-- Verificación: no debe quedar ningún concepto en las dos bases.
SET @sql = N'
SELECT a.[Cód_ Concepto] AS SiguenDuplicados
FROM [dbo].' + @Tabla + N' a
WHERE a.[Cód_ Acumulador] = N''BASE_IG4''
  AND EXISTS (SELECT 1 FROM [dbo].' + @Tabla + N' b
               WHERE b.[Cód_ Concepto] = a.[Cód_ Concepto]
                 AND b.[Cód_ Acumulador] = N''BASE_EXT_IG4'');';
EXEC sp_executesql @sql;

SET @sql = N'
SELECT [Cód_ Acumulador], COUNT(DISTINCT [Cód_ Concepto]) AS Conceptos
FROM [dbo].' + @Tabla + N'
WHERE [Cód_ Acumulador] IN (N''BASE_IG4'', N''BASE_EXT_IG4'', N''BASE_HAB_IG4'')
GROUP BY [Cód_ Acumulador] ORDER BY 1;';
EXEC sp_executesql @sql;
GO
