/*
    PASO 2 de 2 — se ejecuta en la conexión **BC** (SQL Server), después de exportar el bloque 5 del
    paso 1 a la tabla puente dbo.MIG_AusentismosM4. El DDL de la puente está al final.

    QUÉ MIGRA Y QUÉ NO — el alcance es TIERRA, y la razón no es de comodidad.

    El bloque 3.c del paso 1 midió 15.202 ausencias en Meta4:

        Embarcado · ya está en estados    10.412   Meta4 ya las materializó en M4T_HIST_ESTADOS_EMPL
        Embarcado · falta                    945   existen de verdad, pero ver abajo
        Tierra    · falta                  3.845   el 100% de tierra

    LOS 945 DE EMBARCADOS QUEDAN AFUERA A PROPÓSITO. No son duplicados corridos —en una muestra de
    30, sólo 2 tenían un estado cercano—, pero el historial de un embarcado ya es DENSO: cada día
    está cubierto por navegación, franco o puerto. Insertar un AU9 ahí no cae en un hueco, cae encima
    de lo que ya hay, y SincronizarContiguidad cierra el estado anterior en la fecha nueva. O sea que
    reescribe historia existente en silencio — y de esa historia salen los días de "Devenga Francos",
    así que además le mueve el devengo de francos a esa persona.

    En tierra no pasa nada de eso: la línea de tiempo está vacía, no hay qué pisar.

    De los 945, lo que importa es poco: casi todos son de 2000-2008, períodos que no se liquidan ni
    se recalculan. Los posteriores a 2025 sí, y van a mano después de mirarlos uno por uno.

    ORDEN: 1 y 2 miden y hacen el pre-vuelo, el 3 inserta, el 4 verifica.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. LO QUE LLEGÓ A LA PUENTE
------------------------------------------------------------------------------------------------
-- Tiene que dar 3.845 de tierra. Si aparecen embarcados, el bloque 5 del paso 1 se exportó sin el
-- filtro o alguien lo cambió: el INSERT de acá los excluye igual, pero conviene saberlo antes.
SELECT CASE WHEN LEGAJO LIKE '8%' OR LEGAJO LIKE '9%' THEN 'Tierra' ELSE 'Embarcado' END AS Poblacion,
       COUNT(*)                  AS Filas,
       COUNT(DISTINCT LEGAJO)    AS Legajos,
       MIN(FEC_INICIO)          AS Desde,
       MAX(FEC_INICIO)          AS Hasta
FROM   dbo.MIG_AusentismosM4
GROUP  BY CASE WHEN LEGAJO LIKE '8%' OR LEGAJO LIKE '9%' THEN 'Tierra' ELSE 'Embarcado' END;

-- 1.b GUARDA DE DOBLE CARGA. La tabla puente de estados se cargó dos veces en su momento —246.920
--     filas donde tenían que ser 244.010— y el síntoma fue un conteo raro tres pasos después.
--     Una fila repetida exacta acá es eso.
SELECT COUNT(*) AS FilasDuplicadasEnLaPuente
FROM  (SELECT LEGAJO, FEC_INICIO, COD_ESTADO, COUNT(*) AS Veces
       FROM   dbo.MIG_AusentismosM4
       GROUP  BY LEGAJO, FEC_INICIO, COD_ESTADO
       HAVING COUNT(*) > 1) d;

------------------------------------------------------------------------------------------------
-- 2. PRE-VUELO — las cinco cosas que hacen fallar esto. Todas tienen que dar CERO.
------------------------------------------------------------------------------------------------

-- 2.a Códigos de estado que no existen en el catálogo de BC.
--     El paso 1 encontró AU13: cuatro filas de un legajo, sin equivalente. Una fila con un código
--     inexistente NO da error visible: el motor no la reconoce como nada y la ignora al liquidar.
SELECT m.COD_ESTADO, COUNT(*) AS Filas, COUNT(DISTINCT m.LEGAJO) AS Legajos
FROM   dbo.MIG_AusentismosM4 m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                   WHERE c.[Código] = m.COD_ESTADO)
GROUP  BY m.COD_ESTADO;

-- 2.b Legajos que no existen como empleado en BC.
SELECT DISTINCT m.LEGAJO
FROM   dbo.MIG_AusentismosM4 m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
                   WHERE e.[No_] = m.LEGAJO);

-- 2.c Ausencias que caen FUERA de toda fase de alta.
--     Es la misma regla que valida "Estado Empleado".ValidarDentroDeFaseDeAlta, y la que hoy dejó
--     104 estados huérfanos del lado de los embarcados. Insertar por SQL saltea el trigger, así que
--     esto es lo único que lo previene.
SELECT COUNT(*) AS FueraDeFase, COUNT(DISTINCT m.LEGAJO) AS Legajos
FROM   dbo.MIG_AusentismosM4 m
WHERE  (m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%')
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = m.LEGAJO
             AND  f.[Fecha Alta] <= m.FEC_INICIO
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= m.FEC_INICIO));

-- 2.c.2 El detalle de las anteriores, con la fase más cercana al lado. Sirve para ver si es un
--       desfasaje de días —la fase arranca un día tarde— o si de verdad no estaba en la empresa.
SELECT TOP 30 m.LEGAJO, m.FEC_INICIO, m.FEC_FIN, m.COD_ESTADO,
       (SELECT MIN(f.[Fecha Alta]) FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
         WHERE f.[No_ Empleado] = m.LEGAJO AND f.[Fecha Alta] > m.FEC_INICIO) AS FaseSiguienteAlta,
       (SELECT MAX(f.[Fecha Baja]) FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
         WHERE f.[No_ Empleado] = m.LEGAJO AND f.[Fecha Baja] <> '1753-01-01'
           AND f.[Fecha Baja] < m.FEC_INICIO) AS FaseAnteriorBaja
FROM   dbo.MIG_AusentismosM4 m
WHERE  (m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%')
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = m.LEGAJO
             AND  f.[Fecha Alta] <= m.FEC_INICIO
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= m.FEC_INICIO))
ORDER  BY m.LEGAJO, m.FEC_INICIO;

-- 2.d Ausencias que se PISAN con un estado que ya está en BC.
--     Para tierra tendría que dar cero —no tienen ningún estado— y si no da cero, alguien ya cargó
--     algo a mano y hay que mirarlo antes. Dos estados solapados no dan error: dan días contados
--     dos veces.
SELECT COUNT(*) AS SolapanConEstadoExistente
FROM   dbo.MIG_AusentismosM4 m
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON  e.[Tipo Entidad]  = 0
       AND e.[No_ Empleado]  = m.LEGAJO
       AND e.[Fecha Inicio] <= m.FEC_FIN
       AND (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= m.FEC_INICIO)
       -- NO ES SOLAPAMIENTO CONSIGO MISMA. Sin esto, una vez corrido el INSERT el control
       -- devuelve 3.841 "conflictos" que son las propias filas migradas: un estado se pisa
       -- con él mismo. Costó una falsa alarma y frenó la carga por nada.
       AND NOT (e.[Fecha Inicio] = m.FEC_INICIO AND e.[Cód_ Estado] = m.COD_ESTADO)
WHERE  m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%';

-- 2.d.2 ¿QUÉ SON ESOS ESTADOS QUE SE PISAN? — medido el 15/9/2026: 3.841 de 3.845.
--
--     QUÉ PASÓ LA PRIMERA VEZ, y vale anotarlo: el 2.d dio 3.841 y frenamos la carga pensando que
--     los administrativos ya tenían estados. No los tenían. El INSERT ya había corrido, y lo que el
--     control mostraba eran las propias filas migradas solapándose consigo mismas — la Observaciones
--     decía "Migrado de M4T_AUSENTISMOS". El 2.d ahora las excluye.
--
--     Esta consulta sigue sirviendo para lo que fue pensada: si alguna vez aparecen solapamientos de
--     verdad, dice con qué código y de qué origen, que es lo que decide si la ausencia parte un
--     estado envolvente o si hay dos fuentes escribiendo lo mismo.
SELECT e.[Cód_ Estado]                  AS EstadoExistente,
       COUNT(*)                         AS Pares,
       COUNT(DISTINCT m.LEGAJO)         AS Legajos,
       MIN(e.[Fecha Inicio])            AS Desde,
       MAX(e.[Fecha Inicio])            AS Hasta,
       SUM(CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) AS Abiertos,
       MIN(e.[Observaciones])           AS UnaObservacion
FROM   dbo.MIG_AusentismosM4 m
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON  e.[Tipo Entidad]  = 0
       AND e.[No_ Empleado]  = m.LEGAJO
       AND e.[Fecha Inicio] <= m.FEC_FIN
       AND (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= m.FEC_INICIO)
       -- NO ES SOLAPAMIENTO CONSIGO MISMA. Sin esto, una vez corrido el INSERT el control
       -- devuelve 3.841 "conflictos" que son las propias filas migradas: un estado se pisa
       -- con él mismo. Costó una falsa alarma y frenó la carga por nada.
       AND NOT (e.[Fecha Inicio] = m.FEC_INICIO AND e.[Cód_ Estado] = m.COD_ESTADO)
WHERE  m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%'
GROUP  BY e.[Cód_ Estado]
ORDER  BY COUNT(*) DESC;

-- 2.d.3 Diez casos concretos, con la ausencia y el estado que pisa uno al lado del otro.
SELECT TOP 10
       m.LEGAJO, m.FEC_INICIO AS AusenciaDesde, m.FEC_FIN AS AusenciaHasta, m.COD_ESTADO AS AusenciaCod,
       e.[Cód_ Estado] AS EstadoCod, e.[Fecha Inicio] AS EstadoDesde,
       CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN NULL ELSE e.[Fecha Fin] END AS EstadoHasta,
       e.[No_ Proyecto] AS EstadoProyecto, e.[Observaciones]
FROM   dbo.MIG_AusentismosM4 m
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON  e.[Tipo Entidad]  = 0
       AND e.[No_ Empleado]  = m.LEGAJO
       AND e.[Fecha Inicio] <= m.FEC_FIN
       AND (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= m.FEC_INICIO)
       -- NO ES SOLAPAMIENTO CONSIGO MISMA. Sin esto, una vez corrido el INSERT el control
       -- devuelve 3.841 "conflictos" que son las propias filas migradas: un estado se pisa
       -- con él mismo. Costó una falsa alarma y frenó la carga por nada.
       AND NOT (e.[Fecha Inicio] = m.FEC_INICIO AND e.[Cód_ Estado] = m.COD_ESTADO)
WHERE  m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%'
ORDER  BY m.LEGAJO, m.FEC_INICIO;

-- 2.f DE DÓNDE VA A SALIR EL PROYECTO DE CADA AUSENCIA.
--
--     El estado tiene que decir dónde estaba la persona, así que el proyecto sale de "Proyectos
--     Asignados". Pero las asignaciones de los administrativos arrancan el 1/1/2026 y las ausencias
--     van desde 2000: para el histórico no hay asignación vigente que consultar.
--
--     La resolución es en dos pasos y esto muestra cuánto cae en cada uno:
--       a. Asignación VIGENTE a la fecha de la ausencia. Es la respuesta correcta.
--       b. Si no hay, la PRIMERA asignación del empleado. Para tierra es la única que tienen, así
--          que atribuir una vacación de 2004 a su PN-ADM actual es razonable — pero es una
--          atribución, no un dato, y por eso se cuenta aparte.
--       c. Sin ninguna asignación -> queda sin proyecto, como hasta ahora.
SELECT CASE WHEN vig.Proy IS NOT NULL  THEN 'a. Asignación vigente a esa fecha'
            WHEN prim.Proy IS NOT NULL THEN 'b. Primera asignación del empleado (atribuido)'
            ELSE                            'c. Sin asignación — queda sin proyecto' END AS Origen,
       COUNT(*)               AS Filas,
       COUNT(DISTINCT m.LEGAJO) AS Legajos
FROM   dbo.MIG_AusentismosM4 m
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = m.LEGAJO
               AND  pp.[Fecha Alta Asignación] <= m.FEC_INICIO
               AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= m.FEC_INICIO)
             ORDER  BY pp.[Fecha Alta Asignación] DESC) vig
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = m.LEGAJO
             ORDER  BY pp.[Fecha Alta Asignación]) prim
WHERE  m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%'
GROUP  BY CASE WHEN vig.Proy IS NOT NULL  THEN 'a. Asignación vigente a esa fecha'
               WHEN prim.Proy IS NOT NULL THEN 'b. Primera asignación del empleado (atribuido)'
               ELSE                            'c. Sin asignación — queda sin proyecto' END
ORDER  BY 1;

-- 2.e Ausencias que se pisan ENTRE SÍ dentro de la puente. El paso 1 ya lo midió del lado de
--     Meta4; esto lo vuelve a verificar sobre lo que efectivamente se exportó.
SELECT COUNT(*) AS ParesSuperpuestos
FROM   dbo.MIG_AusentismosM4 a
JOIN   dbo.MIG_AusentismosM4 b
       ON  b.LEGAJO = a.LEGAJO
       AND b.FEC_INICIO > a.FEC_INICIO
       AND b.FEC_INICIO <= a.FEC_FIN
WHERE  a.LEGAJO LIKE '8%' OR a.LEGAJO LIKE '9%';

------------------------------------------------------------------------------------------------
-- 3. LA INSERCIÓN  (COMENTADA — descomentar con el bloque 2 en cero)
------------------------------------------------------------------------------------------------
-- POR SQL Y NO POR AL, por lo mismo que la migración de estados: el OnInsert de "Estado Empleado"
-- sincroniza contigüidad y empuja el estado siguiente. Acá las fechas vienen completas de Meta4 y no
-- hay nada que derivar; dejar correr el trigger sobre 3.845 filas movería fechas que ya son las
-- correctas.
--
-- EL PROYECTO SALE DE "PROYECTOS ASIGNADOS", con la resolución que mide el bloque 2.f: la asignación
-- vigente a la fecha de la ausencia y, si no hay —el caso de todo el histórico anterior a 2026—, la
-- primera del empleado. El estado tiene que decir dónde estaba la persona.
--
-- OJO DESPUÉS DE ESTO: NO volver a correr el bloque 5 de MoverEstadosDeTierraANomina sin pensarlo.
-- Ese UPDATE refecha cada asignación contra el MIN/MAX de los estados de su par empleado+proyecto, y
-- con estas ausencias cargadas las asignaciones ADM —que hoy arrancan el 1/1/2026— se irían para
-- atrás hasta 2000. Sería atribuirle al proyecto una antigüedad que no tuvo.
--
-- EL FILTRO DE TIERRA VA ACÁ TAMBIÉN, aunque el paso 1 ya lo aplicó: si alguien exporta de nuevo sin
-- el NOT EXISTS, este INSERT no le mete 945 filas de embarcados encima de su historial.
/*
BEGIN TRANSACTION;

INSERT INTO [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [Fecha Inicio], [Cód_ Estado], [Fecha Fin],
     [Observaciones], [No_ Proyecto], [Tipo Entidad],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT m.LEGAJO,
       m.FEC_INICIO,
       m.COD_ESTADO,
       m.FEC_FIN,
       CAST('Migrado de M4T_AUSENTISMOS. ' + ISNULL(m.COMENT, '') AS nvarchar(250)),
       COALESCE(vig.Proy, prim.Proy, ''),
       0,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.MIG_AusentismosM4 m
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = m.LEGAJO
               AND  pp.[Fecha Alta Asignación] <= m.FEC_INICIO
               AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= m.FEC_INICIO)
             ORDER  BY pp.[Fecha Alta Asignación] DESC) vig
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = m.LEGAJO
             ORDER  BY pp.[Fecha Alta Asignación]) prim
WHERE  (m.LEGAJO LIKE '8%' OR m.LEGAJO LIKE '9%')
  AND  m.FEC_INICIO IS NOT NULL
  AND  m.FEC_FIN IS NOT NULL
  AND  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
               WHERE c.[Código] = m.COD_ESTADO)
  AND  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
               WHERE e.[No_] = m.LEGAJO)
  -- Idempotente: correrlo dos veces no duplica.
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
                   WHERE e.[Tipo Entidad] = 0
                     AND e.[No_ Empleado] = m.LEGAJO
                     AND e.[Fecha Inicio] = m.FEC_INICIO);

PRINT 'Ausencias migradas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 3.b COMPLETAR EL PROYECTO DE LO YA MIGRADO
------------------------------------------------------------------------------------------------
-- POR QUÉ HACE FALTA. La primera corrida del bloque 3 insertó con el proyecto en blanco: la
-- resolución contra "Proyectos Asignados" se agregó después. Volver a correr el INSERT no las
-- arregla —la guarda de idempotencia las saltea— así que las filas ya cargadas se completan acá.
--
-- Es la MISMA resolución del bloque 2.f: asignación vigente a la fecha de la ausencia y, si no hay,
-- la primera del empleado. Sólo toca las filas de esta migración que hoy están sin proyecto, así que
-- correrlo de nuevo no cambia nada.
SELECT COUNT(*) AS SinProyectoTodavia
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Migrado de M4T_AUSENTISMOS%'
  AND  e.[No_ Proyecto] = '';

/*
BEGIN TRANSACTION;

UPDATE e
SET    e.[No_ Proyecto] = COALESCE(vig.Proy, prim.Proy, ''),
       e.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = e.[No_ Empleado]
               AND  pp.[Fecha Alta Asignación] <= e.[Fecha Inicio]
               AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= e.[Fecha Inicio])
             ORDER  BY pp.[Fecha Alta Asignación] DESC) vig
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = e.[No_ Empleado]
             ORDER  BY pp.[Fecha Alta Asignación]) prim
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Migrado de M4T_AUSENTISMOS%'
  AND  e.[No_ Proyecto] = ''
  AND  COALESCE(vig.Proy, prim.Proy, '') <> '';

PRINT 'Estados completados con proyecto: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

-- 3.b.2 Cómo quedó el reparto. Los que sigan sin proyecto son los 436 legajos que nunca tuvieron
--       asignación: gente que ya no está y para la que no hay nada que afirmar.
SELECT CASE WHEN e.[No_ Proyecto] = '' THEN 'Sin proyecto' ELSE e.[No_ Proyecto] END AS Proyecto,
       COUNT(*) AS Estados, COUNT(DISTINCT e.[No_ Empleado]) AS Legajos
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Migrado de M4T_AUSENTISMOS%'
GROUP  BY CASE WHEN e.[No_ Proyecto] = '' THEN 'Sin proyecto' ELSE e.[No_ Proyecto] END
ORDER  BY COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 4. VERIFICACIÓN POSTERIOR
------------------------------------------------------------------------------------------------

-- 4.a Cuánto entró, por código.
SELECT e.[Cód_ Estado], COUNT(*) AS Estados, COUNT(DISTINCT e.[No_ Empleado]) AS Legajos,
       MIN(e.[Fecha Inicio]) AS Desde, MAX(e.[Fecha Inicio]) AS Hasta
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Migrado de M4T_AUSENTISMOS%'
GROUP  BY e.[Cód_ Estado]
ORDER  BY COUNT(*) DESC;

-- 4.b LO QUE ESTO VIENE A ARREGLAR, medido: administrativos que ya no están sin estados.
--     Antes de esto, los 80xxx/90xxx tenían CERO y por eso el bloque 4.a de
--     AuditarAsignacionesSinFase los marcaba a todos como "sin actividad hace dos años".
SELECT COUNT(DISTINCT e.[No_]) AS AdministrativosConEstados
FROM   [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
WHERE  (e.[No_] LIKE '8%' OR e.[No_] LIKE '9%')
  AND  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
               WHERE x.[Tipo Entidad] = 0 AND x.[No_ Empleado] = e.[No_]);

-- 4.c Estados solapados del mismo empleado. Tiene que dar CERO: es lo que rompe el conteo de días.
SELECT COUNT(*) AS Solapados
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] b
       ON  b.[Tipo Entidad] = 0 AND a.[Tipo Entidad] = 0
       AND b.[No_ Empleado] = a.[No_ Empleado]
       AND b.[Fecha Inicio] > a.[Fecha Inicio]
       AND b.[Fecha Inicio] <= a.[Fecha Fin]
WHERE  a.[Fecha Fin] <> '1753-01-01'
  AND  (a.[No_ Empleado] LIKE '8%' OR a.[No_ Empleado] LIKE '9%');

-- 4.d Días de vacaciones por empleado y año, para contrastar contra DIAS_VACACIONES de Meta4.
--     Es el control que cierra el círculo: los mismos números que salieron de M4T_ACUMULADO_RL.
SELECT e.[No_ Empleado] AS LEGAJO, YEAR(e.[Fecha Inicio]) AS Anio,
       SUM(DATEDIFF(day, e.[Fecha Inicio], e.[Fecha Fin]) + 1) AS DiasVacaciones
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Cód_ Estado] = 'AU9'
  AND  e.[Fecha Fin] <> '1753-01-01'
  AND  e.[No_ Empleado] = '90251'        -- el legajo con el que se verificó la fuente
GROUP  BY e.[No_ Empleado], YEAR(e.[Fecha Inicio])
ORDER  BY 2;

------------------------------------------------------------------------------------------------
-- DDL DE LA TABLA PUENTE — crear antes de exportar desde DBeaver
------------------------------------------------------------------------------------------------
/*
IF OBJECT_ID('dbo.MIG_AusentismosM4') IS NOT NULL DROP TABLE dbo.MIG_AusentismosM4;
CREATE TABLE dbo.MIG_AusentismosM4 (
    LEGAJO       varchar(20)  NOT NULL,
    FEC_INICIO  date         NULL,
    FEC_FIN     date         NULL,
    COD_ESTADO    varchar(20)  NULL,
    COMENT       varchar(200) NULL
);
CREATE INDEX IX_MIG_AusentismosM4 ON dbo.MIG_AusentismosM4 (LEGAJO, FEC_INICIO);
*/
