# gen_config.ps1 — Generates ConfigPackage_Payroll.xlsx via Excel COM
$OUTPUT = Join-Path $PSScriptRoot 'ConfigPackage_Payroll.xlsx'
$VIG = '01/12/2023'

$TIPO_MAP = @{
    'HR'='Haber Remunerativo'; 'HN'='Haber No Remunerativo'
    'DE'='Descuento Empleado'; 'CP'='Contribucion Patronal'
    'RE'='Retencion'; 'SS'='Seguridad Social'
}
$PRIMARY_ACC = @{
    'HR'='REMUNERATIVO_BRUTO'; 'HN'='NO_REMUNERATIVO'
    'DE'='TOTAL_DESCUENTOS'; 'RE'='TOTAL_DESCUENTOS'
    'SS'='TOTAL_DESCUENTOS'; 'CP'='TOTAL_CONTRIBUCIONES'
}
$ACC_NAMES = @('BASE_SS','BASE_OS','BASE_SINDICAL','BASE_LRT','BASE_IG4','BASE_SAC','BASE_PROMEDIO','BASE_FERIADO','BASE_ZONA','BASE_AUSENTISMO')
$CCT_CODES = @('175/75','768/19','729/15','ESP','130/75','372/04','ADM')

# ── Acumuladores ─────────────────────────────────────────────────────
$ACUMULADORES = New-Object System.Collections.ArrayList
[void]$ACUMULADORES.Add([object[]]@('REMUNERATIVO_BRUTO','Acum: Total Remunerativo','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('NO_REMUNERATIVO','Acum: Total No Remunerativo','Haber No Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('TOTAL_DESCUENTOS','Acum: Total Descuentos','Descuento Empleado'))
[void]$ACUMULADORES.Add([object[]]@('TOTAL_CONTRIBUCIONES','Acum: Total Contribuciones','Contribucion Patronal'))
[void]$ACUMULADORES.Add([object[]]@('BASE_SS','Acum: Base Seguridad Social','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_OS','Acum: Base Obra Social','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_SINDICAL','Acum: Base Sindical','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_LRT','Acum: Base LRT','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_IG4','Acum: Base Imp. Ganancias 4ta Cat.','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_SAC','Acum: Base SAC / Aguinaldo','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_PROMEDIO','Acum: Base Promedio','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_FERIADO','Acum: Base Feriado Embarcado','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_ZONA','Acum: Base Zona Desfavorable','Haber Remunerativo'))
[void]$ACUMULADORES.Add([object[]]@('BASE_AUSENTISMO','Acum: Base Ausentismo','Haber Remunerativo'))

# ── Conceptos ─────────────────────────────────────────────────────────
# Tuple: cod, nombre, tipo, aplica_tipo_liq, ord, activo,
#        cct[7]: 175,768,729,ESP,130,372,ADM,
#        acc[10]: SS,OS,SIND,LRT,IG4,SAC,PROM,FER,ZONA,AUSEN, formula
$CONCEPTOS = New-Object System.Collections.ArrayList
[void]$CONCEPTOS.Add(@('1003','Sueldo','HR',' ',10,1, 1,1,1,0,1,1,1, 1,1,1,1,1,1,1,0,1,1,'BASICO * PCT_ESCALA'))
[void]$CONCEPTOS.Add(@('1013','Sueldo de navegacion','HR','Cierre Marea',15,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,'DIAS_MAR * PRECIO_NAV'))
[void]$CONCEPTOS.Add(@('1023','Sueldo de feriado','HR',' ',20,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1033','Sueldo de dique','HR',' ',25,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1043','Sueldo de pilotaje','HR',' ',30,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1045','Servicio de asistencia y/o remolque','HR',' ',35,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1053','Antiguedad','HR',' ',50,1, 1,1,1,0,1,1,0, 1,1,1,1,1,1,1,1,0,1,'BASICO * PCT_ESCALA * ANIOS_ANTIGUEDAD * PCT_ANTIG'))
[void]$CONCEPTOS.Add(@('1063','Sueldo de franco','HR','Cierre Marea',60,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,'DIAS_MAR * PRECIO_FRANCO'))
[void]$CONCEPTOS.Add(@('1073','Sueldo a ordenes','HR','Cierre Marea',65,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,'DIAS_MAR * PRECIO_ORDENES'))
[void]$CONCEPTOS.Add(@('1075','Articulo 19 CCT 729/2015','HR',' ',70,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1076','Articulo 48 Parrafo 11 CCT 729/2015','HR',' ',75,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1083','Sueldo de puerto','HR',' ',80,0, 1,1,1,1,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('1093','Gratificacion produccion langostino colas','HR',' ',90,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('1103','Gratificacion trabajos a bordo','HR',' ',95,0, 1,1,1,1,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1113','Sueldo basico articulo 16 AACPyPP','HR',' ',100,1, 0,1,0,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1153','Ajuste de dias de puerto','HR',' ',105,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1173','Adicional bodega no remunerativo','HN',' ',200,1, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('1174','Adicional bodega remunerativo','HR',' ',205,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1183','Ajuste de antiguedad','HR',' ',210,0, 1,1,1,0,1,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1203','Produccion bruta merluza','HR',' ',110,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1213','Produccion bruta calamar entero','HR',' ',115,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1223','Produccion bruta langostino entero','HR',' ',120,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1233','Produccion bruta langostino colas','HR',' ',125,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1243','Produccion bruta calamar vaina','HR',' ',130,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1253','Produccion bruta calamar rejos','HR',' ',135,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1263','Produccion bruta langostino cola rota','HR',' ',140,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1333','Produccion merluza','HR',' ',110,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('1343','Produccion calamar entero','HR',' ',115,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1373','Produccion calamar vaina','HR',' ',130,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1383','Produccion calamar rejos','HR',' ',135,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1387','Complemento no rem produccion calamar','HN',' ',220,1, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('1388','Complemento no rem produccion langostino','HN',' ',225,1, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('1393','Produccion langostino cola rota','HR',' ',140,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('1413','A cuenta futuros aumentos (729/15)','HN',' ',230,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1513','Ajuste a cuenta futuros aumentos','HR',' ',235,0, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1533','Adicional articulo 23','HR',' ',145,1, 1,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1534','Premio adicional especial de produccion','HR',' ',150,1, 0,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('1543','Adicional articulo 33','HR',' ',155,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1547','Incentivo a la produccion','HR','Cierre Marea',160,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,'DIAS_MAR * PRECIO_INCENT'))
[void]$CONCEPTOS.Add(@('1563','Ropa de trabajo','HN',' ',240,1, 0,0,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('1583','Adicional trabajos especiales','HR',' ',165,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1603','Categoria superior','HR',' ',170,1, 1,1,1,0,0,1,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1653','Diferencia remuneracion asegurada','HR',' ',175,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('1693','Horas normales','HR',' ',10,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('1803','Horas extras 50%','HR',' ',20,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('1813','Horas extras 100%','HR',' ',25,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('1823','Adicional frio','HR',' ',30,1, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1863','A cuenta futuros aumentos (STIA)','HR',' ',35,1, 0,0,0,0,0,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1883','Gratificacion trabajos en planta','HR',' ',40,1, 0,0,0,0,0,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1893','Horas extras 150%','HR',' ',27,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('1913','Adicional presencia','HR',' ',45,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('1933','Bonificacion unica extraordinaria','HR',' ',250,0, 1,1,1,0,1,1,1, 0,0,0,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('2003','A cuenta futuros aumentos (175/75)','HR',' ',180,1, 1,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2013','A cuenta futuros aumentos puerto','HR',' ',182,1, 1,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2023','A cuenta futuros aumentos dique','HR',' ',184,1, 1,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2033','A cuenta futuros aumentos pilotaje','HR',' ',186,1, 1,1,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2043','Gratificacion trabajos en puerto','HR',' ',188,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2053','Gratificacion trabajos en dique','HR',' ',190,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2073','Adicional tareas mecanicas','HR',' ',195,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2083','A cuenta futuros aumentos francos','HR',' ',197,1, 1,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2103','Presentismo Comercio','HR',' ',45,1, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,0,1,''))
[void]$CONCEPTOS.Add(@('2303','Porcentaje sobre valor','HR',' ',110,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2313','Diferencia garantizada','HR',' ',115,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2323','Reduccion pactada','HN',' ',245,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2343','Adicional por produccion','HR',' ',120,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('2353','Reduccion pactada 2016','HN',' ',248,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2363','Reduccion pactada 2020','HN',' ',249,1, 0,0,0,1,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2403','Produccion langostino entero 1','HR',' ',141,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2413','Produccion langostino entero 2','HR',' ',142,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2423','Produccion langostino entero 3','HR',' ',143,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2433','Produccion langostino entero 4','HR',' ',144,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2443','Produccion langostino entero 5','HR',' ',145,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2453','Produccion langostino entero 6','HR',' ',146,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2463','Produccion langostino cola 1','HR',' ',147,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2473','Produccion langostino cola 2','HR',' ',148,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2483','Produccion langostino cola 3','HR',' ',149,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,1,0,''))
[void]$CONCEPTOS.Add(@('2535','Complemento no rem produccion merluza','HN',' ',260,1, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('2553','Retroactivo acuerdo SOMU','HR',' ',270,0, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2573','Ajuste de adicional bodega','HR',' ',275,0, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2603','Ajuste de horas extras 150%','HR',' ',325,0, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('2613','Ajuste de marea','HR',' ',280,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2673','Ajuste','HR',' ',285,0, 1,1,1,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2675','Retroactivo incremento paritaria STIA','HR',' ',290,0, 0,0,0,0,0,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2703','Adicional por zona desfavorable','HR',' ',55,1, 0,0,0,0,1,1,1, 1,1,1,1,1,1,1,0,0,1,''))
[void]$CONCEPTOS.Add(@('2713','Gratificacion','HR',' ',295,1, 0,0,0,0,0,0,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2733','Gratificacion por jubilacion','HR',' ',300,1, 0,1,1,0,0,0,0, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('2743','Ajuste de sueldo a ordenes','HR',' ',305,0, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('2763','Ajuste de horas normales','HR',' ',310,0, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('2773','Ajuste de horas extras 50%','HR',' ',315,0, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('2783','Ajuste de horas extras 100%','HR',' ',320,0, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('2803','Indemnizacion francos no gozados','HR','Liquidacion Final',400,1, 1,1,1,0,0,0,0, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('2804','SAC s/ francos no gozados','HR','Liquidacion Final',405,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3473','Gastos de sepelio articulo 84 CCT 372/04','HR',' ',330,1, 0,0,0,0,0,1,0, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3474','Subsidio jubilacion articulo 82 CCT 372/04','HR',' ',335,1, 0,0,0,0,0,1,0, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3553','Vacaciones','HR','Vacaciones',450,1, 1,1,1,1,1,1,1, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3573','Adicional vacaciones articulo 76 CCT 372/04','HR','Vacaciones',455,1, 0,0,0,0,0,1,0, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3613','SAC primer semestre','HR','Aguinaldo',460,1, 1,1,1,1,1,1,1, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3623','SAC segundo semestre','HR','Aguinaldo',465,1, 1,1,1,1,1,1,1, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3813','SAC egreso primer semestre','HR','Liquidacion Final',470,1, 1,1,1,1,1,1,1, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3823','SAC egreso segundo semestre','HR','Liquidacion Final',475,1, 1,1,1,1,1,1,1, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3903','Indemnizacion sustitutiva del preaviso','HR','Liquidacion Final',500,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3904','SAC s/ indem. sustitutiva preaviso','HR','Liquidacion Final',505,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3913','Indemnizacion antiguedad por despido','HR','Liquidacion Final',510,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3923','Indemnizacion antiguedad por fallecimiento','HR','Liquidacion Final',515,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3924','Indemnizacion enfermedad art. 213 LCT','HR','Liquidacion Final',520,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3933','Indemnizacion incapacidad art. 212 P2 LCT','HR','Liquidacion Final',525,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3935','Indemnizacion incapacidad art. 212 P3 LCT','HR','Liquidacion Final',530,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3937','Indemnizacion incapacidad art. 212 P4 LCT','HR','Liquidacion Final',535,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3943','Integracion mes de despido','HR','Liquidacion Final',540,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3944','SAC s/ integracion mes de despido','HR','Liquidacion Final',545,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3953','Indemnizacion causa maternidad','HR','Liquidacion Final',550,1, 0,0,0,0,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3973','Vacaciones no gozadas','HR','Liquidacion Final',555,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3974','SAC s/ vacaciones no gozadas','HR','Liquidacion Final',560,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3975','Vacaciones no gozadas anios anteriores','HR','Liquidacion Final',565,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3976','SAC s/ vacaciones no gozadas anios ant.','HR','Liquidacion Final',570,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3983','Indemnizacion fuerza mayor','HR','Liquidacion Final',575,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('3993','Indemnizacion causa embarazo','HR','Liquidacion Final',580,1, 0,0,0,0,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4003','Indemnizacion causa matrimonio','HR','Liquidacion Final',585,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4013','Indemnizacion art. 52 P4 Ley 23551','HR','Liquidacion Final',590,1, 1,1,1,0,1,1,0, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4023','Conciliacion','HR','Liquidacion Final',595,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4033','Bonificacion fin de relacion laboral','HR','Liquidacion Final',600,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4060','Licencia gremial','HR',' ',340,1, 0,0,0,0,1,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4070','Licencia por casamiento','HR',' ',345,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4080','Licencia por nacimiento','HR',' ',350,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4090','Licencia por defuncion','HR',' ',355,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4100','Licencia por examen','HR',' ',360,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4108','Licencia por donacion de sangre','HR',' ',365,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4110','Enfermedad inculpable','HR',' ',370,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4111','Ajuste de enfermedad inculpable','HR',' ',680,0, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4115','Descuento dias de enfermedad','DE',' ',610,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4120','Accidente - Enfermedad profesional','HR',' ',375,1, 1,1,1,1,1,1,1, 1,1,1,1,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4121','Descuento dias de accidente','DE',' ',615,1, 0,0,0,0,1,1,0, 1,1,1,1,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4123','Horas de accidente - enf. profesional','HR',' ',380,1, 0,0,0,0,1,0,0, 1,1,1,1,0,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4124','Ajuste prestacion ILT','HR',' ',685,0, 1,1,1,1,1,1,1, 1,1,1,1,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4125','Prestacion ILT','HR',' ',385,1, 1,1,1,1,1,1,1, 1,1,1,1,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4135','Descuento dias de maternidad','DE',' ',620,1, 0,0,0,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4140','Suspension disciplinaria','DE',' ',625,1, 1,1,1,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4160','Accidente - Enf. profesional no remunerativo','HN',' ',390,1, 1,1,1,1,1,1,1, 0,1,1,0,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4165','Prestacion ILT no remunerativa','HN',' ',395,1, 1,1,1,1,1,1,1, 0,1,1,0,0,1,0,1,0,0,''))
[void]$CONCEPTOS.Add(@('4213','Anticipo de vacaciones','HR',' ',630,1, 0,0,0,0,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4243','Ajuste de vacaciones','HR',' ',635,0, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4415','Absorcion articulo 36 CCT SOMU-CAPECA','HR',' ',400,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('4423','Horas extras 100% (729/15)','HR',' ',405,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('4433','Horas extras 50% (729/15)','HR',' ',410,1, 0,0,1,0,0,0,0, 1,1,1,1,1,1,1,1,0,0,''))
[void]$CONCEPTOS.Add(@('4443','Adicional presentismo STIA','HR',' ',415,1, 0,0,0,0,0,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4444','Bonificacion especial remunerativa STIA','HR',' ',420,1, 0,0,0,0,0,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4453','Dias feriados','HR',' ',425,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('4473','Ajuste de dias feriados','HR',' ',430,0, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,1,0,''))
[void]$CONCEPTOS.Add(@('4573','Asistencia perfecta','HR',' ',435,1, 0,0,0,0,1,1,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4680','Dec 194/23 prog incremento exportador','HR',' ',440,1, 1,1,1,0,0,0,0, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4683','Incremento no rem paritaria STIA','HN',' ',445,1, 0,0,0,0,0,1,0, 0,1,1,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4684','Retroactivo incremento no rem STIA','HN',' ',450,0, 0,0,0,0,0,1,0, 0,1,1,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4703','Deduccion por ausencias','DE',' ',640,1, 0,0,0,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4723','Deduccion por huelga','DE',' ',645,1, 0,0,0,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4743','Descuento dias de vacaciones','DE',' ',650,1, 0,0,0,0,1,1,1, 1,1,1,1,1,1,1,0,0,0,''))
[void]$CONCEPTOS.Add(@('4803','Anticipo de poder','HR',' ',655,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4805','Adelanto incentivo capacitacion','HR',' ',660,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4813','Anticipo de llegada','HR',' ',665,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4823','Anticipo de haberes','HR',' ',670,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4833','Porcentaje sobre valor (Adelanto haberes)','HR',' ',675,1, 0,0,0,1,0,0,0, 1,1,1,1,1,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4853','Asignacion extraord. no rem Comercio','HN',' ',455,1, 0,0,0,0,1,0,0, 0,1,1,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4856','Incremento no rem acuerdo Comercio','HN',' ',458,1, 0,0,0,0,1,0,0, 1,1,1,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4873','Bonificacion extraordinaria SICONARA','HR',' ',460,1, 1,0,0,0,0,0,0, 0,1,1,0,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4893','Incremento no rem acuerdo SOMU','HN',' ',462,1, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4894','Retroactivo incremento no rem SOMU','HN',' ',464,0, 0,0,1,0,0,0,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4895','Incremento no rem paritaria STIA (2)','HN',' ',466,1, 0,0,0,0,0,1,0, 1,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('4896','Retroactivo incremento no rem STIA (2)','HN',' ',468,0, 0,0,0,0,0,1,0, 0,1,1,1,0,1,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('5498','Redondeo','HR',' ',999,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('5010','Impuesto a las ganancias','RE',' ',850,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,"TRAMO('TAB_IMP_4CAT',MAX(BASE_IG4*12-MNI_ANUAL-DEDUCCION_ESP-DEDUC_GANANCIAS,0))/12"))
[void]$CONCEPTOS.Add(@('5310','Impuesto a las ganancias anio anterior','RE',' ',855,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8522','Cuota sindical','DE',' ',700,1, 1,1,1,0,1,1,0, 0,0,0,0,0,0,0,0,0,0,'BASE_SINDICAL * PCT_CUOTA_SIND'))
[void]$CONCEPTOS.Add(@('8523','Cuota sindical SAC','DE','Aguinaldo',705,1, 1,1,1,0,1,1,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8525','Cuota sindical vacaciones','DE','Vacaciones',710,1, 1,1,1,0,1,1,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8542','Caja compensadora','DE',' ',715,1, 0,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8543','Fondo de desempleo','DE',' ',720,1, 1,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8553','Centro de capacitacion','DE',' ',725,1, 0,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8563','Contribucion solidaria SOMU','DE',' ',730,1, 0,0,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8573','Aporte solidario STIA','DE',' ',735,1, 0,0,0,0,0,1,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8593','Cuota extraordinaria accion social CAP','DE',' ',740,1, 0,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8603','Contribucion solidaria AACPyPP','DE',' ',745,1, 0,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8623','Gastos de hotel','DE',' ',750,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8633','Gastos de farmacia','DE',' ',755,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8643','Gastos de pasajes','DE',' ',760,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8653','Gastos medicos','DE',' ',765,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8683','Gastos de cigarrillos','DE',' ',770,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8693','Descuento de comunicaciones','DE',' ',775,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8703','Gastos varios','DE',' ',780,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8810','Descuento anticipo vacaciones','DE',' ',785,1, 0,0,0,0,1,1,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8830','Descuento anticipo poder','DE',' ',790,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8835','Descuento adelanto incentivo capacitacion','DE',' ',795,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8840','Descuento anticipo llegada','DE',' ',800,1, 1,1,1,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8850','Descuento anticipo haberes','DE',' ',805,1, 1,1,1,1,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8860','Porcentaje sobre valor (Descuento adelanto)','DE',' ',810,1, 0,0,0,1,0,0,0, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8870','Descuento anticipo haberes ADM','DE',' ',815,1, 0,0,0,0,1,0,1, 0,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8883','Embargo judicial','RE',' ',820,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('8893','Cuota alimentaria','RE',' ',825,1, 1,1,1,1,1,1,1, 1,0,0,0,0,0,0,0,0,0,''))
[void]$CONCEPTOS.Add(@('6000','Jubilacion','SS',' ',900,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SS,TOPE_SIPA)*PCT_JUB'))
[void]$CONCEPTOS.Add(@('6002','Jubilacion SAC','SS','Aguinaldo',902,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA)*PCT_JUB'))
[void]$CONCEPTOS.Add(@('6003','Jubilacion vacaciones','SS','Vacaciones',904,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA)*PCT_JUB'))
[void]$CONCEPTOS.Add(@('6010','Ley 19032','SS',' ',906,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SS,TOPE_SIPA)*PCT_19032'))
[void]$CONCEPTOS.Add(@('6012','Ley 19032 SAC','SS','Aguinaldo',908,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA)*PCT_19032'))
[void]$CONCEPTOS.Add(@('6013','Ley 19032 vacaciones','SS','Vacaciones',910,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA)*PCT_19032'))
[void]$CONCEPTOS.Add(@('6030','Obra social','SS',' ',912,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_OS,TOPE_SIPA_OS)*PCT_OS'))
[void]$CONCEPTOS.Add(@('6032','Adicional obra social','SS',' ',914,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_OS,TOPE_SIPA_OS)*PCT_ADICIONAL_OS'))
[void]$CONCEPTOS.Add(@('6034','Obra social SAC','SS','Aguinaldo',916,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA_OS)*PCT_OS'))
[void]$CONCEPTOS.Add(@('6035','Obra social vacaciones','SS','Vacaciones',918,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA_OS)*PCT_OS'))
[void]$CONCEPTOS.Add(@('6036','Adicional obra social SAC','SS','Aguinaldo',920,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA_OS)*PCT_ADICIONAL_OS'))
[void]$CONCEPTOS.Add(@('6037','Adicional obra social vacaciones','SS','Vacaciones',922,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA_OS)*PCT_ADICIONAL_OS'))
[void]$CONCEPTOS.Add(@('7000','Contrib. patronal jubilacion','CP',' ',930,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SS,TOPE_SIPA)*PCT_CONT_JUB'))
[void]$CONCEPTOS.Add(@('7002','Contrib. patronal jub. SAC','CP','Aguinaldo',932,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SAC,TOPE_SIPA)*PCT_CONT_JUB'))
[void]$CONCEPTOS.Add(@('7010','Contrib. patronal ley 19032','CP',' ',934,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_SS,TOPE_SIPA)*PCT_CONT_19032'))
[void]$CONCEPTOS.Add(@('7030','Contrib. patronal obra social','CP',' ',936,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_OS,TOPE_SIPA_OS)*PCT_CONT_23660'))
[void]$CONCEPTOS.Add(@('7050','Contrib. patronal ART','CP',' ',938,1, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0,0,0,0,'MIN(BASE_LRT,TOPE_SIPA)*PCT_ART+VALOR_ART_FIJO'))

# ── COM helpers ──────────────────────────────────────────────────────
function RgbToLong([int]$r,[int]$g,[int]$b) { return [long]($b + $g*256 + $r*65536) }
function HexToLong([string]$hex) {
    return RgbToLong ([Convert]::ToInt32($hex.Substring(0,2),16)) `
                     ([Convert]::ToInt32($hex.Substring(2,2),16)) `
                     ([Convert]::ToInt32($hex.Substring(4,2),16))
}

function Write-SheetFromList($xl, [string]$name, [string[]]$headers,
                             [System.Collections.ArrayList]$rows, [string]$bgHex) {
    $ws = $xl.Worksheets.Add([System.Reflection.Missing]::Value,
                              $xl.Worksheets.Item($xl.Worksheets.Count))
    $ws.Name = if ($name.Length -gt 31) { $name.Substring(0,31) } else { $name }
    $bg = HexToLong $bgHex
    for ($c = 0; $c -lt $headers.Count; $c++) {
        $cell = $ws.Cells.Item(1, $c+1)
        $cell.Value2 = $headers[$c]
        $cell.Font.Bold = $true
        $cell.Font.Color = RgbToLong 255 255 255
        $cell.Font.Size = 9
        $cell.Interior.Color = $bg
        $cell.HorizontalAlignment = -4108
        $cell.WrapText = $true
        $ws.Columns.Item($c+1).ColumnWidth = [Math]::Max(14, $headers[$c].Length + 2)
    }
    $rowNum = 2
    foreach ($row in $rows) {
        $colNum = 1
        foreach ($val in $row) {
            $ws.Cells.Item($rowNum, $colNum).Value2 = "$val"
            $colNum++
        }
        $rowNum++
    }
    $ws.Rows.Item(2).Select() | Out-Null
    $xl.ActiveWindow.FreezePanes = $true
    return $ws
}

# ── Main ──────────────────────────────────────────────────────────────
Write-Host "Iniciando Excel..."
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $xl.Workbooks.Add()
while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }
$wb.Worksheets.Item(1).Name = '__temp__'

# ── 1. INSTRUCCIONES ─────────────────────────────────────────────────
$wsI = $xl.Worksheets.Add([System.Reflection.Missing]::Value, $wb.Worksheets.Item($wb.Worksheets.Count))
$wsI.Name = 'INSTRUCCIONES'
$wsI.Columns.Item(1).ColumnWidth = 80
$instrLines = @(
    'ConfigPackage_Payroll.xlsx - Paquete de configuracion para extension Payroll BC'
    ''
    'COMO IMPORTAR EN BC:'
    '1. Abrir Paquetes de configuracion (Config. Packages)'
    '2. Crear nuevo paquete con un codigo (ej. PAYROLL-25)'
    '3. Importar este Excel via accion "Importar desde Excel"'
    '4. Validar cada tabla y aplicar'
    ''
    'ORDEN DE APLICACION RECOMENDADO:'
    '  1. Convenio Colectivo'
    '  2. Categoria CCT'
    '  3. Parametro + Parametro Vigente'
    '  4. Variable Sistema Liq.'
    '  5. Concepto Liquidacion (incluye acumuladores)'
    '  6. Concepto CCT Vigente'
    '  7. Fraccion Acumulador'
    ''
    'NOTAS:'
    '- Parametro Vigente: valores reales al 01/12/2023 desde sociedad.csv y sindicato.csv'
    '- Precios diarios 729/15: corresponden a buque Congelador (CG). Potero (PT) difiere en puerto/franco'
    '- TC_COMPRADOR: completar con tipo de cambio del dia de liquidacion'
    '- PRECIO_INCENT: valores 2014, requieren actualizacion'
    '- Categoria CCT: % Escala = 100 en todos (BASICO por sufijo ya es el importe correcto)'
    '- Los conceptos con Activo=0 son cerrados o no implementados aun'
    '- Formula vacia = pendiente de completar segun CCT e incidencias disponibles'
    '- SS formulas usan parametros PCT_JUB, PCT_19032, PCT_OS, PCT_ADICIONAL_OS'
    '- Ganancias formula incluye DEDUCCION_ESP + DEDUC_GANANCIAS (cargas de familia)'
    '- Fraccion Acumulador: el % debe sumar 100 por concepto+vigencia'
    '- Concepto CCT Vigente: si no hay filas para un concepto, aplica a TODOS los CCT'
)
for ($row = 0; $row -lt $instrLines.Count; $row++) {
    $wsI.Cells.Item($row + 1, 1).Value2 = $instrLines[$row]
}
$wsI.Cells.Item(1,1).Font.Bold = $true; $wsI.Cells.Item(1,1).Font.Size = 12

# ── 2. Convenio Colectivo ────────────────────────────────────────────
$d = New-Object System.Collections.ArrayList
[void]$d.Add([object[]]@('175/75','CCT 175/75 Personal Embarcado Oficiales CAPECA','','',''))
[void]$d.Add([object[]]@('768/19','CCT 768/19 Personal Embarcado Oficiales AACPyPP','','',''))
[void]$d.Add([object[]]@('729/15','CCT 729/15 Personal Embarcado Marineria SOMU-CAPECA','','',''))
[void]$d.Add([object[]]@('ESP','Sin CCT - Personal Embarcado Espania','','',''))
[void]$d.Add([object[]]@('130/75','CCT 130/1975 Comercio','','',''))
[void]$d.Add([object[]]@('372/04','CCT 372/2004 STIA','','',''))
[void]$d.Add([object[]]@('ADM','Sin CCT - Personal Administrativo','','',''))
Write-SheetFromList $xl 'Convenio Colectivo' @('Codigo','Descripcion','No. CCT','Sindicato','Observaciones') $d '2E75B6' | Out-Null

# ── 3. Categoria CCT ─────────────────────────────────────────────────
# Cols: 'Cod. Convenio','Codigo','Descripcion','% Escala','Observaciones'
# % Escala = 100 en todos: el BASICO por sufijo ya es el importe correcto por categoria.
# PCT_ESCALA en contexto = % Escala / 100 = 1,0 (BASICO * PCT_ESCALA = BASICO)
$d = New-Object System.Collections.ArrayList
# 175/75 - Personal Embarcado Oficiales CAPECA
[void]$d.Add([object[]]@('175/75','OF01','Capitan',                    100,''))
[void]$d.Add([object[]]@('175/75','OF02','Jefe de Maquinas',           100,''))
[void]$d.Add([object[]]@('175/75','OF03','Primer Oficial de Cubierta', 100,''))
[void]$d.Add([object[]]@('175/75','OF04','Primer Maquinista',          100,''))
[void]$d.Add([object[]]@('175/75','OF05','Segundo Oficial de Cubierta',100,''))
# 768/19 - Personal Embarcado Oficiales AACPyPP
[void]$d.Add([object[]]@('768/19','OF01','Capitan',                    100,''))
[void]$d.Add([object[]]@('768/19','OF02','Jefe de Maquinas',           100,''))
[void]$d.Add([object[]]@('768/19','OF03','Primer Oficial de Cubierta', 100,''))
[void]$d.Add([object[]]@('768/19','OF04','Primer Maquinista',          100,''))
[void]$d.Add([object[]]@('768/19','OF05','Segundo Oficial de Cubierta',100,''))
# 729/15 - Marineria Embarcados SOMU-CAPECA
[void]$d.Add([object[]]@('729/15','MR00','Primer Pescador',        100,''))
[void]$d.Add([object[]]@('729/15','MR01','Contramaestre',          100,''))
[void]$d.Add([object[]]@('729/15','MR02','Primer Cocinero',        100,''))
[void]$d.Add([object[]]@('729/15','MR03','Mozo',                   100,''))
[void]$d.Add([object[]]@('729/15','MR04','Engrasador',             100,''))
[void]$d.Add([object[]]@('729/15','MR05','Marinero de Cubierta',   100,''))
[void]$d.Add([object[]]@('729/15','MR06','Enfermero',              100,''))
[void]$d.Add([object[]]@('729/15','MR07','Contramaestre de Frio',  100,''))
[void]$d.Add([object[]]@('729/15','MR08','Marinero de Planta',     100,''))
# ESP - Personal Embarcado Espanoles
[void]$d.Add([object[]]@('ESP','FE01','Patron de Pesca',           100,''))
[void]$d.Add([object[]]@('ESP','FE02','Garantia de Maquinas',      100,''))
[void]$d.Add([object[]]@('ESP','FE03','Contramaestre Espanol',     100,''))
# 130/75 - Empleados de Comercio
[void]$d.Add([object[]]@('130/75','EC01','Maestranza - A',         100,'Res.ST 510/2008'))
# 372/04 - STIA Alimentacion
[void]$d.Add([object[]]@('372/04','CA02','Categoria 2',            100,'Mensualizados Alimentacion'))
[void]$d.Add([object[]]@('372/04','CA05','Maestranza 1/2 Jornada', 100,'STIA Chubut'))
[void]$d.Add([object[]]@('372/04','CA07','Segundo Capataz',        100,''))
[void]$d.Add([object[]]@('372/04','CA08','Maquinista',             100,''))
[void]$d.Add([object[]]@('372/04','CA09','Maquinista Chubut',      100,'STIA Chubut'))
[void]$d.Add([object[]]@('372/04','CA10','Oficial Especializado',  100,''))
# ADM - Administrativos sin CCT
[void]$d.Add([object[]]@('ADM','ADM1','Administrativo Nivel 1',    100,''))
[void]$d.Add([object[]]@('ADM','ADM2','Administrativo Nivel 2',    100,''))
Write-SheetFromList $xl 'Categoria CCT' @('Cod. Convenio','Codigo','Descripcion','% Escala','Observaciones') $d '2E75B6' | Out-Null
Write-Host "  Categoria CCT: $($d.Count) filas"

# ── 4. Parametro ─────────────────────────────────────────────────────
$d = New-Object System.Collections.ArrayList
# --- Parámetros con sufijo CCT/Categoría ---
[void]$d.Add([object[]]@('BASICO',       'Basico/sueldo del convenio-categoria',   'Clave efectiva: BASICO_[CCT]_[CAT]',        'BASICO',        1))
[void]$d.Add([object[]]@('PRECIO_NAV',   'Precio diario de navegacion',            'Clave: PRECIO_NAV_[CCT]_[CAT]',             'PRECIO_NAV',    1))
[void]$d.Add([object[]]@('PRECIO_FRANCO','Precio diario de franco',                'Clave: PRECIO_FRANCO_[CCT]_[CAT]',          'PRECIO_FRANCO', 1))
[void]$d.Add([object[]]@('PRECIO_ORDENES','Precio dia a ordenes',                  'Clave: PRECIO_ORDENES_[CCT]_[CAT]',         'PRECIO_ORDENES',1))
[void]$d.Add([object[]]@('PRECIO_PUERTO','Precio dia de puerto',                   'Clave: PRECIO_PUERTO_[CCT]_[CAT]',          'PRECIO_PUERTO', 1))
[void]$d.Add([object[]]@('PRECIO_INCENT','Incentivo a la produccion por dia',      'Clave: PRECIO_INCENT_[CCT]_[CAT]',          'PRECIO_INCENT', 1))
[void]$d.Add([object[]]@('PCT_CUOTA_SIND','Tasa cuota sindical',                   'Varia por CCT. Clave: PCT_CUOTA_SIND_[CCT]_[CAT]','PCT_CUOTA_SIND',1))
# --- Parámetros globales ---
[void]$d.Add([object[]]@('SMVM',              'Salario Minimo Vital y Movil',              '','SMVM',            0))
[void]$d.Add([object[]]@('TC_COMPRADOR',      'Tipo de cambio comprador (USD)',             '','TC_COMPRADOR',    0))
[void]$d.Add([object[]]@('TOPE_SIPA',         'Tope imponible SIPA (jub/19032)',            '60 MOPRES','TOPE_SIPA',       0))
[void]$d.Add([object[]]@('TOPE_SIPA_OS',      'Tope imponible SIPA (obra social)',          '','TOPE_SIPA_OS',    0))
[void]$d.Add([object[]]@('MNI_ANUAL',         'Minimo no imponible anual Ganancias 4ta',    'ID 651 AFIP','MNI_ANUAL',      0))
[void]$d.Add([object[]]@('DEDUCCION_ESP',     'Deduccion especial anual Ganancias 4ta',     'ID 653 AFIP','DEDUCCION_ESP',  0))
[void]$d.Add([object[]]@('PCT_ANTIG',         'Porcentaje de antiguedad por anio',          '0,01 = 1% por anio','PCT_ANTIG',      0))
# --- Alícuotas empleado (Seguridad Social) ---
[void]$d.Add([object[]]@('PCT_JUB',           'Aporte jubilacion empleado',                 'ID 610 - 11%','PCT_JUB',        0))
[void]$d.Add([object[]]@('PCT_19032',         'Aporte ley 19032 (INSSJP) empleado',         'ID 612 - 3%','PCT_19032',      0))
[void]$d.Add([object[]]@('PCT_OS',            'Aporte obra social empleado',                'ID 616 - 3%','PCT_OS',         0))
[void]$d.Add([object[]]@('PCT_ADICIONAL_OS',  'Aporte adicional obra social empleado',      'ID 618 - 1,5%','PCT_ADICIONAL_OS',0))
# --- Alícuotas patronales ---
[void]$d.Add([object[]]@('PCT_CONT_JUB',      'Contribucion patronal jubilacion',           'ID 624 - 10,77%','PCT_CONT_JUB',   0))
[void]$d.Add([object[]]@('PCT_CONT_23660',    'Contribucion patronal ley 23660 (OS)',        'ID 626 - 6%','PCT_CONT_23660',  0))
[void]$d.Add([object[]]@('PCT_CONT_19032',    'Contribucion patronal ley 19032 (INSSJP)',    'ID 628 - 1,59%','PCT_CONT_19032',  0))
[void]$d.Add([object[]]@('PCT_ART',           'Contribucion patronal ART (% sobre rem)',     'ID 6090 - 5,51%','PCT_ART',        0))
[void]$d.Add([object[]]@('VALOR_ART_FIJO',    'Contribucion patronal ART (valor fijo por emp)','ID 6091 - mensual','VALOR_ART_FIJO',  0))
Write-SheetFromList $xl 'Parametro' @('Codigo','Descripcion','Notas','Nombre Variable','Sufijo CCT') $d '2E75B6' | Out-Null

# ── 4. Parametro Vigente ─────────────────────────────────────────────
# Cols: 'Cod. Parametro','Vigencia Desde','Descripcion Version','Valor','Moneda','En Uso','Notas'
$d = New-Object System.Collections.ArrayList
# ── Globales (fuente: sociedad.csv, Dic 2023) ──
[void]$d.Add([object[]]@('SMVM',              $VIG, 'SMVM Dic 2023',          156000,       '', 0, 'Res.15/2023 CNEPSMVM'))
[void]$d.Add([object[]]@('TC_COMPRADOR',      $VIG, "Vigente $VIG",           0,            'USD', 0, 'Completar con cotizacion del dia'))
[void]$d.Add([object[]]@('TOPE_SIPA',         $VIG, 'Tope 60 MOPRES Dic 2023',1157112.83,  '', 0, 'Res.ANSES 220/2023'))
[void]$d.Add([object[]]@('TOPE_SIPA_OS',      $VIG, 'Tope OS Dic 2023',       1157112.83,  '', 0, 'Mismo tope que SIPA'))
[void]$d.Add([object[]]@('MNI_ANUAL',         $VIG, 'MNI anual 2023',         451683.19,   '', 0, 'ID 651 AFIP - anual'))
[void]$d.Add([object[]]@('DEDUCCION_ESP',     $VIG, 'Ded. Especial anual 2023',2168079.35, '', 0, 'ID 653 AFIP - anual'))
[void]$d.Add([object[]]@('PCT_ANTIG',         $VIG, '1% por anio de antiguedad',0.01,       '', 0, 'LCT art. 208'))
# ── Alícuotas empleado SS ──
[void]$d.Add([object[]]@('PCT_JUB',           $VIG, '% Jubilacion empleado',  0.11,  '', 0, 'ID 610 - estable desde 2008'))
[void]$d.Add([object[]]@('PCT_19032',         $VIG, '% Ley 19032 empleado',   0.03,  '', 0, 'ID 612 - estable desde 1994'))
[void]$d.Add([object[]]@('PCT_OS',            $VIG, '% Obra Social empleado', 0.03,  '', 0, 'ID 616 - estable desde 1994'))
[void]$d.Add([object[]]@('PCT_ADICIONAL_OS',  $VIG, '% Adic. OS empleado',    0.015, '', 0, 'ID 618 - estable desde 1994'))
# ── Alícuotas patronales ──
[void]$d.Add([object[]]@('PCT_CONT_JUB',      $VIG, '% Contrib Jub patronal', 0.1077,  '', 0, 'ID 624 - desde 2019'))
[void]$d.Add([object[]]@('PCT_CONT_23660',    $VIG, '% Contrib OS patronal',  0.06,    '', 0, 'ID 626 - desde 2002'))
[void]$d.Add([object[]]@('PCT_CONT_19032',    $VIG, '% Contrib 19032 patronal',0.0159, '', 0, 'ID 628 - desde 2019'))
[void]$d.Add([object[]]@('PCT_ART',           $VIG, '% ART sobre remuneracion',0.0551, '', 0, 'ID 6090 - Prevencion ART'))
[void]$d.Add([object[]]@('VALOR_ART_FIJO',    $VIG, 'ART valor fijo Dic 2023', 418,    '', 0, 'ID 6091 - por empleado/mes'))
# ── BASICO por CCT/Categoria (concepto 1002 - precio sueldo, fuente: cnv-categ.csv) ──
# CCT 372/04 - STIA (Mensualizados Alimentacion)
[void]$d.Add([object[]]@('BASICO_372/04_CA02',$VIG,'STIA Cat.2 Dic 2023',      274180.88,'',0,'Categoria 2 Mensualizados Alimentacion'))
[void]$d.Add([object[]]@('BASICO_372/04_CA05',$VIG,'STIA Maestranza 1/2 jorn Dic 2023',191745.78,'',0,'50% cat1 CCT 372 STIA Chubut'))
[void]$d.Add([object[]]@('BASICO_372/04_CA07',$VIG,'STIA 2do Capataz Dic 2023',318814.95,'',0,'Segundo Capataz'))
[void]$d.Add([object[]]@('BASICO_372/04_CA08',$VIG,'STIA Maquinista Dic 2023', 321264,  '', 0,'Jornal cat4 * 200'))
[void]$d.Add([object[]]@('BASICO_372/04_CA10',$VIG,'STIA Of.Especializado Dic 2023',340540,'',0,'Jornal cat4 * 200 + 6%'))
# CCT 130/75 - Empleados de Comercio Buenos Aires
[void]$d.Add([object[]]@('BASICO_130/75_EC01',$VIG,'Comercio Maestranza-A Ene 2024',397394.90,'',0,'Res.ST 510/2008'))
# CCT 175/75 - Oficiales (CAPECA)
[void]$d.Add([object[]]@('BASICO_175/75_OF01',$VIG,'CAPECA Capitan Sep 2023',   250618,  '', 0,'Actualizar con paritaria vigente'))
[void]$d.Add([object[]]@('BASICO_175/75_OF03',$VIG,'CAPECA 1er Oficial Sep 2023',213025, '', 0,'Actualizar con paritaria vigente'))
# ── Precios diarios 729/15 (fuente: tp bq-cnv-categ.csv, Congelador CG, Nov 2023) ──
# PRECIO_NAV (navegacion)
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR00',$VIG,'Nav CG Primer Pescador Nov 2023',   174286,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR01',$VIG,'Nav CG Contramaestre Nov 2023',     148143,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR02',$VIG,'Nav CG Primer Cocinero Nov 2023',   148143,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR03',$VIG,'Nav CG Mozo Nov 2023',              139429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR04',$VIG,'Nav CG Engrasador Nov 2023',        130714,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR05',$VIG,'Nav CG Marinero Cubierta Nov 2023', 130714,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR06',$VIG,'Nav CG Enfermero Nov 2023',         139429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR07',$VIG,'Nav CG Cmaestre Frio Nov 2023',     139429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_NAV_729/15_MR08',$VIG,'Nav CG Marinero Planta Nov 2023',   122000,'',0,'Congelador'))
# PRECIO_FRANCO (dias de franco)
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR00',$VIG,'Franco CG Primer Pescador Nov 2023',  418286,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR01',$VIG,'Franco CG Contramaestre Nov 2023',    355543,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR02',$VIG,'Franco CG Primer Cocinero Nov 2023',  355543,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR03',$VIG,'Franco CG Mozo Nov 2023',             334629,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR04',$VIG,'Franco CG Engrasador Nov 2023',       313714,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR05',$VIG,'Franco CG Marinero Cubierta Nov 2023',313714,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR06',$VIG,'Franco CG Enfermero Nov 2023',        334629,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR07',$VIG,'Franco CG Cmaestre Frio Nov 2023',    334629,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_FRANCO_729/15_MR08',$VIG,'Franco CG Marinero Planta Nov 2023',  292800,'',0,'Congelador'))
# PRECIO_ORDENES (dias a ordenes)
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR00',$VIG,'Ordenes CG Primer Pescador Nov 2023', 261429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR01',$VIG,'Ordenes CG Contramaestre Nov 2023',   222214,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR02',$VIG,'Ordenes CG Primer Cocinero Nov 2023', 222214,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR03',$VIG,'Ordenes CG Mozo Nov 2023',            209143,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR04',$VIG,'Ordenes CG Engrasador Nov 2023',      196071,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR05',$VIG,'Ordenes CG Marinero Cub Nov 2023',    196071,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR06',$VIG,'Ordenes CG Enfermero Nov 2023',       209143,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR07',$VIG,'Ordenes CG Cmaestre Frio Nov 2023',   209143,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_ORDENES_729/15_MR08',$VIG,'Ordenes CG Marinero Planta Nov 2023', 183000,'',0,'Congelador'))
# PRECIO_PUERTO (dias de puerto)
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR00',$VIG,'Puerto CG Primer Pescador Nov 2023', 504034,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR01',$VIG,'Puerto CG Contramaestre Nov 2023',   428429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR02',$VIG,'Puerto CG Primer Cocinero Nov 2023', 428429,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR03',$VIG,'Puerto CG Mozo Nov 2023',            403227,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR04',$VIG,'Puerto CG Engrasador Nov 2023',      378026,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR05',$VIG,'Puerto CG Marinero Cub Nov 2023',    378026,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR06',$VIG,'Puerto CG Enfermero Nov 2023',       403227,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR07',$VIG,'Puerto CG Cmaestre Frio Nov 2023',   403227,'',0,'Congelador'))
[void]$d.Add([object[]]@('PRECIO_PUERTO_729/15_MR08',$VIG,'Puerto CG Marinero Planta Nov 2023', 352824,'',0,'Congelador'))
# PRECIO_INCENT (incentivo a la produccion diario — valores 2014, revisar)
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR00',$VIG,'Incent CG Primer Pescador',  2142.85,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR01',$VIG,'Incent CG Contramaestre',    1821.42,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR02',$VIG,'Incent CG Primer Cocinero',  1821.42,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR03',$VIG,'Incent CG Mozo',             1714.28,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR04',$VIG,'Incent CG Engrasador',       1607.14,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR05',$VIG,'Incent CG Marinero Cub',     1607.14,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR06',$VIG,'Incent CG Enfermero',        1714.28,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR07',$VIG,'Incent CG Cmaestre Frio',    1714.28,'',0,'CG 2014 - revisar'))
[void]$d.Add([object[]]@('PRECIO_INCENT_729/15_MR08',$VIG,'Incent CG Marinero Planta',  1500,   '',0,'CG 2014 - revisar'))
# ── PCT_CUOTA_SIND por CCT/Categoria (fuente: sindicato.csv, concepto 622) ──
# 729/15 - SOMU: 4%
foreach ($cat in @('MR00','MR01','MR02','MR03','MR04','MR05','MR06','MR07','MR08')) {
    [void]$d.Add([object[]]@("PCT_CUOTA_SIND_729/15_$cat",$VIG,"SOMU 4% $cat",0.04,'',0,'SOM - Sind. Obreros Maritimos Unidos'))
}
# 175/75 - ASO: 3%
foreach ($cat in @('OF01','OF02','OF03','OF04','OF05')) {
    [void]$d.Add([object[]]@("PCT_CUOTA_SIND_175/75_$cat",$VIG,"ASO 3% $cat",0.03,'',0,'ASO - Capitanes y Patrones Pesca'))
}
# 768/19 - CAP: 2,5%
foreach ($cat in @('OF01','OF02','OF03','OF04','OF05')) {
    [void]$d.Add([object[]]@("PCT_CUOTA_SIND_768/19_$cat",$VIG,"CAP 2.5% $cat",0.025,'',0,'CAP - Capitanes Ultramar AACPyPP'))
}
# 130/75 - FEC: 2,5%
[void]$d.Add([object[]]@('PCT_CUOTA_SIND_130/75_EC01',$VIG,'FEC 2.5% EC01',0.025,'',0,'FEC - Federacion Empleados Comercio'))
# 372/04 - STIA Pto Madryn (STI): 2%
foreach ($cat in @('CA02','CA05','CA07','CA08','CA09','CA10')) {
    [void]$d.Add([object[]]@("PCT_CUOTA_SIND_372/04_$cat",$VIG,"STI 2% $cat",0.02,'',0,'STI - STIA Pto Madryn'))
}
Write-SheetFromList $xl 'Parametro Vigente' @('Cod. Parametro','Vigencia Desde','Descripcion Version','Valor','Moneda','En Uso','Notas') $d '2E75B6' | Out-Null
Write-Host "  Parametro Vigente: $($d.Count) filas"

# ── 5. Variable Sistema Liq. ─────────────────────────────────────────
$d = New-Object System.Collections.ArrayList
[void]$d.Add([object[]]@('ANIOS_ANTIGUEDAD','ANIOS_ANTIGUEDAD','Anios de antiguedad del empleado',1))
[void]$d.Add([object[]]@('DIAS_HAB',        'DIAS_HAB',        'Dias habiles (Lun-Vie) del periodo',1))
[void]$d.Add([object[]]@('PCT_ESCALA',      'PCT_ESCALA',      'Escala % de la categoria CCT / 100 (de tabla Categoria CCT)',1))
[void]$d.Add([object[]]@('DIAS_PROYECTO',   'DIAS_MAR',        'Dias del proyecto (Fecha Fin - Fecha Inicio)',1))
[void]$d.Add([object[]]@('DEDUC_GANANCIAS', 'DEDUC_GANANCIAS', 'Deduccion ganancias 4ta: cargas de familia + SIRADIG (anual)',1))
Write-SheetFromList $xl 'Variable Sistema Liq.' @('Cod. Calculo','Nombre Variable','Descripcion','Activo') $d '2E75B6' | Out-Null

# ── 6. Concepto Liquidacion ───────────────────────────────────────────
Write-Host "  Generando Concepto Liquidacion..."
$concHeaders = @('Codigo','Vigencia Desde','Descripcion','Nombre Impresion','Tipo Concepto','Formula','Condicion','Orden Calculo','Aplica A','Activo','Es Acumulador','Aplica Tipo Liq.')
$concRows = New-Object System.Collections.ArrayList
foreach ($a in $ACUMULADORES) {
    [void]$concRows.Add([object[]]@($a[0], $VIG, $a[1], '', $a[2], '', '', 0, 'Todos', 1, 1, ' '))
}
foreach ($c in $CONCEPTOS) {
    $tipoDesc = $TIPO_MAP["$($c[2])"]
    $nombre = "$($c[1])"
    $nombre50 = if ($nombre.Length -gt 50) { $nombre.Substring(0,50) } else { $nombre }
    $formula = "$($c[23])"
    [void]$concRows.Add([object[]]@($c[0], $VIG, $c[1], $nombre50, $tipoDesc, $formula, '', $c[4], 'Todos', $c[5], 0, $c[3]))
}

$wsCon = Write-SheetFromList $xl 'Concepto Liquidacion' $concHeaders $concRows '375623'
$tipoColors = @{
    'Haber Remunerativo'     = HexToLong 'E2EFDA'
    'Haber No Remunerativo'  = HexToLong 'EBF3E8'
    'Descuento Empleado'     = HexToLong 'FCE4D6'
    'Retencion'              = HexToLong 'FCE4D6'
    'Seguridad Social'       = HexToLong 'FFF2CC'
    'Contribucion Patronal'  = HexToLong 'DAEEF3'
}
for ($r = 2; $r -le ($concRows.Count+1); $r++) {
    $tv = $wsCon.Cells.Item($r,5).Value2
    $col = if ($tipoColors.ContainsKey("$tv")) { $tipoColors["$tv"] } else { HexToLong 'FFFFFF' }
    $wsCon.Range($wsCon.Cells.Item($r,1), $wsCon.Cells.Item($r,$concHeaders.Count)).Interior.Color = $col
}
Write-Host "  Conceptos: $($concRows.Count) filas ($($ACUMULADORES.Count) acum + $($CONCEPTOS.Count) conceptos)"

# ── 7. Concepto CCT Vigente ───────────────────────────────────────────
$cctRows = New-Object System.Collections.ArrayList
foreach ($c in $CONCEPTOS) {
    $flags = @([int]$c[6],[int]$c[7],[int]$c[8],[int]$c[9],[int]$c[10],[int]$c[11],[int]$c[12])
    $applies = @(); for ($i=0; $i -lt 7; $i++) { if ($flags[$i] -eq 1) { $applies += $CCT_CODES[$i] } }
    if ($applies.Count -lt 7) {
        foreach ($cct in $applies) { [void]$cctRows.Add([object[]]@($c[0], $VIG, $cct)) }
    }
}
Write-SheetFromList $xl 'Concepto CCT Vigente' @('Cod. Concepto','Vigencia Desde','Cod. Convenio') $cctRows '7030A0' | Out-Null
Write-Host "  Concepto CCT Vigente: $($cctRows.Count) filas"

# ── 8. Fraccion Acumulador ────────────────────────────────────────────
$fracRows = New-Object System.Collections.ArrayList
foreach ($c in $CONCEPTOS) {
    $tipoK = "$($c[2])"
    $prim = $PRIMARY_ACC[$tipoK]
    if ($prim) { [void]$fracRows.Add([object[]]@($c[0], $VIG, $prim, 100, 'Acumulador principal')) }
    if ($tipoK -eq 'HR' -or $tipoK -eq 'HN') {
        $accFlags = @([int]$c[13],[int]$c[14],[int]$c[15],[int]$c[16],[int]$c[17],[int]$c[18],[int]$c[19],[int]$c[20],[int]$c[21],[int]$c[22])
        for ($i=0; $i -lt 10; $i++) {
            if ($accFlags[$i] -eq 1) {
                [void]$fracRows.Add([object[]]@($c[0], $VIG, $ACC_NAMES[$i], 100, "Base $($ACC_NAMES[$i])"))
            }
        }
    }
}
Write-SheetFromList $xl 'Fraccion Acumulador' @('Cod. Concepto','Vigencia Desde','Cod. Acumulador','Porcentaje','Descripcion') $fracRows '7030A0' | Out-Null
Write-Host "  Fraccion Acumulador: $($fracRows.Count) filas"

# ── 9. Tabla Escalonada ───────────────────────────────────────────────
$d = New-Object System.Collections.ArrayList
[void]$d.Add([object[]]@('TAB_IMP_4CAT',$VIG,'Impuesto Ganancias 4ta Categoria'))
Write-SheetFromList $xl 'Tabla Escalonada' @('Codigo','Vigencia Desde','Descripcion') $d 'C55A11' | Out-Null
$d = New-Object System.Collections.ArrayList
[void]$d.Add([object[]]@('TAB_IMP_4CAT',$VIG,1,0,0,0,0,'Completar con tabla AFIP vigente'))
Write-SheetFromList $xl 'Tabla Escalonada Det.' @('Codigo','Vigencia Desde','No. Tramo','Limite Inferior','Limite Superior','Monto Fijo','Porcentaje','Descripcion') $d 'C55A11' | Out-Null

# ── Finalize ──────────────────────────────────────────────────────────
$wb.Worksheets.Item('__temp__').Delete()
$wb.Worksheets.Item('INSTRUCCIONES').Activate()
if (Test-Path $OUTPUT) { Remove-Item $OUTPUT -Force }
$wb.SaveAs($OUTPUT, 51)
$wb.Close($false)
$xl.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
[System.GC]::Collect()

Write-Host ""
Write-Host "Generado: $OUTPUT"
