/*
    SINCRONIZACIÓN NAV 2013R2 → BC 25.2 — LA MITAD SQL
    Se ejecuta contra la base de BC (SQL Server). El origen, NAV 2013R2, vive en otro servidor y se
    alcanza por un linked server.

    QUÉ HACE Y QUÉ NO HACE
    Este script SÓLO transporta filas: lee de NAV lo que cambió desde la última corrida y lo deja en
    las tablas de staging de la extensión de liquidación. NO escribe ni una fila en Job, en Employee
    ni en las tablas de descarga. Eso lo hace AL, desde la codeunit "Sinc NAV Liq." que corre en una
    entrada de proyecto (Job Queue).

    Esa división no es una preferencia de estilo. Un INSERT por SQL contra las tablas de BC:
      · no crea la fase de alta en "Estado Empleado" — y sin esa fila la antigüedad da cero y los
        francos no devengan;
      · no materializa las Default Dimensions de Buque y Marea del proyecto;
      · no dispara el cierre de asignaciones que ocurre al cargar la fecha de arribo de una marea;
      · deja al service tier sirviendo el caché viejo, porque nadie le avisó que la tabla cambió.
    Las tablas de staging, en cambio, son tablas tontas que existen justamente para que las escriba
    este script.

    CÓMO DETECTA LOS CAMBIOS
    Por rowversion. Cada tabla de NAV tiene su columna [timestamp], que se incrementa en cada INSERT
    y en cada UPDATE. Se guarda hasta dónde se leyó ("Marca de Agua", visible y editable desde BC) y
    en la corrida siguiente se piden sólo las filas con timestamp mayor.

    El detalle que hace que esto no pierda filas es el techo: no se lee hasta el último rowversion
    existente sino hasta min_active_rowversion() - 1, o sea hasta antes de la transacción abierta más
    vieja del origen. Sin ese techo, una fila de una transacción que todavía no confirmó recibe un
    rowversion bajo al confirmarse, la marca de agua ya pasó de largo, y esa descarga no llega nunca
    a BC. No falla nada: simplemente falta.

    LAS BAJAS NO SE DETECTAN ASÍ. Un DELETE en NAV no deja rastro en ningún rowversion. Hoy no hacen
    falta —el alcance acordado es altas y modificaciones—, y si algún día hacen falta el camino es
    activar Change Tracking en la base de NAV, no parchear esto.

    DÓNDE SE CONFIGURA
    EN BC, en la página "Configuración Sincronización NAV". Ahí van el nombre del linked server, la
    base y la empresa de NAV, la empresa de BC que le corresponde y los nombres de las cinco tablas
    del origen. ESTE SCRIPT NO SE EDITA para nada de eso: los procedimientos leen esa tabla, y mover
    el origen de servidor o agregar una empresa se hace desde la interfaz, sin abrir SSMS.

    La única excepción son las credenciales del linked server —usuario y contraseña— que se definen
    una vez en el paso 1 y a propósito no se ven desde BC.

    ORDEN DE INSTALACIÓN
      1. Publicar la extensión de liquidación con los objetos de sincronización.
      2. Abrir "Sincronización con NAV" en BC una vez: crea las cinco filas de control.
      3. Paso 1 de este script: crear el linked server (una sola vez, con el DBA).
      4. En BC, cargar "Configuración Sincronización NAV" con el nombre que le pusiste al linked
         server, la base y la empresa de NAV, y la empresa de BC.
      5. Paso 3: verificar que los nombres de columna del origen sean los que el script espera.
         NO SALTEAR. Es el paso que ahorra la tarde de depurar por qué el MERGE no encuentra una
         columna que en NAV se llama parecido pero no igual.
      6. Pasos 4, 5 y 6: crear los tres procedimientos. LOS TRES.
      7. Paso 7: correr a mano y mirar el resultado en BC.
      8. Paso 8: crear el job del Agent cada 15 minutos.
      9. Configurar la entrada de proyecto en BC para la codeunit "Sinc NAV Liq.", cada 15 minutos.

    CÓMO SE EJECUTA: UN BLOQUE POR VEZ. NO EL ARCHIVO ENTERO.
    Correr todo de una no funciona en ningún cliente, y no es un problema de este script: CREATE OR
    ALTER PROCEDURE tiene que ser la PRIMERA sentencia de su lote, y acá hay tres (pasos 4, 5 y 6).

    Y cada bloque va COMPLETO, desde su primera línea hasta la última. Los bloques 0, 2 y 3 arrancan
    con un DECLARE y lo usan más abajo; el alcance de una variable es el lote, así que si seleccionás
    de la mitad para abajo el servidor contesta "Must declare the scalar variable" sobre una variable
    que en el archivo está declarada tres líneas más arriba. El error señala el uso, nunca la
    selección, y por eso manda a buscar el problema al lugar equivocado.

    Sin GO: no es T-SQL sino una marca de separación de lotes que entienden SSMS y sqlcmd. Un cliente
    JDBC —DBeaver, DataGrip— se la manda al servidor tal cual y responde "Incorrect syntax near 'GO'".
    Como el script se corre bloque por bloque, el separador no hace falta: cada ejecución ya es su
    propio lote.
*/

------------------------------------------------------------------------------------------------
-- 0. Guardián: esto tiene que correr en la base de BC.
--
--    No compara contra un nombre de base escrito a mano, que sería otra cosa más para mantener:
--    busca la tabla de control de la extensión. Si está, estamos donde hay que estar.
------------------------------------------------------------------------------------------------

-- El nombre de la base va por variable y no como DB_NAME() adentro del RAISERROR: los argumentos
-- de sustitución sólo admiten constantes o variables, y una llamada a función ahí no es un error
-- de ejecución sino de sintaxis — "Incorrect syntax near 'DB_NAME'" — o sea que no corta este
-- bloque, corta el parseo de todo el lote. Y va con N'' en las dos puntas porque %s de un mensaje
-- ANSI no acepta un argumento nvarchar, que es lo que devuelve DB_NAME().
DECLARE @BaseActual sysname = DB_NAME();

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name LIKE N'%$Ctrl Sinc NAV$%')
    RAISERROR(N'La base %s no tiene la tabla de control de la sincronización. O el editor está apuntando a otra base, o falta publicar la extensión de liquidación y abrir una vez la página "Sincronización con NAV".', 16, 1, @BaseActual);

------------------------------------------------------------------------------------------------
-- 1. El linked server. Se crea UNA VEZ, con el DBA, y no vuelve a tocarse.
--
--    Va del lado de BC apuntando a NAV, y no al revés, por dos razones: NAV es la base vieja de
--    producción y no se le agregan objetos ni jobs, y el proceso que puede fallar conviene tenerlo
--    donde importa que no falle.
--
--    El login remoto necesita SOLO LECTURA sobre la base de NAV (db_datareader alcanza) más permiso
--    para ejecutar min_active_rowversion(), que viene incluido con VIEW DATABASE STATE.
--
--    'rpc out' TIENE QUE QUEDAR EN TRUE: el paso 5.2 lee el techo de rowversion llamando al
--    sp_executesql del origen con nombre de cuatro partes, y eso es RPC. Es lo único que este script
--    necesita además del acceso de lectura.
--
--    @catalog, en cambio, es opcional. La base va fijada en el nombre de cuatro partes, así que no
--    depende de esa opción. Ponerlo igual no molesta y evita sorpresas si alguien consulta a mano.
--
--    NO hace falta MSDTC. Se llega a necesitarlo si el techo se lee con INSERT ... EXEC ... AT,
--    porque eso promueve a transacción distribuida; con OUTPUT de un RPC, no.
--
--    Este bloque es el único con valores escritos a mano, y es a propósito: son credenciales y no
--    van en una tabla. El nombre que le pongas acá es el que va después en la página "Configuración
--    Sincronización NAV" de BC.
------------------------------------------------------------------------------------------------

/*  Descomentar y ejecutar una sola vez, ajustando servidor, base y credenciales.

EXEC master.dbo.sp_addlinkedserver
     @server     = N'navdb.arbumasa.com',
     @srvproduct = N'',
     @provider   = N'MSOLEDBSQL',
     -- OJO: @datasrc es el SERVIDOR DE SQL, no el service tier de NAV. Va 'host\instancia' o
     -- 'host,1433'. Una dirección con :7046/Instancia es el endpoint del NST (el que usa el cliente
     -- de NAV), y por ahí no se conecta ningún linked server: el puerto ni siquiera habla TDS.
     @datasrc    = N'navdb.arbumasa.com\MSSQLSERVER',
     @catalog    = N'Navision';

EXEC master.dbo.sp_addlinkedsrvlogin
     @rmtsrvname  = N'navdb.arbumasa.com',
     @useself     = N'False',
     @locallogin  = NULL,
     @rmtuser     = N'usr_sinc_bc',
     @rmtpassword = N'********';

EXEC master.dbo.sp_serveroption @server = N'navdb.arbumasa.com', @optname = N'rpc out',              @optvalue = N'true';
EXEC master.dbo.sp_serveroption @server = N'navdb.arbumasa.com', @optname = N'collation compatible', @optvalue = N'false';

-- Prueba de vida:
SELECT TOP 1 * FROM OPENQUERY([navdb.arbumasa.com], 'SELECT 1 AS ok');
*/

------------------------------------------------------------------------------------------------
-- 2. LA CONFIGURACIÓN — SE CARGA EN BC, NO ACÁ
--
--    Página "Configuración Sincronización NAV". Una fila por par de empresas (una en BC, la que le
--    corresponde en NAV). Si mañana hay una segunda empresa es una fila más y el job del Agent no se
--    toca: SincNAV_TraerTodo recorre todas las activas.
--
--    La tabla es DataPerCompany = false, y eso es lo que hace que esto funcione: sin prefijo de
--    empresa se llama en SQL 'Config Sinc NAV$<AppId>' y el procedimiento la encuentra con un LIKE,
--    sin tener que saber de antemano en qué empresa buscar. Si fuera por empresa, para leer la tabla
--    que dice cuál es la empresa habría que saber cuál es la empresa.
--
--    Este bloque no configura nada: muestra lo que hay cargado, para verificarlo desde SQL cuando el
--    problema es justamente que BC no abre.
------------------------------------------------------------------------------------------------

DECLARE @TblCfg nvarchar(300), @qcfg nvarchar(max);
SELECT TOP 1 @TblCfg = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

-- THROW y no RAISERROR: RAISERROR informa pero deja seguir el lote, y la línea siguiente armaría la
-- consulta concatenando un NULL. El error que se vería sería el de la concatenación, no el real.
IF @TblCfg IS NULL
    THROW 50004, 'No está la tabla de configuración. Falta publicar la extensión con los objetos de sincronización.', 1;

SET @qcfg = N'SELECT [Empresa BC], [Empresa NAV], [Linked Server], [Base NAV],
                     [Tabla Empleado], [Tabla Proyecto], [Tabla Descarga Cab], [Tabla Descarga Lin],
                     [Activo]
              FROM ' + @TblCfg + N' ORDER BY [Empresa BC];';
EXEC sp_executesql @qcfg;

------------------------------------------------------------------------------------------------
-- 3. VERIFICACIÓN DE NOMBRES — el paso que no hay que saltear.
--
--    Compara lo que el procedimiento va a pedir contra lo que el origen tiene de verdad, para cada
--    empresa activa de la configuración. Lo que salga listado hay que corregirlo antes de seguir:
--    si es un nombre de TABLA, desde la página de configuración en BC; si es un nombre de COLUMNA,
--    en el MERGE correspondiente del paso 5.
--
--    Va por sp_executesql porque el nombre del linked server sale de la configuración y un nombre
--    de cuatro partes no admite variables.
------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Esperado') IS NOT NULL DROP TABLE #Esperado;
-- COLLATE DATABASE_DEFAULT y no el tipo pelado: una tabla temporal vive en tempdb y hereda la
-- collation del SERVIDOR, no la de la base donde estás parado. Acá no son la misma —la base de BC
-- tiene la suya— así que sin esto la columna nace con una collation y se compara contra otra.
CREATE TABLE #Esperado (Entidad varchar(20), Columna sysname COLLATE DATABASE_DEFAULT);

-- LOS NOMBRES DE ACÁ SON LOS DE SQL, NO LOS DEL CLIENTE DE NAV. La misma sustitución que se aplica
-- al nombre de la empresa ("Arbumasa S.A." -> "Arbumasa S_A_") se aplica a cada columna: el punto y
-- el apóstrofe se convierten en guión bajo. Por eso "No." es [No_], "Social Security No." es
-- [Social Security No_] y "Transport's license" es [Transport_s license].
--
-- Escribir el nombre lindo no da un error que lo explique: el linked server contesta
-- "Invalid column name 'No.'", sin decir que la columna existe con otro nombre. Este bloque es el
-- que lo detecta antes — de ahí que el encabezado insista en no saltearlo.
-- NOMBRE Y APELLIDOS: la localización española de NAV parte el nombre en tres campos con una
-- semántica distinta de la inglesa. No hay 'First Name' ni 'Last Name': hay [Name] (el nombre de
-- pila), [First Family Name] (primer apellido) y [Second Family Name] (segundo apellido).
--
-- El staging los guarda como Nombre / Apellido / Segundo Nombre, y ese último nombre quedó mal
-- puesto: lo que entra ahí es el SEGUNDO APELLIDO, no un segundo nombre de pila.
--
-- Existe además pat_Apellido y pat_Nombre, del add-in de sueldos. Se usan los estándar porque son
-- los que NAV garantiza poblados; si en esta base los que están cargados son los pat_, hay que
-- cambiarlos acá y en el MERGE (ver la consulta de control al final del bloque 3).
INSERT INTO #Esperado (Entidad, Columna) VALUES
 ('Empleado', N'No_'),                        ('Empleado', N'Name'),
 ('Empleado', N'Second Family Name'),         ('Empleado', N'First Family Name'),
 ('Empleado', N'Initials'),                   ('Empleado', N'Job Title'),
 ('Empleado', N'Employment Date'),            ('Empleado', N'Social Security No_'),
 ('Empleado', N'CIF_NIF'),                    ('Empleado', N'Birth Date'),
 ('Empleado', N'Address'),                    ('Empleado', N'Address 2'),
 ('Empleado', N'City'),                       ('Empleado', N'Post Code'),
 ('Empleado', N'Phone No_'),                  ('Empleado', N'E-Mail'),
 ('Empleado', N'pat_Cod_ convenio'),          ('Empleado', N'Categoría'),

 ('Proyecto', N'No_'),                        ('Proyecto', N'Description'),
 ('Proyecto', N'Description 2'),              ('Proyecto', N'Starting Date'),
 ('Proyecto', N'Ending Date'),                ('Proyecto', N'Global Dimension 1 Code'),
 -- Las dimensiones 2 y 3 van cruzadas: en NAV la 2 es la ACTIVIDAD y la 3 es la MAREA; en BC es al
 -- revés. Las dos se leen (ver el MERGE de Proyecto), y cada una va a la que le toca del otro lado.
 -- La 3 es un campo de la personalización de NAV (50000), no de la tabla estándar: si esta
 -- verificación la marca como inexistente, los proyectos quedarían sin marea y sin un solo error.
 ('Proyecto', N'Global Dimension 2 Code'),    ('Proyecto', N'Global Dimension 3 Code'),
 ('Proyecto', N'Status'),
 ('Proyecto', N'Tipo'),                       ('Proyecto', N'Patron'),
 ('Proyecto', N'Hora de zarpada'),            ('Proyecto', N'Hora ingreso a puerto'),
 ('Proyecto', N'Fecha llegada prevista'),     ('Proyecto', N'Puerto zarpada'),
 ('Proyecto', N'Puerto Descarga'),            ('Proyecto', N'Año marea'),

 ('DescargaCab', N'N° proyecto'),            ('DescargaCab', N'Capitán'),
 ('DescargaCab', N'Actividad'),               ('DescargaCab', N'Fecha de inicio de descarga'),
 ('DescargaCab', N'Buque'),                   ('DescargaCab', N'Marea'),
 ('DescargaCab', N'Location'),                ('DescargaCab', N'Libro Diario'),
 ('DescargaCab', N'Puerto'),                  ('DescargaCab', N'Pallets desde'),
 ('DescargaCab', N'Pallets hasta'),           ('DescargaCab', N'Hora inicio descarga'),
 ('DescargaCab', N'Hora fin descarga'),       ('DescargaCab', N'Scale code'),
 ('DescargaCab', N'Registrado'),              ('DescargaCab', N'Origen del cartón'),

 ('DescargaLin', N'No_ proyecto'),            ('DescargaLin', N'Line no_'),
 ('DescargaLin', N'No_ remito'),              ('DescargaLin', N'Item no_'),
 ('DescargaLin', N'Description'),             ('DescargaLin', N'Unidad medida'),
 ('DescargaLin', N'Cantidad'),                ('DescargaLin', N'Net weight'),
 ('DescargaLin', N'Gross weight'),            ('DescargaLin', N'Fecha remito'),
 ('DescargaLin', N'Transport_s license'),     ('DescargaLin', N'Temperatura'),
 ('DescargaLin', N'Hora de ingreso'),         ('DescargaLin', N'Tipo de amparo sanitario'),
 ('DescargaLin', N'No_ amparo sanitario'),    ('DescargaLin', N'Destino'),
 ('DescargaLin', N'No_ Pallet'),              ('DescargaLin', N'Location'),
 ('DescargaLin', N'Buque'),                   ('DescargaLin', N'Marea'),
 ('DescargaLin', N'Puerto'),                  ('DescargaLin', N'Promedio'),
 ('DescargaLin', N'Bin code'),                ('DescargaLin', N'Tare'),
 ('DescargaLin', N'Gross + Tare'),            ('DescargaLin', N'Weighing Date and Time'),
 ('DescargaLin', N'Confirmed'),               ('DescargaLin', N'Status'),
 ('DescargaLin', N'Actividad'),               ('DescargaLin', N'Familia'),
 ('DescargaLin', N'Subfamilia'),              ('DescargaLin', N'Manual unit of measure'),
 ('DescargaLin', N'Manual weight'),

 -- Sólo las cinco columnas que se traen. Es una tabla estándar de NAV, no una personalización, así
 -- que es la menos probable de haber cambiado de nombre; se verifica igual porque el costo es cero.
 ('ValorDim', N'Dimension Code'),            ('ValorDim', N'Code'),
 ('ValorDim', N'Name'),                      ('ValorDim', N'Blocked'),
 ('ValorDim', N'Dimension Value Type');

DECLARE @cfgEmpBC nvarchar(100), @cfgEmpNAV nvarchar(100), @cfgSrv sysname, @cfgDb sysname,
        @cfgTEmp sysname, @cfgTProy sysname, @cfgTCab sysname, @cfgTLin sysname, @cfgTDim sysname,
        @chk nvarchar(max), @cfgTbl nvarchar(300), @cfgSel nvarchar(max),
        @Conecta bit, @probeSql nvarchar(max), @probeN int;

-- La configuración vive en la tabla de la extensión, que no tiene prefijo de empresa. Se copia a
-- una temporal porque un cursor no puede recorrer una tabla cuyo nombre sale de SQL dinámico.
SELECT TOP 1 @cfgTbl = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

IF OBJECT_ID('tempdb..#cfg') IS NOT NULL DROP TABLE #cfg;
CREATE TABLE #cfg (EmpresaBC nvarchar(100), EmpresaNAV nvarchar(100), Srv sysname, Db sysname,
                   TEmp sysname, TProy sysname, TCab sysname, TLin sysname, TDim sysname);

SET @cfgSel = N'SELECT [Empresa BC], [Empresa NAV], [Linked Server], [Base NAV],
                       [Tabla Empleado], [Tabla Proyecto], [Tabla Descarga Cab], [Tabla Descarga Lin],
                       [Tabla Valor Dimension]
                FROM ' + @cfgTbl + N' WHERE [Activo] = 1;';
INSERT INTO #cfg EXEC sp_executesql @cfgSel;

-- 3.a EL LINKED SERVER, ANTES DE MIRAR NINGUNA COLUMNA.
--     Lo único que tiene que estar es 'rpc out': el paso 5.2 lee min_active_rowversion() llamando
--     al sp_executesql del origen con nombre de cuatro partes, y eso es una llamada RPC.
--
--     El CATÁLOGO POR DEFECTO se muestra pero NO bloquea: como la base va fijada en el nombre de
--     cuatro partes, da igual lo que tenga el linked server configurado. Estuvo un rato siendo
--     obligatorio —cuando el techo se leía con OPENQUERY— y se dejó de depender de él justamente
--     porque es una opción invisible que sólo se puede cambiar recreando el linked server.
SELECT  c.EmpresaBC,
        c.Srv                                   AS [Linked Server configurado],
        CASE WHEN s.name IS NULL                 THEN 'NO EXISTE'
             WHEN s.is_rpc_out_enabled = 0       THEN 'FALTA rpc out'
             ELSE 'ok' END                      AS Estado,
        s.data_source                           AS [Apunta a],
        c.Db                                    AS [Base NAV configurada],
        s.catalog                               AS [Catálogo por defecto (informativo)],
        s.is_collation_compatible               AS [Collation compatible],
        CASE WHEN s.name IS NULL OR s.is_rpc_out_enabled = 0
             THEN N'EXEC master.dbo.sp_serveroption @server = N''' + c.Srv + N''', @optname = N''rpc out'', @optvalue = N''true'';'
             ELSE N'' END                       AS [Corregir con]
FROM    #cfg c
LEFT JOIN sys.servers s ON s.name = c.Srv COLLATE DATABASE_DEFAULT;

DECLARE cfg CURSOR LOCAL FAST_FORWARD FOR
    SELECT EmpresaBC, EmpresaNAV, Srv, Db, TEmp, TProy, TCab, TLin, TDim FROM #cfg;

OPEN cfg;
FETCH NEXT FROM cfg INTO @cfgEmpBC, @cfgEmpNAV, @cfgSrv, @cfgDb, @cfgTEmp, @cfgTProy, @cfgTCab, @cfgTLin, @cfgTDim;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- 3.b PRUEBA DE VIDA antes de la consulta pesada.
    --     Si las credenciales del linked server no andan, sin esto el error que sale es un
    --     "Login failed for user 'X'" disparado desde adentro de una consulta contra sys.columns:
    --     no dice a qué servidor intentó entrar, ni que el problema son las credenciales y no los
    --     nombres de las columnas que el bloque dice estar verificando. Además aborta el lote, así
    --     que las demás empresas ni se miran. Acá se atrapa, se informa con nombre, y el recorrido
    --     sigue con la siguiente.
    SET @Conecta = 1;
    BEGIN TRY
        SET @probeSql = N'SELECT @n = uno FROM OPENQUERY(' + QUOTENAME(@cfgSrv) + N', ''SELECT 1 AS uno'');';
        EXEC sp_executesql @probeSql, N'@n int OUTPUT', @n = @probeN OUTPUT;
    END TRY
    BEGIN CATCH
        SET @Conecta = 0;
        SELECT @cfgEmpBC AS EmpresaBC,
               @cfgSrv   AS [Linked Server],
               'NO CONECTA' AS Estado,
               ERROR_MESSAGE() AS Motivo,
               N'Si dice "Login failed": el login remoto del linked server no existe en el origen, está deshabilitado, o la contraseña guardada no es la correcta. Se corrige con sp_addlinkedsrvlogin (ver paso 1). Ojo: para un login SQL el servidor de origen tiene que estar en modo mixto.' AS [Qué mirar];
    END CATCH

    IF @Conecta = 0
    BEGIN
        FETCH NEXT FROM cfg INTO @cfgEmpBC, @cfgEmpNAV, @cfgSrv, @cfgDb, @cfgTEmp, @cfgTProy, @cfgTCab, @cfgTLin, @cfgTDim;
        CONTINUE;
    END

    -- 3.c LOS PREFIJOS DE EMPRESA QUE EXISTEN DE VERDAD EN EL ORIGEN.
    --     NAV no usa el nombre de la empresa tal cual para el nombre de la tabla: reemplaza los
    --     caracteres que no valen como identificador de SQL. "Arbumasa S.A." termina siendo
    --     "Arbumasa S_A_", con los puntos convertidos en guiones bajos. Escribir el nombre lindo en
    --     la configuración de BC no da un error claro: da "Invalid object name", que es el mismo
    --     mensaje que sale cuando no tenés permiso, y manda a revisar permisos que están bien.
    --
    --     Acá salen los prefijos reales. El que va en "Empresa en NAV" es uno de éstos, tal cual.
    SET @chk = N'
    SELECT DISTINCT LEFT(t.name, CHARINDEX(''$'', t.name) - 1) AS [Prefijo de empresa en el origen],
           ' + QUOTENAME(@cfgEmpNAV, '''') + N' AS [Lo que dice la configuración de BC]
    FROM   ' + QUOTENAME(@cfgSrv) + N'.' + QUOTENAME(@cfgDb) + N'.sys.tables t
    WHERE  CHARINDEX(''$'', t.name) > 1
    ORDER BY 1;';
    EXEC sp_executesql @chk;

    SET @chk = N'
    SELECT  ' + QUOTENAME(@cfgEmpBC, '''') + N' AS EmpresaBC,
            e.Entidad,
            CASE e.Entidad WHEN ''Empleado''    THEN ' + QUOTENAME(@cfgTEmp,  '''') + N'
                           WHEN ''Proyecto''    THEN ' + QUOTENAME(@cfgTProy, '''') + N'
                           WHEN ''DescargaCab'' THEN ' + QUOTENAME(@cfgTCab,  '''') + N'
                           WHEN ''DescargaLin'' THEN ' + QUOTENAME(@cfgTLin,  '''') + N'
                                                ELSE ' + QUOTENAME(@cfgTDim,  '''') + N' END AS TablaOrigen,
            e.Columna AS [No existe en el origen]
    FROM    #Esperado e
    WHERE   NOT EXISTS (
                SELECT 1
                FROM   ' + QUOTENAME(@cfgSrv) + N'.' + QUOTENAME(@cfgDb) + N'.sys.columns c
                JOIN   ' + QUOTENAME(@cfgSrv) + N'.' + QUOTENAME(@cfgDb) + N'.sys.tables  t ON t.object_id = c.object_id
                -- COLLATE DATABASE_DEFAULT en LAS DOS PUNTAS de cada comparación. Los nombres de
                -- objeto que vuelven del origen traen la collation de la base de NAV y los de acá
                -- la de la base de BC; son distintas (Modern_Spanish_100_CI_AS contra
                -- Modern_Spanish_CI_AS) y comparar sysname entre servidores da "Cannot resolve the
                -- collation conflict". Forzar sólo un lado no alcanza: el otro sigue trayendo la
                -- suya. Y los paréntesis alrededor de la concatenación no son decorativos — sin
                -- ellos COLLATE se aplicaría nada más al último CASE, no a la expresión entera.
                WHERE  t.name COLLATE DATABASE_DEFAULT =
                       (' + QUOTENAME(@cfgEmpNAV, '''') + N' + N''$'' +
                                 CASE e.Entidad WHEN ''Empleado''    THEN ' + QUOTENAME(@cfgTEmp,  '''') + N'
                                                WHEN ''Proyecto''    THEN ' + QUOTENAME(@cfgTProy, '''') + N'
                                                WHEN ''DescargaCab'' THEN ' + QUOTENAME(@cfgTCab,  '''') + N'
                                                WHEN ''DescargaLin'' THEN ' + QUOTENAME(@cfgTLin,  '''') + N'
                                                                     ELSE ' + QUOTENAME(@cfgTDim,  '''') + N' END
                       ) COLLATE DATABASE_DEFAULT
                  AND  c.name COLLATE DATABASE_DEFAULT = e.Columna COLLATE DATABASE_DEFAULT)
    ORDER BY e.Entidad, e.Columna;';

    EXEC sp_executesql @chk;

    FETCH NEXT FROM cfg INTO @cfgEmpBC, @cfgEmpNAV, @cfgSrv, @cfgDb, @cfgTEmp, @cfgTProy, @cfgTCab, @cfgTLin, @cfgTDim;
END
CLOSE cfg; DEALLOCATE cfg;
DROP TABLE #Esperado;
DROP TABLE #cfg;

/*  EL OTRO LADO: CÓMO SE LLAMAN DE VERDAD LAS COLUMNAS DEL ORIGEN, EN LAS CUATRO TABLAS.

    Correr esto ANTES de empezar a corregir nombres de a uno. El bloque 3 dice cuáles no existen;
    esto dice cómo se llaman en realidad, que es lo que hace falta para arreglarlas todas juntas.

    Sin esto se cae en el bucle de una corrida por columna: el linked server sólo reporta la PRIMERA
    columna inválida de la consulta, así que cada intento descubre exactamente un nombre nuevo.

    Dos motivos por los que un nombre no coincide, y los dos se ven acá:
      · La sustitución de caracteres: el punto y el apóstrofe pasan a guión bajo ([No_],
        [Transport_s license]).
      · EL IDIOMA DE LA BASE. Si NAV se instaló en español, los campos de las tablas estándar están
        en castellano o siguen la semántica local: en esta base no hay 'Last Name' ni 'First Name',
        hay [Name], [First Family Name] y [Second Family Name]; y 'Year tide' es [Año marea].
      · Y NO HAY UNA CONVENCIÓN ÚNICA ni siquiera entre tablas hermanas del mismo desarrollo:
        [Cab_ descarga] usa [N° proyecto] con el símbolo de grado, y [Lín_ descarga] usa
        [No_ proyecto] con guión bajo. Mismo campo conceptual, dos nombres. Por eso esta consulta
        existe: adivinar no sirve.

DECLARE @srv sysname, @db sysname, @emp nvarchar(100), @q nvarchar(max), @t nvarchar(300),
        @tE sysname, @tP sysname, @tC sysname, @tL sysname;
SELECT TOP 1 @t = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

SET @q = N'SELECT TOP 1 @s = [Linked Server], @d = [Base NAV], @e = [Empresa NAV],
                  @e1 = [Tabla Empleado], @e2 = [Tabla Proyecto],
                  @e3 = [Tabla Descarga Cab], @e4 = [Tabla Descarga Lin]
           FROM ' + @t + N' WHERE [Activo] = 1;';
EXEC sp_executesql @q,
     N'@s sysname OUTPUT, @d sysname OUTPUT, @e nvarchar(100) OUTPUT,
       @e1 sysname OUTPUT, @e2 sysname OUTPUT, @e3 sysname OUTPUT, @e4 sysname OUTPUT',
     @s = @srv OUTPUT, @d = @db OUTPUT, @e = @emp OUTPUT,
     @e1 = @tE OUTPUT, @e2 = @tP OUTPUT, @e3 = @tC OUTPUT, @e4 = @tL OUTPUT;

SET @q = N'SELECT t.name AS Tabla, c.column_id AS Orden, c.name AS Columna,
                  ty.name AS Tipo, c.max_length AS Largo
           FROM   ' + QUOTENAME(@srv) + N'.' + QUOTENAME(@db) + N'.sys.columns c
           JOIN   ' + QUOTENAME(@srv) + N'.' + QUOTENAME(@db) + N'.sys.tables  t  ON t.object_id = c.object_id
           JOIN   ' + QUOTENAME(@srv) + N'.' + QUOTENAME(@db) + N'.sys.types   ty ON ty.user_type_id = c.user_type_id
           WHERE  t.name COLLATE DATABASE_DEFAULT IN (@n1, @n2, @n3, @n4)
           ORDER BY t.name, c.column_id;';
-- Los cuatro nombres van precalculados en variables: sp_executesql no admite una EXPRESIÓN como
-- valor de parámetro, sólo una constante o una variable. Concatenar ahí mismo da "Incorrect syntax
-- near '+'", que es un error de parseo y no dice qué parámetro lo causó.
DECLARE @n1 nvarchar(300) = @emp + N'$' + @tE, @n2 nvarchar(300) = @emp + N'$' + @tP,
        @n3 nvarchar(300) = @emp + N'$' + @tC, @n4 nvarchar(300) = @emp + N'$' + @tL;

EXEC sp_executesql @q,
     N'@n1 nvarchar(300), @n2 nvarchar(300), @n3 nvarchar(300), @n4 nvarchar(300)',
     @n1 = @n1, @n2 = @n2, @n3 = @n3, @n4 = @n4;
*/

------------------------------------------------------------------------------------------------
-- 4. El auxiliar que mueve la marca de agua.
--
--    Se llama al final de cada entidad, y sólo si el MERGE terminó bien: si algo falló, la marca no
--    se mueve y la corrida siguiente vuelve a pedir lo mismo. Repetir es inofensivo —el MERGE es
--    idempotente—; saltear no lo es.
--
--    Crear ESTE antes que el del paso 5. SQL Server deja crear el otro aunque éste no exista
--    —resuelve el nombre recién al ejecutar— así que el olvido no da error hasta la primera corrida.
------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.SincNAV_ActualizarControl
    @TblCtrl nvarchar(300),
    @Entidad int,
    @Techo   bigint,
    @Filas   int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql      nvarchar(max),
            @TechoTxt nvarchar(20) = CONVERT(nvarchar(20), @Techo);

    SET @sql = N'
        UPDATE ' + @TblCtrl + N'
        SET    [Marca Agua]        = @techo,
               [Traido El]         = SYSUTCDATETIME(),
               [Filas Traidas]     = @filas,
               [$systemModifiedAt] = SYSUTCDATETIME()
        WHERE  [Entidad] = @ent;';

    EXEC sp_executesql @sql,
         N'@techo nvarchar(20), @filas int, @ent int',
         @techo = @TechoTxt, @filas = @Filas, @ent = @Entidad;
END;

------------------------------------------------------------------------------------------------
-- 5. EL PROCEDIMIENTO PRINCIPAL — trae una empresa.
--
--    Recibe sólo la empresa de BC; el resto (linked server, base y empresa de NAV, nombres de las
--    tablas del origen) lo lee de la configuración que se carga en BC.
--
--    Los nombres de las tablas de BC tampoco se escriben a mano: en BC una tabla de extensión se
--    llama '<Empresa>$<Tabla>$<AppId>', y el AppId se descubre acá para que el script no haya que
--    tocarlo si algún día cambia. Las tablas de staging, del lado AL, se nombraron sin puntos ni
--    acentos justamente para que estas referencias sean literales y no haya que adivinar
--    conversiones.
------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.SincNAV_Traer
    @EmpresaBC nvarchar(100),
    @Debug     bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EmpresaNAV nvarchar(100), @Servidor sysname, @BaseNAV sysname,
            @TabEmp sysname, @TabProy sysname, @TabCab sysname, @TabLin sysname, @TabDim sysname,
            @TblCfg nvarchar(300), @cfg nvarchar(max);

    -- La configuración se carga en BC, en "Configuración Sincronización NAV". Su tabla no lleva
    -- prefijo de empresa (DataPerCompany = false), así que se encuentra sin saber en qué empresa
    -- estamos parados: es lo que permite que la propia empresa sea un dato configurable.
    SELECT TOP 1 @TblCfg = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

    IF @TblCfg IS NULL
        THROW 50004, 'No existe la tabla de configuración de la sincronización. Falta publicar la extensión de liquidación con los objetos de sincronización.', 1;

    SET @cfg = N'SELECT TOP 1 @eNAV = [Empresa NAV], @srv = [Linked Server], @db = [Base NAV],
                        @tE = [Tabla Empleado], @tP = [Tabla Proyecto],
                        @tC = [Tabla Descarga Cab], @tL = [Tabla Descarga Lin],
                        @tD = [Tabla Valor Dimension]
                 FROM ' + @TblCfg + N' WHERE [Empresa BC] = @e AND [Activo] = 1;';

    EXEC sp_executesql @cfg,
         N'@e nvarchar(100), @eNAV nvarchar(100) OUTPUT, @srv sysname OUTPUT, @db sysname OUTPUT,
           @tE sysname OUTPUT, @tP sysname OUTPUT, @tC sysname OUTPUT, @tL sysname OUTPUT,
           @tD sysname OUTPUT',
         @e = @EmpresaBC, @eNAV = @EmpresaNAV OUTPUT, @srv = @Servidor OUTPUT, @db = @BaseNAV OUTPUT,
         @tE = @TabEmp OUTPUT, @tP = @TabProy OUTPUT, @tC = @TabCab OUTPUT, @tL = @TabLin OUTPUT,
         @tD = @TabDim OUTPUT;

    -- Config vieja, de antes de que existiera la entidad de valores de dimensión: el campo está en
    -- blanco y sin esto el nombre de tabla saldría NULL y el MERGE quedaría en nada, sin avisar.
    SET @TabDim = ISNULL(NULLIF(@TabDim, N''), N'Dimension Value');

    IF @EmpresaNAV IS NULL
        THROW 50000, 'Esa empresa no está cargada en "Configuración Sincronización NAV" en BC, o está destildada como inactiva.', 1;

    DECLARE @AppId      nvarchar(50),
            @TblCtrl    nvarchar(300),
            @TblProy    nvarchar(300),
            @TblEmp     nvarchar(300),
            @TblCab     nvarchar(300),
            @TblLin     nvarchar(300),
            @TblDim     nvarchar(300),
            @TblGLS     nvarchar(300),
            @DimBuque   nvarchar(20),
            @DimMarea   nvarchar(20),
            @DimActiv   nvarchar(20),
            @ListaDims  nvarchar(200),
            @qq         nvarchar(2),
            @sql        nvarchar(max),
            @Techo      bigint,
            @Marca      bigint,
            @Filas      int,
            @Habilitada bit;

    ------------------------------------------------------------------------------------------
    -- 5.1 Dónde están las tablas de la extensión en esta base.
    ------------------------------------------------------------------------------------------
    SELECT TOP 1 @AppId = RIGHT(name, 36)
    FROM   sys.tables
    WHERE  name LIKE @EmpresaBC + N'$Ctrl Sinc NAV$%';

    IF @AppId IS NULL
        THROW 50001, 'No se encontró la tabla de control para esa empresa. ¿Está publicada la extensión de liquidación y se abrió una vez la página "Sincronización con NAV" en esa empresa?', 1;

    SET @TblCtrl = QUOTENAME(@EmpresaBC + N'$Ctrl Sinc NAV$'        + @AppId);
    SET @TblProy = QUOTENAME(@EmpresaBC + N'$Stg Proyecto NAV$'     + @AppId);
    SET @TblEmp  = QUOTENAME(@EmpresaBC + N'$Stg Empleado NAV$'     + @AppId);
    SET @TblCab  = QUOTENAME(@EmpresaBC + N'$Stg Descarga Cab NAV$' + @AppId);
    SET @TblLin  = QUOTENAME(@EmpresaBC + N'$Stg Descarga Lin NAV$' + @AppId);
    SET @TblDim  = QUOTENAME(@EmpresaBC + N'$Stg Valor Dim NAV$'    + @AppId);

    -- QUÉ DIMENSIONES SE TRAEN, y de dónde sale la respuesta.
    --
    -- Sólo las tres que la sincronización aplica sobre el proyecto: buque (global 1), marea
    -- (global 2) y actividad (atajo 3). El catálogo de NAV tiene más —CARPETA IMPORTACION, entre
    -- otras— y traerlo entero sería importar a BC dimensiones que nadie pidió.
    --
    -- Los códigos NO van escritos acá: salen de la configuración contable de la propia empresa de
    -- BC, que es donde está la verdad. Escribirlos a mano ataría el script a que la dimensión se
    -- llame DEPARTAMENTO y MAREA/CIUDAD en todas las instalaciones, que es justo la clase de
    -- supuesto que después falla en la empresa número dos.
    SELECT TOP 1 @TblGLS = QUOTENAME(name)
    FROM   sys.tables
    WHERE  name LIKE @EmpresaBC + N'$General Ledger Setup$%';

    IF @TblGLS IS NULL
        THROW 50005, 'No se encontró la tabla de configuración contable de esa empresa. Verificar el nombre de la empresa en "Configuración Sincronización NAV".', 1;

    SET @sql = N'SELECT TOP 1 @d1 = [Global Dimension 1 Code], @d2 = [Global Dimension 2 Code],
                              @d3 = [Shortcut Dimension 3 Code] FROM ' + @TblGLS + N';';
    EXEC sp_executesql @sql,
         N'@d1 nvarchar(20) OUTPUT, @d2 nvarchar(20) OUTPUT, @d3 nvarchar(20) OUTPUT',
         @d1 = @DimBuque OUTPUT, @d2 = @DimMarea OUTPUT, @d3 = @DimActiv OUTPUT;

    -- Las comillas del IN se arman con NCHAR(39) y no escribiéndolas. Adentro del OPENQUERY una
    -- comilla literal necesita CUATRO en este archivo, y una lista construida por concatenación
    -- con ese nivel de escape es imposible de leer y de corregir. Dos caracteres en una variable
    -- dicen lo mismo sin ambigüedad.
    SET @qq = REPLICATE(NCHAR(39), 2);
    SET @ListaDims = @qq + ISNULL(@DimBuque, N'') + @qq + N',' +
                     @qq + ISNULL(@DimMarea, N'') + @qq + N',' +
                     @qq + ISNULL(@DimActiv, N'') + @qq;

    -- Las tablas de BC no admiten NULL en ninguna columna y llevan columnas de sistema que hay que
    -- completar a mano. Si esta comprobación falla, la versión de BC cambió la convención y el
    -- procedimiento hay que revisarlo entero, no parchearlo.
    IF COL_LENGTH(@TblProy, '$systemId') IS NULL
        THROW 50002, 'Las tablas de staging no tienen la columna $systemId. Revisar la convención de columnas de sistema de esta versión de BC antes de seguir.', 1;

    ------------------------------------------------------------------------------------------
    -- 5.2 El techo de lectura: hasta antes de la transacción abierta más vieja del origen.
    --     Es lo que evita perder filas de transacciones en vuelo. Se pide una sola vez por corrida
    --     y vale para las cinco entidades.
    ------------------------------------------------------------------------------------------
    --     LEER ESTE NÚMERO TIENE TRES FORMAS Y DOS SON TRAMPA:
    --
    --       · INSERT INTO #t EXEC ('...') AT [srv] — el resultado vuelve dentro de la transacción y
    --         SQL Server lo promueve a TRANSACCIÓN DISTRIBUIDA. Pide MSDTC habilitado y con acceso
    --         de red en los dos servidores; si no, "The partner transaction manager has disabled its
    --         support for remote/network transactions". Mucha infraestructura para leer un entero.
    --
    --       · OPENQUERY(srv, 'SELECT min_active_rowversion()') — no necesita MSDTC, pero
    --         min_active_rowversion() es POR BASE y OPENQUERY no admite un USE: corre en el catálogo
    --         por defecto del linked server. Si ese catálogo no es la base de NAV —o no está puesto,
    --         que es lo habitual— el número sale de otra base. No falla: da un número plausible y
    --         equivocado, y la marca de agua se pasa de largo perdiendo filas en silencio.
    --
    --       · La que se usa: llamar al sp_executesql DEL ORIGEN con nombre de cuatro partes. La base
    --         queda FIJADA EN EL NOMBRE, así que no depende de ninguna opción invisible del linked
    --         server; el valor vuelve por parámetro OUTPUT, que no es INSERT ... EXEC y por lo tanto
    --         no promueve a transacción distribuida. Sólo necesita 'rpc out' en true, que es una
    --         línea de sp_serveroption y no obliga a recrear nada.
    DECLARE @RpcSp nvarchar(400) =
        QUOTENAME(@Servidor) + N'.' + QUOTENAME(@BaseNAV) + N'.sys.sp_executesql';

    BEGIN TRY
        EXEC @RpcSp N'SELECT @t = CONVERT(bigint, min_active_rowversion()) - 1;',
                    N'@t bigint OUTPUT',
                    @t = @Techo OUTPUT;
    END TRY
    BEGIN CATCH
        DECLARE @MsgRpc nvarchar(2048) =
            N'No se pudo leer min_active_rowversion() en ' + @Servidor + N'.' + @BaseNAV + N': '
          + ERROR_MESSAGE()
          + N'  |  Si habla de RPC: EXEC master.dbo.sp_serveroption @server = N''' + @Servidor
          + N''', @optname = N''rpc out'', @optvalue = N''true'';  Si habla de permisos: el login remoto '
          + N'necesita VIEW DATABASE STATE sobre esa base, además de db_datareader.';
        THROW 50003, @MsgRpc, 1;
    END CATCH

    IF @Techo IS NULL
        THROW 50003, 'min_active_rowversion() volvió NULL desde el origen. Verificar que el login remoto tenga VIEW DATABASE STATE sobre la base de NAV.', 1;

    ------------------------------------------------------------------------------------------
    -- 5.3 EMPLEADOS (entidad 0)
    ------------------------------------------------------------------------------------------
    SET @sql = N'SELECT @h = [Habilitada], @m = TRY_CONVERT(bigint, [Marca Agua]) FROM ' + @TblCtrl + N' WHERE [Entidad] = 0;';
    EXEC sp_executesql @sql, N'@h bit OUTPUT, @m bigint OUTPUT', @h = @Habilitada OUTPUT, @m = @Marca OUTPUT;
    SET @Marca = ISNULL(@Marca, 0);

    IF @Habilitada = 1
    BEGIN
        -- COLLATE DATABASE_DEFAULT del lado de src, en las cinco entidades: lo que vuelve de
        -- OPENQUERY trae la collation de la base de NAV y dst tiene la de BC. Son distintas, y como
        -- el linked server se creó con la opción "collation compatible" en false —que es lo
        -- correcto— el servidor no las asume iguales y el JOIN del MERGE da "Cannot resolve the
        -- collation conflict".
        --
        -- ESTE COMENTARIO VA ACÁ Y NO ADENTRO DEL LITERAL. Adentro sería texto que viaja al servidor
        -- en cada corrida y, sobre todo, que CUENTA para el límite de 4000 caracteres de abajo. Un
        -- párrafo de comentarios metido en el MERGE fue justamente lo que lo empujó sobre el límite.
        --
        -- CAST a nvarchar(max) en el primer operando. Sin eso la concatenación de literales da
        -- nvarchar(4000) —el tipo lo fija la EXPRESIÓN, no la variable destino— y el MERGE, que pasa
        -- los 4000 caracteres, se guarda CORTADO. No hay error ni aviso: sp_executesql recibe SQL
        -- incompleto y se queja de sintaxis en el punto del corte, a mil líneas del problema real.
        SET @sql = CAST(N'' AS nvarchar(max)) + N'
        MERGE ' + @TblEmp + N' AS dst
        USING OPENQUERY(' + QUOTENAME(@Servidor) + N', ''
            SELECT  [No_]                       AS NoEmpleado,
                    RTRIM([First Family Name] + SPACE(1)
                          + [Second Family Name]) AS Apellido,
                    [Name]                      AS Nombre,
                    SPACE(0)                    AS SegundoNombre,
                    [Initials]                  AS Iniciales,
                    [Job Title]                 AS PuestoTitulo,
                    [Employment Date]           AS FechaIngreso,
                    [Social Security No_]       AS NoSegSocial,
                    [CIF_NIF]                   AS CifNif,
                    [Birth Date]                AS FechaNacimiento,
                    [Address]                   AS Direccion,
                    [Address 2]                 AS Direccion2,
                    [City]                      AS Ciudad,
                    [Post Code]                 AS CodPostal,
                    [Phone No_]                 AS Telefono,
                    [E-Mail]                    AS Email,
                    [pat_Cod_ convenio]         AS ConvenioOrigen,
                    [Categoría]                 AS CategoriaOrigen,
                    CONVERT(bigint, [timestamp]) AS rv
            FROM    ' + QUOTENAME(@BaseNAV) + N'.[dbo].' + QUOTENAME(@EmpresaNAV + N'$' + @TabEmp) + N'
            WHERE   CONVERT(bigint, [timestamp]) >  ' + CONVERT(nvarchar(20), @Marca) + N'
              AND   CONVERT(bigint, [timestamp]) <= ' + CONVERT(nvarchar(20), @Techo) + N'
        '') AS src
        ON dst.[No Empleado] = src.NoEmpleado COLLATE DATABASE_DEFAULT
        WHEN MATCHED THEN UPDATE SET
            dst.[Apellido] = src.Apellido, dst.[Nombre] = src.Nombre,
            dst.[Segundo Nombre] = src.SegundoNombre, dst.[Iniciales] = src.Iniciales,
            dst.[Puesto Titulo] = src.PuestoTitulo, dst.[Fecha Ingreso] = src.FechaIngreso,
            dst.[No Seguridad Social] = src.NoSegSocial, dst.[CIF NIF] = src.CifNif,
            dst.[Fecha Nacimiento] = src.FechaNacimiento, dst.[Direccion] = src.Direccion,
            dst.[Direccion 2] = src.Direccion2, dst.[Ciudad] = src.Ciudad,
            dst.[Cod Postal] = src.CodPostal, dst.[Telefono] = src.Telefono,
            dst.[Email] = src.Email, dst.[Convenio Origen] = src.ConvenioOrigen,
            dst.[Categoria Origen] = src.CategoriaOrigen,
            dst.[Estado Sinc] = 0, dst.[Observacion] = N'''', dst.[Intentos] = 0,
            dst.[Marca Origen] = CONVERT(nvarchar(20), src.rv),
            dst.[Traido El] = SYSUTCDATETIME(),
            dst.[$systemModifiedAt] = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            [No Empleado], [Apellido], [Nombre], [Segundo Nombre], [Iniciales], [Puesto Titulo],
            [Fecha Ingreso], [No Seguridad Social], [CIF NIF], [Fecha Nacimiento], [Direccion],
            [Direccion 2], [Ciudad], [Cod Postal], [Telefono], [Email], [Convenio Origen],
            [Categoria Origen], [Estado Sinc], [Observacion], [Intentos], [Marca Origen],
            [Traido El], [Procesado El],
            [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
        VALUES (
            src.NoEmpleado, src.Apellido, src.Nombre, src.SegundoNombre, src.Iniciales, src.PuestoTitulo,
            src.FechaIngreso, src.NoSegSocial, src.CifNif, src.FechaNacimiento, src.Direccion,
            src.Direccion2, src.Ciudad, src.CodPostal, src.Telefono, src.Email, src.ConvenioOrigen,
            src.CategoriaOrigen, 0, N'''', 0, CONVERT(nvarchar(20), src.rv),
            SYSUTCDATETIME(), ''1753-01-01'',
            NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'');';

        IF @Debug = 1 PRINT @sql;
        EXEC sp_executesql @sql;
        SET @Filas = @@ROWCOUNT;
        EXEC dbo.SincNAV_ActualizarControl @TblCtrl, 0, @Techo, @Filas;
    END

    ------------------------------------------------------------------------------------------
    -- 5.4 PROYECTOS (entidad 1)
    ------------------------------------------------------------------------------------------
    SET @sql = N'SELECT @h = [Habilitada], @m = TRY_CONVERT(bigint, [Marca Agua]) FROM ' + @TblCtrl + N' WHERE [Entidad] = 1;';
    EXEC sp_executesql @sql, N'@h bit OUTPUT, @m bigint OUTPUT', @h = @Habilitada OUTPUT, @m = @Marca OUTPUT;
    SET @Marca = ISNULL(@Marca, 0);

    IF @Habilitada = 1
    BEGIN
        -- LAS DIMENSIONES 2 Y 3 ESTÁN CRUZADAS ENTRE LOS DOS LADOS:
        --
        --     NAV  dim 2 = ACTIVIDAD (LAN = langostino, CAL = calamar)   dim 3 = MAREA
        --     BC   dim 2 = MAREA                                         dim 3 = ACTIVIDAD
        --
        -- O sea que el cruce es un intercambio, no un corrimiento. Las dos columnas Marea/Actividad
        -- de abajo son ese intercambio, y por eso van explícitas y no por posición.
        --
        -- Antes se copiaba posicionalmente, dim 2 a dim 2, y cada proyecto de BC quedaba con marea
        -- LAN o CAL. Sin error: "Aplicar Fila Sinc NAV" hace Job.Validate("Global Dimension 2 Code",
        -- Stg.Marea) y el código entra porque el valor de dimensión existe. Sólo estaba mal.
        --
        -- LA MAREA SALE DE LA DIMENSIÓN, NO DEL NÚMERO DE PROYECTO. Hubo una versión que la sacaba
        -- del [No_] con un LIKE de seis dígitos, y era un rodeo con errores propios:
        -- PP-TAE-2600001 tiene siete y quedaba sin marea. Eso quedó como RESPALDO, para el caso del
        -- proyecto viejo que tenga la dimensión 3 vacía pero el número bien formado: sin el
        -- respaldo, ese proyecto perdería la marea que hoy tiene, en silencio y sin una sola fila
        -- en error.
        --
        -- El vacío se compara con LEN() y no contra un literal: una cadena vacía adentro del
        -- OPENQUERY necesitaría OCHO comillas seguidas en este archivo (ver la nota de abajo sobre
        -- los dos niveles de escape), que nadie lee bien. LEN() no lleva ninguna.
        --
        -- El comentario va ACÁ y no adentro del literal: ahí dentro una comilla simple cierra la
        -- cadena del OPENQUERY, y además el texto viaja al servidor en cada corrida y cuenta para
        -- el límite de 4000 caracteres.
        --
        -- SOBRE LAS COMILLAS DE ADENTRO: hay DOS niveles de escape, no uno. El literal de @sql se
        -- arma doblando comillas, y la consulta del OPENQUERY es OTRO literal adentro de ése. Para
        -- que la consulta interna reciba un literal 'X' hacen falta CUATRO comillas en este archivo
        -- (''''X''''), que es lo que tiene el LIKE de abajo. Con dos se obtiene una comilla suelta
        -- que CIERRA la cadena del OPENQUERY: el error sale como "Unclosed quotation mark" y apunta
        -- a cien líneas más abajo.
        --
        -- Por eso la cadena vacía va como SPACE(0) y no como literal: necesitaría ocho comillas
        -- seguidas, que nadie lee bien. Lo mismo el espacio de SPACE(1) en el MERGE de empleados.
        --
        -- CAST a nvarchar(max) en el primer operando. Sin eso la concatenación de literales da
        -- nvarchar(4000) —el tipo lo fija la EXPRESIÓN, no la variable destino— y el MERGE, que pasa
        -- los 4000 caracteres, se guarda CORTADO. No hay error ni aviso: sp_executesql recibe SQL
        -- incompleto y se queja de sintaxis en el punto del corte, a mil líneas del problema real.
        SET @sql = CAST(N'' AS nvarchar(max)) + N'
        MERGE ' + @TblProy + N' AS dst
        USING OPENQUERY(' + QUOTENAME(@Servidor) + N', ''
            SELECT  [No_]                        AS NoProyecto,
                    [Description]                AS Descripcion,
                    [Description 2]              AS Descripcion2,
                    [Starting Date]              AS FechaInicio,
                    [Ending Date]                AS FechaFin,
                    [Global Dimension 1 Code]    AS Buque,
                    CASE WHEN LEN([Global Dimension 3 Code]) > 0
                         THEN [Global Dimension 3 Code]
                         WHEN [No_] LIKE ''''PP-%-[0-9][0-9][0-9][0-9][0-9][0-9]''''
                         THEN RIGHT([No_], 6)
                         ELSE SPACE(0) END      AS Marea,
                    [Global Dimension 2 Code]    AS Actividad,
                    [Status]                     AS Estado,
                    [Tipo]                       AS TipoProyecto,
                    [Patron]                     AS Patron,
                    [Hora de zarpada]            AS HoraZarpada,
                    [Hora ingreso a puerto]      AS HoraIngresoPuerto,
                    [Fecha llegada prevista]     AS FechaLlegadaPrevista,
                    [Puerto zarpada]             AS PuertoZarpada,
                    [Puerto Descarga]            AS PuertoDescarga,
                    [Año marea]                 AS AnioMarea,
                    CONVERT(bigint, [timestamp]) AS rv
            FROM    ' + QUOTENAME(@BaseNAV) + N'.[dbo].' + QUOTENAME(@EmpresaNAV + N'$' + @TabProy) + N'
            WHERE   CONVERT(bigint, [timestamp]) >  ' + CONVERT(nvarchar(20), @Marca) + N'
              AND   CONVERT(bigint, [timestamp]) <= ' + CONVERT(nvarchar(20), @Techo) + N'
        '') AS src
        ON dst.[No Proyecto] = src.NoProyecto COLLATE DATABASE_DEFAULT
        WHEN MATCHED THEN UPDATE SET
            dst.[Descripcion] = src.Descripcion, dst.[Descripcion 2] = src.Descripcion2,
            dst.[Fecha Inicio] = src.FechaInicio, dst.[Fecha Fin] = src.FechaFin,
            dst.[Buque] = src.Buque, dst.[Marea] = src.Marea, dst.[Estado] = src.Estado,
            dst.[Tipo Proyecto] = src.TipoProyecto, dst.[Patron] = src.Patron,
            dst.[Hora Zarpada] = src.HoraZarpada, dst.[Hora Ingreso Puerto] = src.HoraIngresoPuerto,
            dst.[Fecha Llegada Prevista] = src.FechaLlegadaPrevista,
            dst.[Puerto Zarpada] = src.PuertoZarpada, dst.[Puerto Descarga] = src.PuertoDescarga,
            dst.[Anio Marea] = src.AnioMarea, dst.[Actividad] = src.Actividad,
            dst.[Estado Sinc] = 0, dst.[Observacion] = N'''', dst.[Intentos] = 0,
            dst.[Marca Origen] = CONVERT(nvarchar(20), src.rv),
            dst.[Traido El] = SYSUTCDATETIME(),
            dst.[$systemModifiedAt] = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            [No Proyecto], [Descripcion], [Descripcion 2], [Fecha Inicio], [Fecha Fin], [Buque],
            [Marea], [Estado], [Tipo Proyecto], [Patron], [Hora Zarpada], [Hora Ingreso Puerto],
            [Fecha Llegada Prevista], [Puerto Zarpada], [Puerto Descarga], [Anio Marea], [Actividad],
            [Estado Sinc], [Observacion], [Intentos], [Marca Origen], [Traido El], [Procesado El],
            [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
        VALUES (
            src.NoProyecto, src.Descripcion, src.Descripcion2, src.FechaInicio, src.FechaFin, src.Buque,
            src.Marea, src.Estado, src.TipoProyecto, src.Patron, src.HoraZarpada, src.HoraIngresoPuerto,
            src.FechaLlegadaPrevista, src.PuertoZarpada, src.PuertoDescarga, src.AnioMarea, src.Actividad,
            0, N'''', 0, CONVERT(nvarchar(20), src.rv), SYSUTCDATETIME(), ''1753-01-01'',
            NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'');';

        IF @Debug = 1 PRINT @sql;
        EXEC sp_executesql @sql;
        SET @Filas = @@ROWCOUNT;
        EXEC dbo.SincNAV_ActualizarControl @TblCtrl, 1, @Techo, @Filas;
    END

    ------------------------------------------------------------------------------------------
    -- 5.5 DESCARGAS — CABECERAS (entidad 2)
    ------------------------------------------------------------------------------------------
    SET @sql = N'SELECT @h = [Habilitada], @m = TRY_CONVERT(bigint, [Marca Agua]) FROM ' + @TblCtrl + N' WHERE [Entidad] = 2;';
    EXEC sp_executesql @sql, N'@h bit OUTPUT, @m bigint OUTPUT', @h = @Habilitada OUTPUT, @m = @Marca OUTPUT;
    SET @Marca = ISNULL(@Marca, 0);

    IF @Habilitada = 1
    BEGIN
        -- CAST a nvarchar(max) en el primer operando. Sin eso la concatenación de literales da
        -- nvarchar(4000) —el tipo lo fija la EXPRESIÓN, no la variable destino— y el MERGE, que pasa
        -- los 4000 caracteres, se guarda CORTADO. No hay error ni aviso: sp_executesql recibe SQL
        -- incompleto y se queja de sintaxis en el punto del corte, a mil líneas del problema real.
        SET @sql = CAST(N'' AS nvarchar(max)) + N'
        MERGE ' + @TblCab + N' AS dst
        USING OPENQUERY(' + QUOTENAME(@Servidor) + N', ''
            SELECT  [N° proyecto]                 AS NoProyecto,
                    [Capitán]                      AS Capitan,
                    [Actividad]                    AS Actividad,
                    [Fecha de inicio de descarga]  AS FechaInicioDescarga,
                    [Buque]                        AS Buque,
                    [Marea]                        AS Marea,
                    [Location]                     AS CodCamara,
                    [Libro Diario]                 AS LibroDiario,
                    [Puerto]                       AS Puerto,
                    [Pallets desde]                AS PalletsDesde,
                    [Pallets hasta]                AS PalletsHasta,
                    [Hora inicio descarga]         AS HoraInicioDescarga,
                    [Hora fin descarga]            AS HoraFinDescarga,
                    [Scale code]                   AS CodBalanza,
                    [Registrado]                   AS Registrado,
                    [Origen del cartón]            AS OrigenCarton,
                    CONVERT(bigint, [timestamp])   AS rv
            FROM    ' + QUOTENAME(@BaseNAV) + N'.[dbo].' + QUOTENAME(@EmpresaNAV + N'$' + @TabCab) + N'
            WHERE   CONVERT(bigint, [timestamp]) >  ' + CONVERT(nvarchar(20), @Marca) + N'
              AND   CONVERT(bigint, [timestamp]) <= ' + CONVERT(nvarchar(20), @Techo) + N'
        '') AS src
        ON dst.[No Proyecto] = src.NoProyecto COLLATE DATABASE_DEFAULT
        WHEN MATCHED THEN UPDATE SET
            dst.[Capitan] = src.Capitan, dst.[Actividad] = src.Actividad,
            dst.[Fecha Inicio Descarga] = src.FechaInicioDescarga, dst.[Buque] = src.Buque,
            dst.[Marea] = src.Marea, dst.[Cod Camara] = src.CodCamara,
            dst.[Libro Diario] = src.LibroDiario, dst.[Puerto] = src.Puerto,
            dst.[Pallets Desde] = src.PalletsDesde, dst.[Pallets Hasta] = src.PalletsHasta,
            dst.[Hora Inicio Descarga] = src.HoraInicioDescarga,
            dst.[Hora Fin Descarga] = src.HoraFinDescarga, dst.[Cod Balanza] = src.CodBalanza,
            dst.[Registrado] = src.Registrado, dst.[Origen Carton] = src.OrigenCarton,
            dst.[Estado Sinc] = 0, dst.[Observacion] = N'''', dst.[Intentos] = 0,
            dst.[Marca Origen] = CONVERT(nvarchar(20), src.rv),
            dst.[Traido El] = SYSUTCDATETIME(),
            dst.[$systemModifiedAt] = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            [No Proyecto], [Capitan], [Actividad], [Fecha Inicio Descarga], [Buque], [Marea],
            [Cod Camara], [Libro Diario], [Puerto], [Pallets Desde], [Pallets Hasta],
            [Hora Inicio Descarga], [Hora Fin Descarga], [Cod Balanza], [Registrado], [Origen Carton],
            [Estado Sinc], [Observacion], [Intentos], [Marca Origen], [Traido El], [Procesado El],
            [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
        VALUES (
            src.NoProyecto, src.Capitan, src.Actividad, src.FechaInicioDescarga, src.Buque, src.Marea,
            src.CodCamara, src.LibroDiario, src.Puerto, src.PalletsDesde, src.PalletsHasta,
            src.HoraInicioDescarga, src.HoraFinDescarga, src.CodBalanza, src.Registrado, src.OrigenCarton,
            0, N'''', 0, CONVERT(nvarchar(20), src.rv), SYSUTCDATETIME(), ''1753-01-01'',
            NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'');';

        IF @Debug = 1 PRINT @sql;
        EXEC sp_executesql @sql;
        SET @Filas = @@ROWCOUNT;
        EXEC dbo.SincNAV_ActualizarControl @TblCtrl, 2, @Techo, @Filas;
    END

    ------------------------------------------------------------------------------------------
    -- 5.6 DESCARGAS — LÍNEAS (entidad 3)
    --     Es la tabla grande y la que le importa al motor: de acá salen los kilos de la marea.
    ------------------------------------------------------------------------------------------
    SET @sql = N'SELECT @h = [Habilitada], @m = TRY_CONVERT(bigint, [Marca Agua]) FROM ' + @TblCtrl + N' WHERE [Entidad] = 3;';
    EXEC sp_executesql @sql, N'@h bit OUTPUT, @m bigint OUTPUT', @h = @Habilitada OUTPUT, @m = @Marca OUTPUT;
    SET @Marca = ISNULL(@Marca, 0);

    IF @Habilitada = 1
    BEGIN
        -- CAST a nvarchar(max) en el primer operando. Sin eso la concatenación de literales da
        -- nvarchar(4000) —el tipo lo fija la EXPRESIÓN, no la variable destino— y el MERGE, que pasa
        -- los 4000 caracteres, se guarda CORTADO. No hay error ni aviso: sp_executesql recibe SQL
        -- incompleto y se queja de sintaxis en el punto del corte, a mil líneas del problema real.
        SET @sql = CAST(N'' AS nvarchar(max)) + N'
        MERGE ' + @TblLin + N' AS dst
        USING OPENQUERY(' + QUOTENAME(@Servidor) + N', ''
            SELECT  [No_ proyecto]                AS NoProyecto,
                    [Line no_]                    AS [LineNo],
                    [No_ remito]                  AS NoRemito,
                    [Item no_]                    AS ItemNo,
                    [Description]                 AS Descripcion,
                    [Unidad medida]               AS UnidadMedida,
                    [Cantidad]                    AS Cantidad,
                    [Net weight]                  AS PesoNeto,
                    [Gross weight]                AS PesoBruto,
                    [Fecha remito]                AS FechaRemito,
                    [Transport_s license]         AS LicenciaTransporte,
                    [Temperatura]                 AS Temperatura,
                    [Hora de ingreso]             AS HoraIngreso,
                    [Tipo de amparo sanitario]    AS TipoAmparo,
                    [No_ amparo sanitario]        AS NoAmparo,
                    [Destino]                     AS Destino,
                    [No_ Pallet]                  AS NoPallet,
                    [Location]                    AS CodCamara,
                    [Buque]                       AS Buque,
                    [Marea]                       AS Marea,
                    [Puerto]                      AS Puerto,
                    [Promedio]                    AS Promedio,
                    [Bin code]                    AS BinCode,
                    [Tare]                        AS Tara,
                    [Gross + Tare]                AS BrutoMasTara,
                    [Weighing Date and Time]      AS FechaHoraPesaje,
                    [Confirmed]                   AS Confirmado,
                    [Status]                      AS EstadoOrigen,
                    [Actividad]                   AS Actividad,
                    [Familia]                     AS Familia,
                    [Subfamilia]                  AS Subfamilia,
                    [Manual unit of measure]      AS UnidadMedidaManual,
                    [Manual weight]               AS PesoManual,
                    CONVERT(bigint, [timestamp])  AS rv
            FROM    ' + QUOTENAME(@BaseNAV) + N'.[dbo].' + QUOTENAME(@EmpresaNAV + N'$' + @TabLin) + N'
            WHERE   CONVERT(bigint, [timestamp]) >  ' + CONVERT(nvarchar(20), @Marca) + N'
              AND   CONVERT(bigint, [timestamp]) <= ' + CONVERT(nvarchar(20), @Techo) + N'
        '') AS src
        ON dst.[No Proyecto] = src.NoProyecto COLLATE DATABASE_DEFAULT AND dst.[Line No] = src.[LineNo]
        WHEN MATCHED THEN UPDATE SET
            dst.[No Remito] = src.NoRemito, dst.[Item No] = src.ItemNo,
            dst.[Descripcion] = src.Descripcion, dst.[Unidad Medida] = src.UnidadMedida,
            dst.[Cantidad] = src.Cantidad, dst.[Peso Neto] = src.PesoNeto,
            dst.[Peso Bruto] = src.PesoBruto, dst.[Fecha Remito] = src.FechaRemito,
            dst.[Licencia Transporte] = src.LicenciaTransporte, dst.[Temperatura] = src.Temperatura,
            dst.[Hora Ingreso] = src.HoraIngreso, dst.[Tipo Amparo Sanitario] = src.TipoAmparo,
            dst.[No Amparo Sanitario] = src.NoAmparo, dst.[Destino] = src.Destino,
            dst.[No Pallet] = src.NoPallet, dst.[Cod Camara] = src.CodCamara,
            dst.[Buque] = src.Buque, dst.[Marea] = src.Marea, dst.[Puerto] = src.Puerto,
            dst.[Promedio] = src.Promedio, dst.[Bin Code] = src.BinCode, dst.[Tara] = src.Tara,
            dst.[Bruto Mas Tara] = src.BrutoMasTara, dst.[Fecha Hora Pesaje] = src.FechaHoraPesaje,
            dst.[Confirmado] = src.Confirmado, dst.[Estado Origen] = src.EstadoOrigen,
            dst.[Actividad] = src.Actividad, dst.[Familia] = src.Familia,
            dst.[Subfamilia] = src.Subfamilia, dst.[Unidad Medida Manual] = src.UnidadMedidaManual,
            dst.[Peso Manual] = src.PesoManual,
            dst.[Estado Sinc] = 0, dst.[Observacion] = N'''', dst.[Intentos] = 0,
            dst.[Marca Origen] = CONVERT(nvarchar(20), src.rv),
            dst.[Traido El] = SYSUTCDATETIME(),
            dst.[$systemModifiedAt] = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            [No Proyecto], [Line No], [No Remito], [Item No], [Descripcion], [Unidad Medida],
            [Cantidad], [Peso Neto], [Peso Bruto], [Fecha Remito], [Licencia Transporte],
            [Temperatura], [Hora Ingreso], [Tipo Amparo Sanitario], [No Amparo Sanitario], [Destino],
            [No Pallet], [Cod Camara], [Buque], [Marea], [Puerto], [Promedio], [Bin Code], [Tara],
            [Bruto Mas Tara], [Fecha Hora Pesaje], [Confirmado], [Estado Origen], [Actividad],
            [Familia], [Subfamilia], [Unidad Medida Manual], [Peso Manual],
            [Estado Sinc], [Observacion], [Intentos], [Marca Origen], [Traido El], [Procesado El],
            [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
        VALUES (
            src.NoProyecto, src.[LineNo], src.NoRemito, src.ItemNo, src.Descripcion, src.UnidadMedida,
            src.Cantidad, src.PesoNeto, src.PesoBruto, src.FechaRemito, src.LicenciaTransporte,
            src.Temperatura, src.HoraIngreso, src.TipoAmparo, src.NoAmparo, src.Destino,
            src.NoPallet, src.CodCamara, src.Buque, src.Marea, src.Puerto, src.Promedio, src.BinCode, src.Tara,
            src.BrutoMasTara, src.FechaHoraPesaje, src.Confirmado, src.EstadoOrigen, src.Actividad,
            src.Familia, src.Subfamilia, src.UnidadMedidaManual, src.PesoManual,
            0, N'''', 0, CONVERT(nvarchar(20), src.rv), SYSUTCDATETIME(), ''1753-01-01'',
            NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'');';

        IF @Debug = 1 PRINT @sql;
        EXEC sp_executesql @sql;
        SET @Filas = @@ROWCOUNT;
        EXEC dbo.SincNAV_ActualizarControl @TblCtrl, 3, @Techo, @Filas;
    END

    ------------------------------------------------------------------------------------------
    -- 5.7 VALORES DE DIMENSIÓN (entidad 4)
    ------------------------------------------------------------------------------------------
    -- Va última en la TRAÍDA y primera en la APLICACIÓN, y no es contradictorio: acá sólo se
    -- copian filas a staging, donde el orden da igual; el orden que importa es el de
    -- "Sinc NAV Liq.".ProcesarTodo, que aplica los valores antes que los proyectos porque el
    -- Job.Validate del buque o de la marea falla si el valor no existe.
    --
    -- Es la razón de ser de esta entidad: una marea nueva es, por definición, un valor de
    -- dimensión que BC todavía no tiene. Sin esto, cada mes los proyectos de las mareas nuevas
    -- quedaban en Error y había que crear los valores a mano antes de reprocesarlos.
    SET @sql = N'SELECT @h = [Habilitada], @m = TRY_CONVERT(bigint, [Marca Agua]) FROM ' + @TblCtrl + N' WHERE [Entidad] = 4;';
    EXEC sp_executesql @sql, N'@h bit OUTPUT, @m bigint OUTPUT', @h = @Habilitada OUTPUT, @m = @Marca OUTPUT;
    SET @Marca = ISNULL(@Marca, 0);

    IF @Habilitada = 1
    BEGIN
        -- Dos filtros que no son opcionales. El IN deja pasar sólo las tres dimensiones que usa el
        -- proyecto. Y el tipo 0 (Estándar) deja afuera encabezados y totales: en BC sirven para
        -- armar informes, no para asignarse a un proyecto, y traerlos sería llenar el catálogo de
        -- filas que nadie puede elegir.
        --
        -- El origen además tiene basura que hay que dejar donde está: filas con [Dimension Code]
        -- vacío, y códigos de buque cargados dentro de MAREA/CIUDAD. El IN filtra las primeras; las
        -- segundas entran, y no hay cómo distinguirlas automáticamente de una marea legítima — si
        -- aparecen en BC, se bloquean a mano.
        --
        -- CAST a nvarchar(max) en el primer operando, igual que en los otros cuatro: sin eso la
        -- concatenación de literales da nvarchar(4000) y el MERGE se guarda cortado, sin aviso.
        SET @sql = CAST(N'' AS nvarchar(max)) + N'
        MERGE ' + @TblDim + N' AS dst
        USING OPENQUERY(' + QUOTENAME(@Servidor) + N', ''
            SELECT  [Dimension Code]             AS CodDimension,
                    [Code]                       AS Codigo,
                    [Name]                       AS Nombre,
                    [Blocked]                    AS Bloqueado,
                    CONVERT(bigint, [timestamp]) AS rv
            FROM    ' + QUOTENAME(@BaseNAV) + N'.[dbo].' + QUOTENAME(@EmpresaNAV + N'$' + @TabDim) + N'
            WHERE   [Dimension Code] IN (' + @ListaDims + N')
              AND   [Dimension Value Type] = 0
              AND   CONVERT(bigint, [timestamp]) >  ' + CONVERT(nvarchar(20), @Marca) + N'
              AND   CONVERT(bigint, [timestamp]) <= ' + CONVERT(nvarchar(20), @Techo) + N'
        '') AS src
        ON  dst.[Cod Dimension] = src.CodDimension COLLATE DATABASE_DEFAULT
        AND dst.[Codigo]        = src.Codigo       COLLATE DATABASE_DEFAULT
        WHEN MATCHED THEN UPDATE SET
            dst.[Nombre] = src.Nombre, dst.[Bloqueado] = src.Bloqueado,
            dst.[Estado Sinc] = 0, dst.[Observacion] = N'''', dst.[Intentos] = 0,
            dst.[Marca Origen] = CONVERT(nvarchar(20), src.rv),
            dst.[Traido El] = SYSUTCDATETIME(),
            dst.[$systemModifiedAt] = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            [Cod Dimension], [Codigo], [Nombre], [Bloqueado],
            [Estado Sinc], [Observacion], [Intentos], [Marca Origen], [Traido El], [Procesado El],
            [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
        VALUES (
            src.CodDimension, src.Codigo, src.Nombre, src.Bloqueado,
            0, N'''', 0, CONVERT(nvarchar(20), src.rv), SYSUTCDATETIME(), ''1753-01-01'',
            NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'');';

        IF @Debug = 1 PRINT @sql;
        EXEC sp_executesql @sql;
        SET @Filas = @@ROWCOUNT;
        EXEC dbo.SincNAV_ActualizarControl @TblCtrl, 4, @Techo, @Filas;
    END
END;

------------------------------------------------------------------------------------------------
-- 6. EL QUE LLAMA EL JOB — recorre todas las empresas activas.
--
--    Una empresa que falla no frena a las demás: se anota el error y se sigue. Al final, si hubo
--    alguna, relanza para que el job del Agent quede en rojo. Un job en verde con una empresa sin
--    sincronizar es peor que uno en rojo.
------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.SincNAV_TraerTodo
    @Debug bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- @Errores es nvarchar(2048) y no (max) porque THROW no acepta otra cosa como mensaje.
    DECLARE @Empresa nvarchar(100),
            @Errores nvarchar(2048) = N'',
            @Msg     nvarchar(2048),
            @TblCfg  nvarchar(300),
            @sql     nvarchar(max);

    SELECT TOP 1 @TblCfg = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

    IF @TblCfg IS NULL
        THROW 50004, 'No existe la tabla de configuración de la sincronización. Falta publicar la extensión de liquidación con los objetos de sincronización.', 1;

    -- A una temporal primero: un cursor no puede recorrer una tabla cuyo nombre sale de SQL dinámico.
    IF OBJECT_ID('tempdb..#empresas') IS NOT NULL DROP TABLE #empresas;
    CREATE TABLE #empresas (EmpresaBC nvarchar(100));

    SET @sql = N'SELECT [Empresa BC] FROM ' + @TblCfg + N' WHERE [Activo] = 1 ORDER BY [Empresa BC];';
    INSERT INTO #empresas EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM #empresas)
        THROW 50005, 'No hay ninguna empresa activa en "Configuración Sincronización NAV". Cargala en BC antes de programar el job.', 1;

    DECLARE emp CURSOR LOCAL FAST_FORWARD FOR
        SELECT EmpresaBC FROM #empresas;

    OPEN emp;
    FETCH NEXT FROM emp INTO @Empresa;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC dbo.SincNAV_Traer @EmpresaBC = @Empresa, @Debug = @Debug;
        END TRY
        BEGIN CATCH
            SET @Msg = @Empresa + N': ' + ERROR_MESSAGE();
            RAISERROR('%s', 10, 1, @Msg) WITH NOWAIT;   -- severidad 10: informa y no corta el bucle
            SET @Errores = @Errores + CASE WHEN @Errores = N'' THEN N'' ELSE N' | ' END + @Msg;
        END CATCH

        FETCH NEXT FROM emp INTO @Empresa;
    END
    CLOSE emp; DEALLOCATE emp;
    DROP TABLE #empresas;

    IF @Errores <> N''
        THROW 50010, @Errores, 1;
END;

------------------------------------------------------------------------------------------------
-- 7. Primera corrida, a mano y mirando.
--
--    Con @Debug = 1 imprime los MERGE que arma, que es lo que hay que leer si algo no cuadra.
--    Después de esto, abrir "Sincronización con NAV" en BC: tiene que haber filas traídas y, al
--    apretar "Procesar pendientes", empezar a bajar el contador de pendientes.
------------------------------------------------------------------------------------------------

-- EXEC dbo.SincNAV_TraerTodo @Debug = 1;

------------------------------------------------------------------------------------------------
-- 8. El job del Agent, cada 15 minutos.
--
--    Va desfasado dos minutos de la entrada de proyecto de BC para que el orden natural sea traer y
--    después aplicar, y no al revés. No es crítico —lo que no se aplica ahora se aplica en la
--    corrida siguiente— pero evita que todo llegue quince minutos tarde por dos minutos.
--
--    La base la toma de DB_NAME() y el resto sale de la configuración, así que el comando del paso
--    no lleva ningún nombre escrito a mano: mover el origen de servidor no obliga a tocar el job.
------------------------------------------------------------------------------------------------

/*  Descomentar y ejecutar una sola vez.

DECLARE @job nvarchar(128) = N'BC - Sincronizar NAV 2013R2',
        @db  sysname       = DB_NAME();   -- la base donde estás parado ahora: la de BC

EXEC msdb.dbo.sp_add_job
     @job_name    = @job,
     @enabled     = 1,
     @description = N'Trae de NAV 2013R2 proyectos, empleados y descargas al staging de la extensión de liquidación. Aplicarlos es tarea del Job Queue de BC. Se configura desde BC, en "Configuración Sincronización NAV".';

EXEC msdb.dbo.sp_add_jobstep
     @job_name       = @job,
     @step_name      = N'Traer',
     @subsystem      = N'TSQL',
     @database_name  = @db,
     @command        = N'EXEC dbo.SincNAV_TraerTodo;',
     @retry_attempts = 2,
     @retry_interval = 1;

EXEC msdb.dbo.sp_add_jobschedule
     @job_name             = @job,
     @name                 = N'Cada 15 minutos',
     @freq_type            = 4,      -- diaria
     @freq_interval        = 1,
     @freq_subday_type     = 4,      -- minutos
     @freq_subday_interval = 15,
     @active_start_time    = 000200; -- 00:02, desfasado de la entrada de proyecto de BC

EXEC msdb.dbo.sp_add_jobserver @job_name = @job;
*/

------------------------------------------------------------------------------------------------
-- 9. Verificación y diagnóstico.
------------------------------------------------------------------------------------------------

/*  Estado de las entidades de todas las empresas activas. Es la misma información que la página de
    BC, para cuando el problema es justamente que BC no abre.

DECLARE @e nvarchar(100), @a nvarchar(50), @q nvarchar(max), @c nvarchar(300);
SELECT TOP 1 @c = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'Config Sinc NAV$%';

IF OBJECT_ID('tempdb..#emp') IS NOT NULL DROP TABLE #emp;
CREATE TABLE #emp (EmpresaBC nvarchar(100));
SET @q = N'SELECT [Empresa BC] FROM ' + @c + N' WHERE [Activo] = 1;';
INSERT INTO #emp EXEC sp_executesql @q;

DECLARE d CURSOR LOCAL FAST_FORWARD FOR SELECT EmpresaBC FROM #emp;
OPEN d; FETCH NEXT FROM d INTO @e;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT TOP 1 @a = RIGHT(name, 36) FROM sys.tables WHERE name LIKE @e + N'$Ctrl Sinc NAV$%';

    SET @q = N'SELECT ' + QUOTENAME(@e, '''') + N' AS Empresa, [Entidad], [Habilitada], [Marca Agua],
                      [Traido El], [Filas Traidas], [Procesado El], [Filas Procesadas],
                      [Ultima Observacion]
               FROM ' + QUOTENAME(@e + N'$Ctrl Sinc NAV$' + @a) + N' ORDER BY [Entidad];';
    EXEC sp_executesql @q;

    SET @q = N'SELECT ' + QUOTENAME(@e, '''') + N' AS Empresa, ''Líneas descarga'' AS Entidad,
                      [Estado Sinc], COUNT(*) AS Filas
               FROM ' + QUOTENAME(@e + N'$Stg Descarga Lin NAV$' + @a) + N'
               GROUP BY [Estado Sinc];';
    EXEC sp_executesql @q;

    FETCH NEXT FROM d INTO @e;
END
CLOSE d; DEALLOCATE d;
DROP TABLE #emp;
*/

/*  SI ALGO NO LLEGÓ A BC, EN ESTE ORDEN:

    1. ¿"Traido El" es reciente?  No → el problema es de este lado: revisar el historial del job del
       Agent (msdb.dbo.sysjobhistory) y la conectividad del linked server.
    2. ¿Hay filas pendientes hace rato?  Sí → el Job Queue de BC no está corriendo. Mirar la entrada
       de proyecto de la codeunit "Sinc NAV Liq.".
    3. ¿Hay filas en error?  Sí → el dato llegó y no se pudo aplicar. El motivo está en cada fila,
       en la página de la entidad, y se corrige en BC. Después, "Reintentar las que fallaron".
    4. ¿No hay filas y en NAV sí?  La marca de agua se pasó de largo, o la fila que buscás cambió
       antes de que existiera la sincronización. Vaciar "Marca Agua" desde BC y esperar una corrida:
       vuelve a ofrecer todo el origen sin borrar nada.
*/
