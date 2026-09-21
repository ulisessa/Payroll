/*
    COMPLETA LAS FRACCIONES DE 1054, 1055 Y 2493

    Tres conceptos activos quedaron sin sus bases de aportes. Cada uno es una anomalía dentro de su
    propia familia, y por eso se detectó por síntoma y no por control:

      1054  Antigüedad mensuales          sólo REMUNERATIVO_BRUTO; sus hermanos 1053 y 1183 las tienen
      1055  Antigüedad STIA               ídem
      2493  Prod. langostino cola rota    tiene sus bases de producción, pero le faltan las de
                                          aportes que sí tienen los otros 15 conceptos de producción

    SÍNTOMAS QUE PRODUCÍA
      - La cuota sindical (8522, sobre BASE_SINDICAL) omitía producción y antigüedad.
      - Jubilación, Ley 19032 y Obra Social (sobre BASE_SS_TRAB / BASE_OS_TRAB) no tomaban la
        antigüedad de mensualizados ni la de STIA.

    NO ES UNA REGRESIÓN DE LA RECARGA DE FRACCIONES. Comparando el export del 06/09 (previo) contra
    el del 07/09 (posterior), la recarga movió 4 pares en total —3 de REMUNERATIVO_BRUTO y 1 de
    BASE_HAB_IG4— y no tocó BASE_SINDICAL, BASE_SS_TRAB ni BASE_OS_TRAB. Los tres conceptos ya
    estaban así antes.

    QUÉ AGREGA
      1054 y 1055  -> 7 bases, copiando a 1183 "Ajuste de antigüedad"
      2493         -> 8 bases, copiando a 2473 "Producción langostino cola 2"

      Vigencia 2023-01-12, la misma de las fracciones hermanas, para que el acumulado histórico se
      comporte igual. Porcentaje 100 e Invertir Signo 0, como todas.

    DECISIÓN ABIERTA - BASE_FERIADO Y BASE_AUSENTISMO PARA LA ANTIGÜEDAD
      1053 (Antigüedad SOMU, embarcados) tiene además BASE_FERIADO y BASE_AUSENTISMO; 1183 no.
      Este script sigue a 1183, que es el criterio conservador para mensualizados y STIA. Si la
      antigüedad de esa gente también debe alimentar feriados y ausentismo, están al final,
      comentadas.

    ANTES DE CORRER
      1. Backup.
      2. Con nadie liquidando.
      3. Revisar la variable Empresa.
      4. Después, reiniciar el service tier y recalcular los períodos afectados.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';
DECLARE @Tabla   sysname;
DECLARE @sql     nvarchar(max);

SELECT @Tabla = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Fracci_n Acumulador$%';

IF @Tabla IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%Fracci%';
    RAISERROR(N'No se encontró la tabla. Revisar la variable Empresa contra la lista de arriba.',16,1);
    RETURN;
END;

SELECT @Tabla AS TablaFracciones;

-- Estado actual de los tres conceptos.
SET @sql = N'SELECT [Cód_ Concepto], [Cód_ Acumulador], [Vigencia Desde], [Porcentaje]
             FROM [dbo].' + @Tabla + N'
             WHERE [Cód_ Concepto] IN (N''1054'',N''1055'',N''2493'')
             ORDER BY [Cód_ Concepto], [Cód_ Acumulador];';
EXEC sp_executesql @sql;

BEGIN TRAN;

-- Las filas van a una temporal en SQL estático y de ahí a la tabla real: el nombre de la tabla es
-- lo único que necesita SQL dinámico.
--
-- COLLATE DATABASE_DEFAULT no es decorativo: las temporales viven en tempdb, que hereda la
-- collation del SERVIDOR (Modern_Spanish_CI_AS), mientras que la base de BC usa la suya
-- (Modern_Spanish_100_CI_AS). Sin esto, el NOT EXISTS de más abajo compara dos columnas de texto
-- con collations distintas y SQL corta con "Cannot resolve the collation conflict".
CREATE TABLE #Nuevas (
    [Cód_ Concepto]   nvarchar(20)   COLLATE DATABASE_DEFAULT NOT NULL,
    [Vigencia Desde]  date           NOT NULL,
    [Cód_ Acumulador] nvarchar(20)   COLLATE DATABASE_DEFAULT NOT NULL,
    [Porcentaje]      decimal(38,20) NOT NULL,
    [Descripción]     nvarchar(50)   COLLATE DATABASE_DEFAULT NOT NULL,
    [Invertir Signo]  tinyint        NOT NULL
);

INSERT INTO #Nuevas VALUES
    (N'1054','2023-01-12',N'BASE_SS_TRAB' ,100,N'Base BASE_SS_TRAB' ,0),
    (N'1054','2023-01-12',N'BASE_OS_TRAB' ,100,N'Base BASE_OS_TRAB' ,0),
    (N'1054','2023-01-12',N'BASE_SINDICAL',100,N'Base BASE_SINDICAL',0),
    (N'1054','2023-01-12',N'BASE_LRT'     ,100,N'Base BASE_LRT'     ,0),
    (N'1054','2023-01-12',N'BASE_IG4'     ,100,N'Base BASE_IG4'     ,0),
    (N'1054','2023-01-12',N'BASE_SAC'     ,100,N'Base BASE_SAC'     ,0),
    (N'1054','2023-01-12',N'BASE_PROMEDIO',100,N'Base BASE_PROMEDIO',0),

    (N'1055','2023-01-12',N'BASE_SS_TRAB' ,100,N'Base BASE_SS_TRAB' ,0),
    (N'1055','2023-01-12',N'BASE_OS_TRAB' ,100,N'Base BASE_OS_TRAB' ,0),
    (N'1055','2023-01-12',N'BASE_SINDICAL',100,N'Base BASE_SINDICAL',0),
    (N'1055','2023-01-12',N'BASE_LRT'     ,100,N'Base BASE_LRT'     ,0),
    (N'1055','2023-01-12',N'BASE_IG4'     ,100,N'Base BASE_IG4'     ,0),
    (N'1055','2023-01-12',N'BASE_SAC'     ,100,N'Base BASE_SAC'     ,0),
    (N'1055','2023-01-12',N'BASE_PROMEDIO',100,N'Base BASE_PROMEDIO',0),

    (N'2493','2023-01-12',N'BASE_SS_TRAB' ,100,N'Base BASE_SS_TRAB' ,0),
    (N'2493','2023-01-12',N'BASE_OS_TRAB' ,100,N'Base BASE_OS_TRAB' ,0),
    (N'2493','2023-01-12',N'BASE_SINDICAL',100,N'Base BASE_SINDICAL',0),
    (N'2493','2023-01-12',N'BASE_LRT'     ,100,N'Base BASE_LRT'     ,0),
    (N'2493','2023-01-12',N'BASE_IG4'     ,100,N'Base BASE_IG4'     ,0),
    (N'2493','2023-01-12',N'BASE_SAC'     ,100,N'Base BASE_SAC'     ,0),
    (N'2493','2023-01-12',N'BASE_PROMEDIO',100,N'Base BASE_PROMEDIO',0),
    (N'2493','2023-01-12',N'BASE_FERIADO' ,100,N'Base BASE_FERIADO' ,0);

-- Sólo lo que falte: correr el script dos veces no duplica nada.
SET @sql = N'
INSERT INTO [dbo].' + @Tabla + N' ([Cód_ Concepto],[Vigencia Desde],[Cód_ Acumulador],[Porcentaje],[Descripción],[Invertir Signo])
SELECT n.[Cód_ Concepto], n.[Vigencia Desde], n.[Cód_ Acumulador], n.[Porcentaje], n.[Descripción], n.[Invertir Signo]
FROM #Nuevas n
WHERE NOT EXISTS (SELECT 1 FROM [dbo].' + @Tabla + N' f
                   WHERE f.[Cód_ Concepto]   = n.[Cód_ Concepto]
                     AND f.[Cód_ Acumulador] = n.[Cód_ Acumulador]);
SELECT @@ROWCOUNT AS FilasAgregadas;';
EXEC sp_executesql @sql;

COMMIT;

DROP TABLE #Nuevas;

-- Verificación 1: los tres tienen que quedar como sus hermanos.
SET @sql = N'
SELECT [Cód_ Concepto], COUNT(*) AS Acumuladores
FROM [dbo].' + @Tabla + N'
WHERE [Cód_ Concepto] IN (N''1053'',N''1054'',N''1055'',N''1183'',N''2473'',N''2493'')
GROUP BY [Cód_ Concepto] ORDER BY 1;';
EXEC sp_executesql @sql;

-- Verificación 2: no debe devolver nada.
SET @sql = N'
SELECT c.Concepto, c.Base
FROM (VALUES (N''1054'',N''BASE_SINDICAL''),(N''1054'',N''BASE_SS_TRAB''),(N''1054'',N''BASE_OS_TRAB''),
             (N''1055'',N''BASE_SINDICAL''),(N''1055'',N''BASE_SS_TRAB''),(N''1055'',N''BASE_OS_TRAB''),
             (N''2493'',N''BASE_SINDICAL''),(N''2493'',N''BASE_SS_TRAB''),(N''2493'',N''BASE_OS_TRAB''))
     AS c(Concepto, Base)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].' + @Tabla + N' f
                   WHERE f.[Cód_ Concepto]   = c.Concepto COLLATE DATABASE_DEFAULT
                     AND f.[Cód_ Acumulador] = c.Base     COLLATE DATABASE_DEFAULT);';
EXEC sp_executesql @sql;
GO

/*  SI LA ANTIGÜEDAD DE MENSUALIZADOS Y STIA TAMBIÉN VA A FERIADOS Y AUSENTISMO,
    agregar estas cuatro filas al bloque INSERT INTO #Nuevas:

    (N'1054','2023-01-12',N'BASE_FERIADO'   ,100,N'Base BASE_FERIADO'   ,0),
    (N'1054','2023-01-12',N'BASE_AUSENTISMO',100,N'Base BASE_AUSENTISMO',0),
    (N'1055','2023-01-12',N'BASE_FERIADO'   ,100,N'Base BASE_FERIADO'   ,0),
    (N'1055','2023-01-12',N'BASE_AUSENTISMO',100,N'Base BASE_AUSENTISMO',0),
*/
