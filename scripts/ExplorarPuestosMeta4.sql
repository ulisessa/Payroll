/*
    EXPLORACIÓN — M4T_HIST_PUESTOS (Oracle / Meta4).

    PARA CORRER EN DBEAVER, contra la conexión "Meta4" (m4-vm.arbumasa.net.ar:1521,
    SID Meta4). No se puede correr desde BC: Meta4 es Oracle y no hay linked server ni
    provider de Oracle en mimir ni en BRAGI.

    PARA QUÉ. El puesto es el eje que valoriza la PRODUCCIÓN, distinto de la categoría
    del CCT que valoriza el sueldo. En la marea A28/59 los dos difieren en cinco
    tripulantes: 03957 cobró navegación como Contramaestre Argentino (MR01, índice 85)
    y producción a índice 100, porque su puesto es CB04 desde el 07/01/2024, que en el
    catálogo de Meta4 es PRIMER PESCADOR — MR00, índice 100. Hoy ese dato no está en BC
    y hay que deducirlo de un PDF por marea.

    OJO CON LA COLUMNA COMENT del historial: es texto libre. En la fila de 03957 dice
    "CONTROL DE CALIDAD P..." y me hizo leer mal el puesto. La descripción del puesto
    está en el catálogo (consulta 1), no ahí.

    A DÓNDE VA. A un tipo de atributo PUESTO sobre la entidad Empleado, en
    "Atributo Entidad Liq." (Tab110005), que ya es efectivo-fechado. Con eso los 13
    conceptos de producción dejan de leer Personal Proyecto y nadie reconfirma el
    puesto en cada asignación.

    EXPORTAR CADA RESULTADO A CSV (botón derecho > Export resultset > CSV) y dejarlo
    en la carpeta del proyecto.
*/

-- 1. CATÁLOGO DE PUESTOS. Hace falta para mapear ID_PUESTO -> categoría del CCT, que es
--    lo que fija el índice. Del historial sólo conocemos códigos sueltos (CB04, CB06,
--    CB07, PT02) y una descripción suelta en COMENT.
--    Si la tabla no se llama así, buscarla con la consulta 1.b.
SELECT * FROM M4T_PUESTOS;

-- 1.b. SI LA ANTERIOR FALLA: encontrar cómo se llama realmente.
SELECT owner, table_name
FROM   all_tables
WHERE  table_name LIKE '%PUESTO%'
ORDER  BY owner, table_name;

-- 2. EL HISTORIAL COMPLETO, que es lo que se migra. Una fila por empleado y vigencia.
--    Se traen todos los empleados y todas las vigencias: la migración de convenios de
--    septiembre enseñó que hay que NORMALIZAR ANTES DE FILTRAR — el LEAD que cierra
--    cada vigencia necesita ver el historial entero, y filtrando primero salta por
--    encima de las filas descartadas y cierra la vigencia anterior años tarde.
SELECT h.ID_EMPLEADO,
       h.FEC_INICIO,
       h.FEC_FIN,
       h.ID_PUESTO,
       h.ID_MOTIVO_CAMBIO,
       h.COMENT,
       h.FEC_ALTA_EMPLEADO
FROM   M4T_HIST_PUESTOS h
ORDER  BY h.ID_EMPLEADO, h.FEC_INICIO;

-- 3. LA PRUEBA DEL MODELO: los 30 de la marea A28/59, con el puesto vigente durante la
--    marea (03/01/2026 al 29/01/2026).
--
--    Lo que tiene que pasar si el modelo es correcto: el puesto tiene que separar a
--    03957 y 04913 (producción índice 100) de 03961 (índice 85), aunque los tres
--    tengan la misma categoría de convenio MR01.
--
--    Y lo que realmente interesa: COLMAN (04169) figura en el rol de entrada como
--    CONTRA / PLANTA, el mismo puesto que MOLINA (03961), pero Meta4 le pagó índice 70
--    contra 85. Si su ID_PUESTO acá NO es el de contramaestre, el rol estaba mal
--    tipeado y no hay nada que reclamar. Si SÍ lo es, es una diferencia real.
SELECT h.ID_EMPLEADO,
       h.ID_PUESTO,
       h.COMENT,
       h.FEC_INICIO,
       h.FEC_FIN
FROM   M4T_HIST_PUESTOS h
WHERE  h.ID_EMPLEADO IN (
           '03664','03753','03772','03774','03957','03961','04066','04091','04105',
           '04169','04274','04301','04368','04455','04517','04648','04649','04669',
           '04683','04733','04734','04738','04766','04789','04798','04880','04913',
           '04914','04915','04918')
  AND  h.FEC_INICIO <= DATE '2026-01-29'
  AND  (h.FEC_FIN IS NULL OR h.FEC_FIN >= DATE '2026-01-03')
ORDER  BY h.ID_EMPLEADO, h.FEC_INICIO;
