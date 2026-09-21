/* ============================================================================
   ¿Las fechas de Personal Proyecto coinciden con Meta4?

   Disparado por el legajo 00794:
     · PP-119-000308 quedó SIN fecha de baja. Meta4 dice NV del 23/5 al 3/6/2026.
     · PP-119-000311 quedó con baja 12/10/2026. Meta4 la tiene ABIERTA, y además
       esa fecha pasa el fin del proyecto (6/7/2026).
   En la misma ficha, PP-119-000307 coincide exacto con Meta4. O sea que no es
   que la regla esté mal: falla en casos puntuales.

   --------------------------------------------------------------------------
   LA REGLA DEL SPAN

   El span de un tripulante en una marea sale de sus estados que TRANSCURREN A
   BORDO, no de todos los que llevan ese ID_MAREA.

   Esto no es un detalle: en Meta4 el ID_MAREA SIGUE PUESTO después de que la
   marea terminó. Los francos y las guardias en puerto del 00794 llegan hasta
   mayo de 2026 todavía marcados con la marea 307, que había terminado en
   octubre de 2025. Tomando el MIN/MAX sobre todas las filas de una marea, el
   307 daría 23/9/2025 → 22/5/2026 en vez de 23/9 → 12/10/2025: ocho meses de más.

   Qué estados transcurren a bordo NO se escribe acá: sale del campo "Transcurre
   en Marea" de Cód. Estado Empleado, que es el mismo que usa el motor. Si mañana
   se agrega un estado de a bordo, este control lo toma solo.

   --------------------------------------------------------------------------
   EL CRITERIO DE ALTA — decidido

   Las altas viejas (2002-2021) están un día después que Meta4, todas, sin una
   sola excepción: BC arrancó el span en el estado de navegación y salteó el día
   de puerto de salida. Confirmado que la buena es la de Meta4 —el día en puerto
   antes de zarpar cuenta como embarcado—, así que el bloque 4.a lo corrige.

   --------------------------------------------------------------------------
   EL BUQUE

   Meta4 usa dos formatos de código de buque, y se mapean distinto:

       A19    →  119     ("A" + nn   →  "1" + nn)     PP-119-000311
       HF801  →  801     ("HF" + nnn →  nnn)          PP-801-000004

   El bloque 0.c verifica que no haya un tercer formato sin mapear. Si aparece
   uno, sus asignaciones van a figurar como "sin respaldo" para siempre, por más
   completo que esté el histórico.

   --------------------------------------------------------------------------
   EL RANGO CARGADO

   MIG_EstadosM4 no llega hasta hoy. Todo lo asignado después del último día
   cargado sale como "Fuera del rango cargado", que NO es un error de datos: es
   que no hay con qué compararlo. No se mezcla con "Sin respaldo en Meta4", que
   sí es un problema.

   El borde de arriba daba miedo por otra razón: si la extracción hubiera
   cerrado en el último día los estados que Meta4 tiene ABIERTOS, un FEC_FIN =
   30/6/2026 sería basura y no una baja. NO es el caso, y el bloque 0.e lo
   prueba: quedan filas con FEC_FIN en NULL, o sea que los abiertos pasan como
   abiertos. Si ese bloque diera cero, habría que frenar el 4.b.

   NINGÚN BLOQUE ESCRIBE NADA. El 4 está comentado.
   ========================================================================== */


/* ---------------------------------------------------------------------------
   BLOQUE 0 — Que estén las dos puntas antes de comparar.
--------------------------------------------------------------------------- */
SELECT COUNT(*) AS FilasEstadosM4,
       MIN(FEC_INICIO) AS Desde,
       MAX(FEC_INICIO) AS Hasta,
       COUNT(DISTINCT LEGAJO) AS Legajos
FROM   dbo.MIG_EstadosM4;
GO

-- 0.b  Qué códigos cuentan como "a bordo". Tienen que ser los de navegación y
--      puerto de marea (NV, PS, PL) y NO los de franco, guardia ni pilotaje.
SELECT [Código], [Descripción], [Transcurre en Marea], [Devenga Francos]
FROM   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
ORDER  BY [Transcurre en Marea] DESC, [Código];
GO

-- 0.c  Cobertura del mapeo de buques.
--      Mapeado en NULL = formato de código que el script no conoce.
--      ProyectosQueExisten = 0 = mapeo que compila pero no pega contra ningún
--      proyecto de BC: igual de inútil, y más difícil de ver a simple vista.
SELECT m.BUQUE_M4,
       COUNT(*)                AS FilasM4,
       COUNT(DISTINCT m.MAREA) AS MareasM4,
       CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
            WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
       END                     AS Mapeado,
       (SELECT COUNT(*)
        FROM   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
        WHERE  j.[No_] LIKE 'PP-'
                 + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                        ELSE '@@sin-mapeo@@' END + '-%')
                               AS ProyectosQueExisten
FROM   dbo.MIG_EstadosM4 m
WHERE  m.MAREA IS NOT NULL AND m.MAREA > 0
GROUP  BY m.BUQUE_M4
ORDER  BY CASE WHEN m.BUQUE_M4 LIKE 'HF%' OR m.BUQUE_M4 LIKE 'A%' THEN 1 ELSE 0 END,
          m.BUQUE_M4;
GO

-- 0.d  El control espejo: proyectos PP- de BC que el mapeo NO alcanza desde
--      ningún buque de Meta4. Son los que nunca van a poder verificarse.
SELECT LEFT(j.[No_], 6)        AS PrefijoProyecto,
       COUNT(*)                AS Proyectos,
       MIN(j.[Starting Date])  AS ZarpaMasVieja,
       MAX(j.[Starting Date])  AS ZarpaMasNueva
FROM   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
WHERE  j.[No_] LIKE 'PP-%-%'
   AND NOT EXISTS (
        SELECT 1 FROM dbo.MIG_EstadosM4 m
        WHERE  j.[No_] LIKE 'PP-'
                 + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                        ELSE '@@sin-mapeo@@' END + '-%')
GROUP  BY LEFT(j.[No_], 6)
ORDER  BY 2 DESC;
GO

-- 0.e  ¿La extracción respetó los estados abiertos?
--      De esto depende el bloque 4.b. Si Abiertos = 0, la extracción cerró todo
--      al último día cargado, un FEC_FIN igual al tope no es una baja sino el
--      borde del archivo, y NO hay que correr el 4.b.
--      Si Abiertos > 0, los NULL sobrevivieron y una fecha de fin es una fecha
--      de fin, esté donde esté.
WITH Limite AS (
    SELECT MAX(FEC_INICIO) AS Tope FROM dbo.MIG_EstadosM4
)
SELECT SUM(CASE WHEN m.FEC_FIN IS NULL     THEN 1 ELSE 0 END) AS Abiertos,
       SUM(CASE WHEN m.FEC_FIN = l.Tope    THEN 1 ELSE 0 END) AS CerradosJustoEnElTope,
       COUNT(*)                                               AS Total,
       MIN(l.Tope)                                            AS Tope
FROM   dbo.MIG_EstadosM4 m
CROSS  JOIN Limite l
JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON e.[Código] = m.COD_ESTADO AND e.[Transcurre en Marea] = 1;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 1 — El span según Meta4, contra lo que tiene BC.
--------------------------------------------------------------------------- */
WITH Limite AS (
    SELECT MAX(FEC_INICIO) AS Tope FROM dbo.MIG_EstadosM4
),
Abordo AS (
    SELECT m.LEGAJO,
           'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                   END
                 + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6)  AS Proyecto,
           MIN(m.FEC_INICIO)                                                AS AltaM4,
           -- Una sola fila abierta abre el span entero: mientras haya un estado
           -- de a bordo sin cerrar, el tripulante sigue embarcado.
           CASE WHEN SUM(CASE WHEN m.FEC_FIN IS NULL THEN 1 ELSE 0 END) > 0
                THEN NULL ELSE MAX(m.FEC_FIN) END                           AS BajaM4
    FROM   dbo.MIG_EstadosM4 m
    JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Código] = m.COD_ESTADO AND e.[Transcurre en Marea] = 1
    WHERE  m.MAREA IS NOT NULL AND m.MAREA > 0
    GROUP  BY m.LEGAJO, m.BUQUE_M4, m.MAREA
)
SELECT pp.[No_ Empleado],
       pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación]                                 AS AltaBC,
       a.AltaM4,
       DATEDIFF(day, a.AltaM4, pp.[Fecha Alta Asignación])        AS DiasAlta,
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL
            ELSE pp.[Fecha Baja] END                              AS BajaBC,
       a.BajaM4,
       j.[Ending Date]                                            AS FinProyecto,
       CASE WHEN a.AltaM4 IS NULL AND pp.[Fecha Alta Asignación] > (SELECT Tope FROM Limite)
                                                                  THEN 'Fuera del rango cargado'
            WHEN a.AltaM4 IS NULL                                 THEN 'Sin respaldo en Meta4'
            WHEN pp.[Fecha Alta Asignación] <> a.AltaM4           THEN 'Alta distinta'
            WHEN pp.[Fecha Baja] = '1753-01-01' AND a.BajaM4 IS NOT NULL THEN 'Baja faltante'
            WHEN pp.[Fecha Baja] <> '1753-01-01' AND a.BajaM4 IS NULL    THEN 'Baja de más (M4 abierta)'
            WHEN pp.[Fecha Baja] <> a.BajaM4                      THEN 'Baja distinta'
       END                                                        AS Problema
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
LEFT   JOIN Abordo a ON a.LEGAJO = pp.[No_ Empleado] AND a.Proyecto = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND (a.AltaM4 IS NULL
     OR pp.[Fecha Alta Asignación] <> a.AltaM4
     OR (pp.[Fecha Baja] = '1753-01-01' AND a.BajaM4 IS NOT NULL)
     OR (pp.[Fecha Baja] <> '1753-01-01' AND a.BajaM4 IS NULL)
     OR (pp.[Fecha Baja] <> '1753-01-01' AND a.BajaM4 IS NOT NULL AND pp.[Fecha Baja] <> a.BajaM4))
ORDER  BY pp.[No_ Empleado], pp.[No_ Proyecto];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 2 — Cuántos de cada clase. Es lo que dice si hay que corregir a mano
   media docena o rehacer la migración de fechas.

   DesfasajeMin/Max son sólo para "Alta distinta": si los dos dan 1, es el
   corrimiento sistemático conocido y se corrige en bloque sin mirar fila por
   fila. Si aparece un desfasaje grande, hay otra cosa mezclada.
--------------------------------------------------------------------------- */
WITH Limite AS (
    SELECT MAX(FEC_INICIO) AS Tope FROM dbo.MIG_EstadosM4
),
Abordo AS (
    SELECT m.LEGAJO,
           'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                   END
                 + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6) AS Proyecto,
           MIN(m.FEC_INICIO) AS AltaM4,
           CASE WHEN SUM(CASE WHEN m.FEC_FIN IS NULL THEN 1 ELSE 0 END) > 0
                THEN NULL ELSE MAX(m.FEC_FIN) END AS BajaM4
    FROM   dbo.MIG_EstadosM4 m
    JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Código] = m.COD_ESTADO AND e.[Transcurre en Marea] = 1
    WHERE  m.MAREA IS NOT NULL AND m.MAREA > 0
    GROUP  BY m.LEGAJO, m.BUQUE_M4, m.MAREA
),
Clasificado AS (
    SELECT CASE WHEN a.AltaM4 IS NULL AND pp.[Fecha Alta Asignación] > (SELECT Tope FROM Limite)
                                                                  THEN 'Fuera del rango cargado'
                WHEN a.AltaM4 IS NULL                                 THEN 'Sin respaldo en Meta4'
                WHEN pp.[Fecha Alta Asignación] <> a.AltaM4           THEN 'Alta distinta'
                WHEN pp.[Fecha Baja] = '1753-01-01' AND a.BajaM4 IS NOT NULL THEN 'Baja faltante'
                WHEN pp.[Fecha Baja] <> '1753-01-01' AND a.BajaM4 IS NULL    THEN 'Baja de más (M4 abierta)'
                WHEN pp.[Fecha Baja] <> a.BajaM4                      THEN 'Baja distinta'
                ELSE 'Coincide' END                                   AS Problema,
           CASE WHEN a.AltaM4 IS NOT NULL AND pp.[Fecha Alta Asignación] <> a.AltaM4
                THEN DATEDIFF(day, a.AltaM4, pp.[Fecha Alta Asignación]) END AS DiasAlta,
           pp.[No_ Empleado], pp.[No_ Proyecto]
    FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    LEFT   JOIN Abordo a ON a.LEGAJO = pp.[No_ Empleado] AND a.Proyecto = pp.[No_ Proyecto]
    WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
)
SELECT Problema,
       COUNT(*)                       AS Casos,
       COUNT(DISTINCT [No_ Empleado]) AS Empleados,
       COUNT(DISTINCT [No_ Proyecto]) AS Proyectos,
       MIN(DiasAlta)                  AS DesfasajeMin,
       MAX(DiasAlta)                  AS DesfasajeMax
FROM   Clasificado
GROUP  BY Problema
ORDER  BY 2 DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 3 — Control independiente de Meta4: bajas posteriores al fin del
   proyecto.

   La regla ya la fijamos: la baja puede llegar HASTA el fin del proyecto —hay
   uno o dos días de arribo después de la llegada— pero no pasarlo. Esto no
   necesita a Meta4 para detectarse, así que sirve igual con el bridge corto, y
   agarra el caso de PP-119-000311 (baja 12/10/2026 sobre un proyecto que
   termina el 6/7/2026).
--------------------------------------------------------------------------- */
SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación], pp.[Fecha Baja],
       j.[Starting Date] AS ZarpaProyecto, j.[Ending Date] AS FinProyecto,
       DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]) AS DiasDeMas,
       -- Si el ALTA también pasa el fin del proyecto, la asignación entera está
       -- fuera del proyecto y el que está mal es el proyecto, no la asignación.
       -- Pasa en los PP- viejos: varios tienen Ending Date = 2003-02-26 y
       -- Starting Date en blanco, que no es una fecha, es un default.
       CASE WHEN pp.[Fecha Alta Asignación] > j.[Ending Date]
            THEN 'El alta también pasa el fin: revisar el proyecto'
            ELSE 'Sólo la baja' END AS Donde
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND pp.[Fecha Baja] <> '1753-01-01'
   AND j.[Ending Date] <> '1753-01-01'
   AND pp.[Fecha Baja] > j.[Ending Date]
ORDER  BY DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]) DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 4.a — CORRECCIÓN DE ALTAS. Lista para correr.

   Criterio decidido: manda Meta4. El día en puerto de salida cuenta como
   embarcado, y las altas que arrancan un día después están mal.

   Esto NO depende de que el bridge llegue hasta hoy: la fecha de alta sale de
   un MIN, y que la extracción se haya cortado en junio no mueve el mínimo de
   una marea que empezó en 2014. Y sólo toca filas donde Meta4 tiene el dato
   (JOIN, no LEFT JOIN): sin respaldo no hay con qué corregir.

   Corré antes el bloque 2 y mirá DesfasajeMin/DesfasajeMax.
--------------------------------------------------------------------------- */
/*
BEGIN TRAN;

WITH Abordo AS (
    SELECT m.LEGAJO,
           'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                   END
                 + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6) AS Proyecto,
           MIN(m.FEC_INICIO) AS AltaM4
    FROM   dbo.MIG_EstadosM4 m
    JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Código] = m.COD_ESTADO AND e.[Transcurre en Marea] = 1
    WHERE  m.MAREA IS NOT NULL AND m.MAREA > 0
    GROUP  BY m.LEGAJO, m.BUQUE_M4, m.MAREA
)
UPDATE pp
SET    pp.[Fecha Alta Asignación] = a.AltaM4
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   Abordo a ON a.LEGAJO = pp.[No_ Empleado] AND a.Proyecto = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND pp.[Fecha Alta Asignación] <> a.AltaM4;

-- Mirá el número antes de confirmar: tiene que coincidir con el "Alta distinta"
-- del bloque 2.
SELECT @@ROWCOUNT AS FilasTocadas;

-- COMMIT;   -- o ROLLBACK; si el número no es el esperado
*/


/* ---------------------------------------------------------------------------
   BLOQUE 4.b — CORRECCIÓN DE BAJAS. Lista para correr.

   Sólo las asignaciones donde Meta4 TIENE una fecha de baja: las 83 que en BC
   quedaron sin cerrar más la única que quedó con fecha distinta. 84 filas.

   Mirá primero el 0.e. Si Abiertos > 0 —que es lo que se vio— los estados
   abiertos de Meta4 llegaron como NULL, así que un FEC_FIN es una baja de
   verdad y no el borde de la extracción. Si diera cero, frená acá.

   Lo que este UPDATE NO hace, a propósito, es reabrir. Cuando Meta4 tiene el
   estado abierto y BC tiene una fecha, poner el campo en blanco sería seguir a
   Meta4 hasta un lugar donde Meta4 tampoco tiene razón: dejaría 25 tripulantes
   embarcados en mareas que terminaron en julio. Ese caso va aparte, en el 4.c.
--------------------------------------------------------------------------- */
/*
BEGIN TRAN;

WITH Abordo AS (
    SELECT m.LEGAJO,
           'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                        WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                   END
                 + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6) AS Proyecto,
           CASE WHEN SUM(CASE WHEN m.FEC_FIN IS NULL THEN 1 ELSE 0 END) > 0
                THEN NULL ELSE MAX(m.FEC_FIN) END AS BajaM4
    FROM   dbo.MIG_EstadosM4 m
    JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Código] = m.COD_ESTADO AND e.[Transcurre en Marea] = 1
    WHERE  m.MAREA IS NOT NULL AND m.MAREA > 0
    GROUP  BY m.LEGAJO, m.BUQUE_M4, m.MAREA
)
UPDATE pp
SET    pp.[Fecha Baja] = a.BajaM4
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   Abordo a ON a.LEGAJO = pp.[No_ Empleado] AND a.Proyecto = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND a.BajaM4 IS NOT NULL          -- nunca reabre: eso es el 4.c
   AND pp.[Fecha Baja] <> a.BajaM4;

-- Esperado: 84 = 83 "Baja faltante" + 1 "Baja distinta" del bloque 2.
SELECT @@ROWCOUNT AS FilasTocadas;

-- COMMIT;   -- o ROLLBACK;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 4.c — LAS 25 QUE HAY QUE DECIDIR. No es una corrección automática.

   Son las "Baja de más (M4 abierta)": BC tiene una fecha de baja y Meta4 tiene
   el estado abierto. Las 23 peores son el evento del 13/10/2026 del bloque 5.

   Acá no hay una fuente que copiar. Las dos opciones son:

     a) Blanquear, siguiendo a Meta4 al pie de la letra. Deja 22 tripulantes
        embarcados en PP-119-000311, que terminó el 6/7/2026. Es fiel al origen
        y es falso: lo que pasa es que Meta4 tampoco se actualizó.

     b) Cerrar en el fin del proyecto. La marea terminó, la gente bajó. Es la
        cota superior de la regla que ya fijamos —la baja llega hasta el fin del
        proyecto, no lo pasa— y es una decisión, no un dato: nadie tiene el día
        exacto.

   Va (b) escrita porque es la que deja el sistema coherente, pero es tu
   decisión, no una derivación. Mirá el 5.c antes.
--------------------------------------------------------------------------- */
/*
BEGIN TRAN;

UPDATE pp
SET    pp.[Fecha Baja] = j.[Ending Date]
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND pp.[Fecha Baja] <> '1753-01-01'
   AND j.[Ending Date] <> '1753-01-01'
   AND pp.[Fecha Baja] > j.[Ending Date]
   -- Sólo lo del evento del 13/10. Las bajas viejas que pasan el fin del
   -- proyecto son otro problema: ahí el que está mal suele ser el proyecto,
   -- y el bloque 3 las separa con la columna Donde.
   AND pp.[Fecha Baja] >= '2026-07-01';

SELECT @@ROWCOUNT AS FilasTocadas;

-- COMMIT;   -- o ROLLBACK;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 5 — El evento del 13/10/2026.

   Esto NO salió de Meta4: salió de mirar las dos clases malas juntas.

     · 23 asignaciones cerradas el 12/10/2026, repartidas en tres proyectos que
       terminan el 6/7, el 10/7 y el 24/7. Una fecha igual en proyectos distintos
       no es una llegada a puerto.
     · 6 asignaciones dadas de alta el 13/10/2026 en PP-119-000308, un proyecto
       que terminó el 3/6/2026.

   12/10 y 13/10 son el mismo evento visto de los dos lados: el motor cierra la
   asignación anterior el día antes de que arranque la nueva. El legajo 02297 lo
   muestra entero él solo: se le cerró PP-118-000327 el 12/10 y se le abrió
   PP-119-000308 el 13/10.

   O sea que alguien corrió la asignación de tripulación con fecha 13/10/2026,
   que además es futura: hoy es septiembre. No es un problema de migración ni de
   Meta4, es un proceso ejecutado con la fecha equivocada.

   Los bloques de abajo lo confirman y buscan si pasó otras veces.
--------------------------------------------------------------------------- */

-- 5.a  Fechas de baja que cierran asignaciones más allá del fin del proyecto.
--      Una llegada real cierra UN proyecto. Si una misma fecha cierra varios
--      proyectos distintos y en todos se pasa del fin, es un proceso, no un
--      arribo.
SELECT pp.[Fecha Baja]                                       AS FechaBaja,
       COUNT(*)                                              AS Asignaciones,
       COUNT(DISTINCT pp.[No_ Proyecto])                     AS Proyectos,
       MIN(DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]))  AS DiasDeMasMin,
       MAX(DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]))  AS DiasDeMasMax
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND pp.[Fecha Baja] <> '1753-01-01'
   AND j.[Ending Date] <> '1753-01-01'
   AND pp.[Fecha Baja] > j.[Ending Date]
GROUP  BY pp.[Fecha Baja]
HAVING COUNT(DISTINCT pp.[No_ Proyecto]) > 1
ORDER  BY 2 DESC;
GO

-- 5.b  El otro lado: altas posteriores al fin de su propio proyecto.
--      Nadie embarca en una marea que ya terminó.
SELECT pp.[Fecha Alta Asignación]                                        AS FechaAlta,
       COUNT(*)                                                          AS Asignaciones,
       COUNT(DISTINCT pp.[No_ Proyecto])                                 AS Proyectos,
       MAX(DATEDIFF(day, j.[Ending Date], pp.[Fecha Alta Asignación]))   AS DiasDespuesDelFin
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
   AND j.[Ending Date] <> '1753-01-01'
   AND pp.[Fecha Alta Asignación] > j.[Ending Date]
GROUP  BY pp.[Fecha Alta Asignación]
ORDER  BY 2 DESC;
GO

-- 5.c  El detalle de los dos días, uno al lado del otro, para ver la cascada.
--      Los legajos que aparecen en las dos mitades son los que tienen el cierre
--      y la apertura encadenados.
SELECT 'Cerrada el 12/10' AS Lado, pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación] AS Alta, pp.[Fecha Baja] AS Baja,
       j.[Ending Date] AS FinProyecto
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Fecha Baja] = '2026-10-12'

UNION ALL
SELECT 'Abierta el 13/10', pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación],
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END,
       j.[Ending Date]
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Fecha Alta Asignación] = '2026-10-13'
ORDER  BY 2, 1;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 6 — Las PN-, que la auditoría no estaba mirando.

   El 5.c destapó que el evento del 13/10/2026 le cerró a 02804 la asignación
   PN-119-NOMINA, abierta desde el 19/4/2001. Eso NO es una marea: es la
   asignación de nómina, la que sostiene al empleado en el buque.

   Los bloques 1, 2, 3, 5.a y 5.b filtran 'PP-%' porque comparan contra mareas
   de Meta4, y las PN- no tienen marea contra la cual compararse. Del lado de
   las fechas eso fue un punto ciego: el daño estaba afuera del alcance.

   Acá no se compara contra Meta4. Se buscan dos cosas que se ven solas.
--------------------------------------------------------------------------- */

-- 6.a  ¿Ya se corrigió algo? Estado actual de los proyectos del evento.
--      Si PP-119-000311 ya no tiene ninguna baja el 12/10, el 4.c corrió.
SELECT pp.[No_ Proyecto],
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END AS Baja,
       COUNT(*) AS Asignaciones,
       j.[Ending Date] AS FinProyecto
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] IN ('PP-119-000311', 'PP-118-000327',
                             'PP-115-000312', 'PP-119-000308', 'PP-114-000311')
GROUP  BY pp.[No_ Proyecto], pp.[Fecha Baja], j.[Ending Date]
ORDER  BY 1, 2;
GO

-- 6.b  Asignaciones de nómina cerradas, por fecha.
--      Una PN- se cierra cuando el empleado se va del buque, o de la empresa.
--      Si una sola fecha concentra varias, no fue gente yéndose: fue un proceso.
SELECT CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END AS Baja,
       COUNT(*)                          AS Asignaciones,
       COUNT(DISTINCT pp.[No_ Proyecto]) AS Proyectos
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[Fecha Baja] <> '1753-01-01'
GROUP  BY pp.[Fecha Baja]
HAVING COUNT(*) > 1
ORDER  BY 1 DESC;
GO

-- 6.c  OJO: ESTE CONTROL NO SIRVE COMO ESTÁ. Se deja para no repetir el error.
--
--      La idea era buena: un empleado activo sin ninguna asignación abierta no
--      lo encuentra el motor. El problema es el filtro. Devuelve 2.524 casos,
--      con bajas de nómina que empiezan en el año 2000, sobre una empresa de
--      ocho buques y unos 240 tripulantes embarcados.
--
--      Status del Employee NO se migró: está en 0 —"Activo"— para todos. Así
--      que esto no lista empleados activos, lista la rotación entera desde 2000.
--
--      Corré el 9.a antes de creerle a cualquier control que filtre por Status.
--      El control que reemplaza a éste, y que no depende de Status, es el 9.b.
SELECT e.[No_]      AS Empleado,
       e.[First Name], e.[Last Name],
       MAX(pp.[Fecha Baja]) AS UltimaBaja,
       COUNT(*)             AS AsignacionesTotales
FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
       ON pp.[No_ Empleado] = e.[No_]
WHERE  e.[Status] = 0
GROUP  BY e.[No_], e.[First Name], e.[Last Name]
HAVING SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 0
ORDER  BY 4 DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 7 — Hereda el filtro roto del 6.c. Leer con cuidado.

   Arrancó como "qué tan grave es lo del 6.c" y terminó probando que el 6.c no
   medía lo que yo creía. El 7.b devuelve 2.462 + 62 = 2.524 empleados, con
   bajas de nómina desde el año 2000: eso no es un problema, es la rotación de
   veinticinco años. Employee.Status no se migró (ver 9.a).

   El 7.a y el 7.b quedan como están, pero sus totales NO son un recuento de
   daño. Lo que sí sirvió es el 7.c, que no filtra por Status: ahí se ven los
   dos cierres masivos de nómina de mayo de 2026, y de ahí sale el bloque 9.
--------------------------------------------------------------------------- */

-- 7.a  El tamaño real del problema, por mes de última baja.
--      Separa lo que destaparon las correcciones (junio y julio de 2026) del
--      arrastre viejo, que ya estaba ahí antes de tocar nada.
WITH SinNada AS (
    SELECT pp.[No_ Empleado], MAX(pp.[Fecha Baja]) AS UltimaBaja
    FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
    JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
           ON pp.[No_ Empleado] = e.[No_]
    WHERE  e.[Status] = 0
    GROUP  BY pp.[No_ Empleado]
    HAVING SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 0
)
SELECT DATEFROMPARTS(YEAR(UltimaBaja), MONTH(UltimaBaja), 1) AS Mes,
       COUNT(*) AS Empleados
FROM   SinNada
GROUP  BY DATEFROMPARTS(YEAR(UltimaBaja), MONTH(UltimaBaja), 1)
ORDER  BY 1 DESC;
GO

-- 7.b  ¿Tienen nómina, y cuándo se cerró?
--      Tres respuestas posibles, y cada una se arregla distinto:
--        · "Nunca tuvo PN-"  → falta migrar la asignación de nómina.
--        · "PN- cerrada"     → hay que ver por qué y si corresponde reabrirla.
--        · el resto no debería aparecer.
WITH SinNada AS (
    SELECT pp.[No_ Empleado]
    FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
    JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
           ON pp.[No_ Empleado] = e.[No_]
    WHERE  e.[Status] = 0
    GROUP  BY pp.[No_ Empleado]
    HAVING SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 0
)
, Clasif AS (
    SELECT s.[No_ Empleado],
           MAX(CASE WHEN pp.[No_ Proyecto] LIKE 'PN-%' THEN 1 ELSE 0 END)     AS TienePN,
           MAX(CASE WHEN pp.[No_ Proyecto] LIKE 'PN-%' AND pp.[Fecha Baja] <> '1753-01-01'
                    THEN pp.[Fecha Baja] END)                                 AS BajaPN
    FROM   SinNada s
    JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
           ON pp.[No_ Empleado] = s.[No_ Empleado]
    GROUP  BY s.[No_ Empleado]
)
SELECT CASE WHEN TienePN = 0 THEN 'Nunca tuvo PN-' ELSE 'PN- cerrada' END AS Situacion,
       COUNT(*)      AS Empleados,
       MIN(BajaPN)   AS PrimeraBajaPN,
       MAX(BajaPN)   AS UltimaBajaPN
FROM   Clasif
GROUP  BY CASE WHEN TienePN = 0 THEN 'Nunca tuvo PN-' ELSE 'PN- cerrada' END;
GO

-- 7.c  El detalle de las PN- de esa gente: cuál, desde cuándo y hasta cuándo.
--      Si todas cierran el mismo día, fue un proceso y se revierte en bloque.
SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación] AS Alta,
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END AS Baja
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[No_ Empleado] IN (
        SELECT pp2.[No_ Empleado]
        FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
        JOIN   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp2
               ON pp2.[No_ Empleado] = e.[No_]
        WHERE  e.[Status] = 0
        GROUP  BY pp2.[No_ Empleado]
        HAVING SUM(CASE WHEN pp2.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 0)
ORDER  BY pp.[Fecha Baja] DESC, pp.[No_ Empleado];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 8 — Las seis altas fantasma que quedaron.

   PP-119-000308 terminó el 3/6/2026 y tiene seis asignaciones dadas de alta el
   13/10/2026, todavía abiertas. El 4.b no las pudo tocar —Meta4 no las conoce,
   no existen— y el 4.c tampoco, porque no tienen fecha de baja que corregir.

   Éstas no se corrigen: se borran. Nadie embarcó en esa marea ese día, la marea
   ya había terminado cuatro meses antes. Son el residuo del proceso corrido con
   la fecha equivocada.

   Va comentado y mostrando primero, porque un DELETE no tiene vuelta atrás.
--------------------------------------------------------------------------- */
SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación] AS Alta,
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END AS Baja,
       j.[Starting Date] AS ZarpaProyecto, j.[Ending Date] AS FinProyecto
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Fecha Alta Asignación] = '2026-10-13';
GO

/*
BEGIN TRAN;

DELETE pp
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Fecha Alta Asignación] = '2026-10-13'
   AND j.[Ending Date] <> '1753-01-01'
   AND pp.[Fecha Alta Asignación] > j.[Ending Date];

-- Esperado: 6.
SELECT @@ROWCOUNT AS FilasBorradas;

-- COMMIT;   -- o ROLLBACK;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 9 — Navegando con la nómina cerrada.

   El 7.c mostró dos cierres masivos de asignaciones de nómina:

       22/5/2026   22 personas, todas PN-119-NOMINA
       27/5/2026   ~58 personas, todas PN-116-NOMINA y PN-117-NOMINA

   Son, una por una, las tripulaciones de PP-119-000311 y de PP-116-000305 /
   PP-117-000309. Y las mareas son POSTERIORES: el 00794 tiene la nómina cerrada
   el 22/5/2026 y navegó del 24/6 al 6/7. Un mes embarcado sin asignación de
   nómina vigente.

   Eso está mal se mire por donde se mire, y —a diferencia del 6.c— no depende
   de ningún campo dudoso: son dos fechas de la misma tabla comparadas entre sí.
--------------------------------------------------------------------------- */

-- 9.a  ¿Sirve Employee.Status?
--      Si todo cae en un solo valor, el campo no se migró y no se puede filtrar
--      por él. Es lo que invalidó el 6.c.
SELECT [Status], COUNT(*) AS Empleados
FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972]
GROUP  BY [Status]
ORDER  BY 2 DESC;
GO

-- 9.b  Mareas navegadas sin nómina que las cubra.
--      Para cada asignación a una marea, ¿existe una asignación PN- que empiece
--      antes y termine después (o siga abierta)? Si no existe, el tripulante
--      estuvo embarcado sin estar asignado a la nómina de ningún buque.
--      Acotado a 2024 en adelante: más atrás el ruido de la migración tapa todo.
WITH Mareas AS (
    SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
           pp.[Fecha Alta Asignación] AS Alta,
           CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN pp.[Fecha Alta Asignación]
                ELSE pp.[Fecha Baja] END AS Fin
    FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
      AND  pp.[Fecha Alta Asignación] >= '2024-01-01'
)
SELECT m.[No_ Empleado], m.[No_ Proyecto], m.Alta, m.Fin,
       (SELECT MAX(n.[Fecha Baja])
        FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
        WHERE  n.[No_ Empleado] = m.[No_ Empleado]
          AND  n.[No_ Proyecto] LIKE 'PN-%'
          AND  n.[Fecha Baja] <> '1753-01-01') AS UltimaBajaNomina
FROM   Mareas m
WHERE  NOT EXISTS (
        SELECT 1
        FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
        WHERE  n.[No_ Empleado] = m.[No_ Empleado]
          AND  n.[No_ Proyecto] LIKE 'PN-%'
          AND  n.[Fecha Alta Asignación] <= m.Alta
          AND (n.[Fecha Baja] = '1753-01-01' OR n.[Fecha Baja] >= m.Fin))
ORDER  BY m.Alta DESC, m.[No_ Empleado];
GO

-- 9.c  Lo mismo, contado por mes de zarpada, para ver si es un episodio de
--      mayo de 2026 o una costumbre.
WITH Mareas AS (
    SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
           pp.[Fecha Alta Asignación] AS Alta,
           CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN pp.[Fecha Alta Asignación]
                ELSE pp.[Fecha Baja] END AS Fin
    FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  pp.[No_ Proyecto] LIKE 'PP-%'
      AND  pp.[Fecha Alta Asignación] >= '2024-01-01'
)
SELECT DATEFROMPARTS(YEAR(m.Alta), MONTH(m.Alta), 1) AS MesZarpada,
       COUNT(*)                          AS Asignaciones,
       COUNT(DISTINCT m.[No_ Empleado])  AS Empleados,
       COUNT(DISTINCT m.[No_ Proyecto])  AS Mareas
FROM   Mareas m
WHERE  NOT EXISTS (
        SELECT 1
        FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
        WHERE  n.[No_ Empleado] = m.[No_ Empleado]
          AND  n.[No_ Proyecto] LIKE 'PN-%'
          AND  n.[Fecha Alta Asignación] <= m.Alta
          AND (n.[Fecha Baja] = '1753-01-01' OR n.[Fecha Baja] >= m.Fin))
GROUP  BY DATEFROMPARTS(YEAR(m.Alta), MONTH(m.Alta), 1)
ORDER  BY 1 DESC;
GO

-- 9.d  LO QUE DECIDE SI EL 9.b ES UN PROBLEMA O UN MALENTENDIDO.
--
--      El 9.b devuelve la flota entera desde fines de mayo de 2026: las PN- de
--      115 y 119 cerraron el 22/5, y las de 114, 116, 117 y 118 el 27/5. Ocho
--      buques, y todas las mareas posteriores quedan "sin nómina que las cubra".
--      Una anomalía de ese tamaño casi nunca es un desastre silencioso; suele
--      ser que el modelo cambió y el control quedó preguntando por lo viejo.
--
--      Dos lecturas posibles:
--        · Las nóminas se cerraron y nadie las reabrió  → problema real.
--        · Desde mayo la asignación al buque va sólo por PP- y las PN- se
--          discontinuaron a propósito  → el 9.b no mide nada.
--
--      Si Abiertas ≈ la dotación embarcada (unas 240), el modelo sigue vivo y
--      lo de mayo hay que explicarlo. Si da cero, las PN- se discontinuaron y
--      el 9.b hay que tirarlo.
SELECT pp.[No_ Proyecto],
       SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS Abiertas,
       SUM(CASE WHEN pp.[Fecha Baja] <> '1753-01-01' THEN 1 ELSE 0 END) AS Cerradas,
       MAX(pp.[Fecha Alta Asignación])                                 AS UltimaAlta
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
GROUP  BY pp.[No_ Proyecto]
ORDER  BY 2 DESC, 1;
GO

-- 9.e  ¿Se siguieron creando asignaciones de nómina después de los cierres de
--      mayo? Si la respuesta es que no, dejaron de usarse. Si sí, los cierres
--      de mayo fueron una reasignación que a alguien se le quedó por la mitad.
SELECT DATEFROMPARTS(YEAR(pp.[Fecha Alta Asignación]),
                     MONTH(pp.[Fecha Alta Asignación]), 1) AS MesAlta,
       COUNT(*)                          AS Asignaciones,
       COUNT(DISTINCT pp.[No_ Proyecto]) AS Proyectos,
       SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS SiguenAbiertas
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[Fecha Alta Asignación] >= '2026-01-01'
GROUP  BY DATEFROMPARTS(YEAR(pp.[Fecha Alta Asignación]),
                        MONTH(pp.[Fecha Alta Asignación]), 1)
ORDER  BY 1;
GO

-- 9.f  QUIÉN Y CUÁNDO CERRÓ LAS NÓMINAS.
--
--      El rastro en los datos es inequívoco —baja = alta − 1, tres veces, en
--      fechas distintas— pero el mecanismo NO está en el código actual:
--      CerrarAsignacionesDeProyecto filtra por proyecto, y
--      EncadenarSiguienteAsignacion va al revés (cierra una y abre la siguiente
--      en baja+1). Ninguna cierra la nómina al crear una marea.
--
--      O ya se arregló, o lo hizo otra cosa: la sincronización desde NAV, un
--      proceso por lotes, o una acción manual. BC guarda la marca de auditoría
--      de cada fila y eso lo contesta sin adivinar.
--
--      Si todas las filas comparten timestamp al segundo, fue un proceso. Si
--      están desparramadas, fue gente cargando de a una.
SELECT CAST(pp.[$systemModifiedAt] AS date)                 AS DiaModificacion,
       DATEPART(hour, pp.[$systemModifiedAt])               AS Hora,
       pp.[$systemModifiedBy]                               AS UsuarioSID,
       COUNT(*)                                             AS Filas,
       MIN(pp.[$systemModifiedAt])                          AS Primera,
       MAX(pp.[$systemModifiedAt])                          AS Ultima
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[Fecha Baja] IN ('2026-05-22', '2026-05-27', '2026-10-12')
GROUP  BY CAST(pp.[$systemModifiedAt] AS date),
          DATEPART(hour, pp.[$systemModifiedAt]),
          pp.[$systemModifiedBy]
ORDER  BY 1, 2;
GO

-- 9.g  El nombre atrás del SID, para no quedarse con un GUID.
SELECT u.[User Security ID], u.[User Name], u.[Full Name]
FROM   dbo.[User] u
WHERE  u.[User Security ID] IN (
        SELECT DISTINCT pp.[$systemModifiedBy]
        FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
        WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
          AND  pp.[Fecha Baja] IN ('2026-05-22', '2026-05-27', '2026-10-12'));
GO

-- 9.h  QUÉ MÁS TOCÓ LA CORRIDA DEL 14/9/2026.
--
--      El 9.f contestó, y contestó otra cosa de la que yo esperaba: las 170
--      filas se escribieron el 14/9/2026 entre las 20:16 y las 20:30, con
--      $systemModifiedBy en el GUID nulo. Sin usuario = no pasó por una sesión
--      de BC; es una escritura directa por SQL. Por eso el 9.g no devuelve
--      nada: ese SID no está en la tabla User.
--
--      O sea que NO fue la cascada de contigüidad del motor. Las fechas 22/5,
--      27/5 y 12/10 son contenido escrito retroactivamente, no el día en que
--      pasó. Y como las tres salieron de la misma corrida, el "evento del
--      13/10" tampoco fue un proceso con la fecha mal: es la misma escritura.
--
--      LA CAUSA. Ojo con el alcance: el 9.h muestra que la tabla ENTERA —66.674
--      filas— se escribió el 14/9/2026 entre las 00:14 y las 20:30. Personal
--      Proyecto no es una tabla que algo dañó: es una tabla que la migración
--      generó completa ese día. Las 170 nóminas cerradas no son daño posterior,
--      son cómo se generaron.
--
--      La derivación está en MigrarPersonalProyecto_4 (INSERT del bloque 3) y,
--      repetida, en MoverEstadosDeTierraANomina (bloque 5). Las dos hacen
--          Fecha Baja = MAX([Fecha Fin]) de los ESTADOS del empleado en ese proyecto.
--      El error es conceptual: deriva la asignación de NÓMINA de la cobertura de
--      estados, como si fuera un intervalo de presencia igual que una marea. No
--      lo es. Los estados de tierra terminan el día antes de embarcar —son
--      contiguos—, así que ese MAX da exactamente alta − 1.
--
--      Por eso PN-ADM-* no tiene ninguna cerrada: el personal de tierra no
--      embarca, sus estados no se van a otro proyecto y la asignación queda
--      abierta.
--
--      EL ARREGLO va en la derivación, no en un UPDATE de parche: al derivar una
--      asignación PN- no hay que cerrarla con MAX([Fecha Fin]). Queda abierta,
--      o se cierra sólo por baja del empleado. La cabecera de
--      MigrarPersonalProyecto_4 justifica el MIN/MAX -"un tripulante puede
--      embarcar tarde o cortar la marea por accidente"- y para una MAREA está
--      bien. Para una nómina no: no es un intervalo de presencia, es
--      pertenencia.
--
--      Esto mira la tabla entera, no sólo las PN-, para ver el alcance real.
SELECT CAST(pp.[$systemModifiedAt] AS date) AS Dia,
       SUM(CASE WHEN pp.[No_ Proyecto] LIKE 'PN-%' THEN 1 ELSE 0 END) AS Nomina,
       SUM(CASE WHEN pp.[No_ Proyecto] LIKE 'PP-%' THEN 1 ELSE 0 END) AS Mareas,
       COUNT(*)                                                       AS Total,
       COUNT(DISTINCT pp.[$systemModifiedBy])                         AS Usuarios,
       MIN(pp.[$systemModifiedAt])                                    AS Primera,
       MAX(pp.[$systemModifiedAt])                                    AS Ultima
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
GROUP  BY CAST(pp.[$systemModifiedAt] AS date)
ORDER  BY 1 DESC;
GO

-- 9.i  El detalle de esa ventana: qué proyectos y con qué fechas quedaron.
--      Si aparecen las seis altas del 13/10 acá, todo el episodio es una sola
--      escritura y no hay nada que arreglar en el código del motor.
SELECT pp.[No_ Proyecto],
       COUNT(*)                                                       AS Filas,
       SUM(CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS Abiertas,
       MIN(pp.[Fecha Alta Asignación])                                AS AltaMin,
       MAX(pp.[Fecha Alta Asignación])                                AS AltaMax,
       MIN(NULLIF(pp.[Fecha Baja], '1753-01-01'))                     AS BajaMin,
       MAX(pp.[Fecha Baja])                                           AS BajaMax
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[$systemModifiedAt] >= '2026-09-14 20:00:00'
   AND pp.[$systemModifiedAt] <  '2026-09-14 21:00:00'
GROUP  BY pp.[No_ Proyecto]
ORDER  BY 2 DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 10 — Estado Empleado, que es donde empieza todo.

   El 4.d de MigrarPersonalProyecto_4 cerró la cadena: las 23 asignaciones de
   PP-119-000308 tienen un estado con Fecha Inicio = 13/10/2026 sobre una marea
   que terminó el 3/6/2026. Los 6 "fantasma" son los que sólo tienen ése.

   Personal Proyecto no inventó nada: derivó MIN/MAX de los estados y los
   estados están mal. Borrar las asignaciones sin limpiar esto las devuelve en
   la próxima corrida de la migración.
--------------------------------------------------------------------------- */

-- 10.a  Los estados de PP-119-000308, por fecha y código. El 13/10 tiene que
--       saltar a la vista contra los de mayo.
SELECT ee.[Fecha Inicio],
       CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN NULL ELSE ee.[Fecha Fin] END AS FechaFin,
       ee.[Cód_ Estado],
       COUNT(*) AS Empleados
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Proyecto] = 'PP-119-000308'
GROUP  BY ee.[Fecha Inicio], ee.[Fecha Fin], ee.[Cód_ Estado]
ORDER  BY 1;
GO

-- 10.b  El control general: estados que empiezan DESPUÉS de que su proyecto
--       terminó, por más de tres días.
--
--       EL UMBRAL NO ES CAPRICHO. Sin él esto devuelve cientos de filas con
--       DiasDespuesDelFin = 1, que es el relevo normal: termina la marea y al
--       día siguiente arranca el franco. Ese estado pertenece al proyecto de
--       nómina, no a la marea, pero el dato no está mal. Lo que no es normal es
--       un estado que empieza meses después.
--
--       Con el umbral quedan cinco fechas: 13/10/2026 (132 días, 29 empleados,
--       PP-119-000308) y cuatro de 2004-2006 con 300 a 382 días, que son los
--       proyectos viejos con Ending Date basura que ya vimos en el bloque 3.
SELECT ee.[Fecha Inicio],
       COUNT(*)                            AS Estados,
       COUNT(DISTINCT ee.[No_ Empleado])   AS Empleados,
       COUNT(DISTINCT ee.[No_ Proyecto])   AS Proyectos,
       MAX(DATEDIFF(day, j.[Ending Date], ee.[Fecha Inicio])) AS DiasDespuesDelFin
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = ee.[No_ Proyecto]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Proyecto] LIKE 'PP-%'
   AND j.[Ending Date] <> '1753-01-01'
   AND ee.[Fecha Inicio] > j.[Ending Date]
   AND DATEDIFF(day, j.[Ending Date], ee.[Fecha Inicio]) > 3
GROUP  BY ee.[Fecha Inicio]
ORDER  BY 2 DESC;
GO

-- 10.c  ¿Y estos estados cuándo se escribieron? Misma pregunta que el 9.f, un
--       escalón más arriba. Si también son del 14/9, vinieron con la migración
--       de estados y no los generó nadie usando el sistema.
SELECT CAST(ee.[$systemModifiedAt] AS date) AS Dia,
       COUNT(*)                             AS Estados,
       COUNT(DISTINCT ee.[$systemModifiedBy]) AS Usuarios,
       MIN(ee.[$systemModifiedAt])          AS Primera,
       MAX(ee.[$systemModifiedAt])          AS Ultima
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] = '2026-10-13'
GROUP  BY CAST(ee.[$systemModifiedAt] AS date), ee.[$systemModifiedBy]
ORDER  BY 1 DESC;
GO

-- 10.d  CONTESTADO, y no era lo que yo esperaba: 17/7/2026 14:56:59, 29 estados
--       en 60 milisegundos. NO vinieron con la migración del 14/9 — son dos
--       meses anteriores.
--
--       LA CADENA COMPLETA, de abajo hacia arriba:
--
--         1. El 17/7/2026 se escriben 29 estados NV en PP-119-000308 fechados
--            13/10/2026 y abiertos. Los mismos 29 ya tenían su NV real de esa
--            marea, 23/5 → 3/6. Ver el 10.a: dos navegaciones en un proyecto.
--
--         2. Estado Empleado mantiene la contigüidad, así que esa inserción
--            CIERRA el 12/10 el estado que cada uno tuviera abierto: el de
--            PP-119-000311 para veintidós, el PN-119-NOMINA para 02804.
--
--         3. El 14/9/2026 la migración deriva Personal Proyecto del MIN/MAX de
--            esos estados, y el 12/10 y el 13/10 quedan escritos en las
--            asignaciones.
--
--       Una sola escritura de estados futuros explica el 12/10, el 13/10, las
--       seis asignaciones fantasma y la nómina cerrada de 02804.
--
--       QUÉ SIGUE, y el orden importa:
--         a. Averiguar qué corrió el 17/7 a las 14:56 (el SID de arriba lo dice).
--         b. Sacar esos 29 estados. Al borrarlos, la contigüidad reabre los que
--            se cerraron el 12/10 — que es lo que se quiere.
--         c. Recién después regenerar Personal Proyecto, con la derivación de
--            las PN- corregida.
--       Borrar las asignaciones antes de esto no sirve: la migración las
--       vuelve a crear igual.
SELECT ee.[No_ Empleado], ee.[No_ Proyecto], ee.[Cód_ Estado],
       ee.[Fecha Inicio],
       CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN NULL ELSE ee.[Fecha Fin] END AS FechaFin,
       ee.[$systemCreatedAt], ee.[$systemCreatedBy],
       ee.[$systemModifiedAt], ee.[$systemModifiedBy]
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] = '2026-10-13'
ORDER  BY ee.[No_ Empleado];
GO

-- 10.e  QUIÉN. El SID de los 29 estados es 8934204A-7B35-4448-95F8-BE1F1158D68A,
--       un GUID real y no el nulo: fue una SESIÓN DE BC, no una escritura SQL.
--       $systemCreatedAt = $systemModifiedAt, 29 filas en 60 ms con timestamps
--       escalonados de 3-4 ms: un bucle dentro de una sola operación AL.
--
--       Todas quedaron fechadas tres meses en el futuro respecto del día en que
--       se escribieron. Eso es la firma de un proceso corrido con el WorkDate de
--       la sesión puesto en una fecha futura.
SELECT u.[User Security ID], u.[User Name], u.[Full Name], u.[State]
FROM   dbo.[User] u
WHERE  u.[User Security ID] = '8934204A-7B35-4448-95F8-BE1F1158D68A';
GO

-- 10.f  ¿HAY MÁS ESTADOS EN EL FUTURO? Ésta es la pregunta general, y no depende
--       de ningún proyecto ni de Meta4: un estado que empieza después de hoy no
--       existe todavía.
--
--       Si sólo aparece el 13/10/2026, fue una vez. Si hay varias fechas o
--       varios SID, el WorkDate futuro es una costumbre y conviene poner una
--       validación en el motor en vez de limpiar a mano cada vez.
SELECT ee.[Fecha Inicio],
       ee.[Cód_ Estado],
       COUNT(*)                                AS Estados,
       COUNT(DISTINCT ee.[No_ Empleado])       AS Empleados,
       COUNT(DISTINCT ee.[No_ Proyecto])       AS Proyectos,
       MIN(ee.[$systemCreatedAt])              AS Escrito,
       COUNT(DISTINCT ee.[$systemCreatedBy])   AS Usuarios
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] > CAST(GETDATE() AS date)
GROUP  BY ee.[Fecha Inicio], ee.[Cód_ Estado]
ORDER  BY 1;
GO

-- 10.g  Qué más escribió esa sesión. Si el proceso tocó otras tablas con la
--       misma fecha, limpiar sólo los estados deja la mitad.
SELECT 'Estado Empleado' AS Tabla, COUNT(*) AS Filas,
       MIN(ee.[$systemCreatedAt]) AS Primera, MAX(ee.[$systemCreatedAt]) AS Ultima
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[$systemCreatedBy] = '8934204A-7B35-4448-95F8-BE1F1158D68A'
  AND  ee.[$systemCreatedAt] >= '2026-07-17' AND ee.[$systemCreatedAt] < '2026-07-18'

UNION ALL
SELECT 'Personal Proyecto', COUNT(*),
       MIN(pp.[$systemCreatedAt]), MAX(pp.[$systemCreatedAt])
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[$systemCreatedBy] = '8934204A-7B35-4448-95F8-BE1F1158D68A'
  AND  pp.[$systemCreatedAt] >= '2026-07-17' AND pp.[$systemCreatedAt] < '2026-07-18'

UNION ALL
SELECT 'Job', COUNT(*),
       MIN(j.[$systemCreatedAt]), MAX(j.[$systemCreatedAt])
FROM   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
WHERE  j.[$systemCreatedBy] = '8934204A-7B35-4448-95F8-BE1F1158D68A'
  AND  j.[$systemCreatedAt] >= '2026-07-17' AND j.[$systemCreatedAt] < '2026-07-18';
GO

/* ---------------------------------------------------------------------------
   BLOQUE 11 — LA LIMPIEZA. Y acá NO hay un DELETE por SQL, a propósito.

   El SID resultó ser ARBUMASA\ULISES.SASOVSKY, y pasó dos veces: un estado el
   23/9/2026 (escrito el 9/7) y veintinueve el 13/10/2026 (escrito el 17/7).
   Las dos veces NV, en un entorno de prueba, corriendo el flujo de asignar
   tripulación con el WorkDate adelantado. El 10.g muestra que esa misma
   operación creó además 23 asignaciones, y un Job dieciséis minutos después.

   POR QUÉ NO POR SQL. Tab60000.EstadoEmpleado tiene ReabrirAnteriorAlBorrar(),
   llamado desde OnDelete: al borrar un estado, reabre el anterior hasta el
   inicio del siguiente —o lo deja abierto si no hay siguiente—. Ese trigger es
   justamente lo que deshace los cierres del 12/10. Un DELETE por SQL no lo
   ejecuta y dejaría los estados anteriores cerrados: el daño que se quiere
   revertir, pero sin la fila que lo explica.

   ENTONCES: borrar los 30 estados DESDE BC, de la página de Estados de
   Empleado.

   OJO CON 04220, que tiene los dos encadenados: su OR en PN-119-NOMINA lo
   cerró el estado del 23/9, y a ese lo cerró el del 13/10. Hay que borrar los
   dos y verificar con el 11.b. El orden no importa, pero si queda uno solo el
   OR no vuelve a abrirse del todo.

   DESPUÉS, y recién después:
     · Regenerar Personal Proyecto con la derivación de las PN- corregida
       (ver el bloque 9.h). Las asignaciones malas se van solas: salían de
       estos estados.
     · El DELETE del bloque 8 queda sin efecto y conviene borrarlo del script,
       para que nadie lo corra pensando que falta.
--------------------------------------------------------------------------- */

-- 11.a  La lista para borrar, con el buque y la marea a la vista.
SELECT ee.[No_ Empleado], ee.[No_ Proyecto], ee.[Cód_ Estado],
       ee.[Fecha Inicio],
       CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN NULL ELSE ee.[Fecha Fin] END AS FechaFin,
       j.[Starting Date] AS ZarpaProyecto, j.[Ending Date] AS FinProyecto
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
LEFT   JOIN dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = ee.[No_ Proyecto]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] > CAST(GETDATE() AS date)
ORDER  BY ee.[Fecha Inicio], ee.[No_ Empleado];
GO

-- 11.b  ANTES Y DESPUÉS. Los estados de esos empleados alrededor del corte.
--       Antes de borrar hay que ver los cerrados el 12/10; después, los mismos
--       tienen que aparecer abiertos o cerrados contra el estado que siga.
SELECT ee.[No_ Empleado], ee.[No_ Proyecto], ee.[Cód_ Estado],
       ee.[Fecha Inicio],
       CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN NULL ELSE ee.[Fecha Fin] END AS FechaFin
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
ORDER  BY ee.[Fecha Fin], ee.[No_ Empleado];
GO

-- 11.c  EL CONTROL QUE FALTA EN EL MOTOR, y es lo único que evita que vuelva.
--
--       Pasó dos veces en ocho días. Limpiar los datos no impide la tercera: lo
--       que la impide es que un NV que arranca después del arribo del proyecto
--       no se pueda guardar. El error en el momento de la carga cuesta bastante
--       menos que esta cadena de tres tablas y dos meses.
--
--       CONTESTADO, y sin zona gris:
--           Dentro del proyecto      58.947
--           Hasta 3 días después          0
--           Más de 3 días después        63
--
--       Cero en el medio. Un NV legítimo nunca arranca después del arribo, ni
--       un día. Los 63 son íntegramente las anomalías: los 29 del 13/10 más los
--       proyectos viejos con Ending Date basura del bloque 3.
--
--       O sea que la validación va estricta, sin tolerancia: Fecha Inicio de un
--       NV no puede pasar el Ending Date del proyecto. Iría en
--       Tab60000.EstadoEmpleado, al lado de ValidarDentroDeFaseDeAlta.
SELECT CASE WHEN ee.[Fecha Inicio] <= j.[Ending Date] THEN 'Dentro del proyecto'
            WHEN DATEDIFF(day, j.[Ending Date], ee.[Fecha Inicio]) <= 3 THEN 'Hasta 3 días después'
            ELSE 'Más de 3 días después' END AS Situacion,
       COUNT(*) AS Estados
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = ee.[No_ Proyecto]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Proyecto] LIKE 'PP-%'
   AND ee.[Cód_ Estado] = 'NV'
   AND j.[Ending Date] <> '1753-01-01'
GROUP  BY CASE WHEN ee.[Fecha Inicio] <= j.[Ending Date] THEN 'Dentro del proyecto'
               WHEN DATEDIFF(day, j.[Ending Date], ee.[Fecha Inicio]) <= 3 THEN 'Hasta 3 días después'
               ELSE 'Más de 3 días después' END
ORDER  BY 2 DESC;
GO

-- 11.d  EL ORDEN DEL BORRADO NO ES INDIFERENTE, y equivocarlo propaga el daño.
--
--       Pasó al intentar la limpieza: se borraron primero las filas que TERMINAN
--       el 12/10 —las víctimas— en vez de las que EMPIEZAN el 13/10.
--
--       Mientras el estado del 13/10 exista, ReabrirAnteriorAlBorrar hace
--           Anterior."Fecha Fin" := Siguiente."Fecha Inicio" - 1
--       y "Siguiente" es justamente el del 13/10. O sea que borrar la víctima le
--       estampa 12/10 al estado que queda antes. Cada borrado corre el 12/10 un
--       escalón más atrás, y parece que se autogenerara.
--
--       Al revés funciona: borrado primero el del 13/10, no hay siguiente, y el
--       anterior queda abierto (Fecha Fin := 0D), que es lo que se busca.
--
--       ENTONCES: borrar por Fecha Inicio = 13/10/2026 y 23/9/2026. Nunca por
--       Fecha Fin.

-- 11.d.1  Cuánto se corrió el 12/10 hacia atrás. Antes de la limpieza eran 26
--         filas (22 NV en PP-119-000311, 1 PS, 1 AU1, 1 OR, 1 NV sin proyecto).
--         Todo lo que exceda eso son estados alcanzados por el borrado en orden
--         equivocado.
SELECT ee.[Cód_ Estado], ee.[No_ Proyecto],
       COUNT(*)                        AS Filas,
       MIN(ee.[Fecha Inicio])          AS InicioMin,
       MAX(ee.[Fecha Inicio])          AS InicioMax
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
GROUP  BY ee.[Cód_ Estado], ee.[No_ Proyecto]
ORDER  BY 3 DESC;
GO

-- 11.d.2  QUÉ SE BORRÓ. No hay auditoría de borrados, así que se busca el hueco:
--         empleados cuyo historial dejó de ser contiguo. Un estado que termina y
--         cuyo siguiente NO empieza al día siguiente es un tramo que se perdió.
--
--         Los de un día son normales si el estado siguiente todavía no se cargó
--         (el último de cada empleado). El filtro deja fuera los abiertos.
WITH Encadenado AS (
    SELECT ee.[No_ Empleado], ee.[Cód_ Estado], ee.[No_ Proyecto],
           ee.[Fecha Inicio], ee.[Fecha Fin],
           LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                         ORDER BY ee.[Fecha Inicio]) AS InicioSiguiente
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND  ee.[Fecha Inicio] >= '2026-01-01'
)
SELECT [No_ Empleado], [Cód_ Estado], [No_ Proyecto],
       [Fecha Inicio], [Fecha Fin], InicioSiguiente,
       DATEDIFF(day, [Fecha Fin], InicioSiguiente) - 1 AS DiasSinEstado
FROM   Encadenado
WHERE  InicioSiguiente IS NOT NULL
  AND  [Fecha Fin] <> '1753-01-01'
  AND  DATEDIFF(day, [Fecha Fin], InicioSiguiente) > 1
ORDER  BY DiasSinEstado DESC, [No_ Empleado];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 12 — RECONSTRUIR LO QUE SE BORRÓ, contra Meta4.

   Después de borrar los estados del 13/10 quedaron NV en PP-119-000310 —una
   marea que terminó el 23/6/2026— con fecha fin 12/10 o abiertos. Las dos cosas
   están mal, y no se arreglan solas: ReabrirAnteriorAlBorrar sólo sabe cerrar
   contra el estado siguiente o abrir si no hay ninguno, y el que seguía —el NV
   del 25/6 en PP-119-000311— se borró cuando la limpieza iba en orden
   equivocado.

   Así que lo que falta no es corregir fechas, es reponer filas. Y el dato está:
   MIG_EstadosM4 tiene el historial real. No hay que reconstruirlo de memoria.

   OJO CON EL RANGO: el bridge llega hasta el 30/6/2026 (bloque 0). Lo que se
   haya borrado de julio en adelante no está ahí y hay que recuperarlo de otra
   punta — de una extracción nueva, o a mano contra el parte de la marea.
--------------------------------------------------------------------------- */

-- 12.a  Qué estados tiene Meta4 en 2026 para los empleados afectados, y cuáles
--       de ésos ya NO están en BC. Cada fila que salga es una que hay que
--       volver a cargar.
WITH Afectados AS (
    -- Los que tenían un estado futuro, más los que quedaron con el 12/10 pegado.
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND (ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
           OR ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                                    'PP-119-000310', 'PP-119-000311'))
)
SELECT m.LEGAJO, m.COD_ESTADO, m.FEC_INICIO, m.FEC_FIN,
       m.BUQUE_M4, m.MAREA,
       'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                    WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
               END
             + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6) AS ProyectoBC
FROM   dbo.MIG_EstadosM4 m
JOIN   Afectados a ON a.Emp = m.LEGAJO
WHERE  m.FEC_INICIO >= '2026-01-01'
   AND NOT EXISTS (
        SELECT 1
        FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = m.LEGAJO
          AND  ee.[Fecha Inicio] = m.FEC_INICIO)
ORDER  BY m.LEGAJO, m.FEC_INICIO;
GO

-- 12.b  El resumen: cuántas filas hay que reponer y de qué estados. Si son
--       pocas decenas se cargan a mano; si son cientos, conviene un INSERT.
WITH Afectados AS (
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND (ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
           OR ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                                    'PP-119-000310', 'PP-119-000311'))
)
SELECT m.COD_ESTADO,
       COUNT(*)                        AS Faltan,
       COUNT(DISTINCT m.LEGAJO)        AS Empleados,
       MIN(m.FEC_INICIO)               AS Desde,
       MAX(m.FEC_INICIO)               AS Hasta
FROM   dbo.MIG_EstadosM4 m
JOIN   Afectados a ON a.Emp = m.LEGAJO
WHERE  m.FEC_INICIO >= '2026-01-01'
   AND NOT EXISTS (
        SELECT 1
        FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = m.LEGAJO
          AND  ee.[Fecha Inicio] = m.FEC_INICIO)
GROUP  BY m.COD_ESTADO
ORDER  BY 2 DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 13 — LA REPOSICIÓN, contra Meta4 y con fechas exactas.

   Faltan 77 estados: 66 son el tríptico de embarque de 22 tripulantes a la
   marea 311 (PL 23/6 en la 310, PS 24/6 y NV 25/6 en la 311), y 11 son las
   cadenas personales de 02297, 02804 y 04220.

   POR QUÉ POR SQL Y NO POR LA PÁGINA, al revés de lo que dije antes. El
   argumento para cargarlas desde BC era que SincronizarContiguidad cierra al
   anterior contra el nuevo. Cierto, pero innecesario: MIG_EstadosM4 tiene
   FEC_INICIO y FEC_FIN reales, así que no hace falta que el trigger deduzca un
   fin — lo tenemos. Y por la página hay dos problemas que por SQL no existen:

     · Insertar un estado sin siguiente lo deja con fin efectivo 31/12/9999, y
       ValidarNoHayLiquidacionesBloqueantes valida contra TODO ese rango. Con
       liquidaciones aprobadas de 2026 en el medio, corta. (Cargando en orden
       inverso —del más nuevo al más viejo— sólo el primero queda expuesto, pero
       sigue siendo una trampa que hay que recordar.)
     · El NV del 14/6 que quedó con fecha fin 12/10 no lo arregla ninguna
       inserción: hay que corregirlo aparte. El 13.b lo hace junto con todo.

   ORDEN: 13.a inserta lo que falta, 13.b alinea las fechas de lo que quedó.
   Los dos leen de Meta4, así que el resultado no depende de en qué orden se
   procesó nada.

   OJO: el bridge llega al 30/6/2026. De julio en adelante estos bloques no
   tocan nada, y si ahí también se borró algo hay que recuperarlo de otra punta.
--------------------------------------------------------------------------- */

-- 13.a  INSERTAR LOS QUE FALTAN. Comentado.
/*
BEGIN TRANSACTION;

WITH Afectados AS (
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND (ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
           OR ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                                    'PP-119-000310', 'PP-119-000311'))
)
INSERT INTO dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Tipo Entidad], [No_ Empleado], [No_ Proyecto], [Fecha Inicio], [Fecha Fin],
     [Cód_ Estado], [Observaciones],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy],
     [$systemModifiedAt], [$systemModifiedBy])
SELECT 0,
       m.LEGAJO,
       'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                    WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
               END
             + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6),
       m.FEC_INICIO,
       ISNULL(m.FEC_FIN, '1753-01-01'),
       m.COD_ESTADO,
       'Repuesto desde Meta4 tras el borrado del 17/9/2026.',
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.MIG_EstadosM4 m
JOIN   Afectados a ON a.Emp = m.LEGAJO
WHERE  m.FEC_INICIO >= '2026-01-01'
   AND m.MAREA IS NOT NULL AND m.MAREA > 0
   AND EXISTS (SELECT 1 FROM dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
               WHERE j.[No_] = 'PP-' + CASE WHEN m.BUQUE_M4 LIKE 'HF%' THEN SUBSTRING(m.BUQUE_M4, 3, 10)
                                            WHEN m.BUQUE_M4 LIKE 'A%'  THEN '1' + SUBSTRING(m.BUQUE_M4, 2, 10)
                                       END
                                    + '-' + RIGHT('000000' + CAST(m.MAREA AS varchar(10)), 6))
   AND NOT EXISTS (
        SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = m.LEGAJO
          AND  ee.[Fecha Inicio] = m.FEC_INICIO);

-- Esperado: 77.
SELECT @@ROWCOUNT AS FilasRepuestas;

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

-- 13.b  ALINEAR LAS FECHAS DE LOS QUE QUEDARON. Comentado.
--       Acá se arregla el NV del 14/6 con su 12/10 heredado, y cualquier otro
--       que el borrado en orden equivocado haya dejado con un fin inventado.
/*
BEGIN TRANSACTION;

WITH Afectados AS (
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND (ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
           OR ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                                    'PP-119-000310', 'PP-119-000311'))
)
UPDATE ee
SET    ee.[Fecha Fin]          = ISNULL(m.FEC_FIN, '1753-01-01'),
       ee.[$systemModifiedAt]  = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   Afectados a ON a.Emp = ee.[No_ Empleado]
JOIN   dbo.MIG_EstadosM4 m ON m.LEGAJO = ee.[No_ Empleado]
                          AND m.FEC_INICIO = ee.[Fecha Inicio]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] >= '2026-01-01'
   AND ee.[Fecha Fin] <> ISNULL(m.FEC_FIN, '1753-01-01');

SELECT @@ROWCOUNT AS FechasCorregidas;

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

-- 13.c  VERIFICACIÓN. OJO: acota a "Fecha Inicio >= 2026-01-01" y por eso NO ve
--       los estados que empezaron en 2025 y seguían abiertos. Dio 0/0 con una
--       fila todavía mal (ver el 13.e). El control bueno es el 13.d.
WITH Afectados AS (
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0
      AND (ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
           OR ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                                    'PP-119-000310', 'PP-119-000311'))
)
SELECT 'Falta en BC' AS Problema, COUNT(*) AS Casos
FROM   dbo.MIG_EstadosM4 m
JOIN   Afectados a ON a.Emp = m.LEGAJO
WHERE  m.FEC_INICIO >= '2026-01-01'
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
                   WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Empleado] = m.LEGAJO
                     AND ee.[Fecha Inicio] = m.FEC_INICIO)

UNION ALL
SELECT 'Fecha Fin distinta de Meta4', COUNT(*)
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   Afectados a ON a.Emp = ee.[No_ Empleado]
JOIN   dbo.MIG_EstadosM4 m ON m.LEGAJO = ee.[No_ Empleado] AND m.FEC_INICIO = ee.[Fecha Inicio]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] >= '2026-01-01'
   AND ee.[Fecha Fin] <> ISNULL(m.FEC_FIN, '1753-01-01');
GO

-- 13.d  CIERRE. El 13.c dio 0/0, pero ese resultado también sale si el CTE
--       Afectados quedó vacío: cero comparaciones, cero diferencias. Esto lo
--       descarta y verifica lo mismo sin depender de ese conjunto.
SELECT 'Empleados comparados (tiene que ser ~29)' AS Control,
       COUNT(DISTINCT ee.[No_ Empleado]) AS Valor
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Proyecto] IN ('PP-119-000308', 'PP-119-000309',
                             'PP-119-000310', 'PP-119-000311')

UNION ALL
SELECT 'Estados en el futuro (tiene que ser 0)',
       COUNT(*)
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] > CAST(GETDATE() AS date)

UNION ALL
SELECT 'Con el 12/10 o el 22/9 pegado (tiene que ser 0)',
       COUNT(*)
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')

UNION ALL
-- El tríptico de embarque a la marea 311: PL 23/6 + PS 24/6 + NV 25/6. La
-- tripulación son 29, no los 22 que faltaban: 29 x 3 = 87.
SELECT 'Tríptico de embarque a la 311 (tiene que ser 87)',
       COUNT(*)
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Inicio] IN ('2026-06-23', '2026-06-24', '2026-06-25')
   AND ee.[No_ Proyecto] IN ('PP-119-000310', 'PP-119-000311')

UNION ALL
-- Días sin estado en 2026: un estado que cierra y cuyo siguiente no arranca al
-- día siguiente. Cero es lo sano; lo que aparezca es un tramo todavía perdido.
SELECT 'Huecos en el historial 2026 (tiene que ser 0)',
       COUNT(*)
FROM   (SELECT ee.[Fecha Fin] AS Fin,
               LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                             ORDER BY ee.[Fecha Inicio]) AS InicioSig
        FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0 AND ee.[Fecha Inicio] >= '2026-01-01') x
WHERE  InicioSig IS NOT NULL
   AND Fin <> '1753-01-01'
   AND DATEDIFF(day, Fin, InicioSig) > 1;
GO

-- 13.e  LO QUE EL FILTRO DEL 13.b DEJÓ AFUERA.
--
--       El 13.b y el 13.c acotan a "Fecha Inicio >= 2026-01-01", y eso fue un
--       error de encuadre: un estado puede EMPEZAR en 2025 y seguir abierto en
--       2026, y entonces el 13/10 igual se lo llevó puesto. Quedó una fila así
--       —02297, AU1 Enfermedad desde el 31/10/2025 en PN-119-NOMINA, cerrada el
--       12/10/2026— y la verificación no la vio porque usaba el mismo filtro.
--
--       El corte tenía que ser por la fecha de FIN, no por la de inicio. Esto
--       corrige por fin y no mira el inicio.
--
--       Para 02297 el valor bueno es el 4/3/2026: su AU9 arranca el 5/3.
SELECT ee.[No_ Empleado], ee.[Cód_ Estado], ee.[No_ Proyecto],
       ee.[Fecha Inicio], ee.[Fecha Fin]      AS FinActual,
       ISNULL(m.FEC_FIN, '1753-01-01')        AS FinSegunMeta4
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
LEFT   JOIN dbo.MIG_EstadosM4 m ON m.LEGAJO = ee.[No_ Empleado]
                               AND m.FEC_INICIO = ee.[Fecha Inicio]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12');
GO

/*
BEGIN TRANSACTION;

UPDATE ee
SET    ee.[Fecha Fin]         = ISNULL(m.FEC_FIN, '1753-01-01'),
       ee.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.MIG_EstadosM4 m ON m.LEGAJO = ee.[No_ Empleado]
                          AND m.FEC_INICIO = ee.[Fecha Inicio]
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] IN ('2026-09-22', '2026-10-12')
   AND ee.[Fecha Fin] <> ISNULL(m.FEC_FIN, '1753-01-01');

SELECT @@ROWCOUNT AS FilasCorregidas;

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 14 — Separar los huecos que dejó el borrado de los que ya estaban.

   El 11.d.2 devolvió 32 huecos, y no todos son de hoy:
     · Los que tienen InicioSiguiente = 13/10/2026 los causa el estado fantasma
       y se cierran solos al borrarlo.
     · El resto son FR en PN-* repartidos por toda la flota, con huecos de 8 a
       143 días. Eso es anterior al borrado.

   Un hueco no prueba que se haya borrado algo: puede ser que Meta4 tampoco
   tenga nada ahí. Lo que lo distingue es si el bridge tiene filas dentro del
   tramo vacío.
--------------------------------------------------------------------------- */

-- 14.a  Huecos con y sin respaldo en Meta4. "Meta4 tiene N" = filas que caen
--       dentro del tramo vacío, o sea que falta cargarlas. "Meta4 no tiene
--       nada" = el hueco existe también en el origen y no hay qué reponer.
WITH Huecos AS (
    SELECT ee.[No_ Empleado] AS Emp, ee.[Cód_ Estado] AS Est, ee.[No_ Proyecto] AS Proy,
           ee.[Fecha Inicio] AS Desde, ee.[Fecha Fin] AS Hasta,
           LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                         ORDER BY ee.[Fecha Inicio]) AS InicioSig
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[Fecha Inicio] >= '2026-01-01'
)
SELECT h.Emp, h.Est, h.Proy, h.Hasta AS CierraEl, h.InicioSig AS SiguienteArranca,
       DATEDIFF(day, h.Hasta, h.InicioSig) - 1 AS DiasSinEstado,
       (SELECT COUNT(*) FROM dbo.MIG_EstadosM4 m
        WHERE  m.LEGAJO = h.Emp
          AND  m.FEC_INICIO > h.Hasta AND m.FEC_INICIO < h.InicioSig) AS Meta4TieneEnElHueco,
       CASE WHEN h.InicioSig = '2026-10-13' THEN 'Lo causa el estado fantasma: se cierra solo'
            WHEN h.Hasta > (SELECT MAX(FEC_INICIO) FROM dbo.MIG_EstadosM4)
                 THEN 'Fuera del rango del bridge: no se puede saber'
            ELSE 'Revisar' END AS Lectura
FROM   Huecos h
WHERE  h.InicioSig IS NOT NULL
  AND  h.Hasta <> '1753-01-01'
  AND  DATEDIFF(day, h.Hasta, h.InicioSig) > 1
ORDER  BY 7 DESC, 6 DESC;
GO

-- 14.b  RANGOS INVERTIDOS: Fecha Fin anterior a Fecha Inicio.
--       ValidarOrdenFechas lo prohíbe desde AL, así que estas filas entraron
--       por SQL salteando el trigger. Son un problema propio, no del borrado.
SELECT ee.[No_ Empleado], ee.[Cód_ Estado], ee.[No_ Proyecto],
       ee.[Fecha Inicio], ee.[Fecha Fin],
       DATEDIFF(day, ee.[Fecha Inicio], ee.[Fecha Fin]) AS Dias,
       ee.[$systemCreatedAt], ee.[$systemCreatedBy]
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Fecha Fin] <> '1753-01-01'
   AND ee.[Fecha Fin] < ee.[Fecha Inicio]
ORDER  BY ee.[Fecha Inicio];
GO

-- 14.c  EL ORIGEN DE LOS RANGOS INVERTIDOS, y su corrección.
--
--       Las tres filas (01541, 02938, 04487: Fecha Inicio 1/7, Fecha Fin 30/6)
--       no las hizo el borrado. Salen de EmpujarSiguienteEstado, en
--       Tab60000.EstadoEmpleado:
--
--           Siguiente."Fecha Inicio" := NuevoInicio;
--           Siguiente.Modify();
--
--       Empuja el INICIO del estado siguiente sin mirar su propio FIN. Cerrás un
--       estado el 30/6, el siguiente se corre al 1/7, y si ese siguiente ya
--       terminaba el 30/6 queda invertido. El guard que había sólo comparaba
--       contra el SUB-siguiente, así que este caso pasaba. Y Modify() sin
--       validación no vuelve a pasar por ValidarOrdenFechas: se escribe sin que
--       nada avise.
--
--       Ya está corregido en AL (ErrEmpujeSinDias): ahora corta y pide decidir
--       qué hacer con el estado que se quedaría sin días. Esto arregla las tres
--       que ya están.
--
--       El valor bueno es el que la contigüidad habría puesto: el día antes del
--       estado siguiente, o en blanco si no hay ninguno.
SELECT ee.[No_ Empleado], ee.[Cód_ Estado], ee.[No_ Proyecto],
       ee.[Fecha Inicio], ee.[Fecha Fin] AS FinActual,
       (SELECT DATEADD(day, -1, MIN(s.[Fecha Inicio]))
        FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
        WHERE  s.[Tipo Entidad] = ee.[Tipo Entidad]
          AND  s.[No_ Empleado] = ee.[No_ Empleado]
          AND  s.[Fecha Inicio] > ee.[Fecha Inicio]) AS FinQueCorresponde
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Fecha Fin] <> '1753-01-01'
   AND ee.[Fecha Fin] < ee.[Fecha Inicio];
GO

/*
BEGIN TRANSACTION;

UPDATE ee
SET    ee.[Fecha Fin] = ISNULL(
           (SELECT DATEADD(day, -1, MIN(s.[Fecha Inicio]))
            FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
            WHERE  s.[Tipo Entidad] = ee.[Tipo Entidad]
              AND  s.[No_ Empleado] = ee.[No_ Empleado]
              AND  s.[Fecha Inicio] > ee.[Fecha Inicio]),
           '1753-01-01'),
       ee.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Fecha Fin] <> '1753-01-01'
   AND ee.[Fecha Fin] < ee.[Fecha Inicio];

-- Esperado: 3.
SELECT @@ROWCOUNT AS FilasCorregidas;

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 15 — Estados abiertos de gente que ya no está.

   Salió del 5.c de MigrarPersonalProyecto_4, que esperaba cuatro filas y devolvió
   doce. Las ocho de más son nóminas de buque, y el bloque 5 las daba como
   "sigue abierta" por su primera rama: HayAbierto = 1, o sea que el empleado
   tiene un estado sin cerrar. Pero el 5.c las elige porque NO tiene ninguna fase
   de alta abierta.

   Las dos reglas dicen lo contrario porque el dato es contradictorio: según los
   estados sigue navegando, según las fases se fue de la empresa.

   TRES DE LOS OCHO —01767, 02442 y 04895— son de los seis que tenían el estado
   fantasma del 13/10. Al borrarlo, ReabrirAnteriorAlBorrar les reabrió el estado
   anterior, y para alguien que ya se había ido esa reapertura sobra: el trigger
   no sabe nada de fases de alta.

   EL ARREGLO VA ACÁ, no en la asignación. Cerrar la nómina dejando el estado
   abierto mueve la inconsistencia de lugar en vez de resolverla — y la próxima
   corrida de la derivación la volvería a abrir, porque lee los estados.
--------------------------------------------------------------------------- */

-- 15.a  El detalle: qué estado quedó abierto y cuándo se fue la persona.
SELECT ee.[No_ Empleado], ee.[Cód_ Estado], ee.[No_ Proyecto],
       ee.[Fecha Inicio],
       b.BajaEmpresa                                       AS SeFueEl,
       DATEDIFF(day, b.BajaEmpresa, ee.[Fecha Inicio])      AS DiasDespuesDeIrse
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] = '1753-01-01'
   AND b.BajaEmpresa <> '1753-01-01'
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01')
ORDER  BY ee.[No_ Empleado];
GO

-- 15.b  CERRARLOS EN LA BAJA DE LA EMPRESA. Comentado.
--
--       Si DiasDespuesDeIrse es negativo, el estado empezó ANTES de la baja y
--       cerrarlo ahí es correcto: se quedó abierto porque nadie lo cerró.
--       Si es positivo, el estado empieza DESPUÉS de que la persona se fue, y
--       eso no se arregla con una fecha de fin — o la fase está mal, o el estado
--       no debería existir. Por eso el UPDATE excluye ese caso.
/*
BEGIN TRAN;

UPDATE ee
SET    ee.[Fecha Fin]          = b.BajaEmpresa,
       ee.[$systemModifiedAt]  = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[Fecha Fin] = '1753-01-01'
   AND b.BajaEmpresa <> '1753-01-01'
   AND b.BajaEmpresa >= ee.[Fecha Inicio]        -- sólo si no invierte el rango
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01');

SELECT @@ROWCOUNT AS EstadosCerrados;

-- COMMIT;   -- o ROLLBACK;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 16 — Fases de alta que dejaron afuera a gente que está trabajando.

   El 15.a se parte en dos. Los cuatro con DiasDespuesDeIrse negativo son
   estados que nadie cerró, y el 15.b los resuelve. Los ocho positivos son otra
   cosa: el estado empieza DESPUÉS de la baja de la empresa.

   Y no son casos viejos. Cinco están en PP-114-000312 y PP-114-000313, las dos
   últimas mareas del A-14, que zarparon el 12 y el 25 de julio de 2026 y siguen
   abiertas. Esa gente está embarcada hoy. El caso extremo es 01339: fase cerrada
   el 31/5/1995 y navegando el 25/7/2026, treinta y un años después.

   O sea que la fase es la que está mal, no el estado. Encaja con que
   ValidarDentroDeFaseDeAlta prohíbe cargar un estado fuera de una fase: estos
   entraron por SQL en la migración, sin pasar por el trigger.

   POR QUÉ IMPORTA MÁS QUE EL RESTO. La fase de alta es de donde sale la
   antigüedad, y además bloquea: con la fase cerrada, cualquier corrección del
   historial de esa persona va a cortar con ErrFueraDeFase.
--------------------------------------------------------------------------- */

-- 16.a  El tamaño: empleados con estados posteriores a su última baja de fase.
--       Sin acotar a los que tienen el estado abierto — ése era el recorte del
--       15.a, que llegó acá por otro camino y no mide esto.
SELECT COUNT(DISTINCT ee.[No_ Empleado]) AS Empleados,
       COUNT(*)                          AS Estados,
       MIN(ee.[Fecha Inicio])            AS PrimerEstadoHuerfano,
       MAX(ee.[Fecha Inicio])            AS UltimoEstadoHuerfano
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND b.BajaEmpresa <> '1753-01-01'
   AND ee.[Fecha Inicio] > b.BajaEmpresa
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01');
GO

-- 16.b  Los que están EMBARCADOS HOY con la fase cerrada. Son los urgentes: su
--       recibo de esta marea depende de esto.
SELECT ee.[No_ Empleado], em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       ee.[No_ Proyecto], ee.[Cód_ Estado], ee.[Fecha Inicio],
       j.[Starting Date] AS ZarpaProyecto, j.[Ending Date] AS FinProyecto,
       b.BajaEmpresa     AS FaseCerradaEl,
       (SELECT MAX(f.[Fecha Alta])
        FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) AS UltimaFaseAlta
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = ee.[No_ Empleado]
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = ee.[No_ Proyecto]
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Proyecto] LIKE 'PP-%'
   AND j.[Ending Date] = '1753-01-01'          -- marea todavía en curso
   AND b.BajaEmpresa <> '1753-01-01'
   AND ee.[Fecha Inicio] > b.BajaEmpresa
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01')
ORDER  BY ee.[No_ Empleado];
GO

-- 16.c  Las fases de esa gente, enteras. Para decidir caso por caso, que es lo
--       que corresponde: no es lo mismo una baja puesta por error —se reabre—
--       que un reingreso al que le falta la fase nueva —se crea—. Un UPDATE
--       masivo elegiría por las dos y una de las dos estaría mal.
SELECT f.[No_ Empleado], em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       f.[Fecha Alta],
       CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN NULL ELSE f.[Fecha Baja] END AS FechaBaja
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
JOIN   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = f.[No_ Empleado]
WHERE  f.[No_ Empleado] IN ('01339', '02678', '02869', '04318', '04551', '04659', '04822', '04845')
ORDER  BY f.[No_ Empleado], f.[Fecha Alta];
GO

-- 16.d  LOS DIEZ, CLASIFICADOS — y sin lista escrita a mano.
--
--       El 16.c hardcodea ocho legajos sacados del 15.a, que miraba sólo los
--       estados ABIERTOS. El 16.a cuenta diez, así que ese listado se come dos.
--       Esto los saca de la misma condición que los cuenta.
--
--       Y los separa, porque no todos se arreglan igual:
--
--         · "Desborde de días"   → la baja de la fase quedó corta. Se extiende.
--           Son 02678 (+17) y 02869 (+2), de 2001.
--
--         · "Reingreso sin fase" → la baja está bien y falta la fase nueva. Es
--           el caso de los eventuales: 04659 tiene nueve fases en cuatro años,
--           04318 ocho en seis. Volvieron en julio de 2026 y nadie cargó el alta.
--
--         · "Revisar a mano"     → 01339, con una sola fase de 1995 y un estado
--           de 2026. Treinta y un años no es un reingreso mal cargado; o le
--           faltan todas las fases del medio, o el legajo se reutilizó.
--
--       El umbral de 90 días separa el desborde del reingreso. No es exacto ni
--       pretende serlo: los casos reales están en 2 y 17 días de un lado, y en
--       33 o más del otro. Si mañana aparece uno en 60, hay que mirarlo.
WITH Huerfanos AS (
    SELECT ee.[No_ Empleado] AS Emp,
           MIN(ee.[Fecha Inicio]) AS PrimerHuerfano,
           MAX(ee.[Fecha Inicio]) AS UltimoHuerfano,
           COUNT(*)               AS Estados,
           MAX(b.BajaEmpresa)     AS BajaEmpresa
    FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
                  FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                  WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
    WHERE  ee.[Tipo Entidad] = 0
      AND  b.BajaEmpresa <> '1753-01-01'
      AND  ee.[Fecha Inicio] > b.BajaEmpresa
      AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                       WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01')
    GROUP  BY ee.[No_ Empleado]
)
SELECT h.Emp, em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       h.BajaEmpresa AS FaseCerradaEl,
       h.PrimerHuerfano, h.UltimoHuerfano, h.Estados,
       DATEDIFF(day, h.BajaEmpresa, h.PrimerHuerfano) AS DiasDeDesborde,
       (SELECT COUNT(*) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE f.[No_ Empleado] = h.Emp) AS CuantasFases,
       -- EL EJE ES CUÁNTAS FASES TIENE, NO CUÁNTOS DÍAS SE PASÓ.
       --
       -- La primera versión cortaba en 90 días y clasificaba mal a tres: 04659
       -- (+33, nueve fases), 04845 (+74, tres) y 04822 (+89, cuatro). Los tres
       -- son eventuales y los mandaba a "extender la baja" — o sea a declarar
       -- contratada a gente que no lo estaba, con la antigüedad y los días
       -- liquidables que eso arrastra.
       --
       -- Una sola fase con un desborde de días es un cierre que quedó corto.
       -- Varias fases cortas es alguien que entra y sale por temporada, y su
       -- estado posterior a la última baja es un reingreso, se pase por dos días
       -- o por dos años.
       CASE WHEN DATEDIFF(day, h.BajaEmpresa, h.PrimerHuerfano) > 3650
            THEN 'Revisar a mano: más de diez años'
            WHEN (SELECT COUNT(*) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                  WHERE f.[No_ Empleado] = h.Emp) > 1
            THEN 'Reingreso sin fase: crear una nueva desde el primer estado'
            ELSE 'Desborde de días: extender la baja de la fase'
       END AS QueCorresponde
FROM   Huerfanos h
JOIN   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = h.Emp
ORDER  BY 9, h.Emp;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 17 — LAS CORRECCIONES DE FASES, en orden y con el conteo esperado.

   Salen del 16.d. Son tres grupos y cada uno se arregla distinto, así que van
   como tres pasos separados. Correr en este orden.

   TABLA: Fase Alta Empleado. PK = (No. Empleado, No. Fase), y "No. Fase" NO es
   autoincremental: hay que calcularlo. "Días" y "Abierta" son columnas reales,
   no FlowFields — las mantiene el código AL, así que por SQL hay que ponerlas
   a mano: Abierta = 1 y Días = 0 en una fase abierta.
--------------------------------------------------------------------------- */

-- 17.a  GRUPO 1: extender la baja de la fase. 4 empleados (02678, 02869, 80146,
--       80247). Una sola fase cada uno y estados que se pasan de 2 a 25 días:
--       el cierre quedó corto. La nueva baja cubre el último estado huérfano.
SELECT f.[No_ Empleado], f.[No_ Fase], f.[Fecha Alta],
       f.[Fecha Baja] AS BajaActual,
       h.HastaEstados AS BajaNueva
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
JOIN  (SELECT ee.[No_ Empleado] AS Emp,
              MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN ee.[Fecha Inicio]
                       ELSE ee.[Fecha Fin] END) AS HastaEstados
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       WHERE  ee.[Tipo Entidad] = 0
       GROUP  BY ee.[No_ Empleado]) h ON h.Emp = f.[No_ Empleado]
WHERE  f.[No_ Empleado] IN ('02678', '02869', '80146', '80247')
   AND f.[Fecha Baja] <> '1753-01-01'
   AND f.[Fecha Baja] < h.HastaEstados;
GO

/*
BEGIN TRAN;

UPDATE f
SET    f.[Fecha Baja]          = h.HastaEstados,
       f.[Días]                = DATEDIFF(day, f.[Fecha Alta], h.HastaEstados),
       f.[$systemModifiedAt]   = SYSUTCDATETIME()
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
JOIN  (SELECT ee.[No_ Empleado] AS Emp,
              MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN ee.[Fecha Inicio]
                       ELSE ee.[Fecha Fin] END) AS HastaEstados
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       WHERE  ee.[Tipo Entidad] = 0
       GROUP  BY ee.[No_ Empleado]) h ON h.Emp = f.[No_ Empleado]
WHERE  f.[No_ Empleado] IN ('02678', '02869', '80146', '80247')
   AND f.[Fecha Baja] <> '1753-01-01'
   AND f.[Fecha Baja] < h.HastaEstados;

-- Esperado: 4.
SELECT @@ROWCOUNT AS FasesExtendidas;

-- COMMIT;   -- o ROLLBACK;
*/

-- 17.b  GRUPO 2: crear la fase del reingreso. 5 empleados (04318, 04551, 04659,
--       04822, 04845), eventuales con 3 a 9 fases. La baja anterior está bien;
--       falta el alta de julio de 2026.
--
--       LA FASE NUEVA QUEDA ABIERTA, y es una decisión, no un dato: el estado
--       huérfano de los cinco está abierto, así que el historial dice que siguen.
--       Si alguno ya se fue, la baja la tiene que cargar nómina — no la puedo
--       deducir de acá.
SELECT ee.[No_ Empleado],
       MIN(ee.[Fecha Inicio]) AS AltaNueva,
       (SELECT MAX(f.[No_ Fase]) + 1
        FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) AS NoFaseNueva
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND ee.[No_ Empleado] IN ('04318', '04551', '04659', '04822', '04845')
   AND ee.[Fecha Inicio] > b.BajaEmpresa
GROUP  BY ee.[No_ Empleado];
GO

/*
BEGIN TRAN;

INSERT INTO dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [No_ Fase], [Fecha Alta], [Cód_ Motivo Alta], [Comentario Alta],
     [Fecha Baja], [Cód_ Motivo Baja], [Comentario Baja], [Días], [Abierta],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT x.Emp,
       x.NoFaseNueva,
       x.AltaNueva,
       'ALT',
       'Reingreso detectado por estados posteriores a la última baja (17/9/2026).',
       '1753-01-01', '', '',
       0, 1,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM  (SELECT ee.[No_ Empleado] AS Emp,
              MIN(ee.[Fecha Inicio]) AS AltaNueva,
              (SELECT MAX(f.[No_ Fase]) + 1
               FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) AS NoFaseNueva
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
                     FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                     WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
       WHERE  ee.[Tipo Entidad] = 0
         AND  ee.[No_ Empleado] IN ('04318', '04551', '04659', '04822', '04845')
         AND  ee.[Fecha Inicio] > b.BajaEmpresa
       GROUP  BY ee.[No_ Empleado]) x;

-- Esperado: 5.
SELECT @@ROWCOUNT AS FasesCreadas;

-- COMMIT;   -- o ROLLBACK;
*/

-- 17.c  VERIFICACIÓN. Después del 17.a y el 17.b, el 16.a tiene que bajar de
--       10 empleados a 1: queda sólo 01339, el de 1995, que va a mano.
--
--       Y recién ahí corré el 15.b: cierra los estados abiertos de quien ya no
--       está. Después del 17.b, los cinco del grupo 2 tienen fase abierta, así
--       que el 15.b no los toca — que es justamente lo que se quiere.
SELECT COUNT(DISTINCT ee.[No_ Empleado]) AS EmpleadosQueQuedan
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = ee.[No_ Empleado]) b
WHERE  ee.[Tipo Entidad] = 0
   AND b.BajaEmpresa <> '1753-01-01'
   AND ee.[Fecha Inicio] > b.BajaEmpresa
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = ee.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01');
GO


/* ---------------------------------------------------------------------------
   BLOQUE 18 — 01339, el caso que quedó a mano.

   Una sola fase, 11/3/1995 al 31/5/1995 (81 días), y dos estados en julio de
   2026. Treinta y un años en el medio.

   DOS HIPÓTESIS QUE SE VEN IGUAL DESDE LA FASE:
     · Legajo reutilizado: otra persona con el mismo número. Entonces no hay que
       crear ninguna fase — hay que separar los dos legajos, y eso es un problema
       distinto y más caro.
     · Misma persona reingresada, con las fases del medio sin migrar. Entonces se
       crea la fase del tramo de 2026 como en el 17.b, y el resto del historial
       queda incompleto pero no roto.

   LO QUE LAS SEPARA es si hay actividad entre medio. Una persona que volvió
   después de treinta y un años no tiene nada en 2005 ni en 2015; un legajo
   reutilizado sí, porque el segundo dueño trabajó.
--------------------------------------------------------------------------- */

-- 18.a  Su historial completo en BC: fases y estados, todo junto y ordenado.
SELECT 'Fase' AS Tipo, f.[Fecha Alta] AS Desde,
       CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN NULL ELSE f.[Fecha Baja] END AS Hasta,
       CAST(f.[No_ Fase] AS varchar(20)) AS Detalle, '' AS Proyecto
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[No_ Empleado] = '01339'

UNION ALL
SELECT 'Estado', ee.[Fecha Inicio],
       CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN NULL ELSE ee.[Fecha Fin] END,
       ee.[Cód_ Estado], ee.[No_ Proyecto]
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Empleado] = '01339'
ORDER  BY 2;
GO

-- 18.b  Qué dice Meta4, que es el historial real. El bridge llega al 30/6/2026,
--       así que los estados de julio no van a estar — pero todo lo anterior sí.
--
--       Si Meta4 tiene actividad entre 1995 y 2026, es un legajo reutilizado o
--       una migración de fases que se comió tramos. Si no tiene NADA, es alguien
--       que volvió después de treinta y un años y sólo falta la fase de 2026.
SELECT YEAR(m.FEC_INICIO) AS Anio, COUNT(*) AS Estados,
       MIN(m.FEC_INICIO) AS Desde, MAX(m.FEC_INICIO) AS Hasta,
       COUNT(DISTINCT m.BUQUE_M4) AS Buques
FROM   dbo.MIG_EstadosM4 m
WHERE  m.LEGAJO = '01339'
GROUP  BY YEAR(m.FEC_INICIO)
ORDER  BY 1;
GO

-- 18.c  La ficha, para el caso de legajo reutilizado. Si el CUIL o la fecha de
--       nacimiento no cuadran con alguien contratado en 1995, son dos personas.
SELECT em.[No_], em.[First Name], em.[Last Name],
       em.[Birth Date], em.[Social Security No_], em.[Employment Date]
FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
WHERE  em.[No_] = '01339';
GO

-- 18.d  CONTESTADO: Meta4 no tiene NI UNA fila de 01339.
--
--       El bridge arranca en 1999, así que su tramo de 1995 no estaría igual.
--       Pero entre 1999 y junio de 2026 —veintisiete años cubiertos— tampoco
--       aparece. No hay historial de un segundo dueño, o sea que NO es un legajo
--       reutilizado: la hipótesis cara queda descartada.
--
--       Lo que sí muestra el 18.c es que la ficha está vacía: sin CUIL, sin
--       fecha de nacimiento, sin fecha de ingreso. Sólo el nombre. Eso no es un
--       empleado activo, es un registro creado para poder asignarlo a la marea.
--
--       Entonces la fase se crea igual que en el 17.b, pero eso sólo desbloquea
--       el dato. Sin CUIL no se lo puede liquidar, y eso lo tiene que completar
--       nómina antes del próximo recibo.
/*
BEGIN TRAN;

INSERT INTO dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [No_ Fase], [Fecha Alta], [Cód_ Motivo Alta], [Comentario Alta],
     [Fecha Baja], [Cód_ Motivo Baja], [Comentario Baja], [Días], [Abierta],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT '01339',
       (SELECT MAX(f.[No_ Fase]) + 1
        FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = '01339'),
       (SELECT MIN(ee.[Fecha Inicio])
        FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Empleado] = '01339'
          AND  ee.[Fecha Inicio] >= '2026-01-01'),
       'ALT',
       'Reingreso 2026. Meta4 no tiene historial de este legajo; la ficha está incompleta (sin CUIL).',
       '1753-01-01', '', '',
       0, 1,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000';

-- Esperado: 1.
SELECT @@ROWCOUNT AS FaseCreada;

-- COMMIT;   -- o ROLLBACK;
*/

-- 18.e  EL PROBLEMA DE ATRÁS, que es más grande que 01339: gente con estados de
--       2026 y la ficha sin CUIL.
--
--       Sin CUIL no hay F.931 ni libro de sueldos. Esto no lo arregla ningún
--       script —el dato no está en ninguna tabla del sistema— pero conviene
--       saber cuántos son antes de liquidar, no después.
SELECT em.[No_], em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       em.[Social Security No_] AS CUIL,
       CASE WHEN em.[Birth Date] = '1753-01-01' THEN NULL ELSE em.[Birth Date] END AS Nacimiento,
       CASE WHEN em.[Employment Date] = '1753-01-01' THEN NULL ELSE em.[Employment Date] END AS Ingreso,
       MAX(ee.[Fecha Inicio]) AS UltimoEstado
FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
JOIN   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[No_ Empleado] = em.[No_] AND ee.[Tipo Entidad] = 0
WHERE  ee.[Fecha Inicio] >= '2026-01-01'
   AND (em.[Social Security No_] = '' OR em.[Social Security No_] IS NULL)
GROUP  BY em.[No_], em.[First Name], em.[Last Name], em.[Social Security No_],
          em.[Birth Date], em.[Employment Date]
ORDER  BY 6 DESC;
GO

-- 18.f  EL 18.e ESTABA MAL PLANTEADO: MIRABA EL CAMPO EQUIVOCADO.
--
--       El 18.e devolvió cientos de filas porque preguntó por [Social Security No_],
--       que está vacío en los 4.810 empleados —incluidos los de administración y el
--       del propio usuario—. Un campo vacío para TODOS no es un dato faltante: es la
--       señal de que el dato vive en otro lado.
--
--       Y vive en otro lado. Buscando en las columnas de la tabla "$ext" aparecen
--       tres candidatos de la personalización Final Version (a423950b-…):
--
--           pat_No_ ident_ AFIP   →  vacío en los 4.810. Descartado.
--           pat_No_ documento     →  el DNI, cargado en 4.733.
--           CIF_NIF               →  EL CUIL, cargado en 4.790, con guiones:
--                                    "20-18131928-4", "23-20139167-9".
--
--       CIF_NIF no salió en la primera búsqueda porque el filtro tenía CUIL, CUIT,
--       DNI, Social y Tax, y a nadie se le ocurre buscar el CUIL argentino bajo el
--       nombre del identificador fiscal español. El que sí lo sabía era el código:
--       Cod110037.AplicarFilaSincNAV escribe el CUIL en los dos campos y lo dice en
--       un comentario. Mirar la tabla antes que el código costó dos vueltas.
--
--       Esto lista las tres columnas, para no volver a buscarlas.
SELECT t.name AS Tabla, c.name AS Columna, ty.name AS Tipo, c.max_length AS Largo
FROM   sys.columns c
JOIN   sys.tables  t  ON t.object_id = c.object_id
JOIN   sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE  t.name LIKE 'ArbuTest$Employee%'
   AND (c.name LIKE '%CUIL%' OR c.name LIKE '%CUIT%' OR c.name LIKE '%DNI%'
        OR c.name LIKE '%Document%' OR c.name LIKE '%Ident%' OR c.name LIKE '%Social%'
        OR c.name LIKE '%Fiscal%' OR c.name LIKE '%Tax%'
        OR c.name LIKE '%CIF%'    OR c.name LIKE '%NIF%')
ORDER  BY t.name, c.name;
GO

-- 18.g  LOS QUE DE VERDAD NO TIENEN CUIL. Son veinte, y se parten en dos grupos que
--       no tienen nada que ver entre sí.
--
--       CUATRO SON FICHAS INCOMPLETAS CON ESTADOS EN 2026:
--           01339 FERNANDO ARIEL LOBO
--           04937 AGUSTIN EDUARDO ABALLAY
--           04938 FRANCISCO JAVIER ABALLAY
--           04939 GASTON EZEQUIEL GAUNA
--       Sin CUIL, sin DNI, sin fecha de nacimiento y sin fecha de ingreso: sólo el
--       nombre y el legajo. Los cuatro tienen estados hasta el 25/7/2026, así que es
--       gente que efectivamente embarcó. Esto lo completa nómina; no hay dato en
--       ninguna tabla del sistema del que sacarlo, y el 18.d ya confirmó que Meta4
--       tampoco tiene una sola fila de 01339.
--
--       DIECISÉIS SON BASURA: el legajo ES el DNI ("18267215", "20.236.609"), no
--       tienen NI UN estado, y MAURICIO IBARRA está dos veces, con punto y sin punto.
--       Son altas a medio hacer de alguna carga vieja. No entran en ninguna
--       liquidación —sin estados no hay nada que liquidar— así que no urgen, pero
--       ensucian toda búsqueda por empleado y conviene darlos de baja.
SELECT em.[No_] AS Legajo, em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       CASE WHEN em.[Birth Date]='1753-01-01' THEN NULL ELSE em.[Birth Date] END AS Nacimiento,
       CASE WHEN em.[Employment Date]='1753-01-01' THEN NULL ELSE em.[Employment Date] END AS Ingreso,
       NULLIF(LTRIM(RTRIM(ex.[pat_No_ documento$a423950b-02e9-4ee0-ab32-61517ce330cb])),'') AS DNI,
       COUNT(ee.[Fecha Inicio]) AS Estados,
       MAX(ee.[Fecha Inicio])   AS UltimoEstado
FROM   dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
LEFT   JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] ex ON ex.[No_] = em.[No_]
LEFT   JOIN dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[No_ Empleado] = em.[No_] AND ee.[Tipo Entidad] = 0
WHERE  LTRIM(RTRIM(ISNULL(ex.[CIF_NIF$a423950b-02e9-4ee0-ab32-61517ce330cb],''))) = ''
GROUP  BY em.[No_], em.[First Name], em.[Last Name], em.[Birth Date], em.[Employment Date],
          ex.[pat_No_ documento$a423950b-02e9-4ee0-ab32-61517ce330cb]
ORDER  BY 6 DESC, 7 DESC;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 19 — LOS 62 ESTADOS QUE QUEDARON FUERA DE TODA FASE.

   Después de las correcciones del día (30 estados futuros borrados, 77
   restaurados de Meta4, 3 rangos invertidos, 1.275 asignaciones re-derivadas,
   4 fases extendidas, 6 fases creadas) el control de huérfanos todavía marca
   62 estados en 42 empleados. NO son un resto de lo de hoy: el 16.d miraba
   estados POSTERIORES a la baja, y estos son casi todos ANTERIORES al alta.
   Es otro problema, que la limpieza de hoy dejó a la vista.

   El código dominante lo dice solo:

       GP 33  ·  FR 12  ·  NV 7  ·  PS 5  ·  OI 3  ·  PI 1  ·  PL 1

   GP y FR —guardia en puerto y franco— son días que Meta4 registra ANTES de
   que exista el alta formal. O sea: la persona ya figuraba haciendo algo
   cuando la fase todavía no había empezado.

   Se parten en tres grupos con remedios distintos.
--------------------------------------------------------------------------- */

-- 19.a  LOS TRES GRUPOS, con su tamaño. Correr esto primero.
;WITH H AS (
  SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini,
         (SELECT MIN(f.[Fecha Alta]) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WHERE f.[No_ Empleado] = ee.[No_ Empleado]) AS PrimerAlta,
         (SELECT COUNT(*) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WHERE f.[No_ Empleado] = ee.[No_ Empleado]) AS Fases
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  WHERE  ee.[Tipo Entidad] = 0
    AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                     WHERE f.[No_ Empleado] = ee.[No_ Empleado] AND ee.[Fecha Inicio] >= f.[Fecha Alta]
                       AND (f.[Fecha Baja] = '1753-01-01' OR ee.[Fecha Inicio] <= f.[Fecha Baja])))
SELECT CASE WHEN Fases = 0        THEN 'A. Sin ninguna fase'
            WHEN Ini < PrimerAlta THEN 'B. Antes del primer alta'
            ELSE                       'C. En un hueco entre dos fases'
       END AS Grupo,
       COUNT(*) AS Estados, COUNT(DISTINCT Emp) AS Empleados
FROM   H
GROUP  BY CASE WHEN Fases = 0 THEN 'A. Sin ninguna fase'
               WHEN Ini < PrimerAlta THEN 'B. Antes del primer alta'
               ELSE 'C. En un hueco entre dos fases' END
ORDER  BY 1;
GO

-- 19.b  GRUPO A — 3 estados, 3 empleados: 04937, 04938 y 04939, los mismos del
--       18.g. Ficha vacía y ni una fase. Se arreglan igual que 01339, pero
--       PRIMERO nómina tiene que completar CUIL, DNI y fecha de ingreso: sin la
--       fecha de ingreso real no hay de dónde sacar el alta de la fase, y
--       ponerle la del estado es inventar antigüedad.
--       NO CORRER NADA ACÁ HASTA TENER ESE DATO.

-- 19.c  GRUPO B — 51 estados, 31 empleados: el estado empieza ANTES del alta de
--       su propia fase. La distancia parte la población en dos, y la línea no es
--       arbitraria —hay un salto de 18 a 32 días sin nadie en el medio—:
--
--       HISTÓRICOS · 22 empleados, 22 estados, huecos de 2 a 62 días. Todos con
--                   su primer estado ANTES de 2025. Se ven en racimos de una
--                   misma fecha —trece legajos 029xx/030xx con alta el 30/3/2002,
--                   cinco 035xx el 11-14/5/2007, cuatro 033xx el 7/2/2005—: son
--                   cargas masivas donde alguien puso la fecha del día en que
--                   cargó, no la del día en que la persona entró.
--
--       RECIENTES · 9 empleados, 29 estados, huecos de 32 a 274 días. TODOS
--                   legajos 048xx/049xx con estados de 2025-2026 y una sola fase
--                   abierta. Son los únicos que importan para liquidar hoy, y acá
--                   la respuesta NO es obvia: pudo ser el alta cargada tarde, o
--                   pudo ser gente que embarcó como eventual antes de que la
--                   efectivizaran, en cuyo caso el alta está BIEN y lo que sobra
--                   es el estado previo. Son dos historias distintas con la misma
--                   forma; la diferencia la sabe nómina, no la base.
--
--       EL EJE ES LA ANTIGÜEDAD DEL ESTADO, NO EL TAMAÑO DEL HUECO. Con un
--       umbral de días —18, que es donde está el salto— los cuatro legajos
--       033xx de 2005 caen en "preguntar", y no hay a quién preguntarle por un
--       alta de hace veintiún años. Mismo error que el 16.d con los 90 días.
SELECT ee.[No_ Empleado] AS Emp, MIN(ee.[Fecha Inicio]) AS PrimerEstado,
       MIN(f.[Fecha Alta]) AS AltaDeLaFase,
       DATEDIFF(day, MIN(ee.[Fecha Inicio]), MIN(f.[Fecha Alta])) AS DiasAntes,
       COUNT(*) AS Huerfanos,
       CASE WHEN MIN(ee.[Fecha Inicio]) < '2025-01-01'
            THEN 'Historico: correr el alta de la fase hacia atras'
            ELSE 'PREGUNTAR A NOMINA: efectivizacion o alta tardia'
       END AS QueCorresponde
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT MIN(f2.[Fecha Alta]) AS [Fecha Alta]
              FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
              WHERE  f2.[No_ Empleado] = ee.[No_ Empleado]) f
WHERE  ee.[Tipo Entidad] = 0
  AND  ee.[Fecha Inicio] < f.[Fecha Alta]
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f3
                   WHERE f3.[No_ Empleado] = ee.[No_ Empleado] AND ee.[Fecha Inicio] >= f3.[Fecha Alta]
                     AND (f3.[Fecha Baja] = '1753-01-01' OR ee.[Fecha Inicio] <= f3.[Fecha Baja]))
GROUP  BY ee.[No_ Empleado]
ORDER  BY 4 DESC;
GO

-- 19.d  GRUPO C — 8 estados, 8 empleados, uno cada uno, en el hueco entre una
--       baja y el alta siguiente. Mismo fenómeno que el B pero contra la fase de
--       un reingreso: seis de los ocho están entre 2 y 13 días antes del alta,
--       o sea la persona ya estaba cuando se cargó el reingreso. Los otros dos
--       —04020 (7 meses) y 02406 (5 semanas)— hay que mirarlos a mano.
--
--       Nótese que SIETE de los ocho son OI o GP, no NV: no son mareas, así que
--       no afectan la liquidación de producción. El único con proyecto de marea
--       es 02406 con un FR de 2001, que ya no se liquida.
SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini, ee.[Cód_ Estado] AS Est,
       ee.[No_ Proyecto] AS Proy,
       (SELECT MAX(f.[Fecha Baja]) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE f.[No_ Empleado] = ee.[No_ Empleado] AND f.[Fecha Baja] < ee.[Fecha Inicio]
          AND f.[Fecha Baja] <> '1753-01-01')                      AS BajaPrevia,
       (SELECT MIN(f.[Fecha Alta]) FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE f.[No_ Empleado] = ee.[No_ Empleado] AND f.[Fecha Alta] > ee.[Fecha Inicio]) AS AltaSiguiente
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad] = 0
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE f.[No_ Empleado] = ee.[No_ Empleado] AND f.[Fecha Alta] <= ee.[Fecha Inicio])
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WHERE f.[No_ Empleado] = ee.[No_ Empleado] AND ee.[Fecha Inicio] >= f.[Fecha Alta]
                     AND (f.[Fecha Baja] = '1753-01-01' OR ee.[Fecha Inicio] <= f.[Fecha Baja]))
ORDER  BY ee.[Fecha Inicio] DESC;
GO

-- 19.e  LA CORRECCIÓN DE LOS QUE NO TIENEN DUDA: correr el alta de la fase hasta
--       el primer estado, sólo para los 22 históricos del grupo B. Ninguno de
--       esos 22 tiene un estado posterior a 2024, así que no cambia ninguna
--       liquidación en curso: lo que arregla es el historial y la antigüedad.
--
--       NO INCLUYE a los 9 legajos 048xx/049xx. Esos esperan la respuesta de
--       nómina, porque las dos historias posibles llevan a correcciones opuestas
--       —mover el alta, o borrar el estado— y elegir mal deja el error escrito.
/*
BEGIN TRAN;

UPDATE f
SET    f.[Fecha Alta]      = h.PrimerEstado,
       f.[Comentario Alta] = LEFT(ISNULL(f.[Comentario Alta],'')
                             + ' Alta corrida al primer estado (17/9/2026): estaba cargada '
                             + CAST(h.DiasAntes AS varchar(10)) + ' dias tarde.', 250),
       f.[$systemModifiedAt] = SYSUTCDATETIME(),
       f.[$systemModifiedBy] = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
JOIN  (SELECT ee.[No_ Empleado] AS Emp, MIN(ee.[Fecha Inicio]) AS PrimerEstado,
              MIN(fx.[Fecha Alta]) AS AltaDeLaFase,
              DATEDIFF(day, MIN(ee.[Fecha Inicio]), MIN(fx.[Fecha Alta])) AS DiasAntes
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       CROSS  APPLY (SELECT MIN(f2.[Fecha Alta]) AS [Fecha Alta]
                     FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                     WHERE  f2.[No_ Empleado] = ee.[No_ Empleado]) fx
       WHERE  ee.[Tipo Entidad] = 0
         AND  ee.[Fecha Inicio] < fx.[Fecha Alta]
         AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f3
                          WHERE f3.[No_ Empleado] = ee.[No_ Empleado] AND ee.[Fecha Inicio] >= f3.[Fecha Alta]
                            AND (f3.[Fecha Baja] = '1753-01-01' OR ee.[Fecha Inicio] <= f3.[Fecha Baja]))
       GROUP  BY ee.[No_ Empleado]
       HAVING MIN(ee.[Fecha Inicio]) < '2025-01-01') h
       ON f.[No_ Empleado] = h.Emp AND f.[Fecha Alta] = h.AltaDeLaFase;

-- Esperado: 22.
SELECT @@ROWCOUNT AS FasesCorridas;

-- CONTROL DE INVARIANTE: ninguna fase puede quedar con la baja antes del alta.
-- Tiene que dar 0. Si da otra cosa, ROLLBACK.
SELECT COUNT(*) AS BajaAntesDelAlta
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Fecha Baja] <> '1753-01-01' AND [Fecha Baja] < [Fecha Alta];

-- CONTROL DE DIRECCIÓN: esta corrección sólo puede correr el alta hacia ATRÁS.
-- Si alguna de las fases tocadas todavía tiene un estado anterior a su alta, la
-- regla no hizo lo que dice. Tiene que dar 0.
SELECT COUNT(*) AS QuedoAlgunEstadoAntes
FROM   dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[Comentario Alta] LIKE '%Alta corrida al primer estado (17/9/2026)%'
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
               WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Empleado] = f.[No_ Empleado]
                 AND ee.[Fecha Inicio] < f.[Fecha Alta]);

-- COMMIT;   -- o ROLLBACK;
*/


/* ---------------------------------------------------------------------------
   BLOQUE 20 — ESTADOS QUE TRANSCURREN EN MAREA Y NO TIENEN MAREA.

   Salió de mirar la ficha de 00794: entre el NV 24/9→5/10 (marea 000307) y el
   PL 12/10 hay un NV 6/10→11/10 SIN proyecto. No es un estado suelto en el
   medio: es la continuación directa del anterior —mismo código, pegado al día
   siguiente— y es el tramo que CIERRA la navegación de esa marea.

   La auditoría no lo detectaba. Los bloques 1 a 5 comparan fechas contra Meta4
   filtrando 'PP-%', así que una fila con el proyecto EN BLANCO se les escapa
   por el mismo agujero por el que se escapaban las PN-.

   ALCANCE. Estados con "Transcurre en Marea" y sin proyecto:

       1999-2006 · ~23.800 filas · NV, PL y PS de toda la flota. Es la era en
                   que Meta4 todavía no registraba la marea de forma confiable
                   (ver [[migracion-estados-meta4]]: el proyecto sale de Devenga
                   Francos, no de ID_MAREA). No se liquida nada de esos años;
                   se deja como está.

       2025-2026 ·      31 filas · ESTO SÍ IMPORTA. Las 31 son continuación
                   pegada al estado anterior, ninguna existe en Meta4, y las
                   escribió la cuenta de sistema (…0001), no una persona.

   No fue una cascada del buque: no hay NI UN estado con Tipo Entidad = 1 en
   esas fechas. Son tres averías distintas con la misma cara.
--------------------------------------------------------------------------- */

-- 20.a  LOS TRES CASOS. El eje NO es la fecha ni el código: es si ya existe otra
--       fila idéntica con proyecto. Sin esa pregunta, los tres duplicados del
--       1/7/2026 se clasifican como "cola partida" y se les copia el proyecto
--       del estado anterior —PP-114-000310— cuando su gemela dice 000311.
;WITH Sospechosas AS (
  SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini, ee.[Fecha Fin] AS Fin,
         ee.[Cód_ Estado] AS Est,
         (SELECT TOP 1 a.[Cód_ Estado] FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
          WHERE a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
            AND a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) AS EstAnterior,
         (SELECT TOP 1 a.[No_ Proyecto] FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
          WHERE a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
            AND a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) AS ProyAnterior,
         (SELECT COUNT(*) FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] g
          WHERE g.[Tipo Entidad]=0 AND g.[No_ Empleado]=ee.[No_ Empleado]
            AND g.[Fecha Inicio]=ee.[Fecha Inicio] AND g.[Fecha Fin]=ee.[Fecha Fin]
            AND g.[Cód_ Estado]=ee.[Cód_ Estado] AND g.[No_ Proyecto] <> '') AS TieneGemelaConProyecto
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
         ON c.[Código] = ee.[Cód_ Estado]
  WHERE  ee.[Tipo Entidad] = 0 AND c.[Transcurre en Marea] = 1
    AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],''))) = ''
    AND  ee.[Fecha Inicio] >= '2025-01-01')
SELECT CASE WHEN TieneGemelaConProyecto > 0 THEN 'C. Duplicado exacto: borrar'
            WHEN EstAnterior = Est          THEN 'A. Cola partida: restaurar el proyecto'
            ELSE                                 'B. Espurio dentro de otro estado: borrar y reunir'
       END AS Caso,
       COUNT(*) AS Filas, COUNT(DISTINCT Emp) AS Empleados, MIN(Ini) AS Fecha
FROM   Sospechosas
GROUP  BY CASE WHEN TieneGemelaConProyecto > 0 THEN 'C. Duplicado exacto: borrar'
               WHEN EstAnterior = Est          THEN 'A. Cola partida: restaurar el proyecto'
               ELSE                                 'B. Espurio dentro de otro estado: borrar y reunir' END
ORDER  BY 1;
GO

-- 20.b  CASO A — 26 filas, 6/10/2025, toda la tripulación del A19 en la marea
--       000307. En Meta4 es UNA sola fila, NV 24/9→11/10 con marea 307; en BC se
--       partió en dos y la cola perdió el proyecto. Meta4 llega justo al 11/10 en
--       los 26, así que no hay que adivinar nada: el proyecto es el del tramo de
--       adelante, PP-119-000307.
--
--       LO QUE CUESTA: NADA EN PLATA. Escribí acá que eran "156 días-hombre de
--       navegación sin imputar" y estaba mal. El motor no cuenta días leyendo el
--       proyecto de cada estado: CalcDiasNavegacionMarea y CalcDiasPuertoMarea
--       (Cod50016) cuentan un RANGO DE FECHAS, y el rango sale de
--       VentanaEmpleadoEnMarea, que lee "Personal Proyecto" y el Job. La ventana
--       de los 26 ya iba del 24/9 al 12/10 —porque el PL del 12/10 sí tenía la
--       marea puesta— así que los seis días se cobraron igual.
--
--       O sea que este grupo, el más grande y el más vistoso, era el inofensivo.
--       Se corrige igual: el historial tiene que decir la verdad, y el día que
--       alguien agregue un cálculo que sí filtre estados por proyecto —contar NV
--       por marea es lo más natural del mundo— la trampa se arma sola.
SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini, ee.[Fecha Fin] AS Fin,
       ant.[No_ Proyecto] AS ProyectoQueLeCorresponde,
       m.FEC_INICIO AS IniEnMeta4, m.FEC_FIN AS FinEnMeta4, CAST(m.MAREA AS varchar(20)) AS MareaM4
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT TOP 1 a.[Cód_ Estado], a.[Fecha Inicio], a.[No_ Proyecto]
              FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
              WHERE  a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
                AND  a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) ant
LEFT   JOIN dbo.MIG_EstadosM4 m
       ON m.LEGAJO=ee.[No_ Empleado] AND m.FEC_INICIO=ant.[Fecha Inicio] AND m.COD_ESTADO=ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad]=0 AND LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],'')))=''
  AND  ee.[Fecha Inicio]='2025-10-06' AND ant.[Cód_ Estado]=ee.[Cód_ Estado]
ORDER  BY 1;
GO

/*
-- 20.b.1  LA CORRECCIÓN DEL CASO A.
--
--         EL CONTROL SE ANOTA LAS FILAS ANTES DE TOCARLAS. La primera versión
--         verificaba "todo lo que empieza el 6/10/2025" y marcaba 9 diferencias
--         que eran estados AU9, GP y OR sentados correctamente en su
--         PN-xxx-NOMINA: no transcurren en marea, y la columna MAREA de Meta4
--         ahí es el contexto del buque, no una marea asignada. El control no
--         estaba mirando lo que la corrección había hecho sino todo lo que
--         compartía la fecha. Al revés del 13.c, que acotaba de menos: acá
--         acotaba de más. En los dos casos el error es el mismo, que el
--         verificador y lo verificado no se refieran al mismo conjunto.
BEGIN TRAN;

SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini, ee.[Fecha Fin] AS Fin,
       ee.[Cód_ Estado] AS Est
INTO   #Corregidas
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT TOP 1 a.[Cód_ Estado], a.[No_ Proyecto]
              FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
              WHERE  a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
                AND  a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) ant
WHERE  ee.[Tipo Entidad]=0
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],''))) = ''
  AND  ee.[Fecha Inicio] = '2025-10-06'
  AND  ant.[Cód_ Estado] = ee.[Cód_ Estado]
  AND  ant.[No_ Proyecto] <> ''
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] g
                   WHERE g.[Tipo Entidad]=0 AND g.[No_ Empleado]=ee.[No_ Empleado]
                     AND g.[Fecha Inicio]=ee.[Fecha Inicio] AND g.[Fecha Fin]=ee.[Fecha Fin]
                     AND g.[Cód_ Estado]=ee.[Cód_ Estado] AND g.[No_ Proyecto] <> '');

-- Esperado: 26.
SELECT COUNT(*) AS ACorregir FROM #Corregidas;

UPDATE ee
SET    ee.[No_ Proyecto]        = ant.[No_ Proyecto],
       ee.[$systemModifiedAt]   = SYSUTCDATETIME(),
       ee.[$systemModifiedBy]   = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT TOP 1 a.[Cód_ Estado], a.[Fecha Inicio], a.[No_ Proyecto]
              FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
              WHERE  a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
                AND  a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) ant
WHERE  ee.[Tipo Entidad]=0
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],''))) = ''
  AND  ee.[Fecha Inicio] = '2025-10-06'
  AND  ant.[Cód_ Estado] = ee.[Cód_ Estado]
  AND  ant.[No_ Proyecto] <> ''
  -- No tocar las que tienen gemela: esas son el caso C y se borran, no se llenan.
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] g
                   WHERE g.[Tipo Entidad]=0 AND g.[No_ Empleado]=ee.[No_ Empleado]
                     AND g.[Fecha Inicio]=ee.[Fecha Inicio] AND g.[Fecha Fin]=ee.[Fecha Fin]
                     AND g.[Cód_ Estado]=ee.[Cód_ Estado] AND g.[No_ Proyecto] <> '');

-- Esperado: 26.
SELECT @@ROWCOUNT AS ProyectosRestaurados;

-- CONTROL DE INVARIANTE, sólo sobre las 26 anotadas: el proyecto restaurado
-- tiene que terminar en la misma marea que Meta4 le da al tramo entero.
-- Tiene que dar 26 coincidencias y 0 diferencias.
SELECT SUM(CASE WHEN ee.[No_ Proyecto] LIKE 'PP-%-' + RIGHT('00000' + CAST(m.MAREA AS varchar(10)), 6)
                THEN 1 ELSE 0 END) AS CoincidenConMeta4,
       SUM(CASE WHEN ee.[No_ Proyecto] LIKE 'PP-%-' + RIGHT('00000' + CAST(m.MAREA AS varchar(10)), 6)
                THEN 0 ELSE 1 END) AS NoCoincidenConMeta4
FROM   #Corregidas x
JOIN   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[Tipo Entidad]=0 AND ee.[No_ Empleado]=x.Emp
      AND ee.[Fecha Inicio]=x.Ini AND ee.[Cód_ Estado]=x.Est
JOIN   dbo.MIG_EstadosM4 m ON m.LEGAJO = x.Emp AND m.COD_ESTADO = x.Est AND m.FEC_FIN = x.Fin;

-- CONTROL DE DIRECCIÓN: esto sólo puede LLENAR proyectos vacíos, nunca cambiar
-- uno que ya estaba. Si el total de filas sin proyecto en 2025-2026 no bajó
-- exactamente 26, la regla tocó de más. Esperado: 5 (los casos B y C).
SELECT COUNT(*) AS SiguenSinProyecto
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[Código]=ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad]=0 AND c.[Transcurre en Marea]=1
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],'')))='' AND ee.[Fecha Inicio]>='2025-01-01';

DROP TABLE #Corregidas;
-- COMMIT;   -- o ROLLBACK;
*/

-- 20.c  CASO B — 2 filas: 01767 y 04096. Acá el estado anterior NO es un NV sino
--       un FR, y Meta4 no tiene ningún NV en esas fechas: tiene el franco entero.
--
--           01767  Meta4: FR 3/10→8/10, OR 9/10→31/10
--                  BC:    FR 3/10→5/10, NV 6/10→8/10 (sin proy), OR 9/10→31/10
--           04096  Meta4: FR 3/10→6/11, OR 7/11→4/1
--                  BC:    FR 3/10→5/10, NV 6/10→6/11 (sin proy), OR 7/11→4/1
--
--       O sea que el NV se metió ADENTRO del franco y lo partió. Son dos
--       personas que estaban de franco y el sistema las muestra navegando.
--
--       ACÁ SÍ HAY PLATA, y al revés de lo que parecía: éste es uno de los dos
--       grupos chicos, y es el que duele. Los flags lo explican —FR tiene
--       "Tipo Estado = Francos" y "Devenga Francos" apagado; NV lo tiene
--       prendido— así que el NV espurio hace las dos cosas malas a la vez:
--
--         · CalcDiasFrancosPeriodo cuenta MENOS francos gozados (3 días para
--           01767, 32 para 04096).
--         · CalcDiasEnrolamientoMarea cuenta MÁS días devengando francos, porque
--           NV devenga y FR no.
--
--       Estaban acumulando francos justo los días que los estaban gozando.
--
--       LA CORRECCIÓN VA EN ESTE ORDEN Y NO EN OTRO: primero borrar el NV,
--       después estirar el FR. Al revés quedarían superpuestos, y el motor de
--       contigüidad al ver la superposición corre fechas por su cuenta (es lo
--       que pasó el 17/9 borrando por Fecha Fin; ver 11.d).
SELECT 'BC' AS Fuente, ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini,
       NULLIF(ee.[Fecha Fin],'1753-01-01') AS Fin, ee.[Cód_ Estado] AS Est, ee.[No_ Proyecto] AS Proy
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad]=0 AND ee.[No_ Empleado] IN ('01767','04096')
  AND  ee.[Fecha Inicio] BETWEEN '2025-09-25' AND '2025-11-10'
UNION  ALL
SELECT 'Meta4', m.LEGAJO, m.FEC_INICIO, m.FEC_FIN, m.COD_ESTADO, CAST(m.MAREA AS varchar(20))
FROM   dbo.MIG_EstadosM4 m
WHERE  m.LEGAJO IN ('01767','04096') AND m.FEC_INICIO BETWEEN '2025-09-25' AND '2025-11-10'
ORDER  BY 2, 3, 1;
GO

/*
-- 20.c.1  LA CORRECCIÓN DEL CASO B. Dos pasos, en orden.
BEGIN TRAN;

-- Guardar a dónde tiene que llegar el franco ANTES de borrar el NV: después de
-- borrarlo ese dato ya no está en ninguna parte.
SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Fin] AS HastaDonde
INTO   #Reunir
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
CROSS  APPLY (SELECT TOP 1 a.[Cód_ Estado] FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
              WHERE a.[Tipo Entidad]=0 AND a.[No_ Empleado]=ee.[No_ Empleado]
                AND a.[Fecha Inicio] < ee.[Fecha Inicio] ORDER BY a.[Fecha Inicio] DESC) ant
WHERE  ee.[Tipo Entidad]=0 AND ee.[Fecha Inicio]='2025-10-06'
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],'')))='' AND ant.[Cód_ Estado] <> ee.[Cód_ Estado];

-- Esperado: 2.
SELECT COUNT(*) AS ANonir FROM #Reunir;

-- PASO 1: borrar el NV espurio.
DELETE ee
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   #Reunir r ON r.Emp = ee.[No_ Empleado]
WHERE  ee.[Tipo Entidad]=0 AND ee.[Fecha Inicio]='2025-10-06'
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],'')))='';

-- Esperado: 2.
SELECT @@ROWCOUNT AS EspuriosBorrados;

-- PASO 2: estirar el franco hasta donde llegaba el NV.
UPDATE ee
SET    ee.[Fecha Fin]          = r.HastaDonde,
       ee.[$systemModifiedAt]  = SYSUTCDATETIME(),
       ee.[$systemModifiedBy]  = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   #Reunir r ON r.Emp = ee.[No_ Empleado]
WHERE  ee.[Tipo Entidad]=0 AND ee.[Fecha Fin]='2025-10-05';

-- Esperado: 2.
SELECT @@ROWCOUNT AS FrancosReunidos;

-- CONTROL CONTRA META4: el franco reunido tiene que dar exactamente el mismo
-- rango que Meta4. Tiene que dar 2 coincidencias y 0 diferencias.
SELECT SUM(CASE WHEN ee.[Fecha Fin] = m.FEC_FIN THEN 1 ELSE 0 END) AS Coinciden,
       SUM(CASE WHEN ee.[Fecha Fin] <> m.FEC_FIN THEN 1 ELSE 0 END) AS Difieren
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.MIG_EstadosM4 m ON m.LEGAJO=ee.[No_ Empleado] AND m.FEC_INICIO=ee.[Fecha Inicio]
                          AND m.COD_ESTADO=ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad]=0 AND ee.[No_ Empleado] IN ('01767','04096')
  AND  ee.[Fecha Inicio]='2025-10-03';

DROP TABLE #Reunir;
-- COMMIT;   -- o ROLLBACK;
*/

-- 20.d  CASO C — 3 filas del 1/7/2026: 01541, 02938 y 04487, buque 114. No son
--       ni cola partida ni estado espurio: son DUPLICADOS EXACTOS. Cada una tiene
--       una gemela con las mismas tres fechas, el mismo código y el proyecto
--       PP-114-000311 puesto. La copia sin proyecto sobra.
--
--       Ojo con 04487: su gemela está ABIERTA (Fecha Fin en blanco), así que hoy
--       hay alguien con dos navegaciones abiertas a la vez, una sin marea.
--
--       ACÁ TAMBIÉN HAY PLATA. CalcDiasEnrolamientoMarea recorre los estados del
--       empleado y SUMA los solapes uno por uno; no deduplica ni podría, porque
--       dos filas iguales son indistinguibles para él. Con NV devengando francos,
--       cada duplicado devenga DOS VECES: 11 días para 01541, 11 para 02938 y 79
--       y contando para 04487, que está abierto.
--
--       Y hay liquidaciones en borrador tocando justo ese tramo: 01541, 02938 y
--       04487 tienen una de PP-114-000311 al 11/7/2026. Son borradores, así que
--       alcanza con recalcularlas; si alguna estuviera emitida haría falta un
--       ajuste, no un recálculo.
SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Inicio] AS Ini,
       NULLIF(ee.[Fecha Fin],'1753-01-01') AS Fin, ee.[Cód_ Estado] AS Est,
       CASE WHEN ee.[No_ Proyecto]='' THEN '(vacia: sobra)' ELSE ee.[No_ Proyecto] END AS Proy
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad]=0 AND ee.[No_ Empleado] IN ('01541','02938','04487')
  AND  ee.[Fecha Inicio]='2026-07-01'
ORDER  BY 1, 5;
GO

/*
-- 20.d.1  LA CORRECCIÓN DEL CASO C: borrar la copia sin proyecto, y sólo si la
--         gemela con proyecto sigue estando. La condición NOT EXISTS no es
--         decorativa: si alguien ya borró la gemela a mano, esta fila deja de ser
--         un duplicado y pasa a ser el único registro de esos días.
BEGIN TRAN;

DELETE ee
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE  ee.[Tipo Entidad]=0
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],''))) = ''
  AND  ee.[Fecha Inicio] >= '2025-01-01'
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] g
               WHERE g.[Tipo Entidad]=0 AND g.[No_ Empleado]=ee.[No_ Empleado]
                 AND g.[Fecha Inicio]=ee.[Fecha Inicio] AND g.[Fecha Fin]=ee.[Fecha Fin]
                 AND g.[Cód_ Estado]=ee.[Cód_ Estado] AND g.[No_ Proyecto] <> '');

-- Esperado: 3.
SELECT @@ROWCOUNT AS DuplicadosBorrados;

-- CONTROL: nadie puede quedar con dos estados abiertos. Tiene que dar 0.
SELECT COUNT(*) AS ConDosAbiertos
FROM  (SELECT [No_ Empleado] FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
       WHERE [Tipo Entidad]=0 AND [Fecha Fin]='1753-01-01'
       GROUP BY [No_ Empleado] HAVING COUNT(*) > 1) x;

-- COMMIT;   -- o ROLLBACK;
*/

-- 20.e  DESPUÉS DE LOS TRES: re-derivar las asignaciones.
--       Estas correcciones se hacen por SQL, o sea por debajo del motor, así que
--       "Personal Proyecto" sigue diciendo lo de antes. Los 26 del caso A ganan
--       seis días de marea 000307 que la asignación todavía no tiene. Correr
--       MigrarPersonalProyecto_4.sql —o al menos su bloque 3.b— para los buques
--       119 y 114. Es la regla de siempre: fases → estados → asignaciones, y
--       nunca al revés.

-- 20.f  Y EL CONTROL QUE FALTABA EN LA AUDITORÍA. Esto tendría que correr junto
--       con los bloques 1 a 3: un estado que transcurre en marea y no tiene
--       marea es una contradicción que no depende de compararse contra nada.
SELECT COUNT(*) AS SinMareaDesde2025
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   dbo.[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
       ON c.[Código] = ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad] = 0 AND c.[Transcurre en Marea] = 1
  AND  LTRIM(RTRIM(ISNULL(ee.[No_ Proyecto],''))) = ''
  AND  ee.[Fecha Inicio] >= '2025-01-01';
GO


/* ---------------------------------------------------------------------------
   BLOQUE 21 — ESTADOS PARTIDOS EN DOS FILAS QUE SON UNA SOLA.

   El 20.b.1 le devolvió el proyecto a la cola del NV de 00794, pero lo dejó
   como dos renglones: NV 24/9→5/10 y NV 6/10→11/10, los dos en PP-119-000307.
   Eso sigue estando mal. En Meta4 es UNA fila, NV 24/9→11/10, y en la ficha
   tiene que verse igual: un tramo de navegación, no dos.

   Dos filas contiguas con el mismo empleado, el mismo código, el mismo proyecto
   y las mismas observaciones no se distinguen en nada. No hay información en el
   corte: unirlas no pierde nada y es la única forma de que el historial diga lo
   que pasó.

   ALCANCE: 99 islas, 100 filas de más (98 cadenas de dos y una de tres). Y al
   contarlas aparece un SEGUNDO corte masivo que no conocíamos:

       18/3/2025 · 33 filas · OR, AU9 y GP sobre proyectos PN-
        6/10/2025 · 26 filas · el NV de la tripulación del A19 (el del 20.b)

   O sea que lo del 6/10 no fue un accidente único. Hay un proceso que parte
   estados en dos, y corrió por lo menos dos veces.

   SE PUEDE BORRAR SIN MIEDO: nada apunta a una fila de Estado Empleado por su
   id. El único campo del esquema que suena a eso —"Estado Origen" en
   Stg Descarga Lin NAV— es un Text[50] de la staging de NAV, no una FK.
--------------------------------------------------------------------------- */

-- 21.a  LAS ISLAS. Se agrupa por empleado + código + proyecto + observaciones, y
--       se corta la isla donde la fila anterior NO termina el día antes.
--
--       VA POR ISLAS Y NO DE A PARES a propósito: hay una cadena de tres filas, y
--       un arreglo que una de a dos la dejaría en dos. Con islas, una corrida de
--       largo N se resuelve en un solo paso, sea N el que sea.
--
--       OJO CON LA FILA ABIERTA: el fin de la isla no es MAX(Fecha Fin) sino el
--       Fecha Fin de la fila que empieza última. Un estado abierto tiene
--       '1753-01-01', que es el MÍNIMO de la columna, así que MAX() dejaría la
--       isla cerrada en la fecha de la anteúltima y convertiría un estado abierto
--       en uno terminado.
;WITH Base AS (
  SELECT [No_ Empleado] AS Emp, [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
         [Cód_ Estado] AS Est, [No_ Proyecto] AS Proy, ISNULL([Observaciones],'') AS Obs
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE  [Tipo Entidad] = 0),
Marca AS (
  SELECT *, CASE WHEN LAG(Fin) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini)
                      = DATEADD(day,-1,Ini) THEN 0 ELSE 1 END AS EmpiezaIsla
  FROM   Base),
Isla AS (
  SELECT *, SUM(EmpiezaIsla) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini
                                   ROWS UNBOUNDED PRECEDING) AS NoIsla
  FROM   Marca)
SELECT YEAR(MIN(Ini)) AS Anio, Est, COUNT(*) AS FilasEnLaIsla,
       MIN(Ini) AS Desde, MAX(Ini) AS UltimoTramo, MIN(Proy) AS Proy, COUNT(DISTINCT Emp) AS x
FROM   Isla
GROUP  BY Emp, Est, Proy, Obs, NoIsla
HAVING COUNT(*) > 1
ORDER  BY 1 DESC, 4 DESC;
GO

-- 21.b  RESUMEN POR AÑO, para decidir hasta dónde llegar.
;WITH Base AS (
  SELECT [No_ Empleado] AS Emp, [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
         [Cód_ Estado] AS Est, [No_ Proyecto] AS Proy, ISNULL([Observaciones],'') AS Obs
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE  [Tipo Entidad] = 0),
Marca AS (
  SELECT *, CASE WHEN LAG(Fin) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini)
                      = DATEADD(day,-1,Ini) THEN 0 ELSE 1 END AS EmpiezaIsla
  FROM   Base),
Isla AS (
  SELECT *, SUM(EmpiezaIsla) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini
                                   ROWS UNBOUNDED PRECEDING) AS NoIsla
  FROM   Marca),
Resumen AS (
  SELECT Emp, Est, Proy, Obs, NoIsla, MIN(Ini) AS Desde, COUNT(*) AS Filas
  FROM   Isla GROUP BY Emp, Est, Proy, Obs, NoIsla HAVING COUNT(*) > 1)
SELECT YEAR(Desde) AS Anio, COUNT(*) AS Islas, SUM(Filas) - COUNT(*) AS FilasDeMas
FROM   Resumen GROUP BY YEAR(Desde) ORDER BY 1 DESC;
GO

/*
-- 21.c  LA UNIÓN. @DesdeAnio acota hasta dónde se toca: 2025 son las que se ven
--       en las fichas de hoy. Para las históricas es exactamente la misma
--       operación —correrla con 1999 y listo—, pero conviene hacerlo en dos
--       tandas para que el control de abajo hable de un conjunto chico.
BEGIN TRAN;

DECLARE @DesdeAnio date = '2025-01-01';

-- El plan de unión se calcula ENTERO ANTES DE TOCAR NADA. Si se recalculara
-- después del DELETE, las islas ya no serían las mismas: es la misma trampa que
-- el 11.d, donde borrar por Fecha Fin movía la Fecha Fin de lo que quedaba.
;WITH Base AS (
  SELECT [No_ Empleado] AS Emp, [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
         [Cód_ Estado] AS Est, [No_ Proyecto] AS Proy, ISNULL([Observaciones],'') AS Obs
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE  [Tipo Entidad] = 0),
Marca AS (
  SELECT *, CASE WHEN LAG(Fin) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini)
                      = DATEADD(day,-1,Ini) THEN 0 ELSE 1 END AS EmpiezaIsla
  FROM   Base),
Isla AS (
  SELECT *, SUM(EmpiezaIsla) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini
                                   ROWS UNBOUNDED PRECEDING) AS NoIsla
  FROM   Marca)
SELECT Emp, Est, Proy, MIN(Ini) AS IniIsla, MAX(Ini) AS IniUltimoTramo, COUNT(*) AS Filas
INTO   #Plan
FROM   Isla
GROUP  BY Emp, Est, Proy, Obs, NoIsla
HAVING COUNT(*) > 1 AND MIN(Ini) >= @DesdeAnio;

-- Los huecos que YA HABÍA entre los empleados que vamos a tocar, para poder
-- comparar después. Va acá, después de armar #Plan y antes de tocar nada.
DECLARE @HuecosAntes int, @HuecosDespues int;
SELECT @HuecosAntes = COUNT(*)
FROM  (SELECT [No_ Empleado] AS Emp, [Fecha Fin] AS Fin,
              LEAD([Fecha Inicio]) OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS SigIni
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
       WHERE  [Tipo Entidad] = 0 AND [Fecha Inicio] >= @DesdeAnio) q
JOIN   #Plan p ON p.Emp = q.Emp
WHERE  q.Fin <> '1753-01-01' AND q.SigIni IS NOT NULL
  AND  q.SigIni <> DATEADD(day, 1, q.Fin);

-- El fin de la isla sale de la fila que empieza última, NO de MAX(Fecha Fin).
ALTER TABLE #Plan ADD FinIsla datetime;
UPDATE p
SET    p.FinIsla = ee.[Fecha Fin]
FROM   #Plan p
JOIN   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[Tipo Entidad]=0 AND ee.[No_ Empleado]=p.Emp AND ee.[Fecha Inicio]=p.IniUltimoTramo
      AND ee.[Cód_ Estado]=p.Est AND ee.[No_ Proyecto]=p.Proy;

-- Esperado: 59 islas y 0 sin fin resuelto.
SELECT COUNT(*) AS Islas, SUM(Filas) - COUNT(*) AS FilasABorrar,
       SUM(CASE WHEN FinIsla IS NULL THEN 1 ELSE 0 END) AS SinFinResuelto
FROM   #Plan;

-- PASO 1: estirar la primera fila de cada isla hasta el fin de la isla.
UPDATE ee
SET    ee.[Fecha Fin]         = p.FinIsla,
       ee.[$systemModifiedAt] = SYSUTCDATETIME(),
       ee.[$systemModifiedBy] = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   #Plan p ON p.Emp = ee.[No_ Empleado] AND p.IniIsla = ee.[Fecha Inicio]
              AND p.Est = ee.[Cód_ Estado]  AND p.Proy    = ee.[No_ Proyecto]
WHERE  ee.[Tipo Entidad] = 0;

SELECT @@ROWCOUNT AS PrimerasFilasEstiradas;

-- PASO 2: borrar los tramos siguientes de cada isla.
DELETE ee
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   #Plan p ON p.Emp = ee.[No_ Empleado] AND p.Est = ee.[Cód_ Estado]
              AND p.Proy = ee.[No_ Proyecto]
WHERE  ee.[Tipo Entidad] = 0
  AND  ee.[Fecha Inicio] >  p.IniIsla
  AND  ee.[Fecha Inicio] <= p.IniUltimoTramo;

SELECT @@ROWCOUNT AS TramosBorrados;

-- CONTROL 1 · NO SE PERDIÓ NI UN DÍA. Esto es lo que hace que la unión sea
-- verificable y no un acto de fe: la suma de días cubiertos por cada isla antes
-- y después tiene que ser la misma. Tiene que dar 0 diferencias.
SELECT COUNT(*) AS IslasConDiasDistintos
FROM   #Plan p
JOIN   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[Tipo Entidad]=0 AND ee.[No_ Empleado]=p.Emp AND ee.[Fecha Inicio]=p.IniIsla
      AND ee.[Cód_ Estado]=p.Est AND ee.[No_ Proyecto]=p.Proy
WHERE  ee.[Fecha Fin] <> p.FinIsla;

-- CONTROL 2 · NO QUEDAN ISLAS EN EL TRAMO TOCADO. Tiene que dar 0.
;WITH Base AS (
  SELECT [No_ Empleado] AS Emp, [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
         [Cód_ Estado] AS Est, [No_ Proyecto] AS Proy, ISNULL([Observaciones],'') AS Obs
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE  [Tipo Entidad] = 0),
Marca AS (
  SELECT *, CASE WHEN LAG(Fin) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini)
                      = DATEADD(day,-1,Ini) THEN 0 ELSE 1 END AS EmpiezaIsla
  FROM   Base),
Isla AS (
  SELECT *, SUM(EmpiezaIsla) OVER (PARTITION BY Emp, Est, Proy, Obs ORDER BY Ini
                                   ROWS UNBOUNDED PRECEDING) AS NoIsla
  FROM   Marca)
SELECT COUNT(*) AS IslasQueQuedan
FROM  (SELECT MIN(Ini) AS Desde FROM Isla GROUP BY Emp, Est, Proy, Obs, NoIsla
       HAVING COUNT(*) > 1) q
WHERE  q.Desde >= @DesdeAnio;

-- CONTROL 3 · NO SE ABRIÓ NI SE CERRÓ NINGÚN ESTADO POR ERROR. La cantidad de
-- estados abiertos tiene que ser la misma de antes: 0 de diferencia.
SELECT COUNT(*) AS EstadosAbiertos
FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Tipo Entidad] = 0 AND [Fecha Fin] = '1753-01-01';

-- CONTROL 4 · NO SE ABRIÓ NINGÚN HUECO. Un estado que antes empataba con el
-- siguiente tiene que seguir empatando.
--
-- ESTE CONTROL CUENTA LA DIFERENCIA, NO EL TOTAL. La primera versión contaba
-- los huecos que quedaban y devolvía 12, que parecían 12 roturas y eran 12
-- huecos que ya estaban —hay 244 en toda la tabla desde 2025—. Un control que
-- mide un absoluto no puede decir si la corrección lo empeoró. Tiene que dar 0.
SELECT @HuecosDespues = COUNT(*)
FROM  (SELECT [No_ Empleado] AS Emp, [Fecha Fin] AS Fin,
              LEAD([Fecha Inicio]) OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS SigIni
       FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
       WHERE  [Tipo Entidad] = 0 AND [Fecha Inicio] >= @DesdeAnio) q
JOIN   #Plan p ON p.Emp = q.Emp
WHERE  q.Fin <> '1753-01-01' AND q.SigIni IS NOT NULL
  AND  q.SigIni <> DATEADD(day, 1, q.Fin);

SELECT @HuecosAntes AS HuecosAntes, @HuecosDespues AS HuecosDespues,
       @HuecosDespues - @HuecosAntes AS HuecosNuevos;

DROP TABLE #Plan;
-- COMMIT;   -- o ROLLBACK;
*/

-- 21.d  Y EL CONTROL QUE FALTABA. Igual que el 20.f: esto tendría que correr con
--       los bloques 1 a 3. Dos filas contiguas idénticas no necesitan a Meta4
--       para saberse mal.
;WITH Base AS (
  SELECT [No_ Empleado] AS Emp, [Fecha Inicio] AS Ini, [Fecha Fin] AS Fin,
         [Cód_ Estado] AS Est, [No_ Proyecto] AS Proy, ISNULL([Observaciones],'') AS Obs
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE  [Tipo Entidad] = 0)
SELECT COUNT(*) AS FilasPartidasDesde2025
FROM   Base b
WHERE  b.Ini >= '2025-01-01'
  AND  EXISTS (SELECT 1 FROM Base a
               WHERE a.Emp = b.Emp AND a.Est = b.Est AND a.Proy = b.Proy AND a.Obs = b.Obs
                 AND a.Fin = DATEADD(day, -1, b.Ini));
GO


/* ---------------------------------------------------------------------------
   BLOQUE 22 — LOS 31 HUECOS DEL HISTORIAL 2026: NO HAY NADA QUE ARREGLAR.

   El 13.d dejó abierto un control en 31: estados de 2026 que cierran y cuyo
   siguiente no arranca al día siguiente. Quedó anotado como pendiente con el
   título "los 31 huecos FR que afectan la liquidación de francos". Ninguna de
   las dos mitades de esa frase era cierta.

   LA FORMA DEL DATO. 28 de los 31 cierran con FR (franco) y reabren con GP
   (guardia en puerto), los otros 3 con OI. Los huecos van de 8 a 88 días y
   suman 1.231 días. Casi todos son legajos 047xx/048xx/049xx.

   TRES PRUEBAS, Y LAS TRES DAN LO MISMO:

     1. META4 TAMPOCO TIENE NADA EN EL HUECO. En los 31, ni una fila entre el
        cierre y la reapertura. No se perdió nada en la migración.

     2. EL ESTADO QUE CIERRA TERMINA DONDE META4 DICE. DiasQueFaltan = 0 en los
        31. No es un franco recortado como los del 20.c: es un franco completo.

     3. LOS 31 CAEN ENTRE FASES, NO ADENTRO DE UNA. Y el encastre es exacto: los
        31 reabren JUSTO el día del alta de una fase nueva, y 29 cierran JUSTO
        el día de la baja de la anterior.

   O SEA QUE NO ES UN HUECO, ES UN DESPIDO. Son eventuales —tienen entre 4 y 14
   fases cada uno— que terminan el franco, se les da la baja, se van a su casa,
   y meses después vuelven con un alta nueva y una guardia en puerto. El
   historial está bien: durante esos 1.231 días esa gente no trabajaba acá.

   Y NO AFECTA LOS FRANCOS. CalcDiasFrancosPeriodo y CalcDiasEnrolamientoMarea
   (Cod50016) suman los solapes de los estados que existen; un día sin estado
   simplemente no suma. Que no sume es lo correcto: no se devengan francos
   estando dado de baja.

   LOS DOS QUE NO CIERRAN CON UNA BAJA son 04785 y 04932, y no son nuevos: el
   bloque 19 ya los tiene marcados como estados huérfanos esperando la respuesta
   de nómina. Los 31 cierran entonces en 29 explicados + 2 ya conocidos, sin
   resto.

   LECCIÓN PARA EL CONTROL, que es lo único que queda de acá: contar huecos
   sobre "Estado Empleado" mirando SÓLO esa tabla no distingue un tramo perdido
   de una persona que se fue. La contigüidad del historial vale DENTRO de una
   fase, no a través de las bajas. El 22.a es el control corregido.
--------------------------------------------------------------------------- */

-- 22.a  EL CONTROL DE HUECOS, ACOTADO A LO QUE DE VERDAD TIENE QUE SER CONTIGUO:
--       los días en que la persona estaba contratada. Tiene que dar 0.
--
--       Reemplaza a la última línea del 13.d, que devolvía 31 y no era un
--       problema. Un control que grita cuando no pasa nada es peor que no tener
--       control: enseña a ignorarlo.
;WITH X AS (
  SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Fin] AS Fin,
         LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                       ORDER BY ee.[Fecha Inicio]) AS SigIni
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  WHERE  ee.[Tipo Entidad] = 0 AND ee.[Fecha Inicio] >= '2026-01-01')
SELECT COUNT(*) AS HuecosDentroDeUnaFase
FROM   X
WHERE  SigIni IS NOT NULL
  AND  Fin <> '1753-01-01'
  AND  DATEDIFF(day, Fin, SigIni) > 1
  -- El hueco sólo es un problema si la persona siguió contratada durante él.
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE f.[No_ Empleado] = X.Emp
                 AND f.[Fecha Alta] <= DATEADD(day, 1, X.Fin)
                 AND (f.[Fecha Baja] = '1753-01-01'
                      OR f.[Fecha Baja] >= DATEADD(day, -1, X.SigIni)));
GO

-- 22.b  Y EL MISMO CONTROL SIN ACOTAR, para tenerlo al lado: da 31, y los 31
--       están explicados arriba. Si algún día este número sube sin que suba el
--       22.a, es gente nueva que se fue, no un problema.
;WITH X AS (
  SELECT ee.[No_ Empleado] AS Emp, ee.[Fecha Fin] AS Fin,
         LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                       ORDER BY ee.[Fecha Inicio]) AS SigIni
  FROM   dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  WHERE  ee.[Tipo Entidad] = 0 AND ee.[Fecha Inicio] >= '2026-01-01')
SELECT COUNT(*) AS HuecosTotales,
       SUM(DATEDIFF(day, Fin, SigIni) - 1) AS DiasSinEstado
FROM   X
WHERE  SigIni IS NOT NULL AND Fin <> '1753-01-01' AND DATEDIFF(day, Fin, SigIni) > 1;
GO
