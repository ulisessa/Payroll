/* PILOTAJE: EL 2033 ES LA DIFERENCIA ENTRE EL ASEGURADO Y LA LIQUIDACIÓN DE CONVENIO (22/10/2026). Cuando el asegurado supera la liquidación de convenio se paga la diferencia entre uno y otro monto (indicación del usuario).
   Meta4 lo hace de dos maneras, las dos en el 2033 (A_CT_FUT_AUM_PI):
   a) Con NETO garantizado (grossing-up): 04163, 04724, 04826, 04836, 04868 y 04921, que tienen NETO_GU_MAREA (el asegurado del CLC: 15.000, 12.750, 22.000, 16.000, 24.000 y 20.000 USD). El neto de la corrida de pilotaje es
      asegurado x 70 % x TC / 30 x 2 días: 04826, 22.000 x 0,7 x 1.370 / 30 x 2 = 1.406.533 = el neto de su recibo (2.372.310 de haberes - 859.023 de Ganancias - 106.754 de cuota sindical). El 2033 es el complemento que lo lleva ahí.
      Antes yo había anulado el neto garantizado en PILOTAJE (NetoGarantizadoSinPilotaje.sql) porque el complemento caía en 1003/3553/4743, que no corren en el pilotaje, y no convergía; y daba esos seis 2033 por incidencias manuales: era un error.
   b) Sin neto garantizado (03664, 04455): 2033 = garantizado de navegación x TC / 30 x días PI - haberes, mínimo cero (BRUTO_PRORRAT - TOT_HAB_GZDO de Meta4), igual que la rama de la 2003.
   Cambios: (1) NETO_GARANT en PILOTAJE = NETO_GU_MAREA * DIAS_PILOTAJE / 30 * PCT_NETO_GU / 100 (en el lugar: la vigencia del 1/4 es de hoy); (2) 2033 = IF(ES_GROSSING_UP > 0, COMPLEMENTO_GU, <regla b>) (en el lugar);
   (3) 1003, que es comodín y toma COMPLEMENTO_GU, deja de correr en PILOTAJE: se enumeran los tipos existentes menos PILOTAJE (igual que 2013, 2043, etc.); (4) se anulan las novedades 2033 de abril que cargué como importe
   (4302 4878 5128 5179 5333 5445): ya las reproduce el cálculo.
   Rollback: NETO_GARANT con 0 en PILOTAJE; 2033 sin la rama ES_GROSSING_UP; 1003 con "Tipos Liq. Aplicables" en blanco; novedades en Estado 0 con tipo PILOTAJE (o 1 las que estaban aplicadas).
   Después: reiniciar el servicio, recalcular el PILOTAJE de abril de los ocho empleados con 2033 (y, si algo cambia, los 40). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=REPLACE([Fórmula], N'IF(TIPO_LIQ = ''PILOTAJE'', 0,', N'IF(TIPO_LIQ = ''PILOTAJE'', NETO_GU_MAREA * DIAS_PILOTAJE / 30 * PCT_NETO_GU / 100,'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'NETO_GARANT' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] LIKE N'IF(TIPO_LIQ = ''PILOTAJE'', 0,%';
SELECT @@ROWCOUNT AS neto_garant_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'IF(ES_GROSSING_UP > 0, COMPLEMENTO_GU, IF(VALOR_NAV_EMP * DIAS_PILOTAJE = 0, 0, MAX(0, round(VALOR_NAV_EMP / 30 * DIAS_PILOTAJE - (#1043 + #1053 + #1083 + #1603), PRECISION_REDONDEO))))', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'2033' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS c2033_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=N'AGUINALDO|ANTICIPO|CIERRE_MAREA|DEVENGADOS|HIST_REMUN|LIQ_FINAL|REGULAR|RELIQUIDACION|SALDO_INICIAL|VACACIONES', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1003' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101' AND [Tipos Liq_ Aplicables]=N'';
SELECT @@ROWCOUNT AS c1003_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Estado]=2, [No_ Liquidación]='', [Motivo No Aplicada]=N'Anulada: el 2033 lo calcula el motor (neto garantizado o diferencia contra el asegurado), no es una incidencia manual.', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (4302,4878,5128,5179,5333,5445) AND [Cód_ Concepto]='2033' AND [Estado]<>2;
SELECT @@ROWCOUNT AS novedades_esperado_6;
COMMIT;
