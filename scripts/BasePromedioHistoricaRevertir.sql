/* BASE_PROMEDIO HISTÓRICA: REVERTIR LA CORRECCIÓN DE scripts/BasePromedioHistoricaComoMeta4.sql Y DEJAR SÓLO LO QUE NECESITAN LAS VACACIONES DE MARZO.
   Al medir con la regla operativa de Meta4 apareció lo que el script anterior no vio: la historia de BC coincide con Meta4 en la suma de TOT_PROMEDIOS de las corridas con TOT_REM_IMP <> 0 (las de
   tipo de imputación 14 —liquidaciones finales de una fase anterior— tienen TOT_REM_IMP = 0 y quedan afuera). Meta4 no es consistente en el tiempo: las vacaciones de enero y febrero de 00191,
   00965, 02745, 03090 y 03207 y las finales de 04047 y 04573 coinciden con BC con la historia ORIGINAL, y las de marzo de 02737 incluyen esas corridas. Corregir la historia "al literal" rompe
   las de enero y febrero. Se vuelven los 17 valores del script anterior y el de 04706 (octubre) a su valor original (respaldo exacto, con sus decimales).
   Quedan corregidas sólo 01937, 02854, 03660, 04207 y 02737 (octubre de 2025), que son las que necesitan las vacaciones de marzo.
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @r TABLE (liq nvarchar(20), ln int, emp nvarchar(20), nuevo decimal(38,20));
INSERT @r VALUES
  (N'LIQ-00012638',1404018,N'03090',10473907.36680000000000000000),
  (N'LIQ-00012687',1404624,N'03986',4555834.07000000000000000000),
  (N'LIQ-00012761',1405339,N'04573',5026633.63020000000000000000),
  (N'LIQ-00012964',1402868,N'00965',14626590.09660000000000000000),
  (N'LIQ-00013028',1403701,N'02745',9834524.35810000000000000000),
  (N'LIQ-00013051',1404019,N'03090',720025.37090000000000000000),
  (N'LIQ-00013145',1405125,N'04393',106849.52920000000000000000),
  (N'LIQ-00013179',1405502,N'04700',10871270.13930000000000000000),
  (N'LIQ-00013307',1402639,N'00191',2662286.39920000000000000000),
  (N'LIQ-00013326',1402869,N'00965',1254410.15710000000000000000),
  (N'LIQ-00013382',1403588,N'02670',3969293.54230000000000000000),
  (N'LIQ-00013390',1403702,N'02745',908733.58500000000000000000),
  (N'LIQ-00013418',1404086,N'03207',3864249.71300000000000000000),
  (N'LIQ-00013468',1404681,N'04047',4143670.41650000000000000000),
  (N'LIQ-00013486',1404895,N'04216',4013732.20750000000000000000),
  (N'LIQ-00013504',1405126,N'04393',1562674.37000000000000000000),
  (N'LIQ-00013523',1405341,N'04573',2216347.49000000000000000000),
  (N'LIQ-00013537',1405517,N'04706',643126.97080000000000000000);
UPDATE l SET l.Importe = r.nuevo, l.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @r r ON r.liq = l.[No_ Liquidación] AND r.ln = l.[No_ Línea] AND r.emp = l.[No_ Empleado]
WHERE l.[Cód_ Concepto]='BASE_PROMEDIO' AND l.[Cód_ Tipo Liq_]='HIST_REMUN';
SELECT @@ROWCOUNT AS Lineas_revertidas_esperado_18;
COMMIT;
