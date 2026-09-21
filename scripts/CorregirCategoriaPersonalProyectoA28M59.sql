/*
    CORRECCIÓN — categoría de asignación en la marea A28/59 (PP-128-000059).

    EL PROBLEMA. La producción se valoriza con VALOR_CAL_ENT de la categoría de la
    ASIGNACIÓN, no de la ficha: el concepto 2498 está bien configurado, con
    "Par CCT a Usar = El de la asignación al proyecto". Pero Personal Proyecto se
    cargó copiando la categoría del empleado —lo documenta la cabecera de
    MigrarPersonalProyecto_4.sql, "Cód. Convenio / Cód. Categoría -> del empleado,
    el OnInsert los exige con TestField"— y en un buque la gente navega en el puesto
    del rol, que no siempre es el de su ficha. Resultado: cuatro tripulantes cobran
    producción a un índice más bajo del que les pagó Meta4.

    DE DÓNDE SALE LA CATEGORÍA CORRECTA. De dos fuentes independientes que coinciden:

      1. "A28 59 Movimientos.pdf", el rol de entrada de la marea, que da el PUESTO
         con el que cada uno embarcó. OJO AL EXTRAERLO: con `pdftotext -layout` la
         columna CARGO sale corrida y queda cada puesto en la fila equivocada; hay
         que usar `pdftotext -table`, que respeta la grilla. Con -layout, ESCALANTE
         DIEGO figuraba como BODEGUERO; con -table, como CONTROL CALIDAD, que es lo
         correcto.

      2. Los recibos de Meta4. La producción de la marea es kilos x VALOR_CAL_ENT, y
         los kilos son los mismos para toda la tripulación (633,639 t), así que
         dividir el importe por ellos devuelve el $/ton, y ése identifica el escalón
         del convenio sin ambigüedad: los cinco escalones están separados por más de
         700 pesos.

    Cruzadas las dos, el puesto del rol predice el índice que pagó el recibo en 29 de
    las 30 filas. La única excepción se comenta abajo.

    POR QUÉ ESTOS CUATRO Y NO CINCO. REVIEJO (03774) también navegó por encima de su
    ficha —2° Contramaestre de Frío, índice 80, contra Marinero de Planta— pero su
    asignación YA está en MR07, que es índice 80 igual. La plata le da bien y no se
    toca; cambiarlo a MR09 sólo cambiaría el nombre impreso.

    EL ÍNDICE NO FIJA UN NOMBRE ÚNICO. Índice 80 lo comparten MR03, MR06, MR07 y MR09,
    y todos pagan lo mismo. El código de abajo se eligió por el PUESTO del rol
    —MOZO -> MR03— no por el importe, que no alcanza para distinguirlos. Si RRHH
    prefiere otro código del mismo índice, se cambia sin que se mueva un peso.

    LO QUE ESTE SCRIPT NO ARREGLA:

      · COLMAN (04169) figura en el rol como CONTRA / PLANTA, el mismo puesto que
        MOLINA (03961), a quien Meta4 le pagó índice 85. A COLMAN le pagó 70. No se
        toca: este script reproduce lo que Meta4 pagó, y si el rol tiene razón la
        diferencia es un reclamo de RRHH, no un bug de migración.
      · Los cuatro oficiales. Su producción sale de otra tabla de valores que todavía
        no existe (LIQ-00006166 da 0 contra 37.034.484 de Meta4).
      · CORREA (04649) tiene la asignación como OF01 y el CLC de producción lo lista
        como "Pesca"; MARTINEZ (03664) está como OF02 y el CLC dice "Garantía de
        Máquinas". Son oficiales y va con el punto anterior.
*/

DECLARE @Proy nvarchar(20) = 'PP-128-000059';

-- Los cuatro cambios, con su justificación al lado.
DECLARE @Cambio TABLE (Leg nvarchar(20), Nombre nvarchar(50), Puesto nvarchar(20),
                       CatVieja nvarchar(10), CatNueva nvarchar(10), TonRecibo decimal(18,2));
INSERT INTO @Cambio VALUES
    ('03957', 'ESCALANTE DIEGO ARIEL',     'CONTROL CALIDAD', 'MR01', 'MR00', 14286),
    ('04913', 'ARIS ALHIMAM',              'CONTRE / CUB',    'MR01', 'MR00', 14286),
    ('04789', 'BAEZ GUSTAVO FABIAN',       'MOZO',            'MR08', 'MR03', 11429),
    ('04066', 'ROMERO HERNAN MAXIMILIANO', 'CUBIERTA',        'MR08', 'MR05', 10714);

-- 1. PREVISUALIZACIÓN. Qué hay hoy, qué va a quedar, y cuánta plata mueve cada fila.
--    Los kilos son los netos de la marea, del CLC de producción: 633,639 t.
DECLARE @Kilos decimal(18,3) = 633.639;

SELECT c.Leg, c.Nombre, c.Puesto,
       pp.[Cód_ Categoría]                                       AS CatEnBC,
       c.CatNueva                                                AS CatQueVaAQuedar,
       CAST(vv.[Valor] AS decimal(18,2))                         AS TonActual,
       c.TonRecibo                                               AS TonDelRecibo,
       CAST(@Kilos * vv.[Valor]  AS decimal(18,2))               AS ProduccionHoy,
       CAST(@Kilos * c.TonRecibo AS decimal(18,2))               AS ProduccionCorrecta,
       CAST(@Kilos * (c.TonRecibo - vv.[Valor]) AS decimal(18,2)) AS Diferencia,
       CASE WHEN pp.Leg IS NULL                    THEN 'NO EXISTE LA ASIGNACIÓN'
            WHEN pp.[Cód_ Categoría] = c.CatNueva  THEN 'ya corregida'
            WHEN pp.[Cód_ Categoría] <> c.CatVieja THEN 'OJO: la categoría en BC no es la esperada'
            ELSE 'a corregir' END                                AS Estado
FROM   @Cambio c
LEFT   JOIN (SELECT [No_ Empleado] AS Leg, [Cód_ Categoría], [Cód_ Convenio]
             FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
             WHERE [No_ Proyecto] = @Proy) pp ON pp.Leg = c.Leg
LEFT   JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] vv
       ON  vv.[Cód_ Parámetro Base] = 'VALOR_CAL_ENT'
       AND vv.[Cód_ Convenio]  = pp.[Cód_ Convenio]
       AND vv.[Cód_ Categoría] = pp.[Cód_ Categoría]
       AND vv.[Vigencia Desde] = '2026-01-01'
ORDER  BY c.Leg;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

DECLARE @Proy nvarchar(20) = 'PP-128-000059';
DECLARE @Cambio TABLE (Leg nvarchar(20), CatVieja nvarchar(10), CatNueva nvarchar(10));
INSERT INTO @Cambio VALUES
    ('03957','MR01','MR00'), ('04913','MR01','MR00'),
    ('04789','MR08','MR03'), ('04066','MR08','MR05');

-- FOTO PREVIA DE TODA LA MAREA. No alcanza con mirar las cuatro filas: el control que
-- importa es que las OTRAS 26 no se hayan movido, y para eso hace falta el antes. Un
-- control por fecha de modificación no sirve —arrastra ediciones propias de hace un
-- rato— y ya dio un falso positivo antes en esta misma base.
SELECT [No_ Empleado] AS Leg, [Cód_ Convenio] AS Conv, [Cód_ Categoría] AS Cat
INTO   #Antes
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [No_ Proyecto] = @Proy;

UPDATE pp
SET    pp.[Cód_ Categoría]    = c.CatNueva,
       pp.[Observaciones]     = LEFT(RTRIM(pp.[Observaciones])
                                + ' | Categoría corregida 18/9/2026: navegó como '
                                + c.CatNueva + ' (rol de entrada A28/59), no ' + c.CatVieja + '.', 250),
       pp.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   @Cambio c ON c.Leg = pp.[No_ Empleado] AND pp.[Cód_ Categoría] = c.CatVieja
WHERE  pp.[No_ Proyecto] = @Proy;

-- Esperado: 4. Si da menos, alguna ya no tenía la categoría vieja: revisar antes de
-- confirmar, porque el JOIN por CatVieja es lo que hace el script repetible.
SELECT @@ROWCOUNT AS Corregidas;

-- CONTROL 1 · LA INVARIANTE DE PLATA. Con la categoría nueva, kilos x VALOR_CAL_ENT
-- tiene que dar, al centavo, la producción que pagó el recibo de Meta4. Es el control
-- que ata la corrección al documento y no a mi lectura del rol.
-- Tiene que dar 4 filas con Difiere = 0,00.
;WITH Esperado AS (
    SELECT * FROM (VALUES
        ('03957', 9052166.75), ('04913', 9052166.75),
        ('04789', 7241860.13), ('04066', 6788808.25)) v(Leg, ProdRecibo))
SELECT e.Leg, pp.[Cód_ Categoría] AS Cat,
       CAST(633.639 * vv.[Valor] AS decimal(18,2))                AS ProduccionCalculada,
       CAST(e.ProdRecibo AS decimal(18,2))                        AS ProduccionRecibo,
       CAST(633.639 * vv.[Valor] - e.ProdRecibo AS decimal(18,2)) AS Difiere
FROM   Esperado e
JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
       ON pp.[No_ Empleado] = e.Leg AND pp.[No_ Proyecto] = @Proy
JOIN   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] vv
       ON  vv.[Cód_ Parámetro Base] = 'VALOR_CAL_ENT'
       AND vv.[Cód_ Convenio]  = pp.[Cód_ Convenio]
       AND vv.[Cód_ Categoría] = pp.[Cód_ Categoría]
       AND vv.[Vigencia Desde] = '2026-01-01'
ORDER  BY e.Leg;

-- CONTROL 2 · NADIE MÁS SE MOVIÓ. Contra la foto previa, y en las dos direcciones:
-- ni filas de más ni de menos, ni convenios tocados.
-- Tiene que dar 0 filas.
SELECT ISNULL(a.Leg, d.[No_ Empleado]) AS Leg,
       a.Cat AS Antes, d.[Cód_ Categoría] AS Despues,
       a.Conv AS ConvAntes, d.[Cód_ Convenio] AS ConvDespues
FROM   #Antes a
FULL   JOIN (SELECT * FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
             WHERE [No_ Proyecto] = @Proy) d ON d.[No_ Empleado] = a.Leg
WHERE  a.Leg IS NULL OR d.[No_ Empleado] IS NULL
   OR  a.Conv <> d.[Cód_ Convenio]
   OR  (a.Cat <> d.[Cód_ Categoría] AND a.Leg NOT IN ('03957','04913','04789','04066'));

-- CONTROL 3 · LA MAREA COMPLETA, para leerla de un vistazo antes de confirmar.
-- 30 filas, las cuatro corregidas arriba de todo.
SELECT pp.[No_ Empleado] AS Leg, pp.[Cód_ Convenio] AS Conv,
       a.Cat AS Antes, pp.[Cód_ Categoría] AS Ahora,
       CAST(vv.[Valor] AS decimal(18,2)) AS TonCal
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   #Antes a ON a.Leg = pp.[No_ Empleado]
LEFT   JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] vv
       ON  vv.[Cód_ Parámetro Base] = 'VALOR_CAL_ENT'
       AND vv.[Cód_ Convenio]  = pp.[Cód_ Convenio]
       AND vv.[Cód_ Categoría] = pp.[Cód_ Categoría]
       AND vv.[Vigencia Desde] = '2026-01-01'
WHERE  pp.[No_ Proyecto] = @Proy
ORDER  BY CASE WHEN a.Cat <> pp.[Cód_ Categoría] THEN 0 ELSE 1 END, pp.[No_ Empleado];

DROP TABLE #Antes;
-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular los cuatro cierres de marea y comparar el concepto 2498
--    contra el recibo. La diferencia total son 4.073.665,12 pesos.
--
--    LA CABECERA SE LLAMA [No_], NO [No_ Liquidación]. Escrito como subconsulta
--    —"WHERE l.[No_ Liquidación] IN (SELECT [No_ Liquidación] FROM Liquidación...)"—
--    SQL no falla: al no encontrar la columna adentro la resuelve contra la tabla de
--    AFUERA, la subconsulta queda correlacionada y el IN da verdadero para todas las
--    líneas de la base. Devolvía 34 filas de mareas ajenas sin un solo error. Con un
--    JOIN explícito el nombre mal escrito es un error de compilación, no un resultado
--    silenciosamente equivocado.
SELECT h.[No_] AS Liq, h.[No_ Empleado] AS Leg,
       CAST(l.[Cantidad] AS decimal(18,3))                 AS Kilos,
       CAST(l.[Importe]  AS decimal(18,2))                 AS Produccion,
       CAST(e.ProdRecibo AS decimal(18,2))                 AS ProduccionRecibo,
       CAST(l.[Importe] - e.ProdRecibo AS decimal(18,2))   AS Difiere
FROM   dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
JOIN   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
       ON l.[No_ Liquidación] = h.[No_] AND l.[Cód_ Concepto] = '2498'
JOIN   (VALUES ('03957', 9052166.75), ('04913', 9052166.75),
               ('04789', 7241860.13), ('04066', 6788808.25)) e(Leg, ProdRecibo)
       ON e.Leg = h.[No_ Empleado]
WHERE  h.[No_ Proyecto] = 'PP-128-000059'
ORDER  BY h.[No_ Empleado];
GO
