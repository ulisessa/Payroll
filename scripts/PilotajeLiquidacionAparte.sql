/* PILOTAJE COMO LIQUIDACIÓN APARTE, IGUAL QUE UNA MAREA. Decisión del usuario (22/10/2026); es un PARALELO: se reproduce la corrida de pilotaje de Meta4 (TP_IMPUT 12, 21/4/2026).
   El pilotaje tiene su proyecto (fecha y hora de zarpada y de arribo) y su tipo de liquidación PILOTAJE (proyectos Improductivos, disparador Arribo, tripulantes). La duración sale de las horas del proyecto (variable de sistema
   HORAS_PROYECTO, código en Cod50016) y los días que se pagan son los del tramo del CCT: SOMU art. 43 y oficiales art. 29 (hasta 120 h: 5 días; 240: 10; 360: 15; 720: 30; más, 5 días por cada 24 h).
   Corrida de Meta4 (40 recibos): sueldo de pilotaje (1043) = 5 x precio de pilotaje, sueldo de puerto (1083) 1 día (el arribo AM del pilotaje), antigüedad (1053) con 5 + 1 días, categoría superior (1603, 10), a cuenta de futuros aumentos de
   pilotaje (2033, 7), redondeo, aportes (6000/6010/6030 en los 28 de marinería), Ganancias (5010), cuota sindical (8522) y las contribuciones patronales. Sin navegación (1013), feriado, dique ni francos.
   Cambios:
     1. Los tres proyectos de pilotaje (PN-128-260424, PN-801-260423, PN-802-260423) estaban como Productivo (1): pasan a Improductivo (2). Productivo los habría tomado también el CIERRE_MAREA (mismo disparador); el tipo PILOTAJE filtra Improductivo.
     2. Tipo PILOTAJE: "Entra en la corrida sin tipo" = No (no es mensual; se pide a mano). Sigue con "Sólo conceptos declarados" = No: los conceptos sin tipos declarados corren y se ajusta mirando el cálculo.
     3. Tabla TAB_HORAS_PILOTAJE (vigencia 1/4/2026): base en horas; el "hasta 120 h" del convenio incluye el 120, por eso el siguiente tramo arranca en 120,0001 (TRAMO, en el borde exacto, toma el tramo siguiente).
          0,0001 -> 5 | 120,0001 -> 10 | 240,0001 -> 15 | 360,0001 -> 30 | 720,0001 -> 30 + 20,8333 % por hora (5 días por 24 h).
        Se borra TAB_DIAS_PILOTAJE (la tabla en días del 21/10, que no tenía horas).
     4. DIAS_PILOT_PAGO (concepto informativo) pasa a TRAMO('TAB_HORAS_PILOTAJE', HORAS_PROYECTO) y sólo aplica a PILOTAJE: en las demás liquidaciones vale 0 y la antigüedad, el 2013, el 2083, etc. dejan de contar días de pilotaje en la marea.
        (Su "Tipos Liq. Aplicables" se había copiado del molde 5802 por error.)
     5. Conceptos que declaran tipos y ahora también corren en PILOTAJE: 1043 (sólo PILOTAJE), 1083, 1603, 4750, 5010, 5498, 8522, 8542, 8543, 8553, 8593, 6000, 6010, 6030, 6032, 4751-4757, 5397, 7000, 7010, 7030, 7050, 7053, 7055, 7060, 7070,
        y los auxiliares del cálculo de aportes y Ganancias (5800-5831, CNT_*, DEDUC_GANANCIAS, GASTOS_IG4_BASE, PCT_ANTIG_*, SAC_DEV_YTD_BASE, YTD_SAC_DEV, 3610). No se agrega: 1023, 1033, 1062, 3553, 3573, 4743, 3554, 8893, 6003, 6013,
        6035, 7080, 7090, 7091, VAC_DEVENG ni los de marea (1013, 2003, producción).
     6. Se revierte la baja ampliada de las 40 asignaciones a la marea (24/4 -> 23/4): el día de puerto extra era el arribo del pilotaje, que ahora paga la liquidación de pilotaje. El código de 1.0.0.680 (puerto posterior en la asignación) queda,
        pero sin baja posterior al arribo no suma nada.
   Rollback: los tres proyectos a Tipo 1; el tipo PILOTAJE "Entra en la corrida sin tipo" = Sí; borrar TAB_HORAS_PILOTAJE; DIAS_PILOT_PAGO y las fórmulas, como en PilotajeDiasPagadosCCT.sql; quitar "|PILOTAJE" de los tipos aplicables
   (la 1043 vuelve a CIERRE_MAREA|DEVENGADOS|REGULAR|LIQ_FINAL); baja de las 40 asignaciones a 24/4.
   Requiere publicar 1.0.0.681 (variable HORAS_PROYECTO) y reiniciar el servicio antes de calcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Tabla Escalonada$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'TAB_HORAS_PILOTAJE')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
/* 1. proyectos */
UPDATE x SET x.[Tipo$a423950b-02e9-4ee0-ab32-61517ce330cb]=2
FROM dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] x WHERE x.[No_] IN ('PN-128-260424','PN-801-260423','PN-802-260423') AND x.[Tipo$a423950b-02e9-4ee0-ab32-61517ce330cb]=1;
SELECT @@ROWCOUNT AS Proyectos_esperado_3;
/* 2. tipo */
UPDATE dbo.[ArbuTest$Tipo Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Entra en Corrida Completa]=0, [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'PILOTAJE';
SELECT @@ROWCOUNT AS Tipo_esperado_1;
/* 3. tabla en horas */
DELETE FROM dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'TAB_DIAS_PILOTAJE';
DELETE FROM dbo.[ArbuTest$Tabla Escalonada$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'TAB_DIAS_PILOTAJE';
INSERT dbo.[ArbuTest$Tabla Escalonada$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Vigencia Desde],[Descripción],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 VALUES (N'TAB_HORAS_PILOTAJE','20260401',N'Días de pilotaje pagados según las horas del proyecto (CCT SOMU art. 43, oficiales art. 29)',NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000');
INSERT dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Vigencia Desde],[No_ Tramo],[Límite Inferior],[Límite Superior],[Monto Fijo],[Porcentaje],[Descripción],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 SELECT N'TAB_HORAS_PILOTAJE','20260401',t.n,t.li,0,t.mf,t.pc,t.ds,NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000'
 FROM (VALUES (1,0.0001,5,0,N'Hasta 120 horas: 5 días'),(2,120.0001,10,0,N'Más de 120 y hasta 240 horas: 10 días'),(3,240.0001,15,0,N'Más de 240 y hasta 360 horas: 15 días'),
              (4,360.0001,30,0,N'Más de 360 y hasta 720 horas: 30 días'),(5,720.0001,30,20.8333,N'Más de 720 horas: 30 días y 5 por cada 24 horas adicionales')) t(n,li,mf,pc,ds);
SELECT COUNT(*) AS Tramos_esperado_5 FROM dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'TAB_HORAS_PILOTAJE';
/* 4. días pagados */
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'TRAMO(''TAB_HORAS_PILOTAJE'', HORAS_PROYECTO)', [Tipos Liq_ Aplicables]=N'PILOTAJE', [Descripción]=N'Días de pilotaje pagados (tramo de horas del CCT)', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'DIAS_PILOT_PAGO' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS DiasPagados_esperado_1;
/* 5. tipos aplicables */
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=N'PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'1043' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS C1043_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=[Tipos Liq_ Aplicables]+N'|PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Vigencia Hasta]='17530101' AND [Tipos Liq_ Aplicables]<>N'' AND [Tipos Liq_ Aplicables] NOT LIKE N'%PILOTAJE%'
   AND [Código] IN (N'1083',N'1603',N'4750',N'5010',N'5498',N'8522',N'8542',N'8543',N'8553',N'8593',N'6000',N'6010',N'6030',N'6032',N'4751',N'4752',N'4753',N'4754',N'4755',N'4756',N'4757',N'5397',
                    N'7000',N'7010',N'7030',N'7050',N'7053',N'7055',N'7060',N'7070',N'3610',N'5800',N'5802',N'5803',N'5804',N'5811',N'5821',N'5831',N'CNT_APLICA',N'CNT_BASE_PRUEBA',N'CNT_FRAC_SAC',N'CNT_RED_SUELDO',N'CNT_SALDO',
                    N'DEDUC_GANANCIAS',N'GASTOS_IG4_BASE',N'PCT_ANTIG_OFICIALES',N'PCT_ANTIG_SOMU',N'SAC_DEV_YTD_BASE',N'YTD_SAC_DEV');
SELECT @@ROWCOUNT AS Conceptos_con_PILOTAJE_agregado;
/* 6. baja de las asignaciones a la marea */
UPDATE p SET p.[Fecha Baja]='20260423', p.[$systemModifiedAt]=SYSUTCDATETIME()
FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p
WHERE p.[No_ Empleado] IN ('01477','02452','03062','03487','03664','03777','04066','04105','04163','04450','04455','04518','04526','04586','04591','04659','04677','04714','04724','04738','04791','04822','04825','04826','04836','04838','04839','04840','04841','04848','04868','04906','04913','04914','04915','04919','04921','04923','04924','04932')
  AND p.[No_ Proyecto] LIKE 'PP-%' AND p.[Fecha Baja]='20260424';
SELECT @@ROWCOUNT AS Bajas_esperado_40;
COMMIT;
