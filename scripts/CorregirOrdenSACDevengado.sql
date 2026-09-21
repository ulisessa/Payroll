/*
    CORRECCIÓN PREVENTIVA — los cinco conceptos de SAC devengado corren antes de que
    sus bases estén completas. Órdenes 460-463 → 924-928.

    EL PROBLEMA. 4750-4754 leen BASE_IG4, BASE_EXT_IG4, BASE_SS_TRAB, BASE_OS_TRAB,
    BASE_SAC y BASE_SINDICAL, y corren en los órdenes 460-463. Pero esas bases siguen
    recibiendo conceptos mucho después:

        610  Descuento días de enfermedad        630  Anticipo de vacaciones
        615  Descuento días de accidente         635  Ajuste de vacaciones
        620  Descuento días de maternidad        640  Deducción por ausencias
        625  Suspensión disciplinaria            645  Deducción por huelga
        675  Porcentaje sobre valor (adelanto)   680  Ajuste enfermedad inculpable
        685  Ajuste prestación ILT               785  Descuento anticipo vacaciones

    O sea que la provisión del aguinaldo se calcula sobre una remuneración que después
    baja. Con un empleado que tuvo enfermedad, vacaciones o una suspensión en el mes,
    la provisión queda alta, SS_SAC_DEV queda alto, y como ganancias lo RESTA de la
    base imponible, la retención sale BAJA.

    Es la misma avería que la Absorción art. 36 de anoche, en la misma familia de
    conceptos. Aquella se vio porque el legajo 03753 tenía absorción; ésta no se ve en
    su liquidación porque no tuvo ninguno de los doce conceptos de arriba — por eso la
    reconstrucción cerraba al centavo contra el recibo de Meta4 y el problema quedaba
    invisible.

    LA VENTANA VÁLIDA ES 786-949, y sale de dos límites duros:

      · LÍMITE INFERIOR 785. El último concepto que alimenta alguna de esas bases es
        8810 "Descuento anticipo vacaciones", en el 785. Antes de eso, alguna base
        todavía está incompleta.
      · LÍMITE SUPERIOR 950. El único concepto que LEE los resultados de los devengados
        —SS_SAC_DEV, BASE_SAC_DEV, GAN_NETA_A_DEDUC y GAN_NETA_MES— es 5010, ganancias,
        en el 950.

    SE ELIGE 924-928 dentro de esa ventana porque queda libre y porque se lee bien:
    justo después del bloque de aportes del trabajador (900-922) y antes de las
    contribuciones patronales (930+). Los aportes devengados quedan al lado de los
    aportes del mes que espejan.

    ALCANCE MEDIDO: 17 liquidaciones de 853 tienen importe en alguno de esos doce
    conceptos. Son las únicas cuyo resultado cambia al recalcular. Las otras 836 dan
    igual — entre ellas LIQ-00006167, que seguirá cerrando contra el recibo de Meta4.

    POR QUÉ SE MUEVEN LOS CINCO Y NO SÓLO ALGUNOS: son un juego. Dejar tres en un lado
    y dos en el otro es exactamente cómo nacieron los dos errores de esta noche.
*/

-- 1. PREVISUALIZACIÓN.
SELECT c.[Código] AS Cpt, c.[Orden Cálculo] AS OrdenHoy,
       924 + ROW_NUMBER() OVER (ORDER BY c.[Orden Cálculo], c.[Código]) - 1 AS OrdenNuevo,
       SUBSTRING(c.[Descripción], 1, 38) AS Nombre
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4750', '4751', '4752', '4753', '4754')
ORDER  BY c.[Orden Cálculo], c.[Código];
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

-- Foto de todos los órdenes, para el control de "no se movió nadie más".
SELECT c.[Código] AS Cpt, c.[Vigencia Desde] AS Vig, c.[Orden Cálculo] AS Orden
INTO   #Antes
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c;

-- El orden nuevo se calcula por ROW_NUMBER sobre el orden viejo, así que el orden
-- RELATIVO entre los cinco se conserva sin escribirlo a mano.
WITH Nuevo AS (
    SELECT c.[Código] AS Cpt, c.[Vigencia Desde] AS Vig,
           924 + ROW_NUMBER() OVER (ORDER BY c.[Orden Cálculo], c.[Código]) - 1 AS OrdenNuevo
    FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
    WHERE  c.[Código] IN ('4750', '4751', '4752', '4753', '4754'))
UPDATE c
SET    c.[Orden Cálculo]      = n.OrdenNuevo,
       c.[$systemModifiedAt]  = SYSUTCDATETIME(),
       c.[$systemModifiedBy]  = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
JOIN   Nuevo n ON n.Cpt = c.[Código] AND n.Vig = c.[Vigencia Desde];

-- Esperado: 5.
SELECT @@ROWCOUNT AS Movidos;

-- CONTROL 1 · NINGUNA BASE QUEDA INCOMPLETA. Es la invariante que motiva el cambio:
-- ningún concepto que alimente alguna de las seis bases puede correr después del
-- primero de los devengados. Tiene que dar 0.
SELECT COUNT(*) AS AlimentadoresQueQuedaronDespues
FROM   dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
JOIN   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
       ON c.[Código] = f.[Cód_ Concepto]
WHERE  f.[Cód_ Acumulador] IN ('BASE_IG4', 'BASE_EXT_IG4', 'BASE_SS_TRAB',
                               'BASE_OS_TRAB', 'BASE_SAC', 'BASE_SINDICAL')
  AND  c.[Código] NOT IN ('4750', '4751', '4752', '4753', '4754')
  AND  c.[Orden Cálculo] >= 924;

-- CONTROL 2 · QUIEN LOS CONSUME SIGUE DESPUÉS. Tiene que dar 0.
SELECT COUNT(*) AS ConsumidoresQueQuedaronAntes
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] NOT IN ('4750', '4751', '4752', '4753', '4754')
  AND (CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%SS_SAC_DEV%'
    OR CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%BASE_SAC_DEV%'
    OR CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%GAN_NETA_A_DEDUC%'
    OR CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%GAN_NETA_MES%')
  AND  c.[Orden Cálculo] <= 928;

-- CONTROL 3 · LOS CINCO, UNO POR ORDEN, SIN PISAR A NADIE. Tiene que dar 5 y 5.
SELECT COUNT(*) AS Devengados924a928,
       (SELECT COUNT(*) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [Orden Cálculo] BETWEEN 924 AND 928) AS ConceptosEnEseRango
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Código] IN ('4750','4751','4752','4753','4754') AND [Orden Cálculo] BETWEEN 924 AND 928;

-- CONTROL 4 · SE CONSERVÓ EL ORDEN RELATIVO: 4750 antes que 4751, y así. Tiene que dar 0.
SELECT COUNT(*) AS ParesFueraDeOrden
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
JOIN   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] b
       ON b.[Código] IN ('4750','4751','4752','4753','4754') AND b.[Código] > a.[Código]
WHERE  a.[Código] IN ('4750','4751','4752','4753','4754')
  AND  a.[Orden Cálculo] > b.[Orden Cálculo];

-- CONTROL 5 · NO SE MOVIÓ NINGÚN OTRO CONCEPTO, contra la foto. Tiene que dar 0.
SELECT COUNT(*) AS OtrosConceptosMovidos
FROM   #Antes a
JOIN   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
       ON c.[Código] = a.Cpt AND c.[Vigencia Desde] = a.Vig
WHERE  a.Cpt NOT IN ('4750','4751','4752','4753','4754') AND c.[Orden Cálculo] <> a.Orden;

DROP TABLE #Antes;
-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: las 17 liquidaciones que cambian de resultado al recalcular. El resto
--    da igual, incluida LIQ-00006167, que tiene que seguir cerrando contra el recibo.
SELECT DISTINCT l.[No_ Liquidación] AS Liq, liq.[No_ Empleado] AS Emp,
       liq.[Cód_ Período] AS Periodo, liq.[Estado]
FROM   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN   dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] liq
       ON liq.[No_] = l.[No_ Liquidación]
WHERE  l.[Importe] <> 0
  AND  EXISTS (SELECT 1
               FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               JOIN dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                    ON c.[Código] = f.[Cód_ Concepto]
               WHERE f.[Cód_ Concepto] = l.[Cód_ Concepto]
                 AND f.[Cód_ Acumulador] IN ('BASE_IG4','BASE_EXT_IG4','BASE_SS_TRAB',
                                             'BASE_OS_TRAB','BASE_SAC','BASE_SINDICAL')
                 AND c.[Código] NOT IN ('4750','4751','4752','4753','4754')
                 AND c.[Orden Cálculo] > 500)
ORDER  BY 1;
GO
