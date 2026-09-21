/*
    PASO 1 de 2 — se ejecuta en la conexión **Meta4** (Oracle, m4-vm.arbumasa.net.ar:1521).

    Meta4 y BC viven en motores distintos: Oracle uno, SQL Server el otro. No hay forma de que una
    consulta lea las dos, así que la migración va en tres tiempos:

        1. Este SELECT, acá, contra Oracle.                       ← estás acá
        2. Llevar el resultado a una tabla puente en SQL Server.
        3. MigrarFasesAlta_2_BC_SqlServer.sql, contra la base de BC.

    CÓMO LLEVAR EL RESULTADO (paso 2), con DBeaver:
      · Ejecutar este SELECT y esperar a que traiga todo.
      · Botón derecho sobre la grilla → Exportar resultado… → Base de datos.
      · Destino: la conexión Migr2013R2, esquema dbo, tabla  MIG_FasesM4.
        Si no existe, DBeaver ofrece crearla; si preferís crearla a mano, el DDL está al final
        del script del paso 3.
      · Que el mapeo de columnas quede por NOMBRE. Los nombres de acá abajo son exactamente los
        que espera el paso 3.

    Alternativa sin DBeaver: exportar a CSV e importarlo con BULK INSERT. Lo que importa es que la
    tabla puente termine con estas seis columnas y estos nombres.

    LO QUE HAY QUE COMPLETAR
      · ID_SOCIEDAD, abajo. El filtro va acá y no en el paso 3, así se transporta solo lo que se
        va a migrar. Si la columna fuera numérica en Meta4, sacarle las comillas: comparar un
        NUMBER contra texto da ORA-01722 y el mensaje no dice cuál es la columna.
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: Meta4  (Oracle)                                                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
-- Correr esta línea PRIMERO. Es el guardián: DUAL solo existe en Oracle, así que si el editor está
-- apuntando a la conexión equivocada corta acá con "Invalid object name 'DUAL'" en vez de fallar
-- más abajo con un mensaje sobre TRUNC, que manda a buscar el problema al lugar equivocado.
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;

SELECT
    TRIM(f.ID_EMPLEADO)                                  AS LEGAJO,
    TRUNC(f.FEC_ALTA_EMPLEADO)                           AS FEC_ALTA,
    TRUNC(f.FEC_BAJA)                                    AS FEC_BAJA,
    TRIM(f.ID_MOTIVO_BAJA)                               AS MOTIVO_BAJA,
    SUBSTR(TRIM(f.COMENT), 1, 250)                       AS COMENT,
    SUBSTR(TRIM(f.COMENT_BAJA), 1, 250)                  AS COMENT_BAJA
FROM ARBPRO.M4T_FASES_ALTA f
WHERE f.ID_SOCIEDAD = 'COMPLETAR'
ORDER BY 1, 2;

/*
    ANTES DE EXPORTAR, mirar estos tres números. Son los que después tienen que cerrar del otro lado.

    SELECT COUNT(*) AS FILAS,
           COUNT(f.FEC_ALTA_EMPLEADO) AS CON_ALTA,
           COUNT(f.FEC_BAJA) AS CON_BAJA,
           COUNT(DISTINCT f.ID_EMPLEADO) AS LEGAJOS
    FROM ARBPRO.M4T_FASES_ALTA f
    WHERE f.ID_SOCIEDAD = 'COMPLETAR';

    Y los motivos de baja que existen, que son los que hay que mapear en el paso 3:

    SELECT TRIM(f.ID_MOTIVO_BAJA) AS MOTIVO, COUNT(*) AS FILAS
    FROM ARBPRO.M4T_FASES_ALTA f
    WHERE f.ID_SOCIEDAD = 'COMPLETAR' AND f.FEC_BAJA IS NOT NULL
    GROUP BY TRIM(f.ID_MOTIVO_BAJA)
    ORDER BY 2 DESC;

    Esa lista es la que va a la tabla #MapaMotivo del paso 3. Lo que no se mapee entra como DESSIN
    con el motivo original escrito en Observaciones, así que no se pierde — pero conviene mapear los
    que tengan volumen antes de insertar, no después.
*/
