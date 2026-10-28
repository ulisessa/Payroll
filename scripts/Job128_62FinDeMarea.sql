/* FIN DE LA MAREA A28/62: 23/4 Y NO 22/4 (22/10/2026). El proyecto PP-128-000062 tenía Ending Date 22/4/2026; la planilla "A28 62 CLC producción.xlsx" dice LLEGADA 23/4 (celda E5) y SALIDA 31/3 (24 días, celda G5),
   y las 30 asignaciones del cierre tienen Fecha Baja 23/4. Con el 22/4: (1) la ventana del tripulante (VentanaEmpleadoEnMarea) recorta contra el fin del proyecto y daba 23 días de enrolamiento en vez de 24, mientras
   A_CUENTA_MAREA ya descuenta el día de marzo (3/31 en 03664, 677.500): se pagaba un día de menos del asegurado (675.000 en 03664); (2) la Fecha de Liquidación del cierre era 22/4 y el tipo de cambio es el de esa fecha: 1.350 en vez de
   1.365 (el 23/4), que es el TC de la planilla; la producción y el asegurado de los oficiales sin neto garantizado salían con 1,1 % menos. Con 24 días y 1.365 la fórmula de BC da exacto el 2003 de Meta4: 03664, 15.000 x 1.365 / 30 x 24
   = 16.380.000 + producción 2.064.235 = 18.444.235 - 677.500 = 17.766.735 (CLC "dif total", celda G38).
   Las otras mareas de abril (HF801/9, HF802/9) ya tenían fin 23/4. Valor anterior: 2026-04-22. Rollback: volver a 22/4.
   Después: reiniciar el servicio y recalcular el CIERRE_MAREA de abril de las 30 liquidaciones de PP-128-000062 (y su regular y pilotaje si dependen de la fecha). */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] SET [Ending Date]='20260423' WHERE [No_]='PP-128-000062' AND [Ending Date]='20260422';
SELECT @@ROWCOUNT AS esperado_1;
