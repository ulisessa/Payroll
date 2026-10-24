/* COEF_PILOTAJE_PUERTO (filas vigentes). Complemento de scripts/ConceptosPilotajeYDique.sql: la cabecera del parámetro se dio de alta ahí, pero el alta de las tres filas vigentes salió vacía
   (la lista de columnas restantes de la tabla es nula y anulaba la sentencia). General 2; 768/19 OF01 y OF03: 1. Vigencia 1/1/2026.
   Rollback: borrar las filas vigentes con Cód. Parámetro Base COEF_PILOTAJE_PUERTO. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_PILOTAJE_PUERTO')
BEGIN PRINT 'Ya existen las filas'; ROLLBACK; RETURN; END;
INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Parámetro],[Cód_ Parámetro Base],[Vigencia Desde],[Valor],[Moneda],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Descripción],[Notas],[En Uso],[No_ Empleado],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3],
  [$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT x.cod, N'COEF_PILOTAJE_PUERTO', '20260101', x.val, '', x.cv, x.ct, x.niv, N'Precio del día de pilotaje sobre PRECIO_PUERTO', N'Medido en Meta4 (corrida del 21/4/2026)', 0, '', '', '', '', '',
  NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'COEF_PILOTAJE_PUERTO', CAST(2 AS decimal(38,20)), N'', N'', 0),
             (N'COEF_PILOTAJE_PUERTO_768/19_OF01', CAST(1 AS decimal(38,20)), N'768/19', N'OF01', 2),
             (N'COEF_PILOTAJE_PUERTO_768/19_OF03', CAST(1 AS decimal(38,20)), N'768/19', N'OF03', 2)) x(cod,val,cv,ct,niv);
SELECT [Cód_ Parámetro] p, [Nivel] n, CAST([Valor] AS decimal(10,2)) v, [Cód_ Convenio] cv, [Cód_ Categoría] ct FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_PILOTAJE_PUERTO';
COMMIT;
