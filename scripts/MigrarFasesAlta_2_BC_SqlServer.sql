/*
    PASO 3 de 3 — se ejecuta en la conexión **Migr2013R2** (SQL Server, mimir...:1433).

    Meta4 vive en Oracle y BC en SQL Server, así que la migración va en tres tiempos:
        1. MigrarFasesAlta_1_Meta4_Oracle.sql, contra Meta4.
        2. Llevar ese resultado a la tabla puente dbo.MIG_FasesM4 de esta base (DBeaver:
           Exportar resultado… → Base de datos). El DDL está en el paso -1 de acá abajo.
        3. Este script.                                            ← estás acá

    Trae las fases de alta de Meta4 al historial de estados de BC.

    Cada fase de Meta4 se convierte en UNA O DOS filas de "Estado Empleado":

        FEC_ALTA_EMPLEADO  →  fila con Cód. Estado = 'ALT'                (Tipo Estado = Alta)
        FEC_BAJA           →  fila con el código de baja que corresponda  (Tipo Estado = Baja)

    Es el mismo modelo que usa el motor: la fase no se guarda en un renglón, se arma con dos. La de
    Alta pone la fecha de ingreso y la de Baja, más adelante, la de egreso y el motivo. Todo lo que
    pase en el medio —vacaciones, francos, embarques— son estados propios y no interrumpen la fase.

    POR QUÉ ESTO NO PUEDE CORRERSE Y LISTO
    Un INSERT contra la base saltea TODA la lógica de AL: la contigüidad que mantiene "Fecha Fin", la
    validación de un solo estado por fecha, la de que después de una baja solo venga un alta, las
    transiciones automáticas y el registro de cambios. Este script hace a mano lo único que el motor
    necesita —cerrar cada estado contra el siguiente— y deja el resto a los pasos de control. Por eso
    los pasos 1 a 4 son de REVISIÓN y el 5 está comentado.

    ANTES DE CORRER
      1. Backup. Esto inserta filas en una tabla que después usa el cálculo de antigüedad.
      2. Con nadie liquidando.
      3. Correr los pasos 1 a 4 y MIRAR la salida. Sobre todo el 3: los empleados que no existen en
         BC no se migran, y hay que decidir qué hacer con ellos ANTES y no después.
      4. Después de insertar, correr el paso 6 (verificación) y abrir "Fases de Alta" en BC para un
         par de legajos conocidos.

    LO QUE HAY QUE COMPLETAR
      · dbo.MIG_FasesM4 tiene que estar cargada con el resultado del paso 1.
      · Los códigos de baja tienen que existir en BC antes de insertar: uno por cada motivo de
        Meta4, con el número como sufijo (BAJ-1, BAJ-2, … BAJ-50). El paso 2 los verifica y el
        paso 2.b genera el INSERT para crear los que falten.
*/

-- Sin GO: no es T-SQL sino una marca de separación de lotes que entienden SSMS y sqlcmd. Un
-- cliente JDBC —DBeaver, DataGrip— se la manda al servidor tal cual y responde "Incorrect syntax
-- near 'GO'". Cada bloque de acá abajo es una sentencia común, ejecutable sola.
-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: Migr2013R2  (SQL Server)                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
USE [Migr2013R2];
SET NOCOUNT ON;

-- Guardián: si el editor está apuntando a Meta4, esto corta acá con un mensaje claro. DB_NAME() no
-- existe en Oracle, así que allá falla igual, y en cualquier caso el error habla de la conexión y
-- no de una función suelta.
--
-- El nombre de la base sale por variable: los argumentos de sustitución de RAISERROR sólo admiten
-- constantes o variables, y una función ahí da "Incorrect syntax near 'DB_NAME'" — un error de
-- parseo, que voltea el lote entero antes de ejecutar nada, no sólo esta línea. Y el mensaje va
-- con N'' porque %s de un literal ANSI no acepta el nvarchar que devuelve DB_NAME().
DECLARE @BaseActual sysname = DB_NAME();

IF @BaseActual <> N'Migr2013R2'
    RAISERROR(N'Este script va contra la base de BC (Migr2013R2), no contra la base %s. El de Meta4 es MigrarFasesAlta_1_Meta4_Oracle.sql.', 16, 1, @BaseActual);

------------------------------------------------------------------------------------------------
-- -1. La tabla puente: se crea vacía acá y la llena el paso 1 desde Oracle.
--
--     Es una tabla común y corriente de esta base, no temporal: tiene que sobrevivir a la
--     exportación, que corre en otra conexión, y a que cierres el editor.
--
--     ORDEN DE LA PRIMERA VEZ:
--       a. Correr este bloque. Crea la tabla vacía.
--       b. Ir a MigrarFasesAlta_1_Meta4_Oracle.sql, en la conexión Meta4, y ejecutar el SELECT.
--       c. Botón derecho sobre la grilla → Exportar resultado… → Base de datos → esta tabla.
--       d. Volver acá y seguir por el control de abajo.
------------------------------------------------------------------------------------------------
IF OBJECT_ID('dbo.MIG_FasesM4') IS NULL
    CREATE TABLE dbo.MIG_FasesM4 (
        LEGAJO       varchar(20),
        FEC_ALTA     date,
        FEC_BAJA     date,
        MOTIVO_BAJA  varchar(20),
        COMENT       nvarchar(250),
        COMENT_BAJA  nvarchar(250)
    );
-- Se crea SOLO si falta, y nunca se borra sola: un DROP automático acá se llevaría puestos los
-- datos del paso 1 justo cuando uno vuelve a abrir el script para seguir donde iba.
--
-- Para volver a traer todo de cero, descomentar esta línea y correr de nuevo el bloque de arriba:
-- DROP TABLE dbo.MIG_FasesM4;

-- Control de que llegó lo que salió de Oracle: estos números tienen que coincidir con los que
-- mostró el paso 1 antes de exportar. La primera vez, antes de exportar, dan todos cero.
SELECT COUNT(*) AS Filas,
       COUNT(FEC_ALTA) AS ConAlta,
       COUNT(FEC_BAJA) AS ConBaja,
       COUNT(DISTINCT LEGAJO) AS Legajos
FROM dbo.MIG_FasesM4;

------------------------------------------------------------------------------------------------
-- 0. Parámetros, mapeo de motivos y armado del juego de filas a insertar
--
--    Los parámetros van en una tabla temporal y no en variables a propósito: una variable vive
--    hasta el próximo GO, y este script está pensado para recorrerse de a un paso, ejecutando el
--    bloque que uno está mirando. Con variables, cualquier paso corrido suelto muere con
--    "Must declare the scalar variable". #Cfg y #Fases, en cambio, duran toda la conexión.
--
--    Este paso va SIEMPRE primero. Después se puede correr cualquier otro, las veces que haga falta.
--    Todo lo que sigue trabaja sobre #Fases; la base de BC no se toca hasta el paso 5.
------------------------------------------------------------------------------------------------
-- La sociedad ya se filtró en el paso 1, y el código de baja se deriva del número de Meta4: no
-- queda ningún parámetro que completar acá.

-- Sin tabla de mapeo: el código de BC se DERIVA del número de Meta4, con el prefijo BAJ-.
--
--     Meta4 1  (Renuncia)                →  BAJ-1
--     Meta4 2  (Despido con causa)       →  BAJ-2
--     Meta4 50 (Prescripción)            →  BAJ-50
--
-- Es mejor que una tabla de equivalencias por dos motivos. Uno: no hay traducción que revisar, así
-- que ninguna causal puede terminar archivada como otra —el fallecimiento no queda como despido sin
-- causa—. Dos: si mañana Meta4 suma un motivo, la migración no lo mapea mal en silencio: el código
-- BAJ-nuevo no existe en BC y el paso 2 lo muestra como NULL, que es exactamente lo que uno quiere
-- que pase.
--
-- El motivo vacío o nulo cae en BAJ-0, que en Meta4 ya significa "Desconocido".

-- COLLATE DATABASE_DEFAULT en cada columna de texto, y no es decorativo: una tabla temporal hereda
-- la colación de TEMPDB —acá Modern_Spanish_100_CI_AS— mientras que las tablas de BC usan la de esta
-- base, Modern_Spanish_CI_AS. Comparar dos columnas de texto con colaciones distintas no compara
-- mal: directamente no compila, con "Cannot resolve the collation conflict". Y aparece recién en el
-- primer JOIN contra BC, tres pasos después de haber creado la tabla.
IF OBJECT_ID('tempdb..#Fases') IS NOT NULL DROP TABLE #Fases;
CREATE TABLE #Fases (
    Legajo        varchar(20)   COLLATE DATABASE_DEFAULT,
    Fecha         date,
    CodEstado     varchar(20)   COLLATE DATABASE_DEFAULT,
    EsAlta        bit,
    Observaciones nvarchar(250) COLLATE DATABASE_DEFAULT,
    OrigenMotivo  varchar(20)   COLLATE DATABASE_DEFAULT
);

-- Las altas
INSERT INTO #Fases (Legajo, Fecha, CodEstado, EsAlta, Observaciones, OrigenMotivo)
SELECT
    LTRIM(RTRIM(f.LEGAJO)),
    f.FEC_ALTA,
    'ALT',
    1,
    LEFT(LTRIM(RTRIM(ISNULL(f.COMENT, ''))), 250),
    NULL
FROM dbo.MIG_FasesM4 f
WHERE f.FEC_ALTA IS NOT NULL;

-- Las bajas. El código sale del número de motivo.
--
-- El comentario sale de COMENT_BAJA, y si está vacío, de COMENT. No es un capricho: en los registros
-- viejos de Meta4 el motivo no está codificado —queda en 0, "Desconocido"— y el motivo real está
-- escrito a mano en COMENT, el comentario de la FASE: "DESPIDO CAUSADO", "DESPEDIDO - TCL". Si el
-- comentario de la fase se quedara solo en el alta, la baja diría "Desconocido" y sin ninguna pista,
-- mientras el dato que la explica estaría cuatro renglones más arriba, en el alta de 1990.
--
-- El texto queda duplicado en las dos filas cuando la fase tiene un solo comentario. Es a propósito:
-- que sobre en el alta molesta mucho menos que faltar en la baja.
INSERT INTO #Fases (Legajo, Fecha, CodEstado, EsAlta, Observaciones, OrigenMotivo)
SELECT
    LTRIM(RTRIM(f.LEGAJO)),
    f.FEC_BAJA,
    'BAJ-' + ISNULL(NULLIF(LTRIM(RTRIM(f.MOTIVO_BAJA)), ''), '0'),
    0,
    LEFT(LTRIM(RTRIM(COALESCE(NULLIF(LTRIM(RTRIM(f.COMENT_BAJA)), ''), f.COMENT, ''))), 250),
    LTRIM(RTRIM(f.MOTIVO_BAJA))
FROM dbo.MIG_FasesM4 f
WHERE f.FEC_BAJA IS NOT NULL
  AND f.FEC_BAJA > '1900-01-01';   -- Meta4 usa fechas centinela para "sin baja"

------------------------------------------------------------------------------------------------
-- 0.b Las fechas con más de un estado se APARTAN antes de seguir
--
--     "Estado Empleado" tiene una clave única por (Tipo Entidad, Empleado, Proyecto, Fecha Inicio):
--     un empleado no puede tener dos estados el mismo día. Es la misma regla que valida AL, y el
--     INSERT directo la choca de frente — con un error que corta la transacción entera y no dice
--     cuántos casos más había detrás.
--
--     En Meta4 esto pasa por dos motivos, y los dos se resuelven igual:
--       · fases con FEC_ALTA = FEC_BAJA — alguien de alta y de baja el mismo día. La fase dura cero
--         días y no aporta antigüedad: sacarla no cambia ningún número.
--       · una baja y el alta siguiente el mismo día — una recontratación sin interrupción. Sacar el
--         par deja las dos fases unidas en una sola continua, que es exactamente lo que significa:
--         no hubo un día sin relación laboral, y la antigüedad corre derecho.
--
--     Se apartan TODAS las filas de esa fecha, no una: elegir cuál sobrevive es una decisión de
--     negocio y no de un script. Quedan en #FasesDescartadas para revisarlas.
------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#FasesDescartadas') IS NOT NULL DROP TABLE #FasesDescartadas;

SELECT f.*
INTO #FasesDescartadas
FROM #Fases f
JOIN (SELECT Legajo, Fecha FROM #Fases GROUP BY Legajo, Fecha HAVING COUNT(*) > 1) d
  ON d.Legajo = f.Legajo AND d.Fecha = f.Fecha;

DELETE f
FROM #Fases f
JOIN #FasesDescartadas d ON d.Legajo = f.Legajo AND d.Fecha = f.Fecha;

SELECT COUNT(*) AS FilasApartadas, COUNT(DISTINCT Legajo) AS LegajosAfectados
FROM #FasesDescartadas;

SELECT * FROM #FasesDescartadas ORDER BY Legajo, Fecha, EsAlta DESC;

------------------------------------------------------------------------------------------------
-- 1. Qué se va a insertar, en números
------------------------------------------------------------------------------------------------
SELECT 'Filas armadas' AS Concepto, COUNT(*) AS Cantidad FROM #Fases
UNION ALL SELECT 'Altas',  COUNT(*) FROM #Fases WHERE EsAlta = 1
UNION ALL SELECT 'Bajas',  COUNT(*) FROM #Fases WHERE EsAlta = 0
UNION ALL SELECT 'Legajos distintos', COUNT(DISTINCT Legajo) FROM #Fases;

SELECT CodEstado, COUNT(*) AS Filas
FROM #Fases GROUP BY CodEstado ORDER BY Filas DESC;

-- Los motivos que trajo Meta4, con el código de BC que les toca. El que no exista del otro lado
-- aparece en el paso 2 y hay que crearlo antes de insertar.
SELECT OrigenMotivo AS MotivoMeta4, CodEstado AS CodigoBC, COUNT(*) AS Filas
FROM #Fases
WHERE EsAlta = 0
GROUP BY OrigenMotivo, CodEstado ORDER BY Filas DESC;

-- Bajas sin motivo codificado en Meta4: van todas a BAJ-0. Si son muchas, conviene mirar qué dice
-- el comentario antes de migrar — ahí suele estar el motivo real, escrito a mano.
SELECT COUNT(*) AS BajasSinMotivo,
       SUM(CASE WHEN Observaciones <> '' THEN 1 ELSE 0 END) AS ConAlgoEscrito
FROM #Fases WHERE EsAlta = 0 AND CodEstado = 'BAJ-0';

SELECT TOP 50 Observaciones, COUNT(*) AS Filas
FROM #Fases WHERE EsAlta = 0 AND CodEstado = 'BAJ-0' AND Observaciones <> ''
GROUP BY Observaciones ORDER BY Filas DESC;

------------------------------------------------------------------------------------------------
-- 2. Los códigos de estado tienen que existir en BC, y con el Tipo Estado correcto
------------------------------------------------------------------------------------------------
SELECT DISTINCT f.CodEstado, e.[Tipo Estado], e.Activo
FROM #Fases f
LEFT JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON e.[Código] = f.CodEstado
ORDER BY f.CodEstado;
-- Se espera: ALT con Tipo Estado = 1 (Alta) y los demás con 2 (Baja). Un NULL acá corta la
-- migración: la fila entraría apuntando a un código inexistente y el cálculo de antigüedad no la
-- reconocería ni como alta ni como baja — simplemente no contaría.

------------------------------------------------------------------------------------------------
-- 2.b Crear los códigos de baja que falten, con la descripción y el detalle de Meta4
--
--     Los diecinueve motivos, tal como están en Meta4, con el número como sufijo. La columna
--     "Descripción Ampliada" trae el comentario del motivo: qué indemnización genera y contra qué
--     artículo. Es lo que uno necesita leer cuando duda entre BAJ-4, BAJ-5 y BAJ-11, que se llaman
--     casi igual y pagan distinto.
--
--     Descomentar y correr UNA vez. Inserta solo los que falten, así que es seguro repetirlo.
------------------------------------------------------------------------------------------------
/*
WITH Motivos (Nro, Descripcion, Detalle) AS (
    SELECT * FROM (VALUES
        ('0',  'Desconocido',                            ''),
        ('1',  'Renuncia',                               ''),
        ('2',  'Despido con causa',                      ''),
        ('3',  'Finalización de contrato',               ''),
        ('4',  'Incapacidad Art. 212 2º párr.',          'Genera indemnización por antigüedad por incapacidad, Art. 212 2º párr. (50%). En Meta4 el código no debía borrarse ni modificarse: perdía su operativa en cálculos.'),
        ('5',  'Incapacidad Art. 212 4º párr.',          'Genera indemnización por antigüedad por incapacidad, Art. 212 4º párr. (100%). En Meta4 el código no debía borrarse ni modificarse: perdía su operativa en cálculos.'),
        ('6',  'Indemnización por maternidad',           'Genera indemnización por maternidad (25%). En Meta4 el código no debía borrarse ni modificarse: perdía su operativa en cálculos.'),
        ('7',  'Indemnización por fallecimiento',        'Indemnización por antigüedad al 50%.'),
        ('8',  'Jubilación',                             'Genera indemnización por jubilación.'),
        ('9',  'Despido sin causa sin preaviso',         'Genera preaviso, integración e indemnización por antigüedad.'),
        ('10', 'Despido sin causa con preaviso',         'Genera indemnización por antigüedad (100%).'),
        ('11', 'Incapacidad Art. 212 3º párr.',          'Genera indemnización por antigüedad al 100%.'),
        ('12', 'Finalización de contrato',               'Duplicado del motivo 3 en Meta4; se conserva para no perder el origen de las bajas ya cargadas con este número.'),
        ('13', 'Despido de delegado gremial',            ''),
        ('14', 'Indem. fuerza mayor o dismin. de trabajo', ''),
        ('15', 'Indem. por causa de embarazo',           ''),
        ('16', 'Indem. por causa de casamiento',         ''),
        ('17', 'Desvinculación fin plazo Art. 211 LCT',  'Vencimiento del plazo de reserva del puesto.'),
        ('50', 'Prescripción',                           'Finalización del plazo de dos años sin relación laboral.')
    ) v(Nro, Descripcion, Detalle)
)
INSERT INTO [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Código], [Descripción], [Descripción Ampliada], [Tipo Empleado], [Activo], [Tipo Estado],
     [Ámbito], [Estado Siguiente], [Devenga Francos],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT
    'BAJ-' + m.Nro,
    m.Descripcion,
    m.Detalle,
    0,          -- Tipo Empleado = Todos
    1,          -- Activo
    2,          -- Tipo Estado = Baja
    0,          -- Ámbito = Empleado
    '',         -- sin estado siguiente: una baja termina cuando hay un alta nueva
    0,          -- no devenga francos
    NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
             SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM Motivos m
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE e.[Código] = 'BAJ-' + m.Nro);

PRINT 'Códigos creados: ' + CAST(@@ROWCOUNT AS varchar(10));
*/

------------------------------------------------------------------------------------------------
-- 3. Legajos que no existen en BC. NO se migran.

------------------------------------------------------------------------------------------------
SELECT DISTINCT f.Legajo
FROM #Fases f
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
    WHERE emp.[No_] = f.Legajo)
ORDER BY f.Legajo;
-- Ojo con el GUID de arriba: Employee es tabla base de Microsoft, así que su sufijo NO es el de la
-- extensión. Verificar con: SELECT name FROM sys.tables WHERE name LIKE 'ArbuTest$Employee%'

------------------------------------------------------------------------------------------------
-- 4. Choques contra lo que YA está cargado y contra sí mismo
------------------------------------------------------------------------------------------------
-- 4.a Un estado por empleado y por fecha. El paso 0.b ya apartó los choques internos, así que esto
-- tiene que dar VACÍO: si devuelve algo, es que se corrió el 0 sin el 0.b.
SELECT f.Legajo, f.Fecha, COUNT(*) AS FilasMismaFecha
FROM #Fases f GROUP BY f.Legajo, f.Fecha HAVING COUNT(*) > 1;

SELECT f.Legajo, f.Fecha, f.CodEstado, ee.[Cód_ Estado] AS YaCargadoEnBC
FROM #Fases f
JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  ON ee.[No_ Empleado] = f.Legajo
 AND ee.[Fecha Inicio] = f.Fecha
 AND ee.[Tipo Entidad] = 0
ORDER BY f.Legajo, f.Fecha;

-- 4.b La secuencia: después de una baja solo puede venir un alta.
WITH Sec AS (
    SELECT Legajo, Fecha, CodEstado, EsAlta,
           LAG(EsAlta) OVER (PARTITION BY Legajo ORDER BY Fecha) AS EsAltaAnterior
    FROM #Fases
)
SELECT * FROM Sec WHERE EsAltaAnterior = 0 AND EsAlta = 0     -- dos bajas seguidas
UNION ALL
SELECT * FROM Sec WHERE EsAltaAnterior = 1 AND EsAlta = 1     -- dos altas seguidas
ORDER BY Legajo, Fecha;
-- Dos altas seguidas es el caso que más caro sale: el cálculo de antigüedad pisa la fecha de inicio
-- con la segunda y el primer tramo entero deja de contar.

------------------------------------------------------------------------------------------------
-- 5. LA INSERCIÓN — descomentar recién después de revisar los pasos 1 a 4
--
--     OJO CON LA TRANSACCIÓN ABIERTA. El COMMIT queda a mano a propósito —es la última chance de
--     revertir— pero eso significa que entre el INSERT y tu decisión, esta sesión mantiene BLOQUEADA
--     la tabla Estado Empleado. Y no la bloquea solo para vos: BC deja de poder guardar cualquier
--     cosa que la toque, y el usuario ve "un registro se está actualizando en una transacción
--     realizada en otra sesión" sin ninguna pista de que el culpable es una pestaña de SQL.
--
--     Si el INSERT falla, la transacción NO se cierra sola: queda abierta con el trabajo a medias.
--     Antes de irte a mirar el error, cerrala.
------------------------------------------------------------------------------------------------
-- ¿Quedó algo abierto de un intento anterior? Esto lo dice y lo cierra.
SELECT @@TRANCOUNT AS TransaccionesAbiertasEnEstaSesion;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/*
BEGIN TRANSACTION;

INSERT INTO [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    -- Sin [Descripción Estado]: en BC es un FlowField (un Lookup contra el código de estado), y los
    -- FlowField no existen como columna en SQL — se calculan al mostrarlos. Escribirlo daba
    -- "Invalid column name". Tampoco hace falta: la descripción sale sola del código.
    ([No_ Empleado], [Fecha Inicio], [Cód_ Estado], [Fecha Fin],
     [Observaciones], [No_ Proyecto], [Tipo Entidad],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT
    f.Legajo,
    f.Fecha,
    f.CodEstado,
    -- Contigüidad: cada estado se cierra el día anterior al que empieza el siguiente. El último de
    -- cada legajo queda abierto (fecha en blanco), que es como BC representa "sigue vigente".
    COALESCE(DATEADD(day, -1, LEAD(f.Fecha) OVER (PARTITION BY f.Legajo ORDER BY f.Fecha)), '1753-01-01'),
    f.Observaciones,
    '',
    0,                                   -- Tipo Entidad = Empleado
    NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
             SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #Fases f
-- El JOIN queda aunque ya no se lea ninguna columna de ahí: es el que garantiza que no entre una
-- fila apuntando a un código de estado inexistente, que el motor no reconocería ni como alta ni
-- como baja y simplemente no contaría para la antigüedad.
JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
  ON e.[Código] = f.CodEstado
WHERE EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
              WHERE emp.[No_] = f.Legajo)
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
                  WHERE ee.[No_ Empleado] = f.Legajo
                    AND ee.[Fecha Inicio] = f.Fecha
                    AND ee.[Tipo Entidad] = 0);

PRINT 'Filas insertadas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- Si el número cierra con el paso 1:   COMMIT TRANSACTION;
-- Si no cierra, o el INSERT falló:     ROLLBACK TRANSACTION;
--
-- Una u otra, YA: mientras esto siga abierto, nadie puede cargar un estado desde BC.
*/

-- Quién está bloqueando, si BC empieza a quejarse. Si el program_name dice DBeaver y el host es tu
-- máquina, la transacción abierta es de este script: rollback en la pestaña donde corrió, no acá —
-- la transacción vive en su conexión.
/*
SELECT s.session_id, s.login_name, s.host_name, s.program_name,
       s.open_transaction_count, s.last_request_start_time, t.text AS UltimaSentencia
FROM sys.dm_exec_sessions s
OUTER APPLY (SELECT TOP 1 c.most_recent_sql_handle FROM sys.dm_exec_connections c
             WHERE c.session_id = s.session_id) c
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) t
WHERE s.open_transaction_count > 0
ORDER BY s.last_request_start_time;
*/

------------------------------------------------------------------------------------------------
-- 6. Verificación posterior
------------------------------------------------------------------------------------------------
-- 6.a Estados que quedaron con un hueco o con solapamiento contra el siguiente.
WITH Cargados AS (
    SELECT [No_ Empleado] AS Legajo, [Fecha Inicio] AS Desde, [Fecha Fin] AS Hasta,
           LEAD([Fecha Inicio]) OVER (PARTITION BY [No_ Empleado] ORDER BY [Fecha Inicio]) AS ProxDesde
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE [Tipo Entidad] = 0
)
SELECT * FROM Cargados
WHERE ProxDesde IS NOT NULL
  AND CAST(Hasta AS date) <> DATEADD(day, -1, CAST(ProxDesde AS date))
ORDER BY Legajo, Desde;
-- Vacío = la contigüidad quedó bien. Cualquier fila acá es un día sin estado o un día con dos.

-- 6.b Los que quedan de alta hoy, para contrastar contra Meta4.
SELECT ee.[No_ Empleado], ee.[Fecha Inicio], ee.[Cód_ Estado]
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
  ON e.[Código] = ee.[Cód_ Estado]
WHERE ee.[Tipo Entidad] = 0
  AND e.[Tipo Estado] = 1
  AND ee.[Fecha Fin] = '1753-01-01'
ORDER BY ee.[No_ Empleado];

-- 6.c ¿QUEDÓ ALGO SIN CARGAR? — el control para volver a mirar días o semanas después
--
--     Los pasos 1 y 6 comparan contra #Fases, que muere con la sesión. Este compara directo contra la
--     tabla puente, así que sirve en cualquier momento y desde cualquier pestaña: es el que hay que
--     correr antes de decidir si una corrida hay que repetirla. Correrlo ANTES de volver a ejecutar
--     el paso 5 sobre datos ya cargados; si acá no falta nada, no hay nada que repetir.
WITH Esperado AS (
    SELECT m.LEGAJO AS Legajo, CAST(m.FEC_ALTA AS date) AS Fecha, 'Alta' AS Clase
    FROM dbo.MIG_FasesM4 m
    WHERE m.FEC_ALTA IS NOT NULL
    UNION ALL
    SELECT m.LEGAJO, CAST(m.FEC_BAJA AS date), 'Baja'
    FROM dbo.MIG_FasesM4 m
    WHERE m.FEC_BAJA IS NOT NULL
),
-- Los legajos que no existen en BC nunca se iban a migrar (paso 3). Si no se descuentan acá, inflan
-- el "Faltan" y mandan a repetir una carga que en realidad está completa.
EsperadoReal AS (
    SELECT e.* FROM Esperado e
    WHERE EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
                  WHERE emp.[No_] = e.Legajo COLLATE DATABASE_DEFAULT)
)
SELECT e.Clase,
       COUNT(*)                                                        AS Esperadas,
       SUM(CASE WHEN ee.[No_ Empleado] IS NOT NULL THEN 1 ELSE 0 END)  AS Cargadas,
       SUM(CASE WHEN ee.[No_ Empleado] IS NULL     THEN 1 ELSE 0 END)  AS Faltan
FROM EsperadoReal e
LEFT JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[No_ Empleado] = e.Legajo COLLATE DATABASE_DEFAULT
      AND CAST(ee.[Fecha Inicio] AS date) = e.Fecha
      AND ee.[Tipo Entidad] = 0
GROUP BY e.Clase;

-- 6.d El detalle de lo que falta, con el motivo probable al lado. Casi siempre es una de dos, y
--     ninguna de las dos se arregla volviendo a correr el paso 5:
--       · "dos estados para la misma fecha en Meta4" — lo apartó el paso 0.b, hay que decidir a mano
--         cuál de los dos vale.
--       · "la fecha ya estaba ocupada en BC" — había un estado cargado antes de la migración; el
--         paso 5 no lo pisa, y hace bien.
WITH Esperado AS (
    SELECT m.LEGAJO AS Legajo, CAST(m.FEC_ALTA AS date) AS Fecha, 'Alta' AS Clase
    FROM dbo.MIG_FasesM4 m WHERE m.FEC_ALTA IS NOT NULL
    UNION ALL
    SELECT m.LEGAJO, CAST(m.FEC_BAJA AS date), 'Baja'
    FROM dbo.MIG_FasesM4 m WHERE m.FEC_BAJA IS NOT NULL
)
SELECT e.Legajo, e.Fecha, e.Clase,
       CASE
           WHEN NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
                            WHERE emp.[No_] = e.Legajo COLLATE DATABASE_DEFAULT)
                THEN 'el legajo no existe en BC'
           WHEN (SELECT COUNT(*) FROM Esperado x WHERE x.Legajo = e.Legajo AND x.Fecha = e.Fecha) > 1
                THEN 'dos estados para la misma fecha en Meta4'
           WHEN EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee2
                        WHERE ee2.[No_ Empleado] = e.Legajo COLLATE DATABASE_DEFAULT
                          AND CAST(ee2.[Fecha Inicio] AS date) = e.Fecha)
                THEN 'la fecha ya estaba ocupada en BC'
           ELSE 'sin explicar — mirar'
       END AS MotivoProbable
FROM Esperado e
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
                  WHERE ee.[No_ Empleado] = e.Legajo COLLATE DATABASE_DEFAULT
                    AND CAST(ee.[Fecha Inicio] AS date) = e.Fecha
                    AND ee.[Tipo Entidad] = 0)
ORDER BY MotivoProbable, e.Legajo, e.Fecha;

------------------------------------------------------------------------------------------------
-- 7. DESHACER — la alternativa a tener la transacción abierta
--
--     Un COMMIT no se puede hacer desde otra sesión: la transacción pertenece a la conexión que la
--     abrió, y si esa conexión se cerró, SQL Server la revierte y no hay forma de rescatarla. Por eso
--     la red de seguridad no puede ser solo el COMMIT manual.
--
--     Esta es la otra: correr el paso 5 SIN transacción (comentando el BEGIN y el COMMIT), dejar que
--     cada fila se confirme sola, verificar con el paso 6 y —si algo no cierra— deshacer con esto.
--     La tabla queda bloqueada lo que dure el INSERT y nada más, en vez de quedar bloqueada hasta que
--     alguien decida. Para una carga que corre con gente adentro de BC, sale más barato.
--
--     Identifica lo insertado por tres condiciones a la vez: que la clave (legajo, fecha) esté en la
--     tabla puente, que el creador sea el GUID en cero que escribe este script, y que la marca de
--     creación caiga en la ventana del INSERT. Las tres juntas, porque cada una sola borraría de más:
--     una fila cargada a mano en BC para la misma fecha cumple la primera, y el paso 5 justamente NO
--     la insertó —la salteó con el NOT EXISTS—, así que borrarla sería destruir el dato bueno.
------------------------------------------------------------------------------------------------
-- 7.a Completar la ventana y MIRAR lo que se iría. Si el número no coincide con el "Filas
--     insertadas" que imprimió el paso 5, parar acá y averiguar por qué antes de borrar nada.
/*
DECLARE @Desde datetime2 = '2026-08-22 18:00:00';   -- un rato antes de correr el paso 5, en UTC
DECLARE @Hasta datetime2 = '2026-08-22 23:59:59';   -- un rato después

SELECT COUNT(*) AS FilasQueSeBorrarian
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0
  AND ee.[$systemCreatedBy] = '00000000-0000-0000-0000-000000000000'
  AND ee.[$systemCreatedAt] BETWEEN @Desde AND @Hasta
  AND EXISTS (SELECT 1 FROM dbo.MIG_FasesM4 m
              WHERE m.LEGAJO = ee.[No_ Empleado]
                AND (CAST(m.FEC_ALTA AS date) = CAST(ee.[Fecha Inicio] AS date)
                  OR CAST(m.FEC_BAJA AS date) = CAST(ee.[Fecha Inicio] AS date)));
*/

-- 7.b El borrado, con las mismas tres condiciones. Ojo: los estados de BC mantienen la contigüidad
--     con "Fecha Fin", y esa columna la fue pisando el INSERT en las filas vecinas que YA existían.
--     Borrar las nuevas no le devuelve a las viejas su Fecha Fin anterior. Si en la tabla ya había
--     estados cargados a mano para estos legajos, revisar el paso 6.a después de deshacer.
/*
DELETE ee
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0
  AND ee.[$systemCreatedBy] = '00000000-0000-0000-0000-000000000000'
  AND ee.[$systemCreatedAt] BETWEEN @Desde AND @Hasta
  AND EXISTS (SELECT 1 FROM dbo.MIG_FasesM4 m
              WHERE m.LEGAJO = ee.[No_ Empleado]
                AND (CAST(m.FEC_ALTA AS date) = CAST(ee.[Fecha Inicio] AS date)
                  OR CAST(m.FEC_BAJA AS date) = CAST(ee.[Fecha Inicio] AS date)));
*/

------------------------------------------------------------------------------------------------
-- LO QUE ESTE SCRIPT NO TRAE, a propósito
--
--   FEC_ANTIGUEDAD        — no es la fecha de alta: es la antigüedad reconocida de otra empresa o de
--                           una relación anterior. En BC va en el campo "Antigüedad Reconocida
--                           (años)" del legajo, o —mejor— como fases anteriores con sus fechas
--                           reales. Merece su propia decisión, no un INSERT.
--   FEC_BASE_DESPIDO      — base de cálculo indemnizatoria; hoy BC no tiene dónde guardarla.
--   NUM_MATRICULA, NUM_PLURIEMPLEO, DIRECCION_MAIL, EXTENSION_TELEFONICA
--                         — son datos del legajo, no de la fase. Van en el Employee, en otra
--                           migración.
--   ID_ESTADO_NOMINA, ID_ESTADO_PLANTILLA, los campos ST de certificación
--                         — específicos de Meta4, sin equivalente acá.
--
-- Después de migrar conviene revisar en BC, para un puñado de legajos conocidos:
--   · "Fases de Alta" (desde el legajo): que cada alta tenga su baja y su motivo.
--   · Que la antigüedad calculada coincida con la que informa Meta4.
------------------------------------------------------------------------------------------------
