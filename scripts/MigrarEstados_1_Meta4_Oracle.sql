/*
    PASO 1 de 2 — se ejecuta en la conexión **Meta4** (Oracle, m4-vm.arbumasa.net.ar:1521).

    Migra el historial operativo de estados (M4T_HIST_ESTADOS_EMPL) a "Estado Empleado" de BC.

    OJO CON EL ALCANCE: esta tabla NO trae altas ni bajas. Los motivos BAJ-* viven en
    M4T_FASES_ALTA.ID_MOTIVO_BAJA y los migra MigrarFasesAlta_*. Acá vienen los estados
    operativos (NV, PS, GP, PL, PI, DQ), los de tierra (FR, OR, OI) y las ausencias (AU*).
    Las dos migraciones escriben en la misma tabla de BC y no se pisan.

    Como Meta4 es Oracle y BC es SQL Server, la migración va en tres tiempos:

        1. Este SELECT, acá, contra Oracle.                       <- estás acá
        2. Llevar el resultado a la tabla puente dbo.MIG_EstadosM4 en SQL Server.
        3. MigrarEstados_2_BC_SqlServer.sql, contra la base de BC.

    CÓMO LLEVAR EL RESULTADO (paso 2), con DBeaver:
      · Ejecutar este SELECT y esperar a que traiga todo.
      · Botón derecho sobre la grilla -> Exportar resultado... -> Base de datos.
      · Destino: la conexión de BC, esquema dbo, tabla  MIG_EstadosM4.
        El DDL está al final del script del paso 3.
      · Que el mapeo de columnas quede por NOMBRE. Los nombres de acá abajo son exactamente
        los que espera el paso 3.

    EL RANGO DE FECHAS — HOY ES EL HISTÓRICO COMPLETO
      Arrancó acotado a enero-junio 2026 (2910 filas) y desde el 13/9/2026 trae TODO: 244.010
      filas desde 1999. Las dos líneas del rango quedan abajo comentadas: para volver a acotar,
      descomentarlas.

      QUÉ CAMBIA AL TRAER TODO, y por qué el pre-vuelo del paso 3 pasa a ser obligatorio en serio:

        · PROYECTOS. Cada estado que devenga francos necesita su PP-<buque>-<marea> existente
          como Job. La sincronización con NAV trajo 4477 proyectos, que son los recientes. Las
          mareas de 1999 no van a estar. El bloque 3.c los lista: ESE número decide si esto se
          puede hacer entero o hay que recortar por fecha.
        · CÓDIGOS DE ESTADO. Aparecen nueve que el rango 2026 no mostraba: ACC, DQ, LE, AU2, AU4,
          AU8, AU10, AU12, AU18. LOS VEINTE YA EXISTEN en el catálogo de BC — verificado el
          13/9/2026 con el bloque 3.f del paso 3, que dio cero en "código inexistente". No hay
          nada que dar de alta; lo que sí hay que revisar es cómo están CONFIGURADOS, porque
          "Devenga Francos" decide a qué proyecto va el estado y "Tipo Estado" decide si cuenta
          como vacaciones. AU9 es Vacaciones y tiene que estar marcado como tal.
        · BUQUES. La traducción contempla HF*, A* y PM. Sobre 27 años puede haber otros; el
          bloque 3.b los caza.
        · COBERTURA POR FASE. Un estado anterior a la primera alta del empleado no entra
          (bloque 3.h). Con historia larga esto deja de ser un caso de borde.

      Migrar de más no es inocuo: cada fila es un estado que el motor lee al liquidar, y el
      historial de estados alimenta francos FIFO y vacaciones tomadas.
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: Meta4  (Oracle)                                                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
-- Correr esta línea PRIMERO. Es el guardián: DUAL solo existe en Oracle, así que si el editor
-- está apuntando a la conexión equivocada corta acá en vez de fallar más abajo con un mensaje
-- sobre TRUNC, que manda a buscar el problema al lugar equivocado.
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;

SELECT
    TRIM(h.ID_EMPLEADO)                                  AS LEGAJO,
    TRUNC(h.FEC_ALTA_EMPLEADO)                           AS FEC_ALTA,
    TRUNC(h.FEC_INICIO)                                  AS FEC_INICIO,
    TRUNC(h.FEC_FIN)                                     AS FEC_FIN,
    TRIM(h.ID_ESTADO_EMPL)                               AS COD_ESTADO,
    TRIM(h.ID_BUQUE)                                     AS BUQUE_M4,
    h.ID_MAREA                                           AS MAREA,
    -- Observaciones en BC es Text[250] y en Meta4 la columna es VARCHAR2(900). Se corta acá y no
    -- del otro lado: si hubiera un comentario largo, mejor verlo cortado en la grilla antes de
    -- exportar que descubrir el truncamiento como error de inserción en BC.
    SUBSTR(TRIM(h.COMENT), 1, 250)                       AS COMENT
FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
-- ID_SOCIEDAD VA CON EL CERO: '01', no '1'. Confirmado el 13/9/2026 — con '1' la consulta no falla,
-- devuelve CERO filas, y el síntoma es idéntico al de un rango de fechas equivocado o al de no tener
-- permisos sobre la tabla. Es el tipo de error que se busca en el lugar equivocado durante una hora.
WHERE h.ID_SOCIEDAD = '01'
  -- HISTÓRICO COMPLETO. Para volver a acotar, descomentar estas dos líneas:
  -- AND h.FEC_INICIO >= TIMESTAMP '2026-01-01 00:00:00.000000'
  -- AND h.FEC_INICIO <  TIMESTAMP '2026-07-01 00:00:00.000000'
ORDER BY h.ID_EMPLEADO, h.FEC_INICIO;

/*
    ANTES DE EXPORTAR, mirar estos números. Son los que tienen que cerrar del otro lado.

    SELECT COUNT(*)                        AS FILAS,
           COUNT(DISTINCT h.ID_EMPLEADO)   AS LEGAJOS,
           COUNT(h.FEC_FIN)                AS CON_FIN,
           COUNT(*) - COUNT(h.FEC_FIN)     AS ABIERTOS,
           MIN(h.FEC_INICIO)               AS DESDE,
           MAX(h.FEC_INICIO)               AS HASTA
    FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
    WHERE h.ID_SOCIEDAD = '01';

    Con el histórico completo dan del orden de 244.010 filas desde 1999-08-28.
    (Con el rango enero-junio 2026 daban: 2910 filas, 334 legajos, 2764 con fin, 146 abiertos.)

    Los estados que aparecen, que son los que tienen que existir en "Cód. Estado Empleado":

    SELECT TRIM(h.ID_ESTADO_EMPL) AS ESTADO, COUNT(*) AS FILAS
    FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
    WHERE h.ID_SOCIEDAD = '01'
    GROUP BY TRIM(h.ID_ESTADO_EMPL) ORDER BY 2 DESC;

    Sobre el histórico completo dieron veinte, contra los once del rango 2026:
        NV 68305, PS 56661, PL 41923, FR 28062, GP 14241, OR 13517, AU9 7819, OI 5982,
        AU1 2353, PI 2296, ACC 1412, DQ 1154, AU5 234, AU10 22, AU4 9, AU18 7, AU2 6,
        LE 3, AU8 3, AU12 1.

    LOS AU* SON AUSENTISMOS, y su significado sale de ARBPRO.M4T_TIPOS_AUSENTISMO: el código es
    'AU' + ID_TIPO_AUSENTISMO. Importa porque no todos se liquidan igual:
        AU1  Enfermedad                      AU9  VACACIONES
        AU2  Suspensión                      AU10 Licencia por casamiento
        AU4  Licencia Convenio               AU12 Licencia por defunción
        AU5  Licencias sin goce de sueldo    AU18 Licencia por estudio
        AU8  Huelga
    AU9 tiene que quedar con "Tipo Estado" = Vacaciones en el catálogo de BC: es lo que hace que
    DIAS_VAC_PERIODO cuente. AU5, AU2 y AU8 no se pagan.

    Y los buques, que son los que hay que traducir en el paso 3:

    SELECT TRIM(h.ID_BUQUE) AS BUQUE, COUNT(*) AS FILAS
    FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
    WHERE h.ID_SOCIEDAD = '01'
    GROUP BY TRIM(h.ID_BUQUE) ORDER BY 2 DESC;

    Con el rango 2026 daban diez: A28 396, HF802 388, HF801 355, A19 337, A18 325, A15 324,
    A14 304, A17 243, A16 232, PM 6. Sobre 27 años hay que esperar más — cualquiera que no
    empiece con HF o A, y no sea PM, no tiene traducción y lo caza el bloque 3.b.

    LA CONSULTA QUE DECIDE SI ESTO SE PUEDE HACER ENTERO — cuántos proyectos distintos hacen
    falta. Cada uno tiene que existir como Job en BC, y la sincronización con NAV trajo 4477:

    SELECT COUNT(DISTINCT TRIM(h.ID_BUQUE) || '-' || TO_CHAR(h.ID_MAREA)) AS COMBINACIONES,
           MIN(EXTRACT(YEAR FROM h.FEC_INICIO)) AS DESDE_ANIO
    FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
    WHERE h.ID_SOCIEDAD = '01';

    Si el número es mucho mayor que 4477, el bloque 3.c del paso 3 va a listar los que faltan y
    hay que decidir entre crearlos o recortar el rango. NO hay que saltear ese bloque: el INSERT
    tiene un JOIN contra Job, así que las filas sin proyecto NO fallan — desaparecen en silencio.

    ── LO QUE HACE EL PASO 3 CON ESTO ─────────────────────────────────────────────────────────

    BUQUE_M4 -> código de buque de BC:
        'HF' + n   ->  n           (HF801 -> 801, HF802 -> 802)
        'A' + n    ->  '1' + n     (A14 -> 114, A19 -> 119, A28 -> 128)
        'PM'       ->  PPM (Puerto Madryn)

    COD_ESTADO -> "Cód. Estado" tal cual, sin traducir: el catálogo de BC se renombró a los
    códigos de Meta4.

    El PROYECTO no viene en esta tabla, se deduce del estado. ID_MAREA nunca es cero —ni
    siquiera en las filas de tierra—, así que no sirve para distinguir. El criterio es el mismo
    que ya usa ResolverProyectoInactividad en Cod50017: "Devenga Francos".

        Devenga Francos = Sí  (DQ GP NV PI PL PS)  ->  PP-<buque>-<marea a 6 dígitos>  (PP-114-000311)
        Devenga Francos = No  (FR OR OI AU*)       ->  PN-<buque>-NOMINA               (PN-114-NOMINA)

    ESTE CRITERIO ESTÁ MAL Y HAY QUE CAMBIARLO ANTES DE VOLVER A CORRER ESTO.
    "Devenga Francos" contesta "¿se trabaja?", no "¿está en una marea?". Son la misma respuesta para
    NV (navegación), PS (puerto salida) y PL (puerto llegada), y distinta para:

        GP  guardia en puerto  \  se trabaja y devenga francos, pero en TIERRA.
        DQ  dique               >  El ID_MAREA de Meta4 se congela cuando el barco llega, así que
        PI  pilotaje           /   estos días arrastran la marea anterior.

    Dejó 12.324 guardias colgadas del proyecto de la marea previa, una 3.904 días después del arribo,
    más 2.120 pilotajes y 1.038 diques. Lo que lo delató: PL nunca se pasa de 3 días del arribo
    —1.587 de 1.587— y GP llega a diez años.

    El criterio correcto es el campo "Transcurre en Marea" de "Cód. Estado Empleado" (Sí sólo para
    NV, PS y PL). Lo ya migrado se corrige con MoverEstadosDeTierraANomina.sql.

    Con el rango enero-junio eso reparte 2365 filas a marea y 545 a nómina.
*/
