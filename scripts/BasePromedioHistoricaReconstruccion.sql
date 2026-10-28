/* BASE_PROMEDIO DE LA HISTORIA (HIST_REMUN) DE JULIO A DICIEMBRE DE 2025: RECONSTRUIDA DESDE META4 CON LA REGLA DE LA FASE VIGENTE.
   Regla (usuario, 20/10/2026): los promedios se calculan SIEMPRE sobre la fase de alta actual, con todas las remuneraciones devengadas desde la última fecha de ingreso.
   Auditoría: la historia migrada era inconsistente. Corridas con TOT_REM_IMP = 0 y promedio > 0: 124 empleado-mes entre 1/2024 y 1/2026; BC dejó afuera 72 (172,6 M) y las incluyó en 50 (2024: todas afuera;
   enero a julio de 2025: todas incluidas; agosto a diciembre de 2025: mezcladas). Y en 10 meses el mes del alta suma dos fases en la misma línea.
   Cambio: para cada empleado y mes de julio a diciembre de 2025 que no sea un mes entero anterior al alta vigente, BASE_PROMEDIO (la única línea HIST_REMUN) = suma de TOT_PROMEDIOS de Meta4 de las corridas
   de la fase vigente (fec_alta_empleado = última alta), todas las corridas. Se corrigen 27 líneas: 17 con corridas omitidas y 10 con fase anterior en el mismo mes.
   No se tocan: los meses enteros anteriores al alta vigente (la ventana ya los corta), las 13 líneas donde BC es MAYOR que Meta4 (los 90xxx de noviembre y 90455/90456 de diciembre) ni 2024.
   Respaldo exacto de las líneas: scratchpad de la sesión (backup_base_promedio_jul_dic2025_reconstruccion.psv).
   Rollback: volver Importe de esas líneas a los valores del respaldo.
   Efecto: seis liquidaciones de enero y febrero que coincidían con Meta4 con la historia anterior (vacaciones de 00191, 00965, 02745, 03090 y 03207 y la final de 04047) cambian si se recalculan: se cubren con novedades.
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @r TABLE (liq nvarchar(20), ln int, emp nvarchar(20), per nvarchar(10), nuevo decimal(18,2), motivo nvarchar(60));
INSERT @r VALUES
  (N'LIQ-00012638',1404018,N'03090',N'202508',11227488.53,N'corrida omitida'),
  (N'LIQ-00012687',1404624,N'03986',N'202508',8299864.19,N'corrida omitida'),
  (N'LIQ-00012755',1405285,N'04524',N'202508',1243771.17,N'fase anterior en el mismo mes'),
  (N'LIQ-00012758',1405319,N'04546',N'202508',365280.91,N'fase anterior en el mismo mes'),
  (N'LIQ-00012761',1405339,N'04573',N'202508',6646208.64,N'corrida omitida'),
  (N'LIQ-00012821',1405907,N'04818',N'202508',1219383.48,N'fase anterior en el mismo mes'),
  (N'LIQ-00012832',1406006,N'04831',N'202508',1414644.23,N'fase anterior en el mismo mes'),
  (N'LIQ-00012833',1406015,N'04832',N'202508',1219383.48,N'fase anterior en el mismo mes'),
  (N'LIQ-00012856',1406246,N'04861',N'202508',1414644.23,N'fase anterior en el mismo mes'),
  (N'LIQ-00012964',1402868,N'00965',N'202509',15200937.46,N'corrida omitida'),
  (N'LIQ-00013028',1403701,N'02745',N'202509',10578165.48,N'corrida omitida'),
  (N'LIQ-00013051',1404019,N'03090',N'202509',2059725.21,N'corrida omitida'),
  (N'LIQ-00013179',1405502,N'04700',N'202509',13659313.93,N'corrida omitida'),
  (N'LIQ-00013236',1406391,N'04894',N'202509',279292.29,N'fase anterior en el mismo mes'),
  (N'LIQ-00013307',1402639,N'00191',N'202510',5591140.20,N'corrida omitida'),
  (N'LIQ-00013326',1402869,N'00965',N'202510',1900550.94,N'corrida omitida'),
  (N'LIQ-00013382',1403588,N'02670',N'202510',7584825.39,N'corrida omitida'),
  (N'LIQ-00013390',1403702,N'02745',N'202510',2210105.55,N'corrida omitida'),
  (N'LIQ-00013418',1404086,N'03207',N'202510',5443762.61,N'corrida omitida'),
  (N'LIQ-00013468',1404681,N'04047',N'202510',11713405.70,N'corrida omitida'),
  (N'LIQ-00013486',1404895,N'04216',N'202510',5889806.41,N'corrida omitida'),
  (N'LIQ-00013523',1405341,N'04573',N'202510',2472069.86,N'corrida omitida'),
  (N'LIQ-00013537',1405517,N'04706',N'202510',1737823.61,N'corrida omitida'),
  (N'LIQ-00014097',1403590,N'02670',N'202512',4738597.37,N'corrida omitida'),
  (N'LIQ-00014249',1405974,N'04826',N'202512',922157.33,N'fase anterior en el mismo mes'),
  (N'LIQ-00014251',1406028,N'04833',N'202512',291724.04,N'fase anterior en el mismo mes'),
  (N'LIQ-00014276',1406457,N'04921',N'202512',862152.97,N'fase anterior en el mismo mes');
UPDATE l SET l.Importe = r.nuevo, l.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @r r ON r.liq = l.[No_ Liquidación] AND r.ln = l.[No_ Línea] AND r.emp = l.[No_ Empleado] AND r.per = l.[Cód_ Período]
WHERE l.[Cód_ Concepto]='BASE_PROMEDIO' AND l.[Cód_ Tipo Liq_]='HIST_REMUN';
SELECT @@ROWCOUNT AS Lineas_esperado_27;
COMMIT;
