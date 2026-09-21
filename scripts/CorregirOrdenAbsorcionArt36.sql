/*
    CORRECCIÓN — 4415 "Absorción artículo 36 CCT SOMU-CAPECA": orden 480 → 412.

    EL PROBLEMA. La absorción es un concepto remunerativo NEGATIVO: alimenta al
    100% a BASE_IG4, BASE_SS_TRAB, BASE_OS_TRAB, BASE_SAC y REMUNERATIVO_BRUTO.
    Corría en el orden 480, veinte lugares DESPUÉS de los cuatro conceptos de SAC
    devengado (4750-4753, órdenes 460-462), que leen esos mismos acumuladores.

    Resultado: el SAC devengado se provisionaba sobre una remuneración que
    todavía no tenía la absorción descontada. En LIQ-00006167 (legajo 03753,
    enero 2026):

        BASE_IG4 en el orden 460 (SAC devengado)  = 9.379.212,17
        Absorción art. 36, orden 480              =  -724.890,55
        BASE_IG4 en el orden 950 (ganancias)      = 8.654.321,62

    POR QUÉ SE MUEVE LA ABSORCIÓN Y NO EL DEVENGADO. Lo natural sería correr los
    4750-4753 a después del 480, pero entre el 460 y el 480 están los conceptos
    de aguinaldo —3613 SAC primer semestre (459) y 3623 SAC segundo semestre
    (465)—, que TAMBIÉN alimentan BASE_IG4, BASE_SS_TRAB y BASE_OS_TRAB. Moviendo
    el devengado hacia adelante se provisionaría aguinaldo sobre aguinaldo. No
    hay ningún hueco entre el 465 y el 480 que evite las dos cosas a la vez.

    POR QUÉ 412 Y NO OTRO. La absorción no puede subir más arriba que sus propias
    entradas, y su fórmula es:

        IF(TIPOACTIVIDAD = 1, -(#4423 + #4433), -BASE_ABS_SOMU)

        #4423 Horas extras 100%  → orden 405
        #4433 Horas extras 50%   → orden 410
        BASE_ABS_SOMU            → lo alimentan 1013 (orden 15) y 1174 (orden 154)

    O sea que el primer orden válido es el 411. El 412 está libre, es el primer
    hueco después de las horas extras —que es justo lo que la absorción absorbe—
    y queda antes de todo lo que tiene que verla: el primer concepto posterior
    que lee alguno de sus acumuladores es el 4750, en el 460.

    ALCANCE VERIFICADO. Entre el 411 y el 479, los ÚNICOS conceptos que leen
    BASE_IG4, BASE_SS_TRAB, BASE_OS_TRAB, BASE_SAC o REMUNERATIVO_BRUTO son los
    cuatro del SAC devengado. Nada más en ese tramo cambia de resultado.

    EFECTO ESPERADO. De los cuatro, sólo 4750 se mueve: los otros tres aplican
    MIN(base, TOPE_SIPA) y la base está muy por encima del tope —8,6 millones
    contra 3.823.372,95—, así que restarle 724.890 la deja igual de arriba y el
    MIN devuelve el tope en los dos casos. El tope los protege del error de orden.

        BASE_SAC_DEV    781.601,01  →   721.193,47    (-60.407,55)
        5010 Retención  1.364.335,60 → 1.343.192,96   (-21.142,64)

    El recibo de referencia retiene 1.333.096,40, así que quedarían 10.096,56 sin
    explicar — otro asunto, más chico, a buscar en SS_LIQUIDADO o en las
    deducciones.
*/

-- 1. PREVISUALIZACIÓN.
SELECT c.[Código] AS Cpt, c.[Orden Cálculo] AS OrdenHoy, 412 AS OrdenNuevo,
       SUBSTRING(c.[Descripción],1,40) AS Nombre, c.[Vigencia Desde] AS Desde
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] = '4415'
ORDER  BY 2;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

-- Foto de TODOS los órdenes antes de tocar nada. El control de "no se movió
-- nadie más" tiene que comparar contra esto y no contra $systemModifiedAt: la
-- primera versión miraba "modificados en los últimos cinco minutos con GUID
-- nulo" y se atrapaba a sí misma, porque los conceptos 4751-4753 se habían
-- corregido un rato antes con esa misma firma. Un control que no distingue su
-- propio rastro del de otro no sirve.
SELECT c.[Código] AS Cpt, c.[Vigencia Desde] AS Vig, c.[Orden Cálculo] AS Orden
INTO   #Antes
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c;

DECLARE @OrdenViejo int;
SELECT @OrdenViejo = MAX(c.[Orden Cálculo])
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] = '4415';

UPDATE c
SET    c.[Orden Cálculo]      = 412,
       c.[$systemModifiedAt]  = SYSUTCDATETIME(),
       c.[$systemModifiedBy]  = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] = '4415' AND c.[Orden Cálculo] <> 412;

SELECT @@ROWCOUNT AS Movidos, @OrdenViejo AS OrdenQueTenia;

-- CONTROL 1 · LA ABSORCIÓN CORRE DESPUÉS DE TODO LO QUE LEE. Es la invariante
-- que no se puede romper: un concepto no puede calcularse antes que sus
-- entradas. Tiene que dar 0.
SELECT COUNT(*) AS EntradasQueQuedaronDespues
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Código] IN ('4423', '4433', '1013', '1174')
  AND  e.[Orden Cálculo] >= 412;

-- CONTROL 2 · LA ABSORCIÓN CORRE ANTES DE TODO LO QUE LA NECESITA: los cuatro
-- del SAC devengado, los dos de aguinaldo y ganancias. Tiene que dar 0.
SELECT COUNT(*) AS ConsumidoresQueQuedaronAntes
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d
WHERE  d.[Código] IN ('4750', '4751', '4752', '4753', '3613', '3623', '5010')
  AND  d.[Orden Cálculo] <= 412;

-- CONTROL 3 · EL 412 QUEDÓ SÓLO PARA LA ABSORCIÓN. Compartir orden es legal
-- —el 450 tiene tres conceptos y el 455 dos— pero acá se eligió un hueco libre
-- a propósito, para que el resultado no dependa de cómo desempata el motor.
-- Tiene que dar 1.
SELECT COUNT(*) AS ConceptosEnElOrden412
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Orden Cálculo] = 412;

-- CONTROL 4 · NO SE MOVIÓ NINGÚN OTRO CONCEPTO, contra la foto de antes.
-- Tiene que dar 0.
SELECT COUNT(*) AS OtrosConceptosMovidos
FROM   #Antes a
JOIN   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
       ON c.[Código] = a.Cpt AND c.[Vigencia Desde] = a.Vig
WHERE  a.Cpt <> '4415' AND c.[Orden Cálculo] <> a.Orden;

DROP TABLE #Antes;

-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular LIQ-00006167 y mirar estas cinco líneas.
SELECT l.[Orden Cálculo] AS Orden, l.[Cód_ Concepto] AS Cpt,
       SUBSTRING(l.[Nombre Impresión],1,34) AS Nombre, l.[Importe]
FROM   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE  l.[No_ Liquidación] = 'LIQ-00006167'
  AND  l.[Cód_ Concepto] IN ('4415', '4750', '4751', '4752', '4753', '5010')
ORDER  BY 1;
GO
