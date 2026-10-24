/*
   Preparación de la corrección del promedio por vínculo y del estado de enfermedad.
   El llamador suministra, en la misma conexión y sin GO:
     @Aplicar bit: 0 = ensayo con ROLLBACK, 1 = aplicar;
     @FormulaPromAnterior nvarchar(2048), @FormulaPromNueva nvarchar(2048);
     @CambiosEstadoJSON nvarchar(max): exactamente los dos movimientos de 80668;
       AU1: eliminar=false y fechas destino; ACT manual: eliminar=true, destinos=null.

   Requiere prueba y respaldo externos en .snapshots/enfermedad-vinculo-20261013.
   La fuente Oracle se verificó fuera de este lote: enfermedad 20/11/2025-15/03/2026,
   y las corridas originales de enero y febrero tienen 30 días. Este lote no consulta Oracle.
   Retira únicamente el ACT manual 341543, restaura AU1 304856 y conserva el regreso
   ACT original 308744 desde el 16/03/2026. Preserva observaciones de los movimientos que
   permanecen, proyectos, fases, CCT, básicos, novedades 8618/8750 y todos los
   resultados ya almacenados. El llamador reabre y recalcula enero/febrero de 80668 después
   de renovar la caché del servicio y verifica aparte los restantes casos de febrero.
   No ejecutar simultáneamente con publicaciones, cálculos ni otra transacción.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51100,N'Se requiere una conexión sin transacción previa.',1;
IF DB_NAME()<>N'Migr2013R2' THROW 51100,N'Base SQL distinta de Migr2013R2.',1;
IF @Aplicar IS NULL OR @FormulaPromAnterior IS NULL OR @FormulaPromNueva IS NULL
    OR LEN(@FormulaPromAnterior)=0 OR LEN(@FormulaPromNueva)=0
    OR LEN(@FormulaPromAnterior)>2048 OR LEN(@FormulaPromNueva)>2048
    THROW 51100,N'Faltan el modo explícito o las fórmulas completas dentro de 2048 caracteres.',1;
DECLARE @FormulaEsperada nvarchar(2048)=N'IF(MESES_AUS >= 12, IF(DIV_PROM_ENF_12 > 0, (ENF_BASE_12 + ENF_NR_12) / IFZERO(DIV_PROM_ENF_12, 1), 0), IF(DIV_PROM_ENF_6 > 0, (ENF_BASE_6 + ENF_NR_6) / IFZERO(DIV_PROM_ENF_6, 1), 0))';
IF REPLACE(REPLACE(REPLACE(REPLACE(UPPER(@FormulaPromNueva),N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N'')
     COLLATE Latin1_General_100_BIN2 <>
   REPLACE(REPLACE(REPLACE(REPLACE(UPPER(@FormulaEsperada),N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N'')
     COLLATE Latin1_General_100_BIN2
    THROW 51100,N'La fórmula nueva debe usar las bases por vínculo y proteger ambos divisores positivos.',1;
IF @CambiosEstadoJSON IS NULL OR ISJSON(@CambiosEstadoJSON)<>1
    OR LEFT(LTRIM(@CambiosEstadoJSON),1)<>N'['
    OR EXISTS(SELECT 1 FROM OPENJSON(@CambiosEstadoJSON) WHERE [type]<>5)
    THROW 51100,N'Los cambios de estado deben ser un array JSON de objetos.',1;

CREATE TABLE #CambiosEstado
 (mov int NOT NULL PRIMARY KEY,empleado nvarchar(20) COLLATE DATABASE_DEFAULT,
  codigo nvarchar(20) COLLATE DATABASE_DEFAULT,inicioAntes date,finAntes date,
  inicioDespues date,finDespues date,eliminar bit NOT NULL);
INSERT #CambiosEstado
SELECT mov,empleado,codigo,inicioAntes,finAntes,inicioDespues,finDespues,eliminar
FROM OPENJSON(@CambiosEstadoJSON) WITH
 (mov int,empleado nvarchar(20),codigo nvarchar(20),inicioAntes date,finAntes date,
  inicioDespues date,finDespues date,eliminar bit);
IF (SELECT COUNT(*) FROM #CambiosEstado)<>2
    OR EXISTS(SELECT 1 FROM #CambiosEstado WHERE empleado IS NULL OR codigo IS NULL
      OR inicioAntes IS NULL OR finAntes IS NULL
      OR (eliminar=0 AND (inicioDespues IS NULL OR finDespues IS NULL)))
    OR NOT EXISTS(SELECT 1 FROM #CambiosEstado WHERE mov=304856 AND empleado=N'80668' AND codigo=N'AU1'
      AND inicioAntes='20251120' AND finAntes='20251231' AND inicioDespues='20251120' AND finDespues='20260315' AND eliminar=0)
    OR NOT EXISTS(SELECT 1 FROM #CambiosEstado WHERE mov=341543 AND empleado=N'80668' AND codigo=N'ACT'
      AND inicioAntes='20260101' AND finAntes='20260315' AND inicioDespues IS NULL AND finDespues IS NULL AND eliminar=1)
    THROW 51100,N'El payload no contiene exclusivamente la restauración AU1 y el retiro del ACT manual auditados de 80668.',1;

DECLARE @Concepto nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Fuente nvarchar(300)=N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Filtro nvarchar(300)=N'dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Fraccion nvarchar(300)=N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Historial nvarchar(300)=N'dbo.[ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]',
        @Columnas nvarchar(max),@Proyeccion nvarchar(max),@Sql nvarchar(max),
        @Ahora datetime=GETUTCDATE(),@Actor uniqueidentifier='00000000-0000-0000-0000-000000000000',
        @MaxFiltro int=0,@FiltrosNuevos int=0,@EstadosCambiados int=0,@EstadosRetirados int=0,
        @RetornoAntes nvarchar(max),@RetornoDespues nvarchar(max),
        @Formula4110 nvarchar(2048),@Condicion4110 nvarchar(2048),
        @Formula4110Esperada nvarchar(2048)=N'ROUND(IF(TIPOEMPL = 2, #PROM_ENF_MES * IF(TIPOACTIVIDAD = 1, COEF_POTERO, COEF_TANGONERO), BASE_AUSENTISMO) / 30 * DIAS_ENFERMEDAD, PRECISION_REDONDEO)';
CREATE TABLE #Fuentes
 (original nvarchar(30) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
  nueva nvarchar(30) COLLATE DATABASE_DEFAULT NOT NULL UNIQUE,
  codigoAnterior nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,
  codigoNuevo nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,meses int NOT NULL,esNR bit NOT NULL);
INSERT #Fuentes VALUES
 (N'PROM_AUS_6',N'ENF_BASE_6',N'BASE_PROMEDIO',N'BASE_PROMEDIO|AJ_HIST_AUS',6,0),
 (N'PROM_AUS_12',N'ENF_BASE_12',N'BASE_PROMEDIO',N'BASE_PROMEDIO|AJ_HIST_AUS',12,0),
 (N'AUS_NO_REM_ACT_6',N'ENF_NR_6',N'BASE_PROMEDIO_NR',N'BASE_PROMEDIO_NR',6,1),
 (N'AUS_NO_REM_ACT_12',N'ENF_NR_12',N'BASE_PROMEDIO_NR',N'BASE_PROMEDIO_NR',12,1);
CREATE TABLE #Alcance (empleado nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
INSERT #Alcance VALUES
 (N'00191'),(N'00949'),(N'01404'),(N'01767'),(N'01961'),(N'02048'),(N'02297'),(N'02670'),
 (N'02728'),(N'02737'),(N'02854'),(N'02879'),(N'02924'),(N'02937'),(N'03488'),(N'03952'),
 (N'03986'),(N'04185'),(N'04216'),(N'04279'),(N'04315'),(N'04850'),(N'80668');

BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    -- Guarda de concurrencia sobre los valores completos que determinan el tramo corregido.
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
        WITH(UPDLOCK,HOLDLOCK) JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_]
        WHERE e.[Tipo Entidad]=0 AND e.[No_ Empleado]=d.empleado AND e.[Cód_ Estado]=d.codigo
          AND e.[Fecha Inicio]=d.inicioAntes AND e.[Fecha Fin]=d.finAntes)<>2
        THROW 51100,N'Uno de los dos estados cambió desde el respaldo; no sobrescribir.',1;
    IF NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE [No_ Mov_]=304856 AND [No_ Proyecto]=N'')
        OR NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WHERE [No_ Mov_]=341543 AND [No_ Proyecto]=N'PN-ADM-PTOMDY' AND Observaciones=N'')
        THROW 51100,N'Cambió el proyecto o la observación de la licencia/regreso manual.',1;
    IF NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [No_ Mov_]=308744 AND [Tipo Entidad]=0 AND [No_ Empleado]=N'80668'
          AND [Cód_ Estado]=N'ACT' AND [Fecha Inicio]='20260316' AND [Fecha Fin]='17530101')
        THROW 51100,N'El regreso ACT original 308744 del 16/03 dejó de coincidir con el respaldo.',1;
    IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [Tipo Entidad]=0 AND [No_ Empleado]=N'80668'
          AND [Fecha Inicio]>='20251120' AND [No_ Mov_] NOT IN(304856,341543,308744))
        THROW 51100,N'Hay un estado posterior no auditado de 80668; detener para preservar su secuencia.',1;
    SELECT @RetornoAntes=(SELECT e.* FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
        WHERE e.[No_ Mov_]=308744 FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [No_ Empleado]=N'80668' AND [Fecha Alta]='20230801'
          AND [Fecha Baja]='17530101' AND Abierta=1)
        THROW 51100,N'La fase laboral auditada de 80668 dejó de estar abierta.',1;

    -- La extensión de AU1 cambia desde enero, no los HIST_REMUN aprobados de nov/dic.
    IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [No_ Empleado]=N'80668' AND [Cód_ Tipo Liq_]<>N'HIST_REMUN'
          AND (([Cód_ Período] IN(N'202601',N'202602') AND Estado>1)
            OR ([Fecha Liquidación]>='20260301' AND Estado>=1)))
        THROW 51100,N'80668 tiene enero/febrero protegidos o un cálculo posterior que debe revisarse primero.',1;
    IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
        WITH(UPDLOCK,HOLDLOCK) JOIN #Alcance a ON a.empleado=h.[No_ Empleado]
        WHERE h.[Cód_ Tipo Liq_]<>N'HIST_REMUN'
          AND ((h.[Cód_ Período]=N'202602' AND h.Estado>1)
            OR (h.[Fecha Liquidación]>='20260301' AND h.Estado>=1)))
        THROW 51100,N'Hay febrero protegido o cálculos posteriores en el alcance del promedio.',1;
    SELECT e.[No_ Mov_],e.[No_ Proyecto],e.Observaciones,e.[$systemId],e.[$systemCreatedAt],e.[$systemCreatedBy]
    INTO #EstadosConservados
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_] WHERE d.eliminar=0;

    IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WITH(UPDLOCK,HOLDLOCK) JOIN #Fuentes m ON m.nueva=f.[Nombre Variable])
        OR EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WITH(UPDLOCK,HOLDLOCK) JOIN #Fuentes m ON m.nueva=f.[Nombre Variable])
        THROW 51100,N'Ya existen fuentes o filtros destino; no duplicar la aplicación.',1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
        WITH(UPDLOCK,HOLDLOCK) JOIN #Fuentes m ON m.original=f.[Nombre Variable]
        WHERE [Id_ Tabla]=60012 AND [No_ Campo Valor]=7 AND [Función Agregado]=0 AND Activo=1
          AND [No_ Filtro 1]=0 AND [No_ Filtro 2]=0 AND [No_ Filtro 3]=0)<>4
        THROW 51100,N'No están las cuatro fuentes de suma de líneas auditadas.',1;
    IF EXISTS(SELECT 1 FROM #Fuentes m WHERE
        (SELECT COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WITH(UPDLOCK,HOLDLOCK) WHERE f.[Nombre Variable]=m.original)<>4+CONVERT(int,m.esNR)
        OR (SELECT COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WHERE f.[Nombre Variable]=m.original AND
            ((f.[No_ Campo]=3 AND f.[Filtro Valor]=m.codigoAnterior)
              OR (f.[No_ Campo]=16 AND f.[Filtro Valor]=N'{EMP_NO}')
              OR (f.[No_ Campo]=22 AND f.[Filtro Valor]=N'<>0')
              OR (f.[No_ Campo]=23 AND f.[Filtro Valor]=CASE WHEN m.meses=12
                  THEN N'{AUS_PROM12_DESDE}..{AUS_PROM_HASTA}' ELSE N'{AUS_PROM6_DESDE}..{AUS_PROM_HASTA}' END)
              OR (m.esNR=1 AND f.[No_ Campo]=30 AND f.[Filtro Valor]=N'<>HIST_REMUN&<>LIQ_FINAL')))
           <>4+CONVERT(int,m.esNR))
        THROW 51100,N'Los filtros de origen no coinciden con el alcance de empleado/estado/ventana/tipo esperado.',1;

    IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE Código IN(N'PROM_ENF_MES',N'4110') AND [Vigencia Desde]>'20260201')
        THROW 51100,N'Ya hay una fórmula posterior para el promedio o la enfermedad; no pisar.',1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE Código IN(N'PROM_ENF_MES',N'4110') AND [Vigencia Desde]='20260201'
          AND [Vigencia Hasta]='17530101' AND Activo=1)<>2
        THROW 51100,N'No están abiertas las dos plantillas del 01/02/2026.',1;
    IF NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE Código=N'PROM_ENF_MES' AND [Vigencia Desde]='20260201'
          AND Fórmula COLLATE Latin1_General_100_BIN2=@FormulaPromAnterior COLLATE Latin1_General_100_BIN2
          AND DATALENGTH(Fórmula)=DATALENGTH(@FormulaPromAnterior)
          AND [Tipo Concepto]=6 AND [Es Acumulador]=0 AND [Orden Cálculo]=360)
        THROW 51100,N'La fórmula del promedio cambió desde el respaldo o no es el virtual auditado.',1;
    SELECT @Formula4110=Fórmula,@Condicion4110=Condición
    FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE Código=N'4110' AND [Vigencia Desde]='20260201' AND [Variable Base]=N'#PROM_ENF_MES'
      AND [Variable Cantidad]=N'DIAS_ENFERMEDAD' AND [Orden Cálculo]=370;
    IF @Formula4110 IS NULL OR CHARINDEX(N'#PROM_ENF_MES',@Formula4110)=0
        OR CHARINDEX(N'BASE_AUSENTISMO',@Formula4110)=0
        THROW 51100,N'4110 dejó de usar la fórmula y base esperadas del 01/02.',1;
    IF REPLACE(REPLACE(REPLACE(REPLACE(UPPER(@Formula4110),N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N'')
         COLLATE Latin1_General_100_BIN2 <>
       REPLACE(REPLACE(REPLACE(REPLACE(UPPER(@Formula4110Esperada),N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N'')
         COLLATE Latin1_General_100_BIN2
        THROW 51100,N'La fórmula de enfermedad del 01/02 fue modificada desde la revisión; no clonar otra regla.',1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde]='20260201')<>8
        OR EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WITH(UPDLOCK,HOLDLOCK) WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde]>'20260201')
        THROW 51100,N'4110 no tiene exclusivamente sus ocho fracciones ganadoras del 01/02.',1;
    IF NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WITH(UPDLOCK,HOLDLOCK) WHERE [Cód_ Concepto]=N'1053' AND [Vigencia Desde]='20260101'
          AND [Cód_ Acumulador]=N'BASE_AUSENTISMO' AND Porcentaje=100 AND [Invertir Signo]=0
          AND [Filtro Convenio]=N'<>372/04')
        OR EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WITH(UPDLOCK,HOLDLOCK) WHERE [Cód_ Concepto]=N'1053' AND [Cód_ Acumulador]=N'BASE_AUSENTISMO'
            AND [Vigencia Desde]>'20260101')
        THROW 51100,N'Cambió la fracción de antigüedad/BASE_AUSENTISMO o ya tiene una vigencia posterior.',1;

    -- Clonar usando todas las columnas reales conserva ampliaciones concurrentes del esquema.
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP(ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Nombre Variable' THEN N'm.nueva'
        WHEN N'Descripción' THEN N'CASE WHEN m.esNR=1 THEN N''No remunerativo real del vínculo de enfermedad'' ELSE N''Base histórica del vínculo de enfermedad'' END'
        WHEN N'$systemId' THEN N'NEWID()' WHEN N'$systemCreatedAt' THEN N'@Ahora' WHEN N'$systemModifiedAt' THEN N'@Ahora'
        WHEN N'$systemCreatedBy' THEN N'@Actor' WHEN N'$systemModifiedBy' THEN N'@Actor'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP(ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Fuente) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Fuente+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Fuente+N' f JOIN #Fuentes m ON m.original=f.[Nombre Variable];';
    EXEC sys.sp_executesql @Sql,N'@Ahora datetime,@Actor uniqueidentifier',@Ahora,@Actor;

    IF COLUMNPROPERTY(OBJECT_ID(@Filtro),N'No_ Línea','IsIdentity')=0
        SELECT @MaxFiltro=ISNULL(MAX([No_ Línea]),0)
        FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WITH(TABLOCKX,HOLDLOCK);
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP(ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Nombre Variable' THEN N'm.nueva'
        WHEN N'No_ Línea' THEN N'@MaxFiltro+ROW_NUMBER() OVER(ORDER BY m.nueva,f.[No_ Línea])'
        WHEN N'Filtro Valor' THEN N'CASE WHEN f.[No_ Campo]=3 THEN m.codigoNuevo WHEN f.[No_ Campo]=23 THEN CASE WHEN m.meses=12 THEN N''{ENF_PROM12_DESDE}..{ENF_PROM_HASTA}'' ELSE N''{ENF_PROM6_DESDE}..{ENF_PROM_HASTA}'' END ELSE f.[Filtro Valor] END'
        WHEN N'$systemId' THEN N'NEWID()' WHEN N'$systemCreatedAt' THEN N'@Ahora' WHEN N'$systemModifiedAt' THEN N'@Ahora'
        WHEN N'$systemCreatedBy' THEN N'@Actor' WHEN N'$systemModifiedBy' THEN N'@Actor'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP(ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Filtro) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Filtro+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Filtro+N' f JOIN #Fuentes m ON m.original=f.[Nombre Variable];';
    EXEC sys.sp_executesql @Sql,N'@Ahora datetime,@Actor uniqueidentifier,@MaxFiltro int',@Ahora,@Actor,@MaxFiltro;
    SELECT @FiltrosNuevos=COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    JOIN #Fuentes m ON m.nueva=f.[Nombre Variable];
    IF @FiltrosNuevos<>18 THROW 51100,N'No se crearon los dieciocho filtros esperados.',1;

    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP(ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Vigencia Desde' THEN N'CONVERT(datetime,''20260202'')'
        WHEN N'Vigencia Hasta' THEN N'CONVERT(datetime,''17530101'')'
        WHEN N'Fórmula' THEN N'CASE WHEN c.Código=N''PROM_ENF_MES'' THEN @FormulaPromNueva ELSE c.Fórmula END'
        WHEN N'Variable Base' THEN N'CASE WHEN c.Código=N''4110'' THEN N''IF(TIPOEMPL=2,#PROM_ENF_MES,BASE_AUSENTISMO)'' ELSE c.[Variable Base] END'
        WHEN N'$systemId' THEN N'NEWID()' WHEN N'$systemCreatedAt' THEN N'@Ahora' WHEN N'$systemModifiedAt' THEN N'@Ahora'
        WHEN N'$systemCreatedBy' THEN N'@Actor' WHEN N'$systemModifiedBy' THEN N'@Actor'
        ELSE N'c.'+QUOTENAME(name) END),N',') WITHIN GROUP(ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Concepto) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Concepto+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Concepto+N' c WHERE c.Código IN(N''PROM_ENF_MES'',N''4110'') AND c.[Vigencia Desde]=''20260201'';';
    EXEC sys.sp_executesql @Sql,N'@FormulaPromNueva nvarchar(2048),@Ahora datetime,@Actor uniqueidentifier',@FormulaPromNueva,@Ahora,@Actor;
    UPDATE [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    SET [Vigencia Hasta]='20260201',[$systemModifiedAt]=@Ahora,[$systemModifiedBy]=@Actor
    WHERE Código IN(N'PROM_ENF_MES',N'4110') AND [Vigencia Desde]='20260201';
    IF @@ROWCOUNT<>2 THROW 51100,N'No se cerraron las dos versiones anteriores.',1;

    -- La fracción de 1053 se versiona por acumulador. No clona sus otros destinos.
    SELECT @Columnas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP(ORDER BY column_id),
      @Proyeccion=STRING_AGG(CONVERT(nvarchar(max),CASE name
        WHEN N'Vigencia Desde' THEN N'CASE WHEN f.[Cód_ Concepto]=N''1053'' THEN CONVERT(datetime,''20260102'') ELSE CONVERT(datetime,''20260202'') END'
        WHEN N'Filtro Convenio' THEN N'CASE WHEN f.[Cód_ Concepto]=N''1053'' THEN N'''' ELSE f.[Filtro Convenio] END'
        WHEN N'$systemId' THEN N'NEWID()' WHEN N'$systemCreatedAt' THEN N'@Ahora' WHEN N'$systemModifiedAt' THEN N'@Ahora'
        WHEN N'$systemCreatedBy' THEN N'@Actor' WHEN N'$systemModifiedBy' THEN N'@Actor'
        ELSE N'f.'+QUOTENAME(name) END),N',') WITHIN GROUP(ORDER BY column_id)
    FROM sys.columns WHERE object_id=OBJECT_ID(@Fraccion) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
    SET @Sql=N'INSERT '+@Fraccion+N' ('+@Columnas+N') SELECT '+@Proyeccion+N' FROM '+@Fraccion+N' f WHERE (f.[Cód_ Concepto]=N''4110'' AND f.[Vigencia Desde]=''20260201'') OR (f.[Cód_ Concepto]=N''1053'' AND f.[Cód_ Acumulador]=N''BASE_AUSENTISMO'' AND f.[Vigencia Desde]=''20260101'');';
    EXEC sys.sp_executesql @Sql,N'@Ahora datetime,@Actor uniqueidentifier',@Ahora,@Actor;

    UPDATE e SET [Fecha Inicio]=d.inicioDespues,[Fecha Fin]=d.finDespues,
        [$systemModifiedAt]=@Ahora,[$systemModifiedBy]=@Actor
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_]
    WHERE d.eliminar=0 AND e.[Tipo Entidad]=0 AND e.[No_ Empleado]=d.empleado AND e.[Cód_ Estado]=d.codigo
      AND e.[Fecha Inicio]=d.inicioAntes AND e.[Fecha Fin]=d.finAntes;
    SET @EstadosCambiados=@@ROWCOUNT;
    IF @EstadosCambiados<>1 THROW 51100,N'Cantidad de licencias restauradas distinta de una.',1;
    DELETE e FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_]
    WHERE d.eliminar=1 AND e.[Tipo Entidad]=0 AND e.[No_ Empleado]=d.empleado AND e.[Cód_ Estado]=d.codigo
      AND e.[Fecha Inicio]=d.inicioAntes AND e.[Fecha Fin]=d.finAntes;
    SET @EstadosRetirados=@@ROWCOUNT;
    IF @EstadosRetirados<>1 THROW 51100,N'Cantidad de estados manuales retirados distinta de uno.',1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_]
        WHERE d.eliminar=0 AND e.[No_ Empleado]=d.empleado AND e.[Tipo Entidad]=0 AND e.[Cód_ Estado]=d.codigo
          AND e.[Fecha Inicio]=d.inicioDespues AND e.[Fecha Fin]=d.finDespues)<>1
        OR EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
          JOIN #CambiosEstado d ON d.mov=e.[No_ Mov_] WHERE d.eliminar=1)
        OR EXISTS(SELECT 1 FROM #EstadosConservados a JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e ON e.[No_ Mov_]=a.[No_ Mov_]
          WHERE e.[No_ Proyecto]<>a.[No_ Proyecto] OR e.Observaciones<>a.Observaciones OR e.[$systemId]<>a.[$systemId]
            OR e.[$systemCreatedAt]<>a.[$systemCreatedAt] OR e.[$systemCreatedBy]<>a.[$systemCreatedBy])
        THROW 51100,N'La restauración de estado no conservó las fechas o datos originales esperados.',1;
    SELECT @RetornoDespues=(SELECT e.* FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
        WHERE e.[No_ Mov_]=308744 FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF @RetornoAntes IS NULL OR @RetornoDespues IS NULL
        OR @RetornoAntes COLLATE Latin1_General_100_BIN2<>@RetornoDespues COLLATE Latin1_General_100_BIN2
        OR DATALENGTH(@RetornoAntes)<>DATALENGTH(@RetornoDespues)
        THROW 51100,N'Se alteró el regreso original ACT 308744; revertir toda la corrección.',1;

    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        WHERE Código IN(N'PROM_ENF_MES',N'4110') AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101')<>2
        OR NOT EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WHERE Código=N'4110' AND [Vigencia Desde]='20260202' AND [Fórmula] COLLATE Latin1_General_100_BIN2=@Formula4110 COLLATE Latin1_General_100_BIN2
            AND DATALENGTH([Fórmula])=DATALENGTH(@Formula4110) AND [Variable Base]=N'IF(TIPOEMPL=2,#PROM_ENF_MES,BASE_AUSENTISMO)')
        THROW 51100,N'Las nuevas versiones de concepto no conservan las reglas y la base visible auditadas.',1;
    IF (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f JOIN #Fuentes m ON m.nueva=f.[Nombre Variable])<>4
        OR (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde]='20260202')<>8
        OR (SELECT COUNT(*) FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
          WHERE [Cód_ Concepto]=N'1053' AND [Vigencia Desde]='20260102' AND [Cód_ Acumulador]=N'BASE_AUSENTISMO'
            AND Porcentaje=100 AND [Invertir Signo]=0 AND [Filtro Convenio]=N'')<>1
        THROW 51100,N'No quedaron las cuatro fuentes, ocho fracciones de enfermedad y una de antigüedad esperadas.',1;
    IF EXISTS(SELECT [Cód_ Acumulador],Porcentaje,[Invertir Signo],[Filtro Convenio]
        FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde]='20260201'
        EXCEPT SELECT [Cód_ Acumulador],Porcentaje,[Invertir Signo],[Filtro Convenio]
        FROM [dbo].[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde]='20260202')
        THROW 51100,N'Las fracciones copiadas de 4110 difieren de sus destinos, signos o porcentajes anteriores.',1;
    IF EXISTS(SELECT 1 FROM #Fuentes m WHERE
        (SELECT COUNT(*) FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
          WHERE f.[Nombre Variable]=m.nueva AND ((f.[No_ Campo]=3 AND f.[Filtro Valor]=m.codigoNuevo)
            OR (f.[No_ Campo]=16 AND f.[Filtro Valor]=N'{EMP_NO}') OR (f.[No_ Campo]=22 AND f.[Filtro Valor]=N'<>0')
            OR (f.[No_ Campo]=23 AND f.[Filtro Valor]=CASE WHEN m.meses=12 THEN N'{ENF_PROM12_DESDE}..{ENF_PROM_HASTA}' ELSE N'{ENF_PROM6_DESDE}..{ENF_PROM_HASTA}' END)
            OR (m.esNR=1 AND f.[No_ Campo]=30 AND f.[Filtro Valor]=N'<>HIST_REMUN&<>LIQ_FINAL')))
           <>4+CONVERT(int,m.esNR))
        THROW 51100,N'Los filtros nuevos no conservan el concepto, ventana y exclusiones esperados.',1;

    IF COLUMNPROPERTY(OBJECT_ID(@Historial),N'No_ Entrada','IsIdentity')<>1
        THROW 51100,N'La clave del historial dejó de ser IDENTITY; revisar antes de registrar.',1;
    INSERT [dbo].[ArbuTest$Historial Fórmula Concepto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
      ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],[Usuario],[Tipo Cambio],
       [Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],
       [Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
    SELECT c.Código,'20260202',c.Descripción,@Ahora,N'ENFERMEDAD VINCULO META4',0,
       CASE WHEN c.Código=N'PROM_ENF_MES' THEN @FormulaPromAnterior ELSE @Formula4110 END,c.Fórmula,
       c.Condición,c.Condición,CASE WHEN c.Código=N'PROM_ENF_MES' THEN 1 ELSE 0 END,0,
       @Ahora,NEWID(),@Ahora,@Actor,@Ahora,@Actor
    FROM [dbo].[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
    WHERE c.Código IN(N'PROM_ENF_MES',N'4110') AND c.[Vigencia Desde]='20260202';
    IF @@ROWCOUNT<>2 THROW 51100,N'No se registraron ambas nuevas vigencias en el historial de fórmulas.',1;

    IF @Aplicar=1 COMMIT TRANSACTION; ELSE ROLLBACK TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SELECT @Aplicar Aplicado,2 ConceptosNuevos,4 FuentesNuevas,@FiltrosNuevos FiltrosNuevos,
           8 FraccionesEnfermedadCopiadas,1 FraccionAntiguedadNueva,@EstadosCambiados LicenciasRestauradas,
           @EstadosRetirados EstadosManualesRetirados,
           2 AltasHistorial;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    THROW;
END CATCH;
