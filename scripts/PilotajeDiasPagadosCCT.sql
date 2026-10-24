/* PILOTAJE: LOS DÍAS QUE SE PAGAN SON LOS DEL TRAMO DEL CONVENIO, NO LOS DÍAS REALES DEL ESTADO PI. Decisión del usuario (21/10/2026), con el texto del convenio.
   CCT SOMU art. 43 (marinería): el pilotaje se paga como el cuádruplo del sueldo básico mensual de la categoría, con un mínimo equivalente en días según la duración: 5 días hasta 120 horas, 10 hasta 240, 15 hasta 360 y 30 hasta 720;
   las prolongaciones mayores, a razón del quíntuplo del valor diario por día adicional. Oficiales (art. 29 de la copia del usuario, "art. 28" en su mensaje): como mínimo el quíntuplo de cinco días de la remuneración garantizada en
   navegación, con 50 % más pasados los 5 días. El "sueldo de pilotaje" es el ajuste.
   Meta4 lo confirma: DIAS_PILOTAJE pagado = 5 con 1, 2, 3, 4, 5 o 6 días reales de pilotaje (RL3, 2001-2026: 360, 334, 524, 663, 216 y 32 casos); en abril los 40 casos tienen 2 días de estado PI (24 y 25/4) y 5 pagados:
   SUELDO_PILOTAJE = 5 x PRECIO_PILOTAJE = 502.070 en 04839. BC pagaba con los días reales y tapaba el 1043 con 40 novedades por importe; la antigüedad (1053) contaba 31 días y Meta4 34 (22 + 7 + 5).
   Cambio:
     1. Tabla escalonada TAB_DIAS_PILOTAJE (vigencia 1/4/2026): días del estado -> días pagados. TRAMO toma el tramo de mayor Límite Inferior que contiene la base y la base <= 0 da 0.
          1 a 6 -> 5 | 7 a 11 -> 10 | 12 a 16 -> 15 | 17 a 31 -> 30 | más de 31 -> 30 + 5 por día adicional.
        Los cortes son en días de calendario y no en horas (el estado PI no lleva horas): 6 días calendario pueden ser 120 horas o menos, de ahí el 6 -> 5 que confirma Meta4. Si algún día se cargan las horas, se ajustan los tramos.
     2. Concepto informativo DIAS_PILOT_PAGO (orden 26, desde el 1/4/2026): IF(DIAS_PILOTAJE > 0, TRAMO('TAB_DIAS_PILOTAJE', DIAS_PILOTAJE), 0).
     3. En las ocho fórmulas vigentes que usan DIAS_PILOTAJE (1023, 1043, 1053, 2013, 2023, 2033, 2073, 2083) se reemplaza por #DIAS_PILOT_PAGO. Se editan en el lugar: las del 1/4/2026 (la del 2073 es del 1/3) se crearon para abril, que es el primer mes con
        pilotaje y todavía no está aprobado.
     4. Las 40 novedades 1043 de abril (importe de Meta4, fecha 21/4) pasan a Anulada para que rija la fórmula; el precio y el coeficiente ya coincidían con Meta4 (5 x 2 x PRECIO_PUERTO / 30 = 502.069,33 contra 502.070).
   Límite: si el pilotaje cae repartido entre dos liquidaciones de un mismo empleado, cada una pagaría el mínimo por sus días; en abril los dos días PI caen en la regular.
   Rollback: reemplazar #DIAS_PILOT_PAGO por DIAS_PILOTAJE en esas ocho fórmulas, borrar el concepto DIAS_PILOT_PAGO y la tabla TAB_DIAS_PILOTAJE, y volver las 40 novedades a Estado 1 (Motivo No Aplicada trae su número de movimiento).
   Después: reiniciar el servicio y recalcular abril de los 40 empleados con pilotaje. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'DIAS_PILOT_PAGO')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @sysv nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
/* 1. tabla */
INSERT dbo.[ArbuTest$Tabla Escalonada$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Vigencia Desde],[Descripción],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 VALUES (N'TAB_DIAS_PILOTAJE','20260401',N'Días de pilotaje pagados según el tramo del CCT (SOMU art. 43, oficiales art. 29)',NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000');
INSERT dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Vigencia Desde],[No_ Tramo],[Límite Inferior],[Límite Superior],[Monto Fijo],[Porcentaje],[Descripción],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 SELECT N'TAB_DIAS_PILOTAJE','20260401',t.n,t.li,t.ls,t.mf,t.pc,t.ds,NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000'
 FROM (VALUES (1,1,0,5,0,N'1 a 6 días: 5 (hasta 120 horas)'),(2,7,0,10,0,N'7 a 11 días: 10 (hasta 240 horas)'),(3,12,0,15,0,N'12 a 16 días: 15 (hasta 360 horas)'),
              (4,17,0,30,0,N'17 a 31 días: 30 (hasta 720 horas)'),(5,31,0,30,500,N'Más de 31: 30 más 5 por día adicional (quíntuplo del valor diario)')) t(n,li,ls,mf,pc,ds);
SELECT COUNT(*) AS Tramos_esperado_5 FROM dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'TAB_DIAS_PILOTAJE';
/* 2. concepto informativo, molde 5802 */
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Código',N'Vigencia Desde',N'Descripción',N'Fórmula',N'Condición',N'Orden Cálculo',N'Nombre Impresión'));
SET @sql = N'INSERT ' + @C + N' ([Código],[Vigencia Desde],[Descripción],[Fórmula],[Condición],[Orden Cálculo],[Nombre Impresión],' + @cc + @sysc + N')
  SELECT N''DIAS_PILOT_PAGO'',''20260401'',N''Días de pilotaje pagados (tramo del CCT)'',N''IF(DIAS_PILOTAJE > 0, TRAMO(''''TAB_DIAS_PILOTAJE'''', DIAS_PILOTAJE), 0)'',N'''',26,N'''',' + @cc + @sysv
  + N' FROM ' + @C + N' WHERE [Código]=N''5802'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Concepto_esperado_1;
/* 3. fórmulas */
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=REPLACE([Fórmula],N'DIAS_PILOTAJE',N'#DIAS_PILOT_PAGO'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código] IN (N'1023',N'1043',N'1053',N'2013',N'2023',N'2033',N'2073',N'2083') AND [Vigencia Hasta]='17530101' AND [Fórmula] LIKE N'%DIAS_PILOTAJE%' AND [Fórmula] NOT LIKE N'%#DIAS_PILOT_PAGO%';
SELECT @@ROWCOUNT AS Formulas_esperado_8;
/* 4. novedades 1043 */
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=2, [No_ Liquidación]='', [Motivo No Aplicada]=LEFT(N'Anulada: rige la fórmula (días pagados del CCT). Era el importe de Meta4 del 21/4. Mov. ' + CAST([No_ Movimiento] AS nvarchar(20)),250), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Cód_ Concepto]=N'1043' AND [Cód_ Período]='202604' AND Estado=1 AND Fecha='20260421' AND [Cód_ Tipo Liq_]=N'REGULAR';
SELECT @@ROWCOUNT AS Novedades_esperado_29_regulares;
/* 4b. las 11 de empleados con liquidación final (tipo LIQ_FINAL, mismo día): se anularon en una segunda pasada con la misma condición salvo el tipo */
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=2, [No_ Liquidación]='', [Motivo No Aplicada]=LEFT(N'Anulada: rige la fórmula (días pagados del CCT). Era el importe de Meta4 del 21/4. Mov. ' + CAST([No_ Movimiento] AS nvarchar(20)),250), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Cód_ Concepto]=N'1043' AND [Cód_ Período]='202604' AND Estado=1 AND Fecha='20260421' AND [Cód_ Tipo Liq_]=N'LIQ_FINAL';
SELECT @@ROWCOUNT AS Novedades_esperado_11_finales;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'#DIAS_PILOT_PAGO','')))/16 nuevas,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_PILOTAJE','')))/13 total FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'1023',N'1043',N'1053',N'2013',N'2023',N'2033',N'2073',N'2083',N'DIAS_PILOT_PAGO') AND [Vigencia Hasta]='17530101' ORDER BY 1;
COMMIT;
