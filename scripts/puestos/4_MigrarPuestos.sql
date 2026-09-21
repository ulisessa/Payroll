/*
    MIGRACIÓN — historial de puestos de Meta4 al atributo PUESTO.

    QUÉ RESUELVE. La producción se valoriza por el PUESTO con el que el tripulante navega,
    que no es la categoría del CCT con la que cobra el sueldo. Hasta ahora ese dato no
    estaba en BC y había que cargarlo a mano, por marea, en Personal Proyecto — y cuando
    no se cargaba, la producción salía del eje equivocado sin dar ningún error. Comprobado
    en A28/59: cinco tripulantes cobraron de menos 4.073.665,12 pesos por eso.

    ORDEN DE EJECUCIÓN, y la parte que no es SQL:

      0. PUBLICAR LA EXTENSIÓN. Este script no puede correr antes: usa "Espejo De" = 3
         (Puesto) y "Par CCT a Usar" = 2 (Puesto), dos valores de enum que se agregaron
         junto con ParDePuesto en Cod50080 y el despacho en Cod50014. Sin publicar, el
         valor 3 entra en la tabla pero ningún código sabe qué hacer con él.
      1. perl 1_NormalizarHistorialPuestos.pl <csv> puestos_norm.psv
      2. perl 2_GenerarStaging.pl            -> cargaPuestos.sql
      3. sqlcmd -i cargaPuestos.sql          (llena #Puesto: 10.107 filas)
      4. este script, en la MISMA sesión de sqlcmd que el paso 3 — #Puesto es temporal.

    LA NORMALIZACIÓN NO ES COSMÉTICA. En el volcado crudo, 102 vigencias abiertas estaban
    pisadas por una fila posterior y 43 tenían un FEC_FIN que se metía dentro de la
    siguiente. Una fila sin FEC_FIN no significa "vigente hoy": significa "abierta cuando
    se escribió". Es la misma trampa que las islas de Estado Empleado — el fin sale de la
    fila que ARRANCA última, nunca del máximo de FEC_FIN, porque el blanco es el mínimo de
    la columna.

    LO QUE NO SE MIGRA, Y POR QUÉ NO ES UN PROBLEMA. De las 14.810 vigencias normalizadas
    entran 10.107. Quedan afuera 1.633 de gente que no existe en BC y 3.070 de puestos de
    tierra (PN1, PP2, PF2…) y de DES "Desconocido". Sin fila de puesto, el concepto se
    evalúa con la categoría del encuadre, que es exactamente el comportamiento de hoy: el
    fallback es no cambiar nada. Por eso no hay que inventarle un código a ningún puesto.

    LOS 42 ACTIVOS CON PUESTO "DES". Son el 12,5% de la nómina y quedan en el fallback.
    No lo arregla esta migración: falta el dato en el origen.
*/

DECLARE @App nvarchar(40) = 'd4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';

-- ─── 1. EL TIPO DE ATRIBUTO ────────────────────────────────────────────────────
-- Espejo De = 3 (Puesto). Copia el MISMO maestro que CATEGORIA —los puestos de a bordo
-- se expresan con códigos de categoría— pero es un espejo aparte para que ParDeEntidad y
-- ParDePuesto puedan distinguirse: los dos buscan su tipo POR el espejo, y con los dos
-- declarando "Categoría CCT" ese FindFirst devolvería cualquiera de los dos.
--
-- CON "Nombre Variable" y CON "Cód. Clase", como los otros seis tipos. Los dos parecen
-- decorativos y no lo son:
--
--   · Cód. Clase = EMPLEADO. PlantillaAtributosLiq filtra por clase, así que en blanco el
--     atributo NO aparece al abrir los atributos de un empleado: sólo se podría cargar por
--     SQL.
--   · Nombre Variable = PUESTO. No es para que una fórmula lea el número —el puesto elige
--     con qué categoría se resuelven los parámetros, y de eso se encarga el par—. Es que
--     LoadAtributos además llama a GuardarValorTexto, y ESO es lo que hace que el puesto
--     quede registrado en el resumen de variables de la liquidación. Sin nombre, el puesto
--     decide la categoría y no queda rastro de él en ningún lado: invisible en el recibo y
--     en la página de detalle del cálculo, que es exactamente el problema que esta
--     migración vino a resolver.
--
-- OBLIGATORIO = 0, y es el único de los siete que no lo es. Hay 42 activos sin puesto —los
-- DES de Meta4— y su fallback a la categoría del encuadre depende de que no lo sea. Con
-- Obligatorio = 1, PlantillaAtributosLiq les crearía una vigencia vacía a todos.
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
               WHERE [Código] = 'PUESTO')
-- TODAS las columnas, aunque varias vayan en blanco: en BC ninguna admite NULL, y omitir
-- una no la deja en su valor por defecto — hace fallar el INSERT entero.
INSERT INTO dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Código], [Descripción], [Tipo Dato], [Tipo Entidad], [Obligatorio], [Nombre Variable],
     [Cód_ Clase], [Cód_ Tipo Atributo Padre], [Espejo De],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
VALUES ('PUESTO', 'Puesto a bordo', 2, 0, 0, 'PUESTO',
        'EMPLEADO', '', 3,
        NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                 SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000');

-- ─── 2. LOS VALORES, espejados del maestro de categorías ───────────────────────
-- Equivale a la acción "Resincronizar" de la página de tipos de atributo, que después de
-- publicar también los mantiene sola en cada alta, renombrado y baja de una categoría
-- (Cod50078, rama Puesto). Se hace acá para no depender de que alguien la ejecute.
INSERT INTO dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Tipo Atributo], [Cód_ Valor Padre], [Código], [Descripción], [Valor Numérico],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT 'PUESTO', c.[Cód_ Convenio], c.[Código], c.[Descripción], c.[_ Escala],
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
                   WHERE v.[Cód_ Tipo Atributo] = 'PUESTO'
                     AND v.[Cód_ Valor Padre] = c.[Cód_ Convenio] AND v.[Código] = c.[Código]);

-- ─── 3. EL CONVENIO DE CADA VIGENCIA ───────────────────────────────────────────
-- La clave de un valor de atributo encadenado es (tipo, PADRE, código), y el padre de una
-- categoría es su convenio. El staging trae sólo el código de categoría, así que el
-- convenio hay que resolverlo: es el que el empleado tenía EN ESA FECHA, del atributo
-- CONVENIO. No sirve el convenio actual — un oficial cambia de convenio al cambiar de
-- flota, y la vigencia de puesto de 2019 tiene que colgar del convenio de 2019.
IF OBJECT_ID('tempdb..#PuestoConv') IS NOT NULL DROP TABLE #PuestoConv;
SELECT p.Leg, p.Desde, p.Hasta, p.Cat,
       (SELECT TOP 1 cv.[Cód_ Valor]
        FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] cv
        WHERE  cv.[Tipo Entidad] = 0 AND cv.[Cód_ Entidad] = p.Leg
          AND  cv.[Cód_ Tipo Atributo] = 'CONVENIO'
          AND  cv.[Vigencia Desde] <= p.Desde
          AND  (cv.[Vigencia Hasta] >= p.Desde OR cv.[Vigencia Hasta] = '1753-01-01')
        ORDER  BY cv.[Vigencia Desde] DESC) AS Conv
INTO   #PuestoConv
FROM   #Puesto p;

-- CONTROL A · CUÁNTAS QUEDAN SIN CONVENIO. No es un error fatal: una vigencia de puesto de
-- 1994 puede ser anterior a cualquier convenio cargado. Esas NO se migran, porque un valor
-- sin padre no resuelve contra Categoría CCT y daría importe cero en silencio — que es
-- justo el error que este mecanismo viene a evitar.
SELECT COUNT(*) AS TotalStaging,
       SUM(CASE WHEN Conv IS NULL OR Conv = '' THEN 1 ELSE 0 END) AS SinConvenio,
       SUM(CASE WHEN Conv IS NOT NULL AND Conv <> '' THEN 1 ELSE 0 END) AS Migrables
FROM   #PuestoConv;

-- CONTROL B · EL PAR (convenio, categoría) TIENE QUE EXISTIR. Acá es donde aparece el
-- hueco de OF06, que está en 768/19 y no en 175/75: un Segundo Oficial de Máquinas
-- embarcado en un tangonero no tendría categoría. Las que fallen no se migran.
SELECT TOP 20 pc.Conv, pc.Cat, COUNT(*) AS Vigencias
FROM   #PuestoConv pc
WHERE  pc.Conv IS NOT NULL AND pc.Conv <> ''
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                   WHERE c.[Cód_ Convenio] = pc.Conv AND c.[Código] = pc.Cat)
GROUP  BY pc.Conv, pc.Cat ORDER BY COUNT(*) DESC;
GO

/*
-- ─── 4. LA CARGA ───────────────────────────────────────────────────────────────
BEGIN TRAN;

INSERT INTO dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Tipo Entidad], [Cód_ Entidad], [Cód_ Tipo Atributo], [Vigencia Desde], [Vigencia Hasta],
     [Cód_ Valor], [Cód_ Valor Padre], [Valor Decimal], [Valor Texto], [Valor Fecha], [Valor Numérico],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT 0, pc.Leg, 'PUESTO', pc.Desde, pc.Hasta, pc.Cat, pc.Conv, 0, '', '1753-01-01',
       ISNULL((SELECT c.[_ Escala] FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
               WHERE c.[Cód_ Convenio] = pc.Conv AND c.[Código] = pc.Cat), 0),
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   #PuestoConv pc
WHERE  pc.Conv IS NOT NULL AND pc.Conv <> ''
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
               WHERE c.[Cód_ Convenio] = pc.Conv AND c.[Código] = pc.Cat)
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
                   WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = pc.Leg
                     AND a.[Cód_ Tipo Atributo] = 'PUESTO' AND a.[Vigencia Desde] = pc.Desde);

SELECT @@ROWCOUNT AS VigenciasCargadas;

-- CONTROL 1 · NINGÚN SOLAPE POR EMPLEADO. La invariante de Atributo Entidad Liq.: dos
-- vigencias del mismo tipo no pueden pisarse. Acá se mide en ABSOLUTO y no como
-- diferencia porque el atributo PUESTO no existía: todo lo que haya es de esta carga.
-- Tiene que dar 0 filas.
;WITH V AS (
    SELECT [Cód_ Entidad] AS Leg, [Vigencia Desde] AS D, [Vigencia Hasta] AS H,
           LEAD([Vigencia Desde]) OVER (PARTITION BY [Cód_ Entidad] ORDER BY [Vigencia Desde]) AS SigD
    FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE  [Cód_ Tipo Atributo] = 'PUESTO')
SELECT Leg, CONVERT(varchar(10),D,103) AS Desde, CONVERT(varchar(10),H,103) AS Hasta,
       CONVERT(varchar(10),SigD,103) AS SiguienteDesde
FROM   V WHERE SigD IS NOT NULL AND (H = '1753-01-01' OR H >= SigD);

-- CONTROL 2 · NINGÚN INACTIVO CON PUESTO VIGENTE. Una vigencia de puesto no puede
-- sobrevivir a la relación laboral: es el mismo error que el GP sin cerrar que infló el
-- sueldo de puerto de cinco tripulantes en A28/59.
-- Tiene que dar 0 filas.
SELECT TOP 20 a.[Cód_ Entidad] AS Leg, CONVERT(varchar(10),a.[Vigencia Desde],103) AS Desde
FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
WHERE  a.[Cód_ Tipo Atributo] = 'PUESTO' AND a.[Vigencia Hasta] = '1753-01-01'
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WHERE f.[No_ Empleado] = a.[Cód_ Entidad] AND f.[Fecha Baja] = '1753-01-01');

-- CONTROL 3 · LA INVARIANTE DE PLATA, la única que ata todo esto a un documento. Para los
-- 26 de A28/59, el puesto vigente al ARRIBO (29/01/2026) tiene que dar la categoría cuyo
-- VALOR_CAL_ENT reproduce la producción del recibo, al centavo.
-- Tiene que dar 26 filas con Coincide = 'sí'.
;WITH Recibo AS (
    SELECT * FROM (VALUES
        ('03753',10000),('03772',10714),('03774',11429),('03957',14286),('03961',12143),
        ('04066',10714),('04091',10000),('04105',10714),('04169',10000),('04274',10000),
        ('04301',10000),('04368',10000),('04517',10000),('04648',10000),('04669',10714),
        ('04683',10000),('04733',10000),('04734',10000),('04738',10000),('04789',11429),
        ('04798',12143),('04880',10000),('04913',14286),('04914',10714),('04915',10714),
        ('04918',10000)) v(Leg, TonRecibo))
SELECT r.Leg, pu.[Cód_ Valor] AS CatDelPuesto,
       CAST(vc.[Valor] AS decimal(18,2)) AS TonDelPuesto, r.TonRecibo,
       CAST(633.639 * vc.[Valor] AS decimal(18,2)) AS Produccion,
       CASE WHEN vc.[Valor] = r.TonRecibo THEN 'sí' ELSE 'NO' END AS Coincide
FROM   Recibo r
OUTER  APPLY (SELECT TOP 1 a.[Cód_ Valor], a.[Cód_ Valor Padre]
              FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
              WHERE  a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = r.Leg
                AND  a.[Cód_ Tipo Atributo] = 'PUESTO'
                AND  a.[Vigencia Desde] <= '2026-01-29'
                AND  (a.[Vigencia Hasta] >= '2026-01-29' OR a.[Vigencia Hasta] = '1753-01-01')
              ORDER  BY a.[Vigencia Desde] DESC) pu
LEFT   JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] vc
       ON  vc.[Cód_ Parámetro Base] = 'VALOR_CAL_ENT' AND vc.[Cód_ Convenio] = '729/15'
       AND vc.[Cód_ Categoría] = pu.[Cód_ Valor] AND vc.[Vigencia Desde] = '2026-01-01'
ORDER  BY CASE WHEN vc.[Valor] = r.TonRecibo THEN 1 ELSE 0 END, r.Leg;

-- COMMIT;   -- o ROLLBACK;
*/

/*
-- ─── 5. ENCENDERLO: los conceptos de producción pasan a leer el puesto ─────────
-- Son los 13 que hoy tienen "Par CCT a Usar" = Asignación. Recién DESPUÉS de que los
-- controles de arriba den bien, y con un recálculo de prueba antes de aprobar nada.
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET    [Par CCT a Usar] = 2
WHERE  [Par CCT a Usar] = 1;
SELECT @@ROWCOUNT AS ConceptosCambiados;   -- esperado: 13
-- COMMIT;   -- o ROLLBACK;
*/
