/*
    CORRECCIÓN — 4751, 4752 y 4753: los aportes sobre SAC devengado multiplican
    por el porcentaje sin dividir por 100.

    EL ERROR. Las tres fórmulas terminan en "* PCT_xxx / 12" y les falta el
    "/ 100". Sus hermanos normales —6000 Jubilación, 6010 Ley 19032, 6030 Obra
    Social— todos tienen "* PCT_xxx / 100". El "%" que muestra la fórmula
    evaluada es sólo cómo el evaluador dibuja un parámetro marcado como
    porcentaje: no divide nada.

    Se ve exacto en la fórmula evaluada que quedó guardada en la línea de
    LIQ-00006167 (legajo 03753, enero 2026):

        4752:  3.823.372,95 x 3 / 12  = 955.843,2375   ← el importe real
        bien:  3.823.372,95 x 3 / 100 / 12 = 9.558,4324

        4751:  3.823.372,95 x 11 / 12 = 3.504.758,5375 ← el importe real
        bien:  3.823.372,95 x 11 / 100 / 12 = 35.047,5854

    EL DAÑO NO ESTÁ EN ESAS LÍNEAS, ESTÁ EN GANANCIAS. El acumulador
    SS_SAC_DEV suma los tres y da 5.416.445,01 en vez de 54.164,45. La fórmula
    del concepto 5010 lo RESTA de la base imponible, así que la base se desploma
    de cinco millones y medio a 104.892,79, cae en el tramo 1 (5%) y la retención
    sale 5.244,64.

    Con el /100, la base queda en 5.467.173,35 → tramo 9 →
    1.222.726,73 + (5.467.173,35 - 5.062.576,16) x 35% = 1.364.335,75.
    El recibo de referencia (2026-01-19 MAR.pdf) retiene 1.333.096,40: mismo
    orden de magnitud, 2,3% de diferencia.

    LO QUE ESTA CORRECCIÓN NO RESUELVE — el 2,3% que sobra. El concepto 4750
    "SAC Devengado" corre en orden 460 y lee BASE_IG4 = 9.379.212,17, mientras
    que ganancias en orden 950 lee BASE_IG4 = 8.654.321,62. La diferencia son
    exactamente 724.890,55: la Absorción Art 36, que es negativa y entra en el
    orden 480. O sea que el SAC devengado se calcula sobre una base que todavía
    no tiene la absorción. Con la base posterior la retención daría 1.343.193.
    Eso es una decisión de negocio —si el devengado va antes o después de la
    absorción— y no se toca acá. Ver [[acumuladores-orden-calculo]].

    ALCANCE: cambia la retención de ganancias de TODAS las liquidaciones que se
    recalculen, no sólo la de este legajo.
*/

-- 1. PREVISUALIZACIÓN.
SELECT c.[Código] AS Cpt, c.[Vigencia Desde] AS Desde,
       REPLACE(REPLACE(CAST(c.[Fórmula] AS nvarchar(max)), CHAR(13), ' '), CHAR(10), ' ') AS FormulaHoy,
       CASE WHEN CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 12)%'
            THEN 'le falta el /100' ELSE 'revisar a mano' END AS Diagnostico
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4751', '4752', '4753')
ORDER  BY 1, 2;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

-- El asiento en el historial va ANTES del UPDATE, porque necesita la fórmula
-- vieja. Escribir por SQL saltea el trigger que lo mantiene, así que si no se
-- pone a mano el cambio queda sin rastro — y el historial es justamente lo que
-- permitió encontrar la regresión del sueldo de puerto.
INSERT INTO dbo.[ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    -- [No_ Entrada] va afuera: es IDENTITY y lo asigna SQL Server. Ponerlo a
    -- mano necesitaría IDENTITY_INSERT y dejaría el contador desalineado.
    -- La tabla no admite NULL en NINGUNA columna, ni en las de condición ni en
    -- las banderas: hay que darlas todas explícitas.
    ([Cód_ Concepto], [Vigencia Desde], [Descripción Concepto],
     [Fecha Hora], [Usuario], [Tipo Cambio], [Fórmula Anterior], [Fórmula Nueva],
     [Condición Anterior], [Condición Nueva], [Cambió Fórmula], [Cambió Condición],
     [Última Edición],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT c.[Código], c.[Vigencia Desde], c.[Descripción],
       SYSDATETIME(), 'CORRECCION SQL 17/9/2026', 1,
       c.[Fórmula],
       REPLACE(CAST(c.[Fórmula] AS nvarchar(max)), '/ 12)', '/ 100 / 12)'),
       '', '', 1, 0,
       SYSDATETIME(),
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4751', '4752', '4753')
  AND  CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 12)%'
  AND  CAST(c.[Fórmula] AS nvarchar(max)) NOT LIKE '%/ 100%';

-- Esperado: 3.
SELECT @@ROWCOUNT AS AsientosEnElHistorial;

UPDATE c
SET    c.[Fórmula]            = REPLACE(CAST(c.[Fórmula] AS nvarchar(max)), '/ 12)', '/ 100 / 12)'),
       c.[$systemModifiedAt]  = SYSUTCDATETIME(),
       c.[$systemModifiedBy]  = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4751', '4752', '4753')
  AND  CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 12)%'
  AND  CAST(c.[Fórmula] AS nvarchar(max)) NOT LIKE '%/ 100%';

-- Esperado: 3.
SELECT @@ROWCOUNT AS FormulasCorregidas;

-- CONTROL 1 · LAS TRES QUEDARON CON EL /100 Y SIGUEN CON EL /12.
-- Tiene que dar 3 y 3.
SELECT SUM(CASE WHEN CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 100 / 12)%' THEN 1 ELSE 0 END) AS ConLosDos,
       SUM(CASE WHEN CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 12)%' THEN 1 ELSE 0 END)        AS ConservanEl12
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4751', '4752', '4753');

-- CONTROL 2 · NO SE APLICÓ DOS VECES. Ninguna puede tener "/ 100 / 100".
-- Tiene que dar 0. El REPLACE no es idempotente y correr el script otra vez
-- sobre una fórmula ya corregida no la toca —el NOT LIKE '%/ 100%' lo impide—,
-- pero el control lo verifica en vez de confiar.
SELECT COUNT(*) AS ConDobleDivision
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] IN ('4751', '4752', '4753')
  AND  CAST(c.[Fórmula] AS nvarchar(max)) LIKE '%/ 100 / 100%';

-- CONTROL 3 · NO SE TOCÓ NINGÚN OTRO CONCEPTO.
-- Tiene que dar 0.
SELECT COUNT(*) AS OtrosConceptosTocados
FROM   dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Código] NOT IN ('4751', '4752', '4753')
  AND  CAST(c.[$systemModifiedBy] AS varchar(40)) = '00000000-0000-0000-0000-000000000000'
  AND  c.[$systemModifiedAt] > DATEADD(minute, -5, SYSUTCDATETIME());

-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular. La retención del concepto 5010 en LIQ-00006167 tiene
--    que pasar de 5.244,64 a ~1.364.335,75, contra los 1.333.096,40 del recibo
--    de referencia. Esto lo muestra.
SELECT l.[Cód_ Concepto] AS Cpt, SUBSTRING(l.[Nombre Impresión],1,34) AS Nombre, l.[Importe]
FROM   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE  l.[No_ Liquidación] = 'LIQ-00006167'
  AND  l.[Cód_ Concepto] IN ('4750', '4751', '4752', '4753', '5010')
ORDER  BY 1;
GO
