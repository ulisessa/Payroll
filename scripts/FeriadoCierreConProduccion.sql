/* FERIADO (1023) EN CIERRES DE MAREA CON PRODUCCION: LA PRODUCCION ENTRA AL DIA FERIADO, REPARTIDA EN LOS DIAS DE LA MAREA ENTERA.
   Definicion de Meta4 (usuario): PR_DIA_FERIADO = (sueldo navegacion + puerto + dique + pilotaje + categoria superior +
   adicionales art. 23 y 33 + antiguedad + bodega + PRODUCCION SOMU [+ absorcion]) / dias; SUELDO_DIA_FDO = PR_DIA_FERIADO x DIAS_FERIADO.
   Medido sobre los 60 cierres de febrero de 2026 que pagan feriado (Hist. Meta4, TP 10):
     - Oficiales y ESP: BASE_FERIADO / DIAS_MAREA ya daba exacto (sin 2498). No cambian.
     - Marineros 729/15: el sueldo y los adicionales se dividen por los dias LIQUIDADOS (DIAS_MAREA) y la produccion, que es de la
       marea entera, por los dias de la MAREA ENTERA (DIAS_NAV_MAREA + DIAS_PTO_MAREA de Meta4 = DIAS_ENROLAMIENTO de BC: 19, 20 y 21
       segun el buque). Con eso: BC 3.944.314 -> 27.806.029 contra Meta4 27.847.553 (-0,15%); los 60 dentro del 1% (maximo -0,53%).
       El residuo (-0,24% tipico) es que Meta4 pesa el dia de puerto en la produccion a ~0,973 del de navegacion; sin fuente en BC.
     - HORAS_50/100 (4423/4433) y ABS_ART36 (4415) estan los tres en BASE_FERIADO y se anulan entre si (la absorcion es igual y de
       signo contrario a las horas): la composicion de BASE_FERIADO ya es la de Meta4 y no se toca. Lo unico que faltaba era 2498.
   NO se agrega 2498 al acumulador BASE_FERIADO (se dividiria por DIAS_MAREA, 6,8% de mas en promedio y 15% en los cierres de 16 dias):
   va aparte en la formula, dividido por DIAS_ENROLAMIENTO.
   Formula anterior (vigencia 2026-02-02, abierta): la misma sin el termino  + IF(DIAS_ENROLAMIENTO > 0, #2498 / DIAS_ENROLAMIENTO, 0)
   dentro del round(...) de la segunda rama.
   NUEVA VIGENCIA 2026-02-03 (la 2026-02-02 ya existe; se cierra el 2026-02-02). Enero no cambia: la vigencia nueva no alcanza ninguna fecha de enero.
   DEVENGADOS, REGULAR y LIQ_FINAL de febrero no cambian: #2498 vale cero fuera del cierre de marea (todas las lineas 2498 son CIERRE_MAREA).
   Recalcular: los cierres de marea de febrero (CIERRE_MAREA, 90 liquidaciones; 60 pagan feriado).
   Rollback: DELETE de la fila 1023 con Vigencia Desde 2026-02-03 y UPDATE [Vigencia Hasta] = '17530101' en la 2026-02-02. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1023' AND [Vigencia Desde]='20260203')
BEGIN PRINT 'Ya existe la vigencia 2026-02-03'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = N'IF(
    APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0,
    ROUND(BASE_FERIADO / IFZERO(DIAS_MAREA + DIAS_GP_PERIODO, 30), PRECISION_REDONDEO) * DIAS_FERIADOS,
    round(
        (
            BASE_FERIADO
                - IF(
                TIPO_LIQ = ''LIQ_FINAL'',
                #1053 * DIAS_FRANCOS_PERIODO / IFZERO(
                    DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO
                        + DIAS_ORD_PERIODO,
                    1
                ),
                0
            )
        ) / IFZERO(DIAS_MAREA + DIAS_GP_PERIODO, 30)
            + IF(DIAS_ENROLAMIENTO > 0, #2498 / DIAS_ENROLAMIENTO, 0),
        PRECISION_REDONDEO
    ) * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)
)';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260203'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''1023'' AND [Vigencia Desde]=''20260202'';';
EXEC sp_executesql @sql, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Vigencia Hasta]='20260202', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'1023' AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Orden Cálculo],[Tipos Liq_ Aplicables],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1023' ORDER BY 1;
COMMIT;
