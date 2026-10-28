/* ESTADOS DE TIERRA DE A19 COLGADOS DE LA MAREA (22/10/2026). 02297 y 02804 no tenían ninguna liquidación de abril en BC mientras Meta4 les pagó la corrida mensual (02297: 22 días de franco, 1.413.829; 02804: 180.745).
   Sus estados AU9 (enfermedad), FR (franco), OR (órdenes) y AU1 estaban en PP-119-000307 (marea 307 de A19, ya cerrada), no en PN-119-NOMINA: la regular mira los estados sin proyecto o improductivos y uno cuyo
   proyecto es de marea productiva no cuenta, así que no los ve y no crea la liquidación. Es el mismo defecto que MoverEstadosDeTierraANomina.sql corrigió para GP, DQ y PI: la migración puso proyecto de marea a los
   estados que no devengan francos pero esos dos quedaron colgados. Son los únicos tres empleados de toda la base con FR/OR/OI/AU* en un proyecto PP- (el tercero, 04220, en junio).
   Cambio: No. Proyecto = PN-119-NOMINA en AU*, FR y OR de 02297, 02804 y 04220 que están en PP-119-%. Rollback: devolver PP-119-000307 (02297 y 02804) y PP-119-000309 (04220).
   Después: reiniciar el servicio y crear/calcular la REGULAR de abril de 02297 y 02804. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [No_]='PN-119-NOMINA') BEGIN PRINT 'No existe PN-119-NOMINA'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [No_ Proyecto]='PN-119-NOMINA', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Tipo Entidad]=0 AND [No_ Empleado] IN ('02297','02804','04220') AND [No_ Proyecto] LIKE 'PP-119-%' AND ([Cód_ Estado] IN ('FR','OR','OI') OR [Cód_ Estado] LIKE 'AU%');
SELECT @@ROWCOUNT AS esperado_9;
SELECT [No_ Empleado] e,[Cód_ Estado] est,[No_ Proyecto] pr,CONVERT(varchar(10),[Fecha Inicio],120) i FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] IN ('02297','02804') AND [Fecha Inicio]>='20260301' ORDER BY 1,4;
COMMIT;
