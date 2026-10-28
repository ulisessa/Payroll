/* ANULADO (20/10/2026): ver scripts/BasePromedioHistoricaRevertir.sql, que lo revierte. Corregir la historia al TOT_PROMEDIOS literal de Meta4 rompe las vacaciones de enero y febrero que ya coincidían: Meta4 excluye en esos casos las corridas de tipo 14 sin base fiscal. */
/* BASE_PROMEDIO DE LA HISTORIA (HIST_REMUN) DE AGOSTO A DICIEMBRE DE 2025: IGUALAR AL TOT_PROMEDIOS DE META4.
   Seguimiento de scripts/VacacionesMarzoComoMeta4.sql (punto A). Se comparó mes por mes, para todos los empleados y desde 1/2024 hasta 6/2026, la suma de BASE_PROMEDIO de BC contra la de
   TOT_PROMEDIOS de Meta4 (M4_ACUMULADO_RL, tipos de imputación 1,3,10,11,12,13,14,15, por fecha de imputación):
     - 2025-01 a 2025-07: coinciden en todos los empleados.
     - 2025-08 a 2025-12: BC por DEBAJO de Meta4 en 19 empleado-mes (6 de octubre ya corregidos en el script anterior).
     - 2025-11 y 2025-12: 14 empleado-mes con BC por ENCIMA de Meta4 (los 90xxx y 90455/90456): no se tocan, van aparte.
     - 2024: no coincide en cientos de empleados (la historia de 2024 no entra en ninguna ventana de 2026 y se deja para otro análisis).
     - 2026-04 a 2026-06: Meta4 tiene datos y BC todavía no liquidó esos meses: nada que corregir en la historia.
   Las 17 líneas de este script tienen el mismo patrón que las de octubre del script anterior: el HIST_REMUN_BRUTO de BC coincide con el TOT_PROMEDIOS de Meta4 al centavo y el BASE_PROMEDIO quedó
   por debajo (la importación histórica dejó afuera parte del mes). Se pone BASE_PROMEDIO = TOT_PROMEDIOS del mes en la única línea BASE_PROMEDIO de HIST_REMUN de cada empleado y período.
   NO se tocan dos casos: 04751 (septiembre) —se dejó a propósito con sólo la fase vigente, ver BasePromedioSep2025_04751.sql— y 02670 (diciembre) —el bruto de BC (7.255.200) tampoco coincide con Meta4
   (4.738.597): es otro problema—.
   Respaldo: las 17 líneas exportadas antes de correr (scratchpad de la sesión, backup_base_promedio_ago_dic2025.psv).
   Rollback: volver Importe de esas líneas a los valores del respaldo.
   Después: reiniciar el servicio y recalcular lo de 2026 que lea ese promedio (vacaciones, finales con vacaciones no gozadas, SAC de egreso) de los empleados de la lista. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @a TABLE (emp nvarchar(20), per nvarchar(10), nuevo decimal(18,2));
INSERT @a VALUES (N'03090',N'202508',11227488.53),(N'03986',N'202508',8299864.19),(N'04573',N'202508',6646208.64),(N'00965',N'202509',15200937.46),(N'02745',N'202509',10578165.48),(N'03090',N'202509',2059725.21),(N'04393',N'202509',511987.34),(N'04700',N'202509',13659313.93),(N'00191',N'202510',5591140.20),(N'00965',N'202510',1900550.94),(N'02670',N'202510',7584825.39),(N'02745',N'202510',2210105.55),(N'03207',N'202510',5443762.61),(N'04047',N'202510',11713405.70),(N'04216',N'202510',5889806.41),(N'04393',N'202510',1736304.86),(N'04573',N'202510',2472069.86);
UPDATE l SET l.Importe = a.nuevo, l.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @a a ON a.emp = l.[No_ Empleado] AND a.per = l.[Cód_ Período]
WHERE l.[Cód_ Tipo Liq_]='HIST_REMUN' AND l.[Cód_ Concepto]='BASE_PROMEDIO' AND l.Importe < a.nuevo;
SELECT @@ROWCOUNT AS Lineas_esperado_17;
COMMIT;
