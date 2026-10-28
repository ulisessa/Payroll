/* SUELDO DE PILOTAJE (1043) SOBRE NAVEGACIÓN, NO SOBRE PUERTO (22/10/2026). Indicación del usuario. En Meta4 el precio del día es COEF_PILOTAJE 4 x sueldo de navegación / 30 (PRECIO_PILOTAJE, concepto 1042);
   en 768/19 OF01 y OF03 es la garantía de navegación del CCT (GARANT_POT_CCT: 6.900 y 5.400 USD) con coeficiente 1. Hasta ahora salía de 2 x PRECIO_PUERTO / 30 (PRECIO_PUERTO = 2 x PRECIO_NAV en 175/75 y
   729/15), que daba lo mismo en los 40 recibos pero por otro camino.
   Cambios: parámetro nuevo COEF_PILOTAJE_NAV (general 4; 768/19 OF01 y OF03: 1, vigencia 1/1/2026) y 1043 = #DIAS_PILOT_PAGO * IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_NAV) / 30 * COEF_PILOTAJE_NAV * #COEF_PESQUERIA
   (en el lugar: la vigencia del 1/4/2026 es de este mes). Se borra el parámetro COEF_PILOTAJE_PUERTO, que queda sin uso (un valor, una fuente).
   Resultado esperado: idéntico al de hoy (el 1043 coincide con Meta4 en los 40). Si algún recibo cambia, el PRECIO_NAV de ese convenio/categoría no es la mitad del de puerto.
   Rollback: volver a la fórmula con PRECIO_PUERTO y COEF_PILOTAJE_PUERTO (scripts/ParametroCoefPilotajePuerto.sql), y borrar COEF_PILOTAJE_NAV.
   Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'COEF_PILOTAJE_NAV')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
/* cabecera: copia de COEF_PILOTAJE_PUERTO con el nombre y los textos nuevos */
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Código',N'Descripción',N'Notas',N'Nombre Variable'));
SET @sql = N'INSERT ' + @P + N' ([Código],[Descripción],[Notas],[Nombre Variable],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT N''COEF_PILOTAJE_NAV'', N''Precio del día de pilotaje sobre el sueldo de navegación'', N''Meta4 1042 (COEF_PILOTAJE): 4 x sueldo de navegación / 30; 768/19 OF01 y OF03 (garantía de navegación en USD): 1. Clave: COEF_PILOTAJE_NAV_[CCT]_[CAT]'', N''COEF_PILOTAJE_NAV'',' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @P + N' WHERE [Código]=N''COEF_PILOTAJE_PUERTO'';';
EXEC sp_executesql @sql;
/* filas vigentes */
INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Parámetro],[Cód_ Parámetro Base],[Vigencia Desde],[Valor],[Moneda],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Descripción],[Notas],[En Uso],[No_ Empleado],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3],
  [$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT x.cod, N'COEF_PILOTAJE_NAV', '20260101', x.val, '', x.cv, x.ct, x.niv, N'Precio del día de pilotaje sobre navegación', N'Meta4 1042: COEF_PILOTAJE 4 sobre el sueldo de navegación / 30', 0, '', '', '', '', '',
  NEWID(),SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000',SYSUTCDATETIME(),'00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'COEF_PILOTAJE_NAV', CAST(4 AS decimal(38,20)), N'', N'', 0),
             (N'COEF_PILOTAJE_NAV_768/19_OF01', CAST(1 AS decimal(38,20)), N'768/19', N'OF01', 2),
             (N'COEF_PILOTAJE_NAV_768/19_OF03', CAST(1 AS decimal(38,20)), N'768/19', N'OF03', 2)) x(cod,val,cv,ct,niv);
/* concepto */
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'#DIAS_PILOT_PAGO * IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_NAV) / 30 * COEF_PILOTAJE_NAV * #COEF_PESQUERIA', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1043' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] LIKE N'%COEF_PILOTAJE_PUERTO%';
SELECT @@ROWCOUNT AS c1043_esperado_1;
/* se retira el parámetro viejo */
DELETE FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_PILOTAJE_PUERTO';
DELETE FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'COEF_PILOTAJE_PUERTO';
SELECT [Cód_ Parámetro] p,[Nivel] n,CAST([Valor] AS decimal(10,2)) v,[Cód_ Convenio] cv,[Cód_ Categoría] ct FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] LIKE N'COEF_PILOTAJE%';
COMMIT;
