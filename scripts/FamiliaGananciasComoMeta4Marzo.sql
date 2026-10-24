/* FICHA DE FAMILIA PARA GANANCIAS DE MARZO DE 2026: DEJARLA COMO LA TENÍA META4 CUANDO LIQUIDÓ (OPCIÓN B, DECIDIDA POR EL USUARIO EL 20/10/2026).
   Meta4 liquidó marzo con la ficha de familia de ese momento y la corrigió en abril con altas y bajas retroactivas (FEC_ULT_ACTUALIZACION entre el 16 y el 30/4). BC tiene la ficha ya corregida y deduce de más o de menos
   en enero a marzo. Las diferencias de descuentos de marzo (todas de Ganancias) de estos seis legajos son exactamente la deducción por 13/12 (p. ej. 90251: 404.330 x 3 x 13/12 = 1.314.074).
   Se cambian, en la ficha (Employee Relative, campos Fecha alta/baja impuesto 50008/50009 y tipo de deducción):
     90251  cónyuge 26000179 (1977-06-02):     baja impuesto 2026-02-28  -> 2026-03-31   (Meta4 lo deduce 3 meses; en abril dejó de deducirlo)
     04874  cónyuge 46103770 (2004-11-02):     alta impuesto 2026-01-01  -> 2026-04-01   (Meta4 no lo deducía en marzo)
     04874  hijo 70765732 (2025-08-03):         alta impuesto 2026-01-01  -> 2026-04-01
     04877  cónyuge 27483184 (1979-07-21):     alta impuesto 2026-01-01  -> 2026-04-01
     04843  cónyuge 43251485 (2001-03-08):     alta impuesto 2025-01-01  -> 2026-04-01
     04313  hijo 70529870 (2025-01-12):        alta impuesto 2025-01-12  -> 2026-04-01   (Meta4 deducía 2 hijos y BC 3)
     04809  pareja 42097766 (2000-01-30):       tipo de deducción (vacío) -> CONYUGE y baja impuesto 2024-12-31 -> 2026-03-31 (Meta4 la deduce 3 meses aunque su baja es de 2024)
   No se pueden reproducir con fechas: 00794, 04169 y 03664, donde Meta4 deduce a un hijo que cumple 18 en enero o febrero sólo los meses que corresponden (acumulado por mes), y BC multiplica la deducción del mes por los meses del año.
   REVERTIR EN ABRIL: son valores para igualar el paralelo de marzo, no los reales. Los valores originales están arriba (la columna "->" de la izquierda).
   Rollback: devolver cada campo al valor original indicado. Después: reiniciar el servicio y recalcular marzo (y enero y febrero si se quiere ver el efecto) de los siete legajos. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @E nvarchar(300) = N'dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972$ext]';
DECLARE @R nvarchar(300) = N'dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972]';
DECLARE @cambios TABLE (emp nvarchar(20), nac date, doc nvarchar(30), alta date, baja date, tipo nvarchar(20));
INSERT @cambios (emp,nac,doc,alta,baja,tipo) VALUES
 (N'90251','19770602',N'26000179',NULL,'20260331',NULL),
 (N'04874','20041102',N'46103770','20260401',NULL,NULL),
 (N'04874','20250803',N'70765732','20260401',NULL,NULL),
 (N'04877','19790721',N'27483184','20260401',NULL,NULL),
 (N'04843','20010308',N'43251485','20260401',NULL,NULL),
 (N'04313','20250112',N'70529870','20260401',NULL,NULL),
 (N'04809','20000130',N'42097766',NULL,'20260331',N'CONYUGE');
DECLARE @n int;
SELECT @n=COUNT(*) FROM dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] e JOIN dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972] r ON r.[Employee No_]=e.[Employee No_] AND r.[Line No_]=e.[Line No_]
 JOIN @cambios c ON c.emp=r.[Employee No_] AND c.nac=CAST(r.[Birth Date] AS date) AND c.doc=e.[Nro_ Documento$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
SELECT @n AS Filas_encontradas_esperado_7;
IF @n<>7 BEGIN PRINT 'No se encontraron las 7 filas; no se cambia nada'; ROLLBACK; RETURN; END;
UPDATE e SET
  [Fecha alta impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb] = ISNULL(c.alta, e.[Fecha alta impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb]),
  [Fecha baja impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb] = ISNULL(c.baja, e.[Fecha baja impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb]),
  [Cód_ Tipo Ded_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = ISNULL(c.tipo, e.[Cód_ Tipo Ded_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890])
FROM dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] e
JOIN dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972] r ON r.[Employee No_]=e.[Employee No_] AND r.[Line No_]=e.[Line No_]
JOIN @cambios c ON c.emp=r.[Employee No_] AND c.nac=CAST(r.[Birth Date] AS date) AND c.doc=e.[Nro_ Documento$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
SELECT @@ROWCOUNT AS Actualizadas_esperado_7;
SELECT e.[Employee No_] emp, e.[Cód_ Tipo Ded_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] tipo, CONVERT(varchar(10),r.[Birth Date],120) nac, CONVERT(varchar(10),e.[Fecha alta impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb],120) alta, CONVERT(varchar(10),e.[Fecha baja impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb],120) baja
FROM dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] e JOIN dbo.[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972] r ON r.[Employee No_]=e.[Employee No_] AND r.[Line No_]=e.[Line No_]
JOIN @cambios c ON c.emp=r.[Employee No_] AND c.nac=CAST(r.[Birth Date] AS date) AND c.doc=e.[Nro_ Documento$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ORDER BY 1,3;
COMMIT;
