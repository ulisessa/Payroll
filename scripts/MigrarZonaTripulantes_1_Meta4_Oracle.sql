/*
    PASO 1 de 2 — se ejecuta en la conexión **Meta4** (Oracle).

    La zona DGI de cada liquidación de tripulantes de 2026 (ID_ZONA_DGI de M4T_ACUMULADO_RL2), con su
    fecha de imputación, para cargarla en el atributo ZONA_DESFAVORABLE (COD_ZONA) de BC. Es la zona
    con la que Meta4 calculaba el crédito fiscal IVA de las contribuciones (Dto. 814/01,
    CREDITO_IVA_ST = (5811 + 5821 + 5831) * ALI_CRED_IVA_ST / 100).

    POR QUÉ DE LA LIQUIDACIÓN Y NO DE UNA TABLA DE ZONAS. Meta4 la deriva en cada liquidación
    (ID_ZONA_DGI, concepto 231): para un embarcado es la zona del centro de trabajo en el que más
    permaneció (MP→07, PM/CR→29, PD→69), y cambia cuando el tripulante pasa de un buque de Mar del
    Plata a uno de Madryn. En 2026, 19 de los 336 cambian. No hay historial de zonas por empleado
    que copiar: el historial ES la secuencia de liquidaciones.

    Tripulantes = convenio MR, OF o FE. Coinciden uno a uno con TIPOEMPLEADO = TRIPUL de BC.
    Se excluyen los anticipos (TP_IMPUT 4) y las filas sin zona.

    Salida: cargarla tal cual en dbo.MIG_ZonaTripulantesM4 de la base de BC (Emp, Fecha, TpImput,
    Zona, Convenio) y seguir con MigrarZonaTripulantes_2_BC_SqlServer.sql.
*/
SELECT c.ID_EMPLEADO      AS EMP,
       c.FEC_IMPUTACION   AS FECHA,
       c.TP_IMPUT         AS TP_IMPUT,
       c.ID_ZONA_DGI      AS ZONA,
       a.ID_CONVENIO      AS CONVENIO
FROM ARBPRO.M4T_ACUMULADO_RL2 c
JOIN ARBPRO.M4T_ACUMULADO_RL a
  ON a.ID_SOCIEDAD = c.ID_SOCIEDAD AND a.ID_EMPLEADO = c.ID_EMPLEADO AND a.FEC_IMPUTACION = c.FEC_IMPUTACION
 AND a.FEC_ALTA_EMPLEADO = c.FEC_ALTA_EMPLEADO AND a.FEC_PAGO = c.FEC_PAGO AND a.TP_IMPUT = c.TP_IMPUT AND a.TP_PAGO = c.TP_PAGO
WHERE c.FEC_IMPUTACION >= DATE '2026-01-01'
  AND c.TP_IMPUT <> 4
  AND c.ID_ZONA_DGI IS NOT NULL
  AND a.ID_CONVENIO IN ('MR', 'OF', 'FE')
ORDER BY c.ID_EMPLEADO, c.FEC_IMPUTACION, c.TP_IMPUT
