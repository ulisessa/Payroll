/*
    CARGA — valores de oficiales en el convenio 768/19.

    DE DÓNDE SALEN LOS NÚMEROS. De los recibos de Meta4, no del Excel. Se extrajo el
    "Salario Base" de cada oficial de todos los recibos de 2026 (pdftotext -layout
    sobre 2026-01 a 2026-07) y da exactamente dos vigencias:

        Categoría                  ene-abr 2026    may 2026 en adelante
        OF01 Capitán                1.485.000          3.000.000
        OF02 Jefe de Máquinas         900.000          1.500.000
        OF03 1er Of. de Cubierta    1.162.000          2.295.000
        OF04 Primer Maquinista        765.000          1.275.000

    Los cuatro de mayo coinciden AL PESO con la tabla del Excel de tangoneros, lo que
    valida esa columna de forma independiente. Los de enero-abril no estaban en
    ningún lado: sólo existen en los recibos.

    LAS DOS TARIFAS SALEN DEL BÁSICO, verificado contra recibos:

      · Navegación = básico / 30.  Legajo 03664, enero: 26 días x 30.000 = 780.000,
        con básico 900.000. Exacto.
      · Puerto = básico x 2 / 30.  Confirmado en tres Jefes de Máquinas con dos
        básicos distintos (900.000 y 1.500.000), los tres dando 0,0667 del básico.

    El parámetro es MENSUAL y la fórmula divide por 30 —igual que en SOMU, ver
    PRECIO_NAV_CAL_729/15_*— así que se carga el básico tal cual para navegación y el
    doble para puerto.

    LAS DOS PESQUERÍAS CON EL MISMO VALOR. Se cargan _LAN y _CAL idénticos porque el
    básico del oficial no depende del buque. Si algún día difieren, son parámetros
    distintos y se separan sin tocar fórmulas.

    LO QUE NO SE CARGA, Y POR QUÉ. Francos y órdenes quedan afuera:

      · Francos: se midieron las tarifas diarias —Capitán 47.265, Jefe de Máquinas
        41.100, Primer Maquinista 34.935— y las dos últimas son consistentes en
        varios legajos, pero no hay una relación única contra el básico (0,0158 para
        el Capitán contra 0,0274 para los otros) y NO SE ENCONTRÓ ningún recibo de
        francos de 1er Of. de Cubierta. Cargar tres de cuatro sería dejar el juego
        desparejo, que es cómo nacieron los dos errores de SAC devengado.
      · Órdenes: los recibos ORD revisados no traen oficiales.

    ESTO DESTRABA LA LIQUIDACIÓN DE OFICIALES. LIQ-00006166 (legajo 03664, OF02)
    calculaba las CANTIDADES bien —26 días de navegación, 1 de puerto— y las
    multiplicaba por un precio inexistente, así que sólo tenía las dos líneas de
    contribución patronal. Con esto, esas dos líneas tienen que dar 780.000 y 60.000.
*/

-- 1. PREVISUALIZACIÓN. Los 32 valores que se van a crear, con su derivación a la vista.
;WITH Basico AS (
    SELECT * FROM (VALUES
        ('2026-01-01', 'OF01', 1485000.0), ('2026-01-01', 'OF02',  900000.0),
        ('2026-01-01', 'OF03', 1162000.0), ('2026-01-01', 'OF04',  765000.0),
        ('2026-05-01', 'OF01', 3000000.0), ('2026-05-01', 'OF02', 1500000.0),
        ('2026-05-01', 'OF03', 2295000.0), ('2026-05-01', 'OF04', 1275000.0)
    ) v(Vig, Cat, Base)),
Param AS (
    SELECT * FROM (VALUES
        ('PRECIO_NAV_LAN', 1.0), ('PRECIO_NAV_CAL', 1.0),
        ('PRECIO_PUERTO_LAN', 2.0), ('PRECIO_PUERTO_CAL', 2.0)
    ) p(Base, Factor))
SELECT p.Base + '_768/19_' + b.Cat AS Codigo, b.Vig AS Vigencia, b.Cat AS Categoria,
       CAST(b.Base AS decimal(18,2)) AS BasicoDelRecibo,
       CAST(p.Factor AS decimal(4,1)) AS Factor,
       CAST(b.Base * p.Factor AS decimal(18,2)) AS ValorACargar,
       CAST(b.Base * p.Factor / 30 AS decimal(18,2)) AS PorDia
FROM   Basico b CROSS JOIN Param p
ORDER  BY b.Vig, b.Cat, p.Base;
GO

/*
-- 2. LA CARGA.
BEGIN TRAN;

;WITH Basico AS (
    SELECT * FROM (VALUES
        ('2026-01-01', 'OF01', 1485000.0), ('2026-01-01', 'OF02',  900000.0),
        ('2026-01-01', 'OF03', 1162000.0), ('2026-01-01', 'OF04',  765000.0),
        ('2026-05-01', 'OF01', 3000000.0), ('2026-05-01', 'OF02', 1500000.0),
        ('2026-05-01', 'OF03', 2295000.0), ('2026-05-01', 'OF04', 1275000.0)
    ) v(Vig, Cat, Base)),
Param AS (
    SELECT * FROM (VALUES
        ('PRECIO_NAV_LAN', 1.0), ('PRECIO_NAV_CAL', 1.0),
        ('PRECIO_PUERTO_LAN', 2.0), ('PRECIO_PUERTO_CAL', 2.0)
    ) p(Base, Factor)),
Nuevo AS (
    SELECT p.Base                              AS ParamBase,
           p.Base + '_768/19_' + b.Cat         AS Codigo,
           CAST(b.Vig AS datetime)             AS Vigencia,
           b.Cat                               AS Categoria,
           CAST(b.Base * p.Factor AS decimal(38,20)) AS Valor
    FROM   Basico b CROSS JOIN Param p)
INSERT INTO dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Parámetro Base], [Cód_ Parámetro], [Vigencia Desde], [Descripción], [Valor],
     [Moneda], [En Uso], [Notas], [No_ Empleado], [Cód_ Convenio], [Cód_ Categoría], [Nivel],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT n.ParamBase, n.Codigo, n.Vigencia, '', n.Valor,
       '', 0, 'Deducido de los recibos de Meta4 (17/9/2026): Salario Base del oficial.',
       '', '768/19', n.Categoria, 2,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   Nuevo n
WHERE  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
                   WHERE x.[Cód_ Parámetro] = n.Codigo AND x.[Vigencia Desde] = n.Vigencia);

-- Esperado: 32.
SELECT @@ROWCOUNT AS ValoresCargados;

-- CONTROL 1 · PUERTO ES EXACTAMENTE EL DOBLE DE NAVEGACIÓN, en las 16 parejas.
-- Es la invariante de la derivación: si alguna no lo cumple, la carga se desvió.
-- Tiene que dar 16 y 0.
SELECT SUM(CASE WHEN pu.[Valor] = 2 * nv.[Valor] THEN 1 ELSE 0 END) AS ParejasCorrectas,
       SUM(CASE WHEN pu.[Valor] <> 2 * nv.[Valor] THEN 1 ELSE 0 END) AS ParejasMal
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] nv
JOIN   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pu
       ON  pu.[Cód_ Convenio]  = nv.[Cód_ Convenio]
       AND pu.[Cód_ Categoría] = nv.[Cód_ Categoría]
       AND pu.[Vigencia Desde] = nv.[Vigencia Desde]
       AND pu.[Cód_ Parámetro Base] = REPLACE(nv.[Cód_ Parámetro Base], 'NAV', 'PUERTO')
WHERE  nv.[Cód_ Parámetro Base] IN ('PRECIO_NAV_LAN', 'PRECIO_NAV_CAL')
  AND  nv.[Cód_ Convenio] = '768/19';

-- CONTROL 2 · CONTRA EL RECIBO. El precio diario de navegación de OF02 en enero
-- tiene que dar 30.000, que es lo que pagó el recibo del legajo 03664
-- (26 días x 30.000 = 780.000). Es el control que ata la carga al documento fuente.
-- Tiene que dar 30000,00 y 60000,00.
SELECT CAST(MAX(CASE WHEN [Cód_ Parámetro Base] = 'PRECIO_NAV_CAL'    THEN [Valor] END) / 30 AS decimal(18,2)) AS NavPorDiaOF02Enero,
       CAST(MAX(CASE WHEN [Cód_ Parámetro Base] = 'PRECIO_PUERTO_CAL' THEN [Valor] END) / 30 AS decimal(18,2)) AS PuertoPorDiaOF02Enero
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Cód_ Convenio] = '768/19' AND [Cód_ Categoría] = 'OF02'
  AND  [Vigencia Desde] = '2026-01-01';

-- CONTROL 3 · LAS CUATRO CATEGORÍAS EN LAS DOS VIGENCIAS, sin faltantes ni de más.
-- Tiene que dar 4 filas de 8 (4 categorías x 4 parámetros = 16 por vigencia... 8 por
-- vigencia y parámetro base). Se mira que no falte ninguna combinación.
SELECT [Cód_ Parámetro Base] AS ParamBase, COUNT(*) AS Valores,
       COUNT(DISTINCT [Cód_ Categoría]) AS Categorias,
       COUNT(DISTINCT [Vigencia Desde]) AS Vigencias
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Cód_ Convenio] = '768/19'
  AND  [Cód_ Parámetro Base] LIKE 'PRECIO_%'
GROUP  BY [Cód_ Parámetro Base] ORDER BY 1;

-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular LIQ-00006166 (legajo 03664, Jefe de Máquinas, enero 2026).
--    Las dos líneas que tenían cantidad y no importe tienen que dar:
--        1013 Sueldo de navegación   26 días  ->   780.000,00
--        1083 Sueldo de puerto        1 día   ->    60.000,00
SELECT l.[Orden Cálculo] AS Orden, l.[Cód_ Concepto] AS Cpt,
       SUBSTRING(l.[Nombre Impresión],1,30) AS Nombre, l.[Cantidad], l.[Importe]
FROM   dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE  l.[No_ Liquidación] = 'LIQ-00006166'
  AND  l.[Cód_ Concepto] IN ('1013', '1083')
ORDER  BY 1;
GO
