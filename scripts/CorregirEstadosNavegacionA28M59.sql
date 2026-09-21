/*
    CORRECCIÓN — estado de navegación ausente en la marea A28/59 (PP-128-000059).

    EL SÍNTOMA. Cinco tripulantes cobraron el sueldo de puerto por 27 días en vez de 1.
    La fórmula del concepto 1083 es

        (DIAS_PUERTO + DIAS_GP_PERIODO) * PRECIO_PUERTO_CAL / 30 * COEF_POTERO

    y está bien. DIAS_GP_PERIODO les daba 26 (27 a 03774) en vez de 0.

    LA CAUSA, UNA CAPA MÁS ARRIBA. A estos cinco les falta el estado NV de la marea.
    El GP —guardia en puerto— anterior al embarque nunca se cerró el 02/01 y cubre los
    26 días que estuvieron navegando, así que el motor se los cobra como guardia.
    Comparado con 03961, que liquida bien:

        03961   OR 03/12-31/12 | GP 01/01-02/01 | NV 03/01-28/01 | PL 29/01 | PS 30/01
        03957   OR 03/11-31/12 | GP 01/01----------------28/01   | PL 29/01 | PS 30/01

    Y se ve que es un faltante de la migración, no un estado mal fechado: los No. Mov.
    son consecutivos. A 03957 le tocó el 59260 (su PL) y a 03961 el 59261 y 59262 (su
    NV y su PL). La fila NV de 03957 sencillamente no se generó.

    POR QUÉ EL SUELDO DE NAVEGACIÓN SÍ SALE BIEN. Porque los días de navegación se
    cuentan del rango de Personal Proyecto —la asignación— y no de los estados. Por eso
    el error aparece sólo en el puerto, y por eso no lo detecta ningún control que mire
    la navegación.

    POR QUÉ NO ALCANZA CON SincronizarEstadoDesdeProyecto. Esa rutina crea el estado a
    partir de la asignación, pero con Fecha Fin = Fecha Baja (29/01), y el último día
    es de puerto, no de navegación; y sobre todo NO cierra el GP, así que quedarían los
    dos solapados y el problema sería peor. La transición de llegada la hace la
    automatización de Cierre de Marea, que acá nunca corrió.

    LAS FECHAS SE DERIVAN DE LA ASIGNACIÓN, no van escritas a mano:
        GP  hasta  Fecha Alta - 1   (02/01)
        NV  de     Fecha Alta       a  Fecha Baja - 1   (03/01 a 28/01)
        PL  el     Fecha Baja       (29/01)

    03774 ADEMÁS NECESITA EL PL. Los otros cuatro ya lo tienen; a él su GP se lo comió
    —termina el 29/01 y el siguiente estado es PS 30/01— así que si sólo se cerrara el
    GP el 02/01 quedaría un hueco el 29/01, y el motor no liquida a alguien sin estado.

    ALCANCE MÁS AMPLIO, PARA DESPUÉS. En toda la base hay 61 asignaciones a marea sin
    estado NV, en 16 mareas. Sólo estas 5 tienen un GP encima, que es lo que convierte
    el faltante en plata. Las otras 56 están igual de mal y hoy no se ven.
*/

DECLARE @Proy nvarchar(20) = 'PP-128-000059';

-- 1. PREVISUALIZACIÓN. La cadena de estados de los cinco, con lo que va a cambiar.
SELECT e.[No_ Empleado] AS Leg, e.[No_ Mov_] AS Mov, e.[Cód_ Estado] AS Est,
       CONVERT(varchar(10), e.[Fecha Inicio],103) AS Ini,
       CONVERT(varchar(10), NULLIF(e.[Fecha Fin],'1753-01-01'),103) AS Fin,
       e.[No_ Proyecto] AS Proy,
       CASE WHEN e.[Cód_ Estado] = 'GP' AND e.[Fecha Fin] >= pp.[Fecha Alta Asignación]
            THEN 'SE CIERRA EL ' + CONVERT(varchar(10), DATEADD(day,-1,pp.[Fecha Alta Asignación]),103)
            ELSE '' END AS Cambio
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
       ON pp.[No_ Empleado] = e.[No_ Empleado] AND pp.[No_ Proyecto] = @Proy
WHERE  e.[Tipo Entidad] = 0
  AND  e.[No_ Empleado] IN ('03774','03957','04066','04789','04913')
  AND  e.[Fecha Fin] >= '2025-12-01' AND e.[Fecha Inicio] <= '2026-02-28'
ORDER  BY e.[No_ Empleado], e.[Fecha Inicio];

-- Y las filas que se van a crear.
SELECT pp.[No_ Empleado] AS Leg, 'NV' AS Est,
       CONVERT(varchar(10), pp.[Fecha Alta Asignación],103)            AS Ini,
       CONVERT(varchar(10), DATEADD(day,-1,pp.[Fecha Baja]),103)       AS Fin,
       @Proy AS Proy,
       DATEDIFF(day, pp.[Fecha Alta Asignación], pp.[Fecha Baja])      AS Dias
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] = @Proy
  AND  pp.[No_ Empleado] IN ('03774','03957','04066','04789','04913')
UNION  ALL
SELECT '03774', 'PL', '29/01/2026', '29/01/2026', @Proy, 1
ORDER  BY 1, 2;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

DECLARE @Proy nvarchar(20) = 'PP-128-000059';

-- Los cinco, con sus fechas sacadas de la asignación. Que salgan de una tabla y no de
-- literales repetidos es lo que hace que el UPDATE y los dos INSERT no puedan
-- desincronizarse entre sí.
SELECT pp.[No_ Empleado]                          AS Leg,
       pp.[Fecha Alta Asignación]                 AS Alta,
       pp.[Fecha Baja]                            AS Baja,
       DATEADD(day,-1, pp.[Fecha Alta Asignación]) AS CierreGP,
       DATEADD(day,-1, pp.[Fecha Baja])           AS FinNV
INTO   #Obj
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] = @Proy
  AND  pp.[No_ Empleado] IN ('03774','03957','04066','04789','04913');

-- FOTO PREVIA de toda la historia de los cinco, para el control de "no se movió nada más".
SELECT [No_ Mov_] AS Mov, [No_ Empleado] AS Leg, [Cód_ Estado] AS Est,
       [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin, [No_ Proyecto] AS Proy
INTO   #Antes
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Tipo Entidad] = 0
  AND  [No_ Empleado] IN ('03774','03957','04066','04789','04913');

-- HUECOS PREEXISTENTES, ANTES DE TOCAR NADA. Lo usa el CONTROL 1, que mide diferencia.
DECLARE @HuecosAntes int;
;WITH C0 AS (
    SELECT [No_ Empleado] AS Leg, [Fecha Fin] AS Fin,
           LEAD([Fecha Inicio]) OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS SigIni
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE  [Tipo Entidad] = 0 AND [No_ Empleado] IN ('03774','03957','04066','04789','04913')
      AND  [Fecha Fin] <> '1753-01-01')
SELECT @HuecosAntes = COUNT(*) FROM C0 WHERE SigIni IS NOT NULL AND SigIni <> DATEADD(day,1,Fin);

-- 2.a · Cerrar el GP el día anterior al embarque.
UPDATE e
SET    e.[Fecha Fin]          = o.CierreGP,
       e.[Observaciones]      = LEFT(RTRIM(e.[Observaciones])
                                + ' Cerrado 18/9/2026: cubría la marea A28/59 sin cerrarse.', 250),
       e.[$systemModifiedAt]  = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   #Obj o ON o.Leg = e.[No_ Empleado]
WHERE  e.[Tipo Entidad] = 0 AND e.[Cód_ Estado] = 'GP'
  AND  e.[Fecha Inicio] <  o.Alta          -- empezó antes del embarque
  AND  e.[Fecha Fin]    >= o.Alta;         -- y se estiró dentro de la marea

SELECT @@ROWCOUNT AS GPCerrados;           -- esperado: 5

-- 2.b · Crear el estado de navegación que faltaba.
--       [No_ Mov_] es IDENTITY: no va en la lista de columnas.
INSERT INTO dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [Fecha Inicio], [Fecha Fin], [Cód_ Estado], [No_ Proyecto],
     [Tipo Entidad], [Observaciones],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT o.Leg, o.Alta, o.FinNV, 'NV', @Proy, 0,
       'Alta 18/9/2026: la migración no generó el estado de navegación de esta marea.',
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   #Obj o
WHERE  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
                   WHERE x.[Tipo Entidad] = 0 AND x.[No_ Empleado] = o.Leg
                     AND x.[No_ Proyecto] = @Proy AND x.[Cód_ Estado] = 'NV');

SELECT @@ROWCOUNT AS NVCreados;            -- esperado: 5

-- 2.c · El PL de llegada de 03774. Los otros cuatro ya lo tienen; a él su GP se lo
--       tapaba, y sin esta fila el 29/01 le queda sin estado.
INSERT INTO dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [Fecha Inicio], [Fecha Fin], [Cód_ Estado], [No_ Proyecto],
     [Tipo Entidad], [Observaciones],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT o.Leg, o.Baja, o.Baja, 'PL', @Proy, 0,
       'Alta 18/9/2026: día de llegada, que el GP sin cerrar tapaba.',
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   #Obj o
WHERE  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
                   WHERE x.[Tipo Entidad] = 0 AND x.[No_ Empleado] = o.Leg
                     AND x.[Fecha Inicio] <= o.Baja AND x.[Fecha Fin] >= o.Baja);

SELECT @@ROWCOUNT AS PLCreados;            -- esperado: 1 (03774)

-- CONTROL 1 · LA CADENA NO GANÓ HUECOS NI SOLAPES.
--
-- MEDIDO COMO DIFERENCIA, NO COMO ABSOLUTO, y por eso el conteo previo se toma ANTES
-- del UPDATE. Estos cinco arrastran 44 huecos históricos de entre 2013 y 2025 que no
-- tienen nada que ver con esta marea: contarlos como si fueran nuevos aborta una
-- corrección que está bien, y eso fue exactamente lo que pasó en el primer intento.
--
-- La segunda mitad sí mide en absoluto, pero sólo sobre los días que se tocan, del
-- 01/01 al 31/01. La ventana va ajustada a la marea y no a "diciembre a febrero"
-- porque 04789 tiene un hueco propio de diciembre —su FR termina el 10/12/2025 y el
-- GP arranca el 01/01/2026— que tampoco es de esta corrección.
--
-- Las dos tienen que dar 0.
;WITH Cad AS (
    SELECT [No_ Empleado] AS Leg, [Cód_ Estado] AS Est,
           [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
           LEAD([Fecha Inicio]) OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS SigIni,
           LEAD([Cód_ Estado])  OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS SigEst
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE  [Tipo Entidad] = 0 AND [No_ Empleado] IN ('03774','03957','04066','04789','04913')
      AND  [Fecha Fin] <> '1753-01-01')
SELECT (SELECT COUNT(*) FROM Cad WHERE SigIni IS NOT NULL AND SigIni <> DATEADD(day,1,Fin))
       - @HuecosAntes                                              AS HuecosNuevos,
       (SELECT COUNT(*) FROM Cad
        WHERE  SigIni IS NOT NULL AND SigIni <> DATEADD(day,1,Fin)
          AND  Fin >= '2026-01-01' AND Ini <= '2026-01-31')        AS ProblemasEnLaMarea;

-- CONTROL 2 · YA NO QUEDA GP DENTRO DE LA MAREA, que es la condición que inflaba el
-- puerto, medida igual que en el diagnóstico.
-- Tiene que dar 0 filas.
SELECT e.[No_ Empleado] AS Leg, e.[Cód_ Estado] AS Est,
       CONVERT(varchar(10),e.[Fecha Inicio],103) AS Ini,
       CONVERT(varchar(10),e.[Fecha Fin],103) AS Fin
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   #Obj o ON o.Leg = e.[No_ Empleado]
WHERE  e.[Tipo Entidad] = 0 AND e.[Cód_ Estado] = 'GP'
  AND  e.[Fecha Inicio] <= o.Baja AND e.[Fecha Fin] >= o.Alta;

-- CONTROL 3 · NADA MÁS SE MOVIÓ. Contra la foto previa: sólo pueden aparecer filas
-- nuevas (las 6 que se insertaron) y sólo pueden haber cambiado los 5 GP.
-- Tiene que dar exactamente 6 filas 'NUEVA' y 5 'GP CERRADO', y ninguna otra.
SELECT ISNULL(a.Leg, d.[No_ Empleado]) AS Leg,
       ISNULL(a.Est, d.[Cód_ Estado])  AS Est,
       CASE WHEN a.Mov IS NULL                     THEN 'NUEVA'
            WHEN d.[No_ Mov_] IS NULL              THEN 'BORRADA (MAL)'
            WHEN a.Est <> d.[Cód_ Estado]          THEN 'CAMBIÓ EL CÓDIGO (MAL)'
            WHEN a.Ini <> d.[Fecha Inicio]         THEN 'CAMBIÓ EL INICIO (MAL)'
            WHEN a.Proy <> d.[No_ Proyecto]        THEN 'CAMBIÓ EL PROYECTO (MAL)'
            WHEN a.Est = 'GP' AND a.Fin <> d.[Fecha Fin] THEN 'GP CERRADO'
            WHEN a.Fin <> d.[Fecha Fin]            THEN 'CAMBIÓ EL FIN (MAL)'
            ELSE 'sin cambios' END AS Que,
       CONVERT(varchar(10), a.Fin,103) AS FinAntes,
       CONVERT(varchar(10), d.[Fecha Fin],103) AS FinDespues
FROM   #Antes a
FULL   JOIN (SELECT * FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
             WHERE [Tipo Entidad] = 0
               AND [No_ Empleado] IN ('03774','03957','04066','04789','04913')) d
       ON d.[No_ Mov_] = a.Mov
WHERE  a.Mov IS NULL OR d.[No_ Mov_] IS NULL
   OR  a.Est <> d.[Cód_ Estado] OR a.Ini <> d.[Fecha Inicio]
   OR  a.Fin <> d.[Fecha Fin]   OR a.Proy <> d.[No_ Proyecto];

-- CONTROL 4 · LA CADENA DE ENERO, para leerla antes de confirmar. Los cinco tienen que
-- quedar con la misma forma que 03961, que se incluye de testigo y no se toca.
SELECT e.[No_ Empleado] AS Leg, e.[Cód_ Estado] AS Est,
       CONVERT(varchar(10),e.[Fecha Inicio],103) AS Ini,
       CONVERT(varchar(10),e.[Fecha Fin],103) AS Fin, e.[No_ Proyecto] AS Proy
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[No_ Empleado] IN ('03774','03957','04066','04789','04913','03961')
  AND  e.[Fecha Fin] >= '2025-12-25' AND e.[Fecha Inicio] <= '2026-02-05'
ORDER  BY e.[No_ Empleado], e.[Fecha Inicio];

DROP TABLE #Obj; DROP TABLE #Antes;
-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS DE RECALCULAR: el puerto tiene que volver al valor de un día, que es el
--    que ya tienen sus compañeros de la misma categoría en esta misma marea. No hay
--    número escrito a mano: se compara contra el testigo.
SELECT h.[No_ Empleado] AS Leg, h.[Cód_ Categoría] AS Cat,
       CAST(l.[Cantidad] AS decimal(9,2))  AS DiasPuerto,
       CAST(l.[Importe]  AS decimal(18,2)) AS Puerto,
       CAST(t.Testigo    AS decimal(18,2)) AS PuertoEsperado,
       CAST(l.[Importe] - t.Testigo AS decimal(18,2)) AS Difiere
FROM   dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
JOIN   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
       ON l.[No_ Liquidación] = h.[No_] AND l.[Cód_ Concepto] = '1083'
JOIN   (SELECT h2.[Cód_ Categoría] AS Cat, MIN(l2.[Importe]) AS Testigo
        FROM   dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h2
        JOIN   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l2
               ON l2.[No_ Liquidación] = h2.[No_] AND l2.[Cód_ Concepto] = '1083'
        WHERE  h2.[No_ Proyecto] = 'PP-128-000059' AND h2.[Cód_ Tipo Liq_] = 'CIERRE_MAREA'
        GROUP  BY h2.[Cód_ Categoría]) t ON t.Cat = h.[Cód_ Categoría]
WHERE  h.[No_ Proyecto] = 'PP-128-000059'
  AND  h.[No_ Empleado] IN ('03774','03957','04066','04789','04913')
ORDER  BY h.[No_ Empleado];
GO
