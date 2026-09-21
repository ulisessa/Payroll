/*
    ALTA — concepto 4754 "Cuota sindical SAC Devengado".

    POR QUÉ. El acumulador SS_SAC_DEV —los aportes sobre el aguinaldo devengado, que
    la fórmula de ganancias RESTA de la base imponible— lo alimentan tres conceptos:
    jubilación (4751), ley 19032 (4752) y obra social (4753). Su espejo del mes,
    SS_LIQUIDADO, lo alimentan TRECE, y entre ellos está la cuota sindical (8522).
    Falta el devengado de esa.

    LA CUENTA CIERRA CONTRA UN RECIBO REAL. En LIQ-00006167 (legajo 03753, enero 2026)
    la retención da 1.343.192,96 y el recibo de Meta4 —"2026-01-19 MAR.pdf"— retiene
    1.333.096,40. Trabajando hacia atrás desde el tramo 9, la base de Meta4 tiene que
    ser 5.377.918,07 contra los 5.406.765,39 nuestros: sobran 28.847,32 en la BASE,
    no en el impuesto. Y

        BASE_SINDICAL x PCT_CUOTA_SIND / 100 / 12
          = 8.654.321,6234 x 4 / 100 / 12
          = 28.847,74

    que deja la retención en 1.333.096,25, a QUINCE CENTAVOS del recibo. Esos quince
    son de la misma familia que las otras dos diferencias de 0,14 que ya conocíamos:
    PRECISION_REDONDEO está en 1 y redondea al peso donde el sistema viejo guardaba
    centavos.

    CÓMO SE CREA. Copiando los campos de 4752 en vez de escribirlos a mano, y sólo
    cambiando los cuatro que tienen que cambiar: código, descripción, orden y fórmula.
    Así no puede quedar desalineado del juego al que pertenece — que es exactamente
    cómo nació este problema.

    TRES ACUMULADORES, NO UNO. Sus hermanos alimentan SS_SAC_DEV, GAN_NETA_A_DEDUC y
    GAN_NETA_MES, los tres al 100%. Cargar sólo el primero lo dejaría a medias.

    SIN ASIGNACIÓN POR CONVENIO. 8522 está asignado a cinco convenios, pero 4751-4753
    no tienen ni una fila en "Concepto CCT Vigente", o sea que aplican a todos. El
    nuevo va igual.

    SIN TOPE. 4751-4753 topean contra TOPE_SIPA porque la seguridad social tiene tope;
    la cuota sindical no lo tiene —8522 tampoco topea— así que la fórmula va derecha.

    ORDEN 463. Está libre, cae después de los otros tres (460-462) y antes del 464.

    LO QUE NO RESUELVE, Y YA PASABA ANTES. Hay entre 11 y 17 conceptos que alimentan
    cada una de estas bases DESPUÉS del orden 462 —descuentos por enfermedad,
    accidente, maternidad, suspensión, y los SAC—, así que los cuatro devengados se
    calculan sobre bases que después crecen o se achican. En esta liquidación ninguno
    de esos tiene importe, que es por qué la reconstrucción cierra exacta. Con un
    empleado que sí los tenga, la provisión va a estar corrida. Es un problema
    preexistente de los tres conceptos que ya estaban y no lo agrega éste; arreglarlo
    significa mover los cuatro después del orden 640, y eso cambia resultados en serio.
*/

-- 1. PREVISUALIZACIÓN. Qué se va a crear, copiado del hermano.
SELECT '4754' AS CodigoNuevo, 463 AS OrdenNuevo,
       'Cuota sindical SAC Devengado' AS DescripcionNueva,
       c.[Código] AS CopiadoDe, c.[Tipo Concepto] AS Tipo, c.[Es Devengo] AS EsDev,
       c.[Imprime en Recibo] AS Imprime, c.[Grupo Costo Laboral] AS Grupo,
       c.[Tipos Liq_ Aplicables] AS TiposLiq
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] = '4752';

SELECT f.[Cód_ Acumulador] AS AcumuladorQueVaARecibirlo, CAST(f.[Porcentaje] AS decimal(10,2)) AS Pct
FROM   dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[Cód_ Concepto] = '4752' ORDER BY 1;
GO

/*
-- 2. EL ALTA.
BEGIN TRAN;

-- EL CONCEPTO, copiando 4752. Los únicos campos que se escriben a mano son los
-- cuatro que distinguen a este concepto de su hermano.
INSERT INTO dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Código], [Vigencia Desde], [Descripción], [Nombre Impresión], [Tipo Concepto],
     [Fórmula], [Condición], [Orden Cálculo], [Aplica A], [Activo], [Es Acumulador],
     [Aplica Tipo Liq_], [Variable Cantidad], [Unidad Cantidad], [Etiqueta Det_ Ganancias],
     [Imprime en Recibo], [Grupo Costo Laboral], [Es Devengo], [Variable Base],
     [Tipos Liq_ Aplicables], [Rol Franco], [Vigencia Hasta], [Par CCT a Usar],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT '4754', c.[Vigencia Desde],
       'Cuota sindical SAC Devengado', 'Cuota sindical SAC Devengado',
       c.[Tipo Concepto],
       'round((BASE_SINDICAL * PCT_CUOTA_SIND / 100 / 12), 0.0001)',
       c.[Condición], 463,
       c.[Aplica A], c.[Activo], c.[Es Acumulador], c.[Aplica Tipo Liq_],
       c.[Variable Cantidad], c.[Unidad Cantidad], c.[Etiqueta Det_ Ganancias],
       c.[Imprime en Recibo], c.[Grupo Costo Laboral], c.[Es Devengo], c.[Variable Base],
       c.[Tipos Liq_ Aplicables], c.[Rol Franco], c.[Vigencia Hasta], c.[Par CCT a Usar],
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] = '4752'
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
                   WHERE x.[Código] = '4754');

-- Esperado: 1.
SELECT @@ROWCOUNT AS ConceptoCreado;

-- LAS FRACCIONES, también copiadas: las mismas tres que tiene 4752, al mismo
-- porcentaje y con el mismo signo. Copiarlas en vez de nombrarlas evita que el juego
-- quede desparejo si mañana se le agrega un cuarto acumulador a los otros tres.
INSERT INTO dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Concepto], [Vigencia Desde], [Cód_ Acumulador], [Porcentaje], [Descripción],
     [Invertir Signo],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT '4754', f.[Vigencia Desde], f.[Cód_ Acumulador], f.[Porcentaje], f.[Descripción],
       f.[Invertir Signo],
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[Cód_ Concepto] = '4752'
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
                   WHERE x.[Cód_ Concepto] = '4754' AND x.[Cód_ Acumulador] = f.[Cód_ Acumulador]);

-- Esperado: 3.
SELECT @@ROWCOUNT AS FraccionesCreadas;

-- CONTROL 1 · QUEDÓ IDÉNTICO A SUS HERMANOS salvo en los cuatro campos que debían
-- cambiar. Es el control que importa: el problema que estamos arreglando nació de un
-- juego de conceptos desparejo. Tiene que dar 0.
SELECT COUNT(*) AS CamposQueNoDebieronCambiar
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
JOIN   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.[Código] = '4752'
WHERE  n.[Código] = '4754'
  AND (n.[Tipo Concepto]          <> h.[Tipo Concepto]
    OR n.[Aplica A]               <> h.[Aplica A]
    OR n.[Activo]                 <> h.[Activo]
    OR n.[Es Acumulador]          <> h.[Es Acumulador]
    OR n.[Es Devengo]             <> h.[Es Devengo]
    OR n.[Imprime en Recibo]      <> h.[Imprime en Recibo]
    OR n.[Grupo Costo Laboral]    <> h.[Grupo Costo Laboral]
    OR n.[Aplica Tipo Liq_]       <> h.[Aplica Tipo Liq_]
    OR n.[Rol Franco]             <> h.[Rol Franco]
    OR n.[Par CCT a Usar]         <> h.[Par CCT a Usar]
    OR n.[Vigencia Desde]         <> h.[Vigencia Desde]
    OR n.[Vigencia Hasta]         <> h.[Vigencia Hasta]
    OR n.[Tipos Liq_ Aplicables]  <> h.[Tipos Liq_ Aplicables]);

-- CONTROL 2 · LOS CUATRO ALIMENTAN LOS MISMOS ACUMULADORES. Tiene que dar 4 filas,
-- una por concepto, todas con 3.
SELECT f.[Cód_ Concepto] AS Cpt, COUNT(*) AS Acumuladores
FROM   dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[Cód_ Concepto] IN ('4751', '4752', '4753', '4754')
GROUP  BY f.[Cód_ Concepto] ORDER BY 1;

-- CONTROL 3 · EL ORDEN 463 QUEDÓ SÓLO PARA ÉL, y después de los otros tres.
-- Tiene que dar 1 y 0.
SELECT (SELECT COUNT(*) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [Orden Cálculo] = 463)                                            AS EnElOrden463,
       (SELECT COUNT(*) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [Código] IN ('4751','4752','4753') AND [Orden Cálculo] >= 463)    AS HermanosQueQuedaronDespues;

-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular LIQ-00006167. La retención tiene que pasar de 1.343.192,96
--    a 1.333.096,25, contra los 1.333.096,40 del recibo de Meta4.
SELECT l.[Orden Cálculo] AS Orden, l.[Cód_ Concepto] AS Cpt,
       SUBSTRING(l.[Nombre Impresión],1,34) AS Nombre, l.[Importe]
FROM   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE  l.[No_ Liquidación] = 'LIQ-00006167'
  AND  l.[Cód_ Concepto] IN ('4751', '4752', '4753', '4754', '5010')
ORDER  BY 1;
GO
