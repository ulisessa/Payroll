/*
    PASO 4 — se ejecuta en la conexión **BC** (SQL Server), DESPUÉS de MigrarEstados_2.

    Deriva "Personal Proyecto" de los estados ya migrados. No lee Meta4: Meta4 no tiene esta tabla,
    la asignación está implícita en que un estado apunte a un proyecto.

    POR QUÉ HACE FALTA
      El motor corta al liquidar si la liquidación tiene proyecto y el empleado no está asignado:
      "El empleado %1 no está asignado al proyecto %2" (Cod50014, ValidarAsignacionProyecto). O sea
      que sin esto los 240.956 estados migrados no sirven para liquidar ni uno solo.

    POR QUÉ POR SQL Y NO POR AL — no es comodidad, es obligatorio
      "Personal Proyecto".OnInsert llama a SincronizarEstadoDesdeProyecto, que CREA un estado. Acá
      los estados ya existen y vienen de Meta4: dejar correr el trigger generaría un segundo estado
      por cada asignación, encima del que ya está. Insertar por SQL es lo que evita esa duplicación.

    DE DÓNDE SALE CADA CAMPO
      · No. Empleado / No. Proyecto → los pares distintos de "Estado Empleado" con proyecto no vacío.
      · Fecha Alta Asignación / Fecha Baja → del PRIMER y ÚLTIMO estado del empleado en ese proyecto,
        NO de las fechas del Job. Un tripulante puede embarcar tarde o cortar la marea por accidente,
        y ahí las fechas del proyecto mienten. Es el mismo motivo por el que existe el diario de
        abordo: la producción se liquida hasta el día en que esa persona dejó el barco.
      · Buque / Marea → dimensiones 1 y 2 del Job, igual que hace el OnValidate del campo.
      · Cód. Convenio / Cód. Categoría → del empleado. El OnInsert los exige con TestField, y aunque
        por SQL el trigger no corre, el motor los necesita igual para elegir conceptos.

    ORDEN: bloques 1 y 2 (leen), después el 3 (inserta) y el 4 (verifica).
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: BC  (SQL Server)                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. VOLUMEN — cuántas asignaciones saldrían, y cuántas ya están
------------------------------------------------------------------------------------------------
SELECT COUNT(*)                            AS ParesEnEstados,
       SUM(CASE WHEN pp.[No_ Empleado] IS NULL THEN 1 ELSE 0 END) AS AInsertar,
       SUM(CASE WHEN pp.[No_ Empleado] IS NOT NULL THEN 1 ELSE 0 END) AS YaExisten
FROM  (SELECT DISTINCT ee.[No_ Empleado] AS Emp, ee.[No_ Proyecto] AS Proy
       FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> '') x
LEFT JOIN [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
       ON pp.[No_ Empleado] = x.Emp AND pp.[No_ Proyecto] = x.Proy;

-- El reparto por año del PRIMER estado de cada par. Sirve para decidir si vale la pena crear la
-- asignación de una marea de 2001, que nunca se va a liquidar. Acotar por fecha es legítimo: la
-- asignación es dato derivado, y el estado —que es el dato real— ya está cargado igual.
SELECT YEAR(MIN(ee.[Fecha Inicio])) AS Anio, COUNT(*) AS Pares
FROM  (SELECT DISTINCT [No_ Empleado] AS Emp, [No_ Proyecto] AS Proy
       FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
       WHERE  [Tipo Entidad] = 0 AND [No_ Proyecto] <> '') x
JOIN  [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
      ON ee.[No_ Empleado] = x.Emp AND ee.[No_ Proyecto] = x.Proy AND ee.[Tipo Entidad] = 0
GROUP BY x.Emp, x.Proy
ORDER BY 1;
-- (Devuelve una fila por par; agrupalo en Excel o envolvelo si querés sólo el total por año.)

------------------------------------------------------------------------------------------------
-- 2. PRE-VUELO — tiene que dar CERO filas
------------------------------------------------------------------------------------------------

-- 2.a Empleados sin convenio o sin categoría. El motor los necesita para elegir qué conceptos
--     aplican: sin convenio, SelectConceptos no encuentra nada y el recibo sale vacío sin error.
--
--     DÓNDE VIVEN ESOS DOS CAMPOS. No están en ArbuTest$Employee$437dbf0e-... —esa es la tabla del
--     base app— sino en su compañera terminada en "$ext", y ahí cada columna lleva el id de la
--     extensión que la agregó como SUFIJO del nombre:
--
--         [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext]
--             [Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
--
--     Buscar la tabla por el id de NUESTRA extensión no la encuentra: el nombre lleva el id del
--     base app, que es el dueño de la tabla extendida. Se descubre así:
--         SELECT t.name, c.name FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
--         WHERE t.name LIKE 'ArbuTest$Employee%';
--
--     OJO CON LA COLUMNA VECINA: la personalización Final Version (a423950b-...) tiene SU PROPIO
--     convenio en la misma tabla, "pat_Cod_ convenio". Son dos campos distintos con el mismo
--     significado. El motor de liquidación lee el nuestro; si el nuestro está vacío y el de ellos
--     tiene dato, la migración del convenio quedó a medias y hay que copiarlo antes de liquidar.
SELECT DISTINCT ee.[No_ Empleado],
       emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]  AS ConvenioLiq,
       emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] AS CategoriaLiq,
       emx.[pat_Cod_ convenio$a423950b-02e9-4ee0-ab32-61517ce330cb]      AS ConvenioFinalVersion,
       emx.[pat_ Categoría_Cargo_Rango$a423950b-02e9-4ee0-ab32-61517ce330cb] AS CategoriaFinalVersion
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx
       ON emx.[No_] = ee.[No_ Empleado]
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
  AND (emx.[No_] IS NULL
       OR emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
       OR emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '')
ORDER BY ee.[No_ Empleado];

-- 2.b Proyectos que no existen como Job. No debería devolver nada —el bloque 5 de MigrarEstados_2
--     ya blanquea el proyecto cuando el Job no existe— pero si alguien borró un Job después, esto
--     lo caza antes de que el INSERT falle por la relación.
SELECT DISTINCT ee.[No_ Proyecto]
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
                  WHERE j.[No_] = ee.[No_ Proyecto]);

-- 2.c LOS QUE FALTAN DE VERDAD, cruzados con el convenio y con el año.
--
--     EL 2.a MIDE DEMASIADO. Lista a todo empleado con estados y sin convenio en la ficha, o sea el
--     histórico entero: miles de legajos de veinte años atrás que nunca se van a liquidar. Como
--     control de pre-vuelo no sirve para decidir, porque nunca va a dar cero y no distingue lo que
--     importa.
--
--     ESTO MIDE SÓLO LOS PARES QUE FALTAN —los que el bloque 0 de RecortarAsignacionesAlProyecto
--     cuenta como pendientes— y los cruza con dos cosas: si el empleado tiene convenio y categoría,
--     y de qué año es su primer estado en ese proyecto.
--
--     CÓMO SE DECIDE CON ESTO:
--       · Falta el convenio y el par es de 2026  -> hay que completarlo antes de liquidar.
--       · Falta el convenio y el par es viejo    -> se crea igual: la asignación existe para que el
--         motor no corte al abrir un período histórico, y ese período no se va a liquidar nunca.
--         Aparecerá en el 4.c, que pasa a ser informativo y no un error.
WITH Faltantes AS (
    SELECT ee.[No_ Empleado] AS Emp, ee.[No_ Proyecto] AS Proy,
           MIN(ee.[Fecha Inicio]) AS PrimerEstado
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
      AND  NOT EXISTS (
               SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
               WHERE pp.[No_ Empleado] = ee.[No_ Empleado] AND pp.[No_ Proyecto] = ee.[No_ Proyecto])
    GROUP  BY ee.[No_ Empleado], ee.[No_ Proyecto]
),
Clasificado AS (
    SELECT f.Emp, f.Proy, f.PrimerEstado,
           CASE WHEN emx.[No_] IS NULL
                  OR emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
                  OR emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
                THEN 'b. SIN convenio o categoría'
                ELSE 'a. Con convenio y categoría' END AS Encuadre,
           CASE WHEN f.PrimerEstado >= '2026-01-01' THEN '2. DE 2026 EN ADELANTE (se liquida)'
                ELSE                                     '1. Histórico (no se liquida)' END AS Epoca
    FROM   Faltantes f
    LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx
           ON emx.[No_] = f.Emp
)
SELECT Epoca, Encuadre, COUNT(*) AS Pares, COUNT(DISTINCT Emp) AS Empleados,
       MIN(PrimerEstado) AS Desde, MAX(PrimerEstado) AS Hasta
FROM   Clasificado
GROUP  BY Epoca, Encuadre
ORDER  BY Epoca, Encuadre;

-- 2.c.2 Si el cruce de arriba muestra pares de 2026 sin convenio, ÉSTOS son los que hay que
--       completar a mano antes de liquidar. Son pocos y se listan enteros.
WITH Faltantes AS (
    SELECT ee.[No_ Empleado] AS Emp, ee.[No_ Proyecto] AS Proy,
           MIN(ee.[Fecha Inicio]) AS PrimerEstado
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
      AND  NOT EXISTS (
               SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
               WHERE pp.[No_ Empleado] = ee.[No_ Empleado] AND pp.[No_ Proyecto] = ee.[No_ Proyecto])
    GROUP  BY ee.[No_ Empleado], ee.[No_ Proyecto]
)
SELECT f.Emp AS Legajo, em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       f.Proy AS Proyecto, f.PrimerEstado,
       emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]  AS ConvenioLiq,
       emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] AS CategoriaLiq,
       emx.[pat_ Categoría_Cargo_Rango$a423950b-02e9-4ee0-ab32-61517ce330cb] AS PuestoFinalVersion
FROM   Faltantes f
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx ON emx.[No_] = f.Emp
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = f.Emp
WHERE  f.PrimerEstado >= '2026-01-01'
  AND  (emx.[No_] IS NULL
        OR emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
        OR emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '')
ORDER  BY f.Emp, f.Proy;

-- 2.d ¿ESTÁ EL PAR EN LOS ATRIBUTOS? — antes de cargar nada a mano
--
--     LA FICHA NO ES LA FUENTE. El par convenio/categoría que usa el motor sale de "Atributo Entidad
--     Liq." vía ParDeEntidad (Cod50080), no de los campos de la ficha del empleado. Esos campos son
--     el valor por defecto que se hereda a una asignación nueva — importantes para que "Personal
--     Proyecto" nazca completo, pero no son de donde el cálculo lee.
--
--     ENTONCES, ANTES DE PEDIRLE A NADIE QUE COMPLETE 14 FICHAS A MANO: si la migración de CCT ya
--     les cargó el atributo, el dato está y lo único que falta es copiarlo. Cargarlo a mano sería
--     tipear de nuevo algo que ya está, con el riesgo de tipearlo distinto.
--
--     SIN FECHA DE REFERENCIA, Y ESO ES DELIBERADO. La primera versión buscaba la vigencia anterior
--     al 1/1/2026 y marcó cinco legajos como "falta el atributo" cuando en realidad lo tenían: son
--     ingresos de febrero en adelante y su vigencia arranca en su alta, después de esa fecha. El
--     campo de la ficha NO tiene vigencia —es el valor por defecto que hereda una asignación nueva—
--     así que pedirle el valor "de enero" a alguien que entró en febrero no significa nada. Lo que
--     corresponde es el más reciente.
--
--     Para el CÁLCULO la fecha sí importa, pero el cálculo no lee de acá: lee el atributo vigente al
--     día que liquida, vía ParDeEntidad.
WITH Faltantes AS (
    SELECT DISTINCT ee.[No_ Empleado] AS Emp
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
      AND  ee.[Fecha Inicio] >= '2026-01-01'
      AND  NOT EXISTS (
               SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
               WHERE pp.[No_ Empleado] = ee.[No_ Empleado] AND pp.[No_ Proyecto] = ee.[No_ Proyecto])
),
-- La vigencia que manda es la MÁS RECIENTE del empleado. No se filtra ni por fecha de referencia
-- ni por "Vigencia Hasta": una vigencia cerrada igual pierde contra una posterior, y si es la
-- única que hay, es la que corresponde como valor por defecto de la ficha.
Vigente AS (
    SELECT at.[Cód_ Entidad] AS Emp, at.[Cód_ Tipo Atributo] AS Tipo, at.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY at.[Cód_ Entidad], at.[Cód_ Tipo Atributo]
                              ORDER BY at.[Vigencia Desde] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
    WHERE  at.[Tipo Entidad] = 0
      AND  at.[Cód_ Tipo Atributo] IN ('CONVENIO', 'CATEGORIA')
)
SELECT f.Emp AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]  AS ConvenioEnLaFicha,
       emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] AS CategoriaEnLaFicha,
       vc.Valor AS ConvenioEnAtributos,
       vg.Valor AS CategoriaEnAtributos,
       CASE WHEN vc.Valor IS NULL OR vg.Valor IS NULL
            THEN 'FALTA EL ATRIBUTO — cargar a mano'
            ELSE 'Está en atributos — se copia con el UPDATE de abajo' END AS QueHacer
FROM   Faltantes f
LEFT JOIN Vigente vc ON vc.Emp = f.Emp AND vc.Tipo = 'CONVENIO'  AND vc.Orden = 1
LEFT JOIN Vigente vg ON vg.Emp = f.Emp AND vg.Tipo = 'CATEGORIA' AND vg.Orden = 1
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx ON emx.[No_] = f.Emp
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = f.Emp
WHERE  emx.[No_] IS NULL
   OR  emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
   OR  emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ''
ORDER  BY f.Emp;

-- 2.d.2 COPIAR EL PAR DE LOS ATRIBUTOS A LA FICHA  (COMENTADO)
--
--     Sólo donde la ficha está vacía y el atributo tiene valor. Nunca pisa un valor cargado: si la
--     ficha dice una cosa y el atributo otra, es una discrepancia que hay que mirar, no resolver
--     con un UPDATE masivo.
/*
BEGIN TRANSACTION;

WITH Vigente AS (
    SELECT at.[Cód_ Entidad] AS Emp, at.[Cód_ Tipo Atributo] AS Tipo, at.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY at.[Cód_ Entidad], at.[Cód_ Tipo Atributo]
                              ORDER BY at.[Vigencia Desde] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
    WHERE  at.[Tipo Entidad] = 0
      AND  at.[Cód_ Tipo Atributo] IN ('CONVENIO', 'CATEGORIA')
)
UPDATE emx
SET    emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] =
           CASE WHEN emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '' AND vc.Valor IS NOT NULL
                THEN vc.Valor ELSE emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] END,
       emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] =
           CASE WHEN emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '' AND vg.Valor IS NOT NULL
                THEN vg.Valor ELSE emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] END
FROM   [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx
LEFT JOIN Vigente vc ON vc.Emp = emx.[No_] AND vc.Tipo = 'CONVENIO'  AND vc.Orden = 1
LEFT JOIN Vigente vg ON vg.Emp = emx.[No_] AND vg.Tipo = 'CATEGORIA' AND vg.Orden = 1
WHERE  (emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]  = '' AND vc.Valor IS NOT NULL)
   OR  (emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '' AND vg.Valor IS NOT NULL);

PRINT 'Fichas completadas desde los atributos: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 3. LA INSERCIÓN — descomentar después de que el bloque 2 dé cero
--
--     EL FILTRO DE FECHA está puesto en @Desde y se aplica al PRIMER estado del par. Con
--     '1900-01-01' entra todo; ponelo en '2026-01-01' si sólo querés lo liquidable.
------------------------------------------------------------------------------------------------
SELECT @@TRANCOUNT AS TransaccionesAbiertasEnEstaSesion;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/*
DECLARE @Desde date = '1900-01-01';

BEGIN TRANSACTION;

-- LA FECHA DE BAJA NO SE DERIVA IGUAL PARA UNA MAREA QUE PARA UNA NÓMINA.
--
-- Para una MAREA el MIN/MAX de los estados es correcto, y está justificado en la cabecera:
-- un tripulante puede embarcar tarde o cortar la marea por accidente.
--
-- Para una NÓMINA es un error, y costó caro: el 14/9/2026 cerró 170 asignaciones. Una nómina
-- no es un intervalo de presencia, es PERTENENCIA. El tripulante sigue perteneciendo a la
-- nómina del A-19 mientras navega, pero sus estados se mudan al proyecto de la marea —que es
-- exactamente lo que se espera— y MAX([Fecha Fin]) lee esa mudanza como que se fue. Como los
-- estados son contiguos, el MAX cae el día antes de embarcar: de ahí la firma "baja = alta − 1"
-- que parecía una cascada del motor y no lo era.
--
-- La prueba está en PN-ADM-*: el personal de tierra no embarca, sus estados nunca se van a
-- otro proyecto, y ninguna de esas asignaciones quedó cerrada.
--
-- Una nómina se cierra por dos motivos, y ninguno es la falta de estados:
--   · el empleado pasa a la nómina de otro buque  → cierra el día antes de la siguiente
--   · el empleado se va de la empresa             → cierra con la baja de su fase de alta
-- Si no pasó ninguna de las dos, queda abierta.
WITH ParesRaw AS (
    SELECT ee.[No_ Empleado]      AS Emp,
           ee.[No_ Proyecto]      AS Proy,
           MIN(ee.[Fecha Inicio]) AS Desde,
           -- Si alguno de los estados del par quedó abierto, la asignación queda abierta también:
           -- MAX sobre '1753-01-01' daría una fecha absurda, así que se detecta y se blanquea.
           CASE WHEN MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                THEN '1753-01-01'
                ELSE MAX(ee.[Fecha Fin]) END AS HastaEstados
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
    GROUP  BY ee.[No_ Empleado], ee.[No_ Proyecto]
),
-- El orden de las nóminas de cada empleado, para saber cuál viene después de cuál.
Nominas AS (
    SELECT Emp, Proy, Desde,
           LEAD(Desde) OVER (PARTITION BY Emp ORDER BY Desde) AS SigNominaDesde
    FROM   ParesRaw
    WHERE  Proy LIKE 'PN-%'
),
Pares AS (
    SELECT p.Emp, p.Proy, p.Desde,
           CASE WHEN p.Proy NOT LIKE 'PN-%' THEN p.HastaEstados
                -- Algún estado de la cobertura sigue abierto: la nómina queda abierta.
                WHEN c.HayAbierto = 1 THEN '1753-01-01'
                -- Última nómina de alguien que sigue en la empresa: queda abierta, tenga o no
                -- estados recientes. Una nómina es pertenencia, no cobertura.
                WHEN n.SigNominaDesde IS NULL AND b.SigueEnLaEmpresa = 1 THEN '1753-01-01'
                -- Última nómina de alguien que YA NO ESTÁ: manda la baja de la empresa, no el
                -- último estado. Se puede dejar de tener estados antes del cese formal —el
                -- caso de la temporada: última fase 5/1 al 6/2/2026 y el último estado el 5/1—
                -- y en ese tramo la persona seguía contratada.
                WHEN n.SigNominaDesde IS NULL THEN COALESCE(b.BajaEmpresa, c.FinCobertura, '1753-01-01')
                -- Nómina anterior: cierra donde termina su cobertura. Acá la baja de la empresa
                -- NO aplica: cerraría una nómina de 2005 con la fecha en que la persona se fue
                -- quince años después.
                ELSE COALESCE(c.FinCobertura, '1753-01-01')
           END AS Hasta
    FROM   ParesRaw p
    LEFT   JOIN Nominas n ON n.Emp = p.Emp AND n.Proy = p.Proy
    OUTER  APPLY (
        -- LA COBERTURA DE UNA NÓMINA SON SUS ESTADOS MÁS LOS DE LAS MAREAS DE SU BUQUE.
        -- Ahí está el meollo: los estados se mudan a la marea, y por eso el MAX sobre la
        -- nómina sola cerraba el día antes de embarcar. El buque sale del código, que es el
        -- mismo en los dos: PN-119-NOMINA y PP-119-000311 comparten '119'.
        SELECT MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) AS HayAbierto,
               MAX(NULLIF(ee.[Fecha Fin], '1753-01-01'))                      AS FinCobertura
        FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = p.Emp
          AND  ee.[Fecha Inicio] >= p.Desde
          AND (ee.[No_ Proyecto] = p.Proy
               OR ee.[No_ Proyecto] LIKE 'PP-' + SUBSTRING(p.Proy, 4, 3) + '-%')) c
    OUTER  APPLY (
        -- LA BAJA DE LA EMPRESA SÓLO CUENTA SI EL EMPLEADO YA NO ESTÁ. Con una fase abierta
        -- sigue contratado y la nómina no se cierra, por más bajas viejas que tenga de
        -- contrataciones anteriores.
        SELECT MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS SigueEnLaEmpresa,
               CASE WHEN MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                    THEN NULL
                    WHEN MAX(f.[Fecha Baja]) < p.Desde THEN NULL
                    ELSE MAX(f.[Fecha Baja]) END AS BajaEmpresa
        FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = p.Emp) b
)
INSERT INTO [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    -- Sin [Nombre Empleado]: es FlowField y no existe como columna.
    ([No_ Empleado], [No_ Proyecto], [Cód_ Convenio], [Cód_ Categoría],
     [Fecha Alta Asignación], [Fecha Baja], [Rol en Proyecto], [Buque], [Marea], [Observaciones],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT p.Emp,
       p.Proy,
       -- Columnas de la tabla "$ext", con el id de la extensión como sufijo. Ver el bloque 2.a.
       emx.[Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890],
       emx.[Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890],
       p.Desde,
       p.Hasta,
       '',
       j.[Global Dimension 1 Code],          -- Buque
       j.[Global Dimension 2 Code],          -- Marea
       'Generado por la migración a partir del historial de estados.',
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM Pares p
JOIN [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
  ON j.[No_] = p.Proy
JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] emx
  ON emx.[No_] = p.Emp
WHERE p.Desde >= @Desde
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
                  WHERE pp.[No_ Empleado] = p.Emp AND pp.[No_ Proyecto] = p.Proy);

PRINT 'Asignaciones creadas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 3.c COMPLETAR EL CONVENIO DE LAS ASIGNACIONES QUE NACIERON SIN ÉL
--
--     POR QUÉ APARECE ESTO. El INSERT del bloque 3 copia el convenio de la FICHA en el momento en que
--     corre. Las asignaciones creadas en una corrida anterior —cuando la ficha todavía estaba vacía—
--     se quedaron con el campo en blanco, y completar la ficha después (2.d.2) no las toca. Medido el
--     14/9/2026 quedaban 1.295 asignaciones sin convenio con estados de 2026 en adelante.
--
--     DE DÓNDE SE SACA EL VALOR, y no es de la ficha. La ficha tiene UN valor, el actual. La
--     asignación pertenece a un momento: un tripulante que ascendió en marzo tenía otra categoría en
--     enero, y copiarle la de hoy le cambiaría el recibo de enero. Por eso el valor sale del atributo
--     VIGENTE AL DÍA EN QUE EMPIEZA LA ASIGNACIÓN, que es la misma lectura que hace el motor.
--
--     Sólo completa lo que está vacío. Nunca pisa un convenio ya cargado.
WITH Vigente AS (
    SELECT at.[Cód_ Entidad] AS Emp, at.[Cód_ Tipo Atributo] AS Tipo,
           at.[Cód_ Valor] AS Valor, at.[Vigencia Desde] AS Desde
    FROM   [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
    WHERE  at.[Tipo Entidad] = 0
      AND  at.[Cód_ Tipo Atributo] IN ('CONVENIO', 'CATEGORIA')
),
-- Por cada asignación, la última vigencia que empezó antes de su alta. Es el FindLast de
-- ValorParaLiquidacion escrito en SQL.
AlAlta AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy,
           v.Tipo, v.Valor,
           ROW_NUMBER() OVER (PARTITION BY pp.[No_ Empleado], pp.[No_ Proyecto], v.Tipo
                              ORDER BY v.Desde DESC) AS Orden
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   Vigente v ON v.Emp = pp.[No_ Empleado] AND v.Desde <= pp.[Fecha Alta Asignación]
    WHERE  pp.[Cód_ Convenio] = '' OR pp.[Cód_ Categoría] = ''
)
SELECT COUNT(*) AS SeCompletan
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  (pp.[Cód_ Convenio] = '' OR pp.[Cód_ Categoría] = '')
  AND  EXISTS (SELECT 1 FROM AlAlta a
               WHERE a.Emp = pp.[No_ Empleado] AND a.Proy = pp.[No_ Proyecto] AND a.Orden = 1);

/*
BEGIN TRANSACTION;

WITH Vigente AS (
    SELECT at.[Cód_ Entidad] AS Emp, at.[Cód_ Tipo Atributo] AS Tipo,
           at.[Cód_ Valor] AS Valor, at.[Vigencia Desde] AS Desde
    FROM   [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
    WHERE  at.[Tipo Entidad] = 0
      AND  at.[Cód_ Tipo Atributo] IN ('CONVENIO', 'CATEGORIA')
),
AlAlta AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy,
           v.Tipo, v.Valor,
           ROW_NUMBER() OVER (PARTITION BY pp.[No_ Empleado], pp.[No_ Proyecto], v.Tipo
                              ORDER BY v.Desde DESC) AS Orden
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   Vigente v ON v.Emp = pp.[No_ Empleado] AND v.Desde <= pp.[Fecha Alta Asignación]
    WHERE  pp.[Cód_ Convenio] = '' OR pp.[Cód_ Categoría] = ''
)
UPDATE pp
SET    pp.[Cód_ Convenio]  = CASE WHEN pp.[Cód_ Convenio]  = '' AND ac.Valor IS NOT NULL
                                  THEN ac.Valor ELSE pp.[Cód_ Convenio]  END,
       pp.[Cód_ Categoría] = CASE WHEN pp.[Cód_ Categoría] = '' AND ag.Valor IS NOT NULL
                                  THEN ag.Valor ELSE pp.[Cód_ Categoría] END,
       pp.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
LEFT JOIN AlAlta ac ON ac.Emp = pp.[No_ Empleado] AND ac.Proy = pp.[No_ Proyecto]
                   AND ac.Tipo = 'CONVENIO'  AND ac.Orden = 1
LEFT JOIN AlAlta ag ON ag.Emp = pp.[No_ Empleado] AND ag.Proy = pp.[No_ Proyecto]
                   AND ag.Tipo = 'CATEGORIA' AND ag.Orden = 1
WHERE  (pp.[Cód_ Convenio]  = '' AND ac.Valor IS NOT NULL)
   OR  (pp.[Cód_ Categoría] = '' AND ag.Valor IS NOT NULL);

PRINT 'Asignaciones completadas desde los atributos: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 3.b CORREGIR LAS FECHAS DE LAS ASIGNACIONES QUE YA EXISTÍAN
--
--     No todo estaba sin asignar: había asignaciones cargadas de antes con fechas que salen del
--     Job y no del tripulante. El bloque 4.d las encontró. El caso extremo del 13/9/2026 fue el
--     legajo 00794 en PP-119-000308: asignación desde el 2026-10-13 cuando sus estados en esa
--     marea van del 2026-05-23 al 2026-10-13. Empieza donde termina.
--
--     POR QUÉ IMPORTA, y no es un detalle de presentación: VentanaEmpleadoEnMarea (Cod50016) usa
--     [Fecha Alta Asignación, Fecha Baja] para acotar la ventana del tripulante DENTRO de la marea,
--     y de esa ventana salen DIAS_NAVEGACION y DIAS_PUERTO. Una asignación que arranca el último
--     día le paga a esa persona un día de una marea de cinco meses. El error sale en el recibo.
--
--     LA REGLA ES ENSANCHAR, NUNCA ANGOSTAR. La ventana se estira hasta cubrir los estados del par,
--     pero si alguien cargó a mano una ventana MÁS AMPLIA que los estados, se respeta. Angostar
--     sería sobrescribir una decisión de nómina —el relevo a mitad de marea es justamente eso— y
--     este script no tiene con qué distinguir una fecha puesta a propósito de una heredada del Job.
--     Lo que quede sin cubrir después de esto lo vuelve a listar el 4.d, para mirarlo a mano.
------------------------------------------------------------------------------------------------
/*
BEGIN TRANSACTION;

-- Misma corrección que en el bloque 3: para una NÓMINA la fecha de baja no sale del MAX de
-- los estados. Ver el comentario largo allá arriba — acá se repite la derivación porque los
-- dos bloques se corren por separado y tienen que coincidir. Si se toca uno, tocar el otro.
WITH RealesRaw AS (
    SELECT ee.[No_ Empleado]      AS Emp,
           ee.[No_ Proyecto]      AS Proy,
           MIN(ee.[Fecha Inicio]) AS Desde,
           CASE WHEN MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                THEN '1753-01-01'
                ELSE MAX(ee.[Fecha Fin]) END AS HastaEstados
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
    GROUP  BY ee.[No_ Empleado], ee.[No_ Proyecto]
),
NominasR AS (
    SELECT Emp, Proy, Desde,
           LEAD(Desde) OVER (PARTITION BY Emp ORDER BY Desde) AS SigNominaDesde
    FROM   RealesRaw
    WHERE  Proy LIKE 'PN-%'
),
Reales AS (
    SELECT r.Emp, r.Proy, r.Desde,
           CASE WHEN r.Proy NOT LIKE 'PN-%' THEN r.HastaEstados
                WHEN c.HayAbierto = 1 THEN '1753-01-01'
                WHEN n.SigNominaDesde IS NULL AND b.SigueEnLaEmpresa = 1 THEN '1753-01-01'
                -- Última nómina de alguien que YA NO ESTÁ: manda la baja de la empresa, no el
                -- último estado. Se puede dejar de tener estados antes del cese formal —el
                -- caso de la temporada: última fase 5/1 al 6/2/2026 y el último estado el 5/1—
                -- y en ese tramo la persona seguía contratada.
                WHEN n.SigNominaDesde IS NULL THEN COALESCE(b.BajaEmpresa, c.FinCobertura, '1753-01-01')
                -- Nómina anterior: cierra donde termina su cobertura. Acá la baja de la empresa
                -- NO aplica: cerraría una nómina de 2005 con la fecha en que la persona se fue
                -- quince años después.
                ELSE COALESCE(c.FinCobertura, '1753-01-01')
           END AS Hasta
    FROM   RealesRaw r
    LEFT   JOIN NominasR n ON n.Emp = r.Emp AND n.Proy = r.Proy
    OUTER  APPLY (
        -- Ver el comentario largo del bloque 3. Cobertura = estados de la nómina + estados de
        -- las mareas del mismo buque.
        SELECT MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) AS HayAbierto,
               MAX(NULLIF(ee.[Fecha Fin], '1753-01-01'))                      AS FinCobertura
        FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = r.Emp
          AND  ee.[Fecha Inicio] >= r.Desde
          AND (ee.[No_ Proyecto] = r.Proy
               OR ee.[No_ Proyecto] LIKE 'PP-' + SUBSTRING(r.Proy, 4, 3) + '-%')) c
    OUTER  APPLY (
        SELECT MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS SigueEnLaEmpresa,
               CASE WHEN MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                    THEN NULL
                    WHEN MAX(f.[Fecha Baja]) < r.Desde THEN NULL
                    ELSE MAX(f.[Fecha Baja]) END AS BajaEmpresa
        FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = r.Emp) b
)
UPDATE pp
   SET pp.[Fecha Alta Asignación] =
           CASE WHEN pp.[Fecha Alta Asignación] = '1753-01-01'
                  OR pp.[Fecha Alta Asignación] > r.Desde
                THEN r.Desde
                ELSE pp.[Fecha Alta Asignación] END,
       pp.[Fecha Baja] =
           -- Un estado abierto deja la asignación abierta. Si no, se estira hasta el último estado;
           -- una baja ya posterior se conserva.
           CASE WHEN r.Hasta = '1753-01-01'                                 THEN '1753-01-01'
                WHEN pp.[Fecha Baja] = '1753-01-01'                          THEN '1753-01-01'
                WHEN pp.[Fecha Baja] < r.Hasta                               THEN r.Hasta
                ELSE pp.[Fecha Baja] END,
       pp.[$systemModifiedAt] = SYSUTCDATETIME()
FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN Reales r ON r.Emp = pp.[No_ Empleado] AND r.Proy = pp.[No_ Proyecto]
WHERE (pp.[Fecha Alta Asignación] = '1753-01-01' OR pp.[Fecha Alta Asignación] > r.Desde)
   OR (r.Hasta <> '1753-01-01' AND pp.[Fecha Baja] <> '1753-01-01' AND pp.[Fecha Baja] < r.Hasta)
   -- REABRIR. Sin esta línea el UPDATE no toca el caso principal: la asignación que está
   -- cerrada y que según la derivación tiene que quedar abierta. El SET ya lo contempla
   -- —la primera rama pone '1753-01-01'— pero el WHERE nunca seleccionaba esas filas, así
   -- que las 344 nóminas a reabrir, incluidas las 170 de mayo, se quedaban afuera.
   --
   -- Reabrir es el ensanche máximo, o sea que no contradice la regla de "ensanchar, nunca
   -- angostar": no se está borrando una decisión de nómina, se está sacando una baja que la
   -- derivación vieja inventó.
   OR (r.Hasta = '1753-01-01' AND pp.[Fecha Baja] <> '1753-01-01');

PRINT 'Asignaciones con fechas corregidas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 4. VERIFICACIÓN POSTERIOR
------------------------------------------------------------------------------------------------

-- 4.a Estados con proyecto que siguen sin asignación. Es el control que importa: cada fila acá es
--     una liquidación que va a cortar con "El empleado no está asignado al proyecto".
SELECT COUNT(*) AS EstadosSinAsignacion, COUNT(DISTINCT ee.[No_ Empleado]) AS Legajos
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
                  WHERE pp.[No_ Empleado] = ee.[No_ Empleado]
                    AND pp.[No_ Proyecto] = ee.[No_ Proyecto]);

-- 4.b Lo mismo pero sólo de lo que se va a liquidar ahora. Si el bloque 3 se corrió con @Desde
--     acotado, ésta es la que tiene que dar cero; la 4.a va a devolver la historia vieja.
SELECT COUNT(*) AS EstadosSinAsignacionDesde2026
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
  AND ee.[Fecha Inicio] >= '2026-01-01'
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
                  WHERE pp.[No_ Empleado] = ee.[No_ Empleado]
                    AND pp.[No_ Proyecto] = ee.[No_ Proyecto]);

-- 4.c Asignaciones sin convenio o sin categoría. El OnInsert las prohíbe, pero este INSERT entra por
--     SQL y no lo ejecuta.
--
--     YA NO TIENE QUE DAR CERO, y decía que sí hasta el 14/9/2026. Con el histórico completo cargado
--     hay ~600 legajos de entre 2002 y 2025 sin convenio en la ficha: la migración de CCT alcanzó a
--     los que están hoy, no a los de hace veinte años, y no tiene por qué. Sus asignaciones existen
--     para que el motor no corte con "el empleado no está asignado al proyecto" si alguien abre un
--     período viejo, y ese período no se va a liquidar.
--
--     LO QUE SÍ TIENE QUE DAR CERO es la segunda consulta: una asignación sin convenio con estados
--     de 2026 en adelante es un recibo vacío esperando a que alguien lo liquide.
SELECT COUNT(*) AS AsignacionesIncompletas_Todas
FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Cód_ Convenio] = '' OR [Cód_ Categoría] = '';

SELECT COUNT(*) AS AsignacionesIncompletas_Liquidables
FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE ([Cód_ Convenio] = '' OR [Cód_ Categoría] = '')
  AND EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
              WHERE ee.[Tipo Entidad] = 0
                AND ee.[No_ Empleado] = pp.[No_ Empleado]
                AND ee.[No_ Proyecto] = pp.[No_ Proyecto]
                AND ee.[Fecha Inicio] >= '2026-01-01');

-- 4.d Asignaciones cuyas fechas no cubren a sus propios estados. Tiene que dar CERO.
SELECT TOP 50 pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación], pp.[Fecha Baja],
       MIN(ee.[Fecha Inicio]) AS PrimerEstado, MAX(ee.[Fecha Inicio]) AS UltimoEstado
FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
     ON ee.[No_ Empleado] = pp.[No_ Empleado] AND ee.[No_ Proyecto] = pp.[No_ Proyecto]
    AND ee.[Tipo Entidad] = 0
GROUP BY pp.[No_ Empleado], pp.[No_ Proyecto], pp.[Fecha Alta Asignación], pp.[Fecha Baja]
HAVING MIN(ee.[Fecha Inicio]) < pp.[Fecha Alta Asignación]
    OR (pp.[Fecha Baja] <> '1753-01-01' AND MAX(ee.[Fecha Inicio]) > pp.[Fecha Baja]);

GO

------------------------------------------------------------------------------------------------
-- 5. PREVISUALIZACIÓN DE LA DERIVACIÓN NUEVA DE LAS PN-
--
--    No escribe. Muestra, para cada asignación de nómina que ya existe, qué fecha de baja tiene
--    hoy y cuál le daría la regla corregida de los bloques 3 y 3.b.
--
--    LO QUE HAY QUE VER:
--      · Las PN-ADM-* no se mueven: siguen abiertas. Si alguna se cierra, la regla está mal.
--      · Las ~170 cerradas el 22/5 y el 27/5 tienen que pasar a abiertas, salvo las de gente
--        que efectivamente se fue de la empresa o cambió de buque.
--      · Ninguna baja nueva puede caer antes de su propia alta.
------------------------------------------------------------------------------------------------
-- TERCERA VERSIÓN DE LA REGLA. Las dos anteriores fallaron y el bloque las agarró:
--
--   1ª  Baja = MIN de las bajas de fase posteriores al primer estado.
--       Cerraba once nóminas de tierra con fechas de los noventa, nueve con la baja ANTES
--       del alta. La agarró BajaAntesDelAlta.
--
--   2ª  Baja = el día antes de la nómina siguiente.
--       Movía ~4.700 fechas en vez de las 170 del problema: a quien dejó el A-10 en 2005 y
--       entró al A-14 en 2008 le estiraba la nómina del A-10 tres años sin un estado que lo
--       respalde. La agarró CambiaLaFecha.
--
-- LO QUE FALTABA PRECISAR es por qué la nómina no se cierra al embarcar: porque los estados
-- se mudan a las mareas DEL MISMO BUQUE. Mientras navega en un PP-119-* sigue perteneciendo
-- al PN-119. Tres años sin ningún estado de ese buque, no.
--
-- Entonces la cobertura de una nómina son sus estados MÁS los de las mareas de su buque, y
-- el tope es la nómina siguiente si la hay. El buque sale del código en los dos casos:
-- PN-119-NOMINA y PP-119-000311 comparten '119'. Las PN-ADM-*, PPM y FLT no tienen mareas,
-- así que su cobertura son sólo sus propios estados — que es lo correcto para tierra.
;WITH ParesRaw AS (
    SELECT ee.[No_ Empleado] AS Emp, ee.[No_ Proyecto] AS Proy,
           MIN(ee.[Fecha Inicio]) AS Desde
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] LIKE 'PN-%'
    GROUP  BY ee.[No_ Empleado], ee.[No_ Proyecto]
),
Nominas AS (
    SELECT Emp, Proy, Desde,
           SUBSTRING(Proy, 4, 3) AS Buque,
           LEAD(Desde) OVER (PARTITION BY Emp ORDER BY Desde) AS SigNominaDesde
    FROM   ParesRaw
),
Nueva AS (
    SELECT n.Emp, n.Proy, n.Desde,
           CASE
             -- Algún estado de la cobertura sigue abierto: la nómina queda abierta.
             WHEN c.HayAbierto = 1 THEN '1753-01-01'
             -- Última nómina de alguien que SIGUE EN LA EMPRESA: queda abierta, tenga o no
             -- estados recientes. Una nómina es pertenencia, no cobertura: si la persona
             -- sigue contratada, sigue perteneciendo. Cerrarla con la fecha del último
             -- estado es lo que dejaba seis administrativos de Puerto Madryn cerrados, dos
             -- de ellos con la baja ANTES de su propia alta.
             WHEN n.SigNominaDesde IS NULL AND b.SigueEnLaEmpresa = 1 THEN '1753-01-01'
             -- El resto cierra donde termina su cobertura, o con la baja de la empresa si
             -- no dejó ninguna.
             --
             -- SIN TOPE CONTRA LA NÓMINA SIGUIENTE, y eso fue la cuarta versión de la regla.
             -- La tercera cerraba "el día antes de la nómina siguiente" y SeAdelanta la
             -- delató: recortaba 2.150 filas. El tope daba por sentado que las nóminas de una
             -- persona son una secuencia limpia, y no lo son — hay quien tiene estados en
             -- PN-110 en 2008-2010 y a la vez una asignación a PN-114 desde 2008, porque rota
             -- entre buques. Las nóminas se SOLAPAN, y cortar por la siguiente borra cobertura
             -- real. Si dos se pisan, eso lo dicen los estados; no es algo que deba inventar
             -- esta derivación.
             -- Última nómina de alguien que ya no está: manda la baja de la empresa.
             WHEN n.SigNominaDesde IS NULL THEN COALESCE(b.BajaEmpresa, c.FinCobertura, '1753-01-01')
             -- Nómina anterior: cierra donde termina su cobertura, sin mirar la baja.
             ELSE COALESCE(c.FinCobertura, '1753-01-01')
           END AS HastaNueva
    FROM   Nominas n
    OUTER  APPLY (
        -- Cobertura = estados de la nómina + estados de las mareas del mismo buque.
        SELECT MAX(CASE WHEN ee.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) AS HayAbierto,
               MAX(NULLIF(ee.[Fecha Fin], '1753-01-01'))                      AS FinCobertura
        FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0
          AND  ee.[No_ Empleado] = n.Emp
          AND  ee.[Fecha Inicio] >= n.Desde
          AND (ee.[No_ Proyecto] = n.Proy
               OR ee.[No_ Proyecto] LIKE 'PP-' + n.Buque + '-%')) c
    OUTER  APPLY (
        SELECT MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS SigueEnLaEmpresa,
               CASE WHEN MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                    THEN NULL
                    WHEN MAX(f.[Fecha Baja]) < n.Desde THEN NULL
                    ELSE MAX(f.[Fecha Baja]) END AS BajaEmpresa
        FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WHERE  f.[No_ Empleado] = n.Emp) b
)
SELECT pp.[No_ Proyecto],
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 'Abierta' ELSE 'Cerrada' END AS Hoy,
       CASE WHEN x.HastaNueva     = '1753-01-01' THEN 'Abierta' ELSE 'Cerrada' END AS ConLaReglaNueva,
       COUNT(*) AS Asignaciones,
       SUM(CASE WHEN x.HastaNueva <> '1753-01-01'
                 AND x.HastaNueva < pp.[Fecha Alta Asignación] THEN 1 ELSE 0 END) AS BajaAntesDelAlta,
       -- Una asignación puede seguir cerrada y cambiar igual de fecha. Sin esto, todo el bloque
       -- "Cerrada → Cerrada" —la mayoría— pasa por "no cambia nada" sin que sea cierto.
       SUM(CASE WHEN x.HastaNueva <> pp.[Fecha Baja] THEN 1 ELSE 0 END) AS CambiaLaFecha,
       -- Y de las que cambian, separar en qué dirección. La corrección esperada ALARGA: la
       -- nómina que cerraba el día antes de embarcar pasa a cubrir la marea. Una que se
       -- ADELANTE está recortando cobertura, que es lo contrario de lo que venimos a hacer,
       -- y hay que mirarla antes de escribir nada.
       SUM(CASE WHEN x.HastaNueva <> '1753-01-01' AND pp.[Fecha Baja] <> '1753-01-01'
                 AND x.HastaNueva < pp.[Fecha Baja] THEN 1 ELSE 0 END) AS SeAdelanta
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   Nueva x ON x.Emp = pp.[No_ Empleado] AND x.Proy = pp.[No_ Proyecto]
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
GROUP  BY pp.[No_ Proyecto],
          CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN 'Abierta' ELSE 'Cerrada' END,
          CASE WHEN x.HastaNueva    = '1753-01-01' THEN 'Abierta' ELSE 'Cerrada' END
ORDER  BY 1, 2;
GO

------------------------------------------------------------------------------------------------
-- 5.b LAS ÚNICAS QUE PIERDEN UNA ASIGNACIÓN ABIERTA
--
--     Con la regla de la cuarta versión, BajaAntesDelAlta y SeAdelanta dan cero en todas las
--     filas. La única clase que "pierde" algo son 4 nóminas de PN-ADM-PTOMDY que pasan de
--     abiertas a cerradas, y cierran porque el empleado no tiene NINGUNA fase de alta abierta:
--     según las fases, ya no trabaja en la empresa.
--
--     Si efectivamente se fueron, la regla acierta. Si alguno sigue trabajando, el problema no
--     está en esta derivación sino en su fase de alta, que quedó cerrada sin corresponder.
------------------------------------------------------------------------------------------------
SELECT pp.[No_ Empleado], em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación] AS AltaAsignacion,
       f.[Fecha Alta]             AS FaseAlta,
       CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN NULL ELSE f.[Fecha Baja] END AS FaseBaja,
       (SELECT MAX(ee.[Fecha Inicio])
        FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
        WHERE  ee.[Tipo Entidad] = 0 AND ee.[No_ Empleado] = pp.[No_ Empleado]) AS UltimoEstado
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = pp.[No_ Empleado]
LEFT   JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
       ON f.[No_ Empleado] = pp.[No_ Empleado]
WHERE  pp.[No_ Proyecto] = 'PN-ADM-PTOMDY'
   AND pp.[Fecha Baja] = '1753-01-01'
   AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = pp.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01')
ORDER  BY pp.[No_ Empleado], f.[Fecha Alta];
GO

------------------------------------------------------------------------------------------------
-- 5.c CERRAR LAS DE GENTE QUE YA NO ESTÁ — la excepción a "ensanchar, nunca angostar"
--
--     Después de correr el 3.b, el bloque 5 da CambiaLaFecha = 0 en todo salvo cuatro filas de
--     PN-ADM-PTOMDY. No es un error del UPDATE: su SET tiene
--
--         WHEN pp.[Fecha Baja] = '1753-01-01' THEN '1753-01-01'
--
--     o sea que una asignación abierta se deja abierta. Cerrarla sería angostar, y el bloque
--     general no puede distinguir una fecha puesta a mano por nómina de una heredada de la
--     migración. La regla está bien y no hay que tocarla.
--
--     PERO DE ESTOS CUATRO SÍ SABEMOS: el 5.b los muestra con la fase de alta cerrada y sin
--     estados posteriores. Se fueron de la empresa. Una nómina abierta de alguien que no
--     trabaja lo deja entrando en los procesos de su buque.
--
--     Por eso va como bloque aparte y acotado a ese caso —fase cerrada, sin fase abierta—, no
--     como una excepción dentro del 3.b. Si mañana aparece una nómina abierta de alguien que
--     sigue trabajando, esto no la toca.
------------------------------------------------------------------------------------------------
SELECT pp.[No_ Empleado], pp.[No_ Proyecto],
       pp.[Fecha Alta Asignación] AS Alta,
       b.BajaEmpresa              AS CerrariaEl
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = pp.[No_ Empleado]) b
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[Fecha Baja] = '1753-01-01'
   AND b.BajaEmpresa <> '1753-01-01'
   AND b.BajaEmpresa >= pp.[Fecha Alta Asignación]
   AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = pp.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01');
GO

/*
BEGIN TRANSACTION;

UPDATE pp
SET    pp.[Fecha Baja]         = b.BajaEmpresa,
       pp.[$systemModifiedAt]  = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
CROSS  APPLY (SELECT MAX(f.[Fecha Baja]) AS BajaEmpresa
              FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
              WHERE  f.[No_ Empleado] = pp.[No_ Empleado]) b
WHERE  pp.[No_ Proyecto] LIKE 'PN-%'
   AND pp.[Fecha Baja] = '1753-01-01'
   AND b.BajaEmpresa <> '1753-01-01'
   AND b.BajaEmpresa >= pp.[Fecha Alta Asignación]
   AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
                   WHERE f2.[No_ Empleado] = pp.[No_ Empleado] AND f2.[Fecha Baja] = '1753-01-01');

-- Esperado: 4.
SELECT @@ROWCOUNT AS FilasCerradas;

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/
