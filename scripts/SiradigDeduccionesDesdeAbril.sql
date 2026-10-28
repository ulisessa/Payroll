/* DEDUCCIONES SIRADIG (Ded. Ganancias Empleado): SÓLO DESDE ABRIL DE 2026.
   Al procesar las presentaciones SIRADIG de enero a abril (importador nuevo, línea de tiempo mensual), enero a marzo dejaron de coincidir con Meta4: el motor empezó a descontar el seguro de muerte,
   las primas de ahorro, la educación, los gastos médicos, el servicio doméstico, etc. declarados por 23 empleados, y Meta4 liquidó esos meses sin ninguno de esos datos
   (en M4T_VAL_FASE_ALTA no figuran). Ej.: 04921, neto garantizado: -63.972 de bruto en enero y +63.938 en febrero; 04850: -1.265.202 de descuentos en febrero.
   Decisión del usuario (19/10/2026, opción 2): cargar las deducciones sólo desde el mes en que Meta4 las empezó a aplicar; hasta marzo se mantiene la conciliación con Meta4. Como no hay evidencia de un mes
   anterior, el corte es el 1/4/2026, el primer mes que BC todavía no concilió.
   Cambio: borra de Ded. Ganancias Empleado las líneas con Vigencia Desde anterior al 1/4/2026 (23 empleados, 186 líneas). Las de abril en adelante (líneas en cero que cierran lo declarado hasta
   marzo, y las de agosto) quedan.
   Respaldo: antes de correrlo, exportar esas 186 líneas (SELECT con el mismo WHERE) a un archivo fuera del repo; el dato de origen también sigue en las presentaciones guardadas en el registro de
   auditoría de AFIP, así que se puede volver a cargar reprocesando.
   OJO con reprocesar: el importador carga cada mes desde la presentación (hoy sin corte): reprocesar una importación vuelve a insertar las líneas de enero a marzo.
   Después: reiniciar el servicio y recalcular enero, febrero y marzo de los 23 empleados:
     00900|00949|01404|01588|02792|03481|03985|03995|04137|04185|04351|04419|04455|04751|04768|04803|04807|04830|04849|04850|04921|90184|90454 */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT COUNT(*) AS Filas_a_borrar_esperado_186 FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde] < '20260401';
DELETE FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde] < '20260401';
SELECT COUNT(*) AS Filas_que_quedan, MIN(CONVERT(varchar(10),[Vigencia Desde],120)) AS desde FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
COMMIT;
