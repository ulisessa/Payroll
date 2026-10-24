/*
    FECHA DEL TIPO DE CAMBIO FORZABLE POR NOVEDAD.

    El tipo de cambio de los sueldos en divisa de nómina (90251 en USD, 90212 y 90302 en EUR) es el de
    la fecha en que se CORTÓ el proceso, que cambia cada mes. BC tomaba siempre el de la fecha de
    referencia (el fin del período). Ahora el contexto resuelve el token {FECHA_TC}: la fecha de una
    novedad FECHA_TC del empleado y del período, o la de referencia si no hay.

    Este script deja la CONFIGURACIÓN lista:
      1. El concepto FECHA_TC (informativo, sin fórmula, con condición 0 y fuera del recibo). Existe
         sólo porque Novedad Liquidación exige un concepto válido; nunca genera una línea.
      2. Las Fuentes TC_COMPRADOR y TC_VENDEDOR pasan de "<={FECHA_REF}" a "<={FECHA_TC}". Sin la
         novedad dan lo mismo que antes.

    USO: cargar una novedad con Concepto FECHA_TC, Empleado, Período y Fecha = el día de cotización
    (ej. 90251, 202602, 26/02/2026). Queda Pendiente a propósito: no se materializa.
    Después de aplicar: reiniciar el service tier.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';

BEGIN TRAN;

-- 1. Concepto FECHA_TC, copiado de un informativo (PROM_AUS_MES, vigencia 2023) y vaciado.
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
        WHEN N'Código' THEN N'N''FECHA_TC'''
        WHEN N'Descripción' THEN N'N''Fecha del tipo de cambio (novedad)'''
        WHEN N'Nombre Impresión' THEN N'N'''''
        WHEN N'Fórmula' THEN N'N'''''
        WHEN N'Condición' THEN N'N''0'''
        WHEN N'Imprime en Recibo' THEN N'0'
        WHEN N'Es Acumulador' THEN N'0'
        WHEN N'Es Devengo' THEN N'0'
        WHEN N'Vigencia Hasta' THEN N'''17530101'''
        ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'IF NOT EXISTS (SELECT 1 FROM ' + @C + N' WHERE [Código] = N''FECHA_TC'')
INSERT ' + @C + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @C + N' WHERE [Código] = N''PROM_AUS_MES'' AND [Vigencia Desde] = ''20230112'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Concepto_esperado_1;

-- 2. Las dos Fuentes.
UPDATE f SET f.[Filtro Valor] = N'<={FECHA_TC}', f.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE f.[Nombre Variable] IN (N'TC_COMPRADOR', N'TC_VENDEDOR') AND f.[Filtro Valor] = N'<={FECHA_REF}';
SELECT @@ROWCOUNT AS Filtros_esperado_2;

-- Controles
SELECT [Código], [Tipo Concepto] tipo, [Condición] cond, [Imprime en Recibo] imprime, LEN([Fórmula]) formula FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'FECHA_TC';
SELECT f.[Nombre Variable] v, f.[Filtro Valor] FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WHERE f.[Nombre Variable] IN (N'TC_COMPRADOR', N'TC_VENDEDOR') ORDER BY 1;
COMMIT;
