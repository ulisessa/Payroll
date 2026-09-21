/*
    PASO 1 de 2 — se ejecuta en la conexión **Meta4** (Oracle, m4-vm.arbumasa.net.ar:1521).

    Trae el historial de CONVENIO y CATEGORÍA de cada empleado, que en BC viven como atributos de
    entidad con vigencia ("Atributo Entidad Liq.", Tab110005).

    POR QUÉ ESTO Y NO LA FICHA DEL EMPLEADO
      La ficha tiene "Cód. Convenio" y "Cód. Categoría", pero son sólo el respaldo: el par que el
      motor usa sale de los ATRIBUTOS. Ver ResolverParDeAtributos en Tab60011 y ParDeEntidad en
      Cod50080 — el orden es asignación → ficha → atributos, y el último pisa a los dos.
      Medido el 13/9/2026: 103 empleados con atributo de convenio y 95 con el de categoría, contra
      2.974 con estados. Ése es el motivo real por el que no liquida casi nadie.

    LAS DOS SALEN JUNTAS Y NO POR SEPARADO
      La categoría de BC no se identifica sola: la clave de "Categoría CCT" es (convenio, código), y
      OF01 es Capitán tanto en 175/75 como en 768/19. Por eso el atributo de categoría guarda el
      convenio en "Cód. Valor Padre", y el padre tiene que ser el convenio vigente EN ESA FECHA. Con
      los dos historiales en la misma tabla puente, el paso 2 cruza las vigencias y parte la
      categoría cuando el convenio cambia en el medio.

    CÓMO LLEVAR EL RESULTADO, con DBeaver:
      · Ejecutar y esperar a que traiga todo (unas 21.000 filas).
      · Botón derecho sobre la grilla -> Exportar resultado... -> Base de datos.
      · Destino: la conexión de BC, esquema dbo, tabla  MIG_AtributosM4  (el DDL está al final del
        paso 2). Mapeo de columnas POR NOMBRE.
      · TRUNCATE TABLE dbo.MIG_AtributosM4 antes, si es una recarga. La doble carga no falla: deja
        vigencias duplicadas que el paso 2 detecta como superposición.
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: Meta4  (Oracle)                                                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;

SELECT 'CONVENIO'                          AS TIPO,
       TRIM(h.ID_EMPLEADO)                 AS LEGAJO,
       TRUNC(h.FEC_INICIO)                 AS FEC_INICIO,
       TRUNC(h.FEC_FIN)                    AS FEC_FIN,
       TRIM(h.ID_CONVENIO)                 AS VALOR_M4,
       SUBSTR(TRIM(h.COMENT), 1, 250)      AS COMENT
FROM   ARBPRO.M4T_HIST_CONVENIOS h
WHERE  h.ID_SOCIEDAD = '01'
UNION ALL
SELECT 'CATEGORIA',
       TRIM(h.ID_EMPLEADO),
       TRUNC(h.FEC_INICIO),
       TRUNC(h.FEC_FIN),
       TRIM(h.ID_CATEGORIA),
       SUBSTR(TRIM(h.COMENT), 1, 250)
FROM   ARBPRO.M4T_HIST_CATEGORIAS h
WHERE  h.ID_SOCIEDAD = '01'
ORDER  BY 2, 1, 3;

/*
    LO QUE TIENE QUE DAR, medido el 13/9/2026:
        CONVENIO   11.269 filas,  6.490 empleados
        CATEGORIA   9.768 filas,  4.819 empleados

    SELECT 'CONVENIO' T, COUNT(*) FILAS, COUNT(DISTINCT ID_EMPLEADO) EMP
    FROM ARBPRO.M4T_HIST_CONVENIOS WHERE ID_SOCIEDAD='01'
    UNION ALL SELECT 'CATEGORIA', COUNT(*), COUNT(DISTINCT ID_EMPLEADO)
    FROM ARBPRO.M4T_HIST_CATEGORIAS WHERE ID_SOCIEDAD='01';

    ── EL ALCANCE DE ESTA MIGRACIÓN ───────────────────────────────────────────────────────────

    Se traen los DOS historiales COMPLETOS, pero el paso 2 sólo aplica los convenios que tienen
    catálogo del lado de BC. El límite lo pone el catálogo, no el dato: las categorías embarcadas
    ya existen en BC con el mismo código, y las de tierra en su mayoría no.

    ENTRAN (360 activos al 13/9/2026):
        MR  Marinería Embarcados   -> 729/15   MR01..MR05, MR08   codigos idénticos
        OF  Oficiales Embarcados   -> 175/75 SI TANGONERO, 768/19 SI POTERO — ver abajo
        FE  Fuera de Conv. Españoles -> ESP    FE01..FE03         codigos idénticos
        EC  Empleados de Comercio  -> 130/75   EC01               codigo idéntico
        JO  Jornalizado Alimentación -> JO     JO01..JO04         codigo idéntico
        FA  Fuera de Convenio Argentinos -> FA  las FA* que use el historial

    EL CONVENIO DE LOS OFICIALES NO SALE DE META4, SALE DEL BUQUE. BC tiene dos convenios de
    oficiales embarcados con las mismas cinco categorías OF01..OF05 —175/75 CAPECA para tangoneros
    y 768/19 AACPyPP para poteros— y Meta4 tiene uno solo, "OF". La distinción está en el barco:
    101 a 119 son tangoneros y el resto (126..129, 801, 802) poteros.

    Y la tripulación rota mucho: hay activos con ocho buques distintos en seis años. Así que un
    oficial que pasa de un tangonero a un potero CAMBIA de convenio ese día, y su categoría tiene
    que partirse en el mismo borde —OF03 colgado de 175/75 y OF03 colgado de 768/19 son dos filas
    distintas—. El bloque 2.b.2 del paso 2 arma la línea de tiempo de flota desde los ESTADOS y la
    interseca con las vigencias OF. Por eso este paso no necesita saber nada de buques: sólo trae
    el historial tal como está en Meta4.

    JO Y FA SE MAPEAN A SÍ MISMOS, y es una decisión, no una omisión.

    JO —jornalizados de planta— ya no existe en la empresa y no hay un CCT vigente al que llevarlo:
    372/04 es STIA mensualizados, otro régimen, y mezclarlos falsearía la historia.

    FA es "Fuera de Convenio Argentinos" y en BC el equivalente sería ADM, que tiene tres
    categorías —ADM1, ADM2, GERADM— contra 58 cargos FA*: Contador, Chofer, Electricista, Sereno,
    Jardinero. Meter 58 en 3 pierde el dato sin ganar nada, porque ADM tampoco es un CCT: es
    "Sin CCT - Personal Administrativo", exactamente lo mismo que FA.

    Los dos se crean en BC con el mismo código para que el historial se lea sin traducción. HAY QUE
    DARLOS DE ALTA ANTES de correr el bloque 4 del paso 2:
        · Convenio Colectivo  JO  y  FA
        · Categoría CCT       JO01..JO04 bajo JO, y las FA* que liste el bloque 3.a

    CUÁLES FA* EXACTAMENTE LO DICE EL BLOQUE 3.a, no esta lista. Se migra el historial COMPLETO, así
    que hacen falta todas las categorías que alguna vez se usaron —no las 18 vigentes hoy, sino las
    58— y lo mismo pasa con los embarcados: Meta4 tiene FE04 (Marinero Español) y FE05 (Control de
    Calidad) que BC no tiene, aunque nadie los use desde 2017. El 3.a devuelve la lista exacta con
    cuánta gente afecta cada una; se cargan de una vez en vez de descubrirlas de a una.

    NO ENTRA todavía (11 activos):
        CA  Mensualizados Alimentación — sí tiene CCT vigente en BC (372/04), sólo faltan cuatro
            categorías: CA11, CA13, CA14 y CA15. Es el único caso donde ampliar el catálogo
            existente es lo correcto, porque el convenio sí está vivo.

    MUERTOS, no hay nada que mapear:
        MA última alta 2006 · DE 1997 · CE 2001 · (EC tiene 1 activo y sí entra)

    ── DOS EMPLEADOS CON EL DATO INCONSISTENTE EN EL ORIGEN ───────────────────────────────────
    Uno tiene convenio MR (marinería) con categoría OF01 (Capitán) y otro convenio DE
    (Desconocido) con categoría MR05. El paso 2 los deja afuera por el bloque 3.a —el par
    (convenio, categoría) no existe en BC— y hay que corregirlos en Meta4 o a mano.

    SELECT v.ID_CONVENIO, c.ID_CATEGORIA, v.ID_EMPLEADO
    FROM   ARBPRO.M4T_HIST_CONVENIOS v
    JOIN   ARBPRO.M4T_HIST_CATEGORIAS c
           ON c.ID_EMPLEADO = v.ID_EMPLEADO AND c.ID_SOCIEDAD = v.ID_SOCIEDAD AND c.FEC_FIN IS NULL
    WHERE  v.ID_SOCIEDAD = '01' AND v.FEC_FIN IS NULL
      AND  SUBSTR(c.ID_CATEGORIA, 1, 2) <> v.ID_CONVENIO
      AND  v.ID_CONVENIO IN ('MR','OF','FE','EC','JO','FA');

    ── LO QUE QUEDA ABIERTO ───────────────────────────────────────────────────────────────────
    · Las categorías que liste el bloque 3.a del paso 2: ésa es la lista de trabajo del catálogo.
    · CA11, CA13, CA14 y CA15 en 372/04, para los 11 activos de CA.
    · El rango 101-119 que clasifica la flota está escrito como número mágico en el paso 2. Debería
      ser un atributo TIPO_BUQUE sobre la entidad buque: el modelo ya lo soporta, y resolvería los
      dos límites del rango —un buque nuevo cae en potero sin avisar, y un buque que cambie de arte
      no se puede expresar porque haría falta una vigencia—.

    ── Y LOS OTROS DOS HISTORIALES, que existen y todavía no se migran ────────────────────────
    M4T_HIST_PUESTOS (14.810 filas, 6.419 empleados) es el CARGO, y en BC no hay un tipo de
    atributo para él: habría que crearlo con espejo Ninguno y cargarle los 50 valores.
    M4T_HIST_SINDICATOS es el que decide la retención sindical —ya hay BASE_SINDICAL en las
    fracciones— y trae además NRO_AFILIADO_SIND, que entraría en "Valor Texto" de la misma fila.
*/
