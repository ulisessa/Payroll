# gen_rapidstart.ps1 — Genera ConfigPackage_Payroll.rapidstart (importable directo en BC)
# USAR: Paquetes de Configuracion → Nueva → "Importar paquete" → seleccionar el .rapidstart
# No requiere XML mapping en Excel.
$OUTPUT = Join-Path $PSScriptRoot 'ConfigPackage_Payroll.rapidstart'
$PKG_CODE = 'PAYROLL-25'
$PKG_NAME = 'Payroll BC 2023'
$VIG = '2023-12-01'   # ISO format YYYY-MM-DD para BC

# ── Enum maps ──────────────────────────────────────────────────────────
$TIPO_INT = @{ 'HR'=0; 'HN'=1; 'DE'=2; 'CP'=3; 'RE'=4; 'SS'=5 }
$TIPO_LIQ_INT = @{ ' '=0; ''=0; 'Regular'=1; 'Aguinaldo'=2; 'Vacaciones'=3;
                   'Liquidacion Final'=4; 'Reliquidacion'=5;
                   'Devengados'=6; 'Cierre Marea'=7 }
$CCT_CODES = @('175/75','768/19','729/15','ESP','130/75','372/04','ADM')
$ACC_NAMES = @('BASE_SS','BASE_OS','BASE_SINDICAL','BASE_LRT','BASE_IG4',
               'BASE_SAC','BASE_PROMEDIO','BASE_FERIADO','BASE_ZONA','BASE_AUSENTISMO')
$PRIMARY_ACC = @{ 'HR'='REMUNERATIVO_BRUTO'; 'HN'='NO_REMUNERATIVO';
                  'DE'='TOTAL_DESCUENTOS'; 'RE'='TOTAL_DESCUENTOS';
                  'SS'='TOTAL_DESCUENTOS'; 'CP'='TOTAL_CONTRIBUCIONES' }

# ── Acumuladores ──────────────────────────────────────────────────────
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
# Tuple: cod,nombre,tipo,aplica_tipo_liq,ord,activo, cct[7]:175,768,729,ESP,130,372,ADM,
#        acc[10]:SS,OS,SIND,LRT,IG4,SAC,PROM,FER,ZONA,AUSEN, formula
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

# ── XML Writer helpers ────────────────────────────────────────────────
# BC RapidStart XML uses PascalCase attribute names (TableID, FieldID, Value, Code, etc.)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ms   = New-Object System.IO.MemoryStream
$cfg  = New-Object System.Xml.XmlWriterSettings
$cfg.Indent = $true; $cfg.Encoding = [System.Text.Encoding]::UTF8
$xw = [System.Xml.XmlWriter]::Create($ms, $cfg)

function Attr($xw, $n, $v) { $xw.WriteAttributeString($n, "$v") }

function OpenTable($xw, $tid, $tname, $tord) {
    $xw.WriteStartElement('configpackagetable')
    Attr $xw 'TableID'                    $tid
    Attr $xw 'TableName'                  $tname
    Attr $xw 'PackageCode'                $PKG_CODE
    Attr $xw 'TableOrder'                 $tord
    Attr $xw 'ImportIntoApplicationType'  '0'
    Attr $xw 'DeleteOption'               '0'
    Attr $xw 'LoopActions'                '0'
    Attr $xw 'ProcessingOrder'            '0'
    $xw.WriteStartElement('configpackagefilter'); $xw.WriteEndElement()
}
function Field($xw, $fid, $fname) {
    $xw.WriteStartElement('configpackagefield')
    Attr $xw 'FieldID'              $fid
    Attr $xw 'FieldName'            $fname
    Attr $xw 'IncludeField'         '1'
    Attr $xw 'ValidateField'        '0'
    Attr $xw 'DimensionCode'        ''
    Attr $xw 'RelationTableFilter'  ''
    $xw.WriteEndElement()
}
function OpenData($xw) { $xw.WriteStartElement('configpackagedata') }
function Rec($xw, $no, $fids, $vals) {
    $xw.WriteStartElement('configpackagerecord')
    Attr $xw 'No' $no
    for ($i=0; $i -lt $fids.Count; $i++) {
        $xw.WriteStartElement('configpackagerecordfield')
        Attr $xw 'FieldID' $fids[$i]
        Attr $xw 'Value'   "$($vals[$i])"
        $xw.WriteEndElement()
    }
    $xw.WriteEndElement()
}
function CloseTable($xw) { $xw.WriteEndElement(); $xw.WriteEndElement() } # data + table

# ── XML Root ─────────────────────────────────────────────────────────
$xw.WriteStartDocument()
$xw.WriteStartElement('configurationpackages')
Attr $xw 'version' '22.00'   # BC 2023 wave 2
$xw.WriteStartElement('configurationpackage')
Attr $xw 'Code' $PKG_CODE
Attr $xw 'Name' $PKG_NAME

# ── Table 1: Convenio Colectivo (60004) ──────────────────────────────
$fids = @(1,2,3,4,6); $rows = @(
    @('175/75','CCT 175/75 Personal Embarcado Oficiales CAPECA','','',''),
    @('768/19','CCT 768/19 Personal Embarcado Oficiales AACPyPP','','',''),
    @('729/15','CCT 729/15 Personal Embarcado Marineria SOMU-CAPECA','','',''),
    @('ESP',   'Sin CCT - Personal Embarcado Espana','','',''),
    @('130/75','CCT 130/1975 Comercio','','',''),
    @('372/04','CCT 372/2004 STIA','','',''),
    @('ADM',   'Sin CCT - Personal Administrativo','','','')
)
OpenTable $xw '60004' 'Convenio Colectivo' '1'
Field $xw 1 'Codigo'; Field $xw 2 'Descripcion'; Field $xw 3 'No. CCT'; Field $xw 4 'Sindicato'; Field $xw 6 'Observaciones'
OpenData $xw; $n=1; foreach ($r in $rows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Convenio Colectivo: $($rows.Count) filas"

# ── Table 2: Categoria CCT (60006) ───────────────────────────────────
$fids = @(1,2,3,4,5)
$catRows = New-Object System.Collections.ArrayList
@('OF01','OF02','OF03','OF04','OF05') | ForEach-Object {
    $cats = @{ 'OF01'='Capitan'; 'OF02'='Jefe de Maquinas'; 'OF03'='Primer Oficial de Cubierta'; 'OF04'='Primer Maquinista'; 'OF05'='Segundo Oficial' }
    [void]$catRows.Add(@('175/75',$_,$cats[$_],100,''))
    [void]$catRows.Add(@('768/19',$_,$cats[$_],100,''))
}
$mrCats = @{ 'MR00'='Primer Pescador'; 'MR01'='Contramaestre'; 'MR02'='Primer Cocinero'; 'MR03'='Mozo'; 'MR04'='Engrasador'; 'MR05'='Marinero de Cubierta'; 'MR06'='Enfermero'; 'MR07'='Contramaestre de Frio'; 'MR08'='Marinero de Planta' }
foreach ($k in ($mrCats.Keys | Sort-Object)) { [void]$catRows.Add(@('729/15',$k,$mrCats[$k],100,'')) }
@(@('ESP','FE01','Patron de Pesca'),@('ESP','FE02','Garantia de Maquinas'),@('ESP','FE03','Contramaestre Espanol'),
  @('130/75','EC01','Maestranza - A'),
  @('372/04','CA02','Categoria 2'),@('372/04','CA05','Maestranza 1/2 Jornada'),
  @('372/04','CA07','Segundo Capataz'),@('372/04','CA08','Maquinista'),
  @('372/04','CA09','Maquinista Chubut'),@('372/04','CA10','Oficial Especializado'),
  @('ADM','ADM1','Administrativo Nivel 1'),@('ADM','ADM2','Administrativo Nivel 2')
) | ForEach-Object { [void]$catRows.Add(@($_[0],$_[1],$_[2],100,'')) }
OpenTable $xw '60006' 'Categoria CCT' '2'
Field $xw 1 'Cod. Convenio'; Field $xw 2 'Codigo'; Field $xw 3 'Descripcion'; Field $xw 4 '% Escala'; Field $xw 5 'Observaciones'
OpenData $xw; $n=1; foreach ($r in $catRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Categoria CCT: $($catRows.Count) filas"

# ── Table 3: Parametro (60016) ────────────────────────────────────────
$fids = @(1,2,3,4,5)
$paramRows = @(
    @('BASICO',       'Basico del convenio-categoria',    'Clave: BASICO_[CCT]_[CAT]',  'BASICO',          'true'),
    @('PRECIO_NAV',   'Precio diario de navegacion',      'Clave: PRECIO_NAV_[CCT]_[CAT]','PRECIO_NAV',   'true'),
    @('PRECIO_FRANCO','Precio diario de franco',          'Clave: PRECIO_FRANCO_[CCT]_[CAT]','PRECIO_FRANCO','true'),
    @('PRECIO_ORDENES','Precio dia a ordenes',            'Clave: PRECIO_ORDENES_[CCT]_[CAT]','PRECIO_ORDENES','true'),
    @('PRECIO_PUERTO','Precio dia de puerto',             'Clave: PRECIO_PUERTO_[CCT]_[CAT]','PRECIO_PUERTO','true'),
    @('PRECIO_INCENT','Incentivo produccion por dia',     'Clave: PRECIO_INCENT_[CCT]_[CAT]','PRECIO_INCENT','true'),
    @('PCT_CUOTA_SIND','Tasa cuota sindical',             'Varia por CCT',              'PCT_CUOTA_SIND',  'true'),
    @('SMVM',         'Salario Minimo Vital y Movil',     '','SMVM',                                       'false'),
    @('TC_COMPRADOR', 'Tipo de cambio comprador USD',     '','TC_COMPRADOR',                               'false'),
    @('TOPE_SIPA',    'Tope imponible SIPA jub/19032',    '60 MOPRES','TOPE_SIPA',                         'false'),
    @('TOPE_SIPA_OS', 'Tope imponible SIPA obra social',  '','TOPE_SIPA_OS',                               'false'),
    @('MNI_ANUAL',    'MNI anual Ganancias 4ta',          'ID 651 AFIP','MNI_ANUAL',                       'false'),
    @('DEDUCCION_ESP','Ded. especial anual Ganancias 4ta','ID 653 AFIP','DEDUCCION_ESP',                    'false'),
    @('PCT_ANTIG',    'Porcentaje antiguedad por anio',   '0.01 = 1%/anio','PCT_ANTIG',                    'false'),
    @('PCT_JUB',      'Aporte jubilacion empleado',       'ID 610 - 11%','PCT_JUB',                        'false'),
    @('PCT_19032',    'Aporte ley 19032 empleado',        'ID 612 - 3%','PCT_19032',                       'false'),
    @('PCT_OS',       'Aporte obra social empleado',      'ID 616 - 3%','PCT_OS',                          'false'),
    @('PCT_ADICIONAL_OS','Aporte adicional OS empleado',  'ID 618 - 1.5%','PCT_ADICIONAL_OS',              'false'),
    @('PCT_CONT_JUB',   'Contrib patronal jubilacion',       'ID 624 - 10.77%', 'PCT_CONT_JUB',   'false'),
    @('PCT_CONT_23660','Contrib patronal ley 23660 OS',    'ID 626 - 6%',     'PCT_CONT_23660', 'false'),
    @('PCT_CONT_19032','Contrib patronal ley 19032 INSSJP','ID 628 - 1.59%',  'PCT_CONT_19032', 'false'),
    @('PCT_ART',       'Contrib patronal ART porcentaje',  'ID 6090 - 5.51%', 'PCT_ART',        'false'),
    @('VALOR_ART_FIJO','Contrib patronal ART valor fijo',  'ID 6091/mes',     'VALOR_ART_FIJO', 'false')
)
OpenTable $xw '60016' 'Parametro' '3'
Field $xw 1 'Codigo'; Field $xw 2 'Descripcion'; Field $xw 3 'Notas'; Field $xw 4 'Nombre Variable'; Field $xw 5 'Sufijo CCT'
OpenData $xw; $n=1; foreach ($r in $paramRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Parametro: $($paramRows.Count) filas"

# ── Table 4: Parametro Vigente (60008) ────────────────────────────────
# Cols: Cod.Param, Vigencia, Descripcion, Valor, Moneda, En Uso, Notas
$fids = @(1,2,3,4,5,6,7)
$pvRows = New-Object System.Collections.ArrayList
# Globales
foreach ($r in @(
    @('SMVM',         $VIG,'SMVM Dic 2023',          '156000',       '','false','Res.15/2023'),
    @('TC_COMPRADOR', $VIG,"Vigente $VIG",            '0',            'USD','false','Completar con cotizacion del dia'),
    @('TOPE_SIPA',    $VIG,'Tope 60 MOPRES Dic 2023','1157112.83',   '','false','Res.ANSES 220/2023'),
    @('TOPE_SIPA_OS', $VIG,'Tope OS Dic 2023',        '1157112.83',   '','false','Mismo tope que SIPA'),
    @('MNI_ANUAL',    $VIG,'MNI anual 2023',          '451683.19',    '','false','ID 651 AFIP anual'),
    @('DEDUCCION_ESP',$VIG,'Ded.Especial anual 2023', '2168079.35',   '','false','ID 653 AFIP anual'),
    @('PCT_ANTIG',    $VIG,'1% por anio antiguedad',  '0.01',         '','false','LCT art.208'),
    @('PCT_JUB',      $VIG,'% Jubilacion empleado',   '0.11',         '','false','ID 610'),
    @('PCT_19032',    $VIG,'% Ley 19032 empleado',    '0.03',         '','false','ID 612'),
    @('PCT_OS',       $VIG,'% Obra Social empleado',  '0.03',         '','false','ID 616'),
    @('PCT_ADICIONAL_OS',$VIG,'% Adic OS empleado',   '0.015',        '','false','ID 618'),
    @('PCT_CONT_JUB',    $VIG,'% Contrib Jub patronal',     '0.1077', '','false','ID 624'),
    @('PCT_CONT_23660', $VIG,'% Contrib OS patronal',       '0.06',   '','false','ID 626'),
    @('PCT_CONT_19032', $VIG,'% Contrib 19032 patronal',    '0.0159', '','false','ID 628'),
    @('PCT_ART',        $VIG,'% ART sobre remuneracion',    '0.0551', '','false','ID 6090'),
    @('VALOR_ART_FIJO', $VIG,'ART valor fijo Dic 2023',     '418',    '','false','ID 6091 por emp/mes')
)) { [void]$pvRows.Add($r) }
# BASICO por CCT/Categoria
foreach ($r in @(
    @("BASICO_372/04_CA02",$VIG,'STIA Cat.2 Dic 2023',      '274180.88','','false',''),
    @("BASICO_372/04_CA05",$VIG,'STIA Maestranza 1/2 Dic23','191745.78','','false','50% cat1 STIA Chubut'),
    @("BASICO_372/04_CA07",$VIG,'STIA 2do Capataz Dic 2023','318814.95','','false',''),
    @("BASICO_372/04_CA08",$VIG,'STIA Maquinista Dic 2023', '321264',   '','false','Jornal cat4*200'),
    @("BASICO_372/04_CA10",$VIG,'STIA Of.Espec. Dic 2023',  '340540',   '','false','Jornal cat4*200+6%'),
    @("BASICO_130/75_EC01",$VIG,'Comercio Maestranza-A 2024','397394.90','','false','Res.ST 510/2008'),
    @("BASICO_175/75_OF01",$VIG,'CAPECA Capitan Sep 2023',   '250618',   '','false','Revisar con paritaria'),
    @("BASICO_175/75_OF03",$VIG,'CAPECA 1er Oficial Sep 2023','213025',  '','false','Revisar con paritaria')
)) { [void]$pvRows.Add($r) }
# Precios diarios 729/15 (Congelador CG, Nov 2023)
$mrCodes = @('MR00','MR01','MR02','MR03','MR04','MR05','MR06','MR07','MR08')
$navP = @(174286,148143,148143,139429,130714,130714,139429,139429,122000)
$fraP = @(418286,355543,355543,334629,313714,313714,334629,334629,292800)
$ordP = @(261429,222214,222214,209143,196071,196071,209143,209143,183000)
$puertP = @(504034,428429,428429,403227,378026,378026,403227,403227,352824)
$incentP = @(2142.85,1821.42,1821.42,1714.28,1607.14,1607.14,1714.28,1714.28,1500)
for ($i=0; $i -lt 9; $i++) {
    $cat = $mrCodes[$i]
    [void]$pvRows.Add(@("PRECIO_NAV_729/15_$cat",   $VIG,"Nav CG $cat Nov23",     "$($navP[$i])",   '','false','Congelador'))
    [void]$pvRows.Add(@("PRECIO_FRANCO_729/15_$cat",$VIG,"Franco CG $cat Nov23",   "$($fraP[$i])",   '','false','Congelador'))
    [void]$pvRows.Add(@("PRECIO_ORDENES_729/15_$cat",$VIG,"Ordenes CG $cat Nov23", "$($ordP[$i])",   '','false','Congelador'))
    [void]$pvRows.Add(@("PRECIO_PUERTO_729/15_$cat",$VIG,"Puerto CG $cat Nov23",   "$($puertP[$i])", '','false','Congelador'))
    [void]$pvRows.Add(@("PRECIO_INCENT_729/15_$cat",$VIG,"Incent CG $cat",         "$($incentP[$i])",'','false','2014 revisar'))
}
# PCT_CUOTA_SIND por CCT/Categoria
foreach ($cat in $mrCodes) { [void]$pvRows.Add(@("PCT_CUOTA_SIND_729/15_$cat",$VIG,"SOMU 4% $cat",'0.04','','false','SOM')) }
foreach ($cat in @('OF01','OF02','OF03','OF04','OF05')) { [void]$pvRows.Add(@("PCT_CUOTA_SIND_175/75_$cat",$VIG,"ASO 3% $cat",'0.03','','false','ASO')) }
foreach ($cat in @('OF01','OF02','OF03','OF04','OF05')) { [void]$pvRows.Add(@("PCT_CUOTA_SIND_768/19_$cat",$VIG,"CAP 2.5% $cat",'0.025','','false','CAP')) }
[void]$pvRows.Add(@('PCT_CUOTA_SIND_130/75_EC01',$VIG,'FEC 2.5%','0.025','','false','FEC'))
foreach ($cat in @('CA02','CA05','CA07','CA08','CA09','CA10')) { [void]$pvRows.Add(@("PCT_CUOTA_SIND_372/04_$cat",$VIG,"STI 2% $cat",'0.02','','false','STI Pto Madryn')) }

OpenTable $xw '60008' 'Parametro Vigente' '4'
Field $xw 1 'Cod. Parametro'; Field $xw 2 'Vigencia Desde'; Field $xw 3 'Descripcion'
Field $xw 4 'Valor'; Field $xw 5 'Moneda'; Field $xw 6 'En Uso'; Field $xw 7 'Notas'
OpenData $xw; $n=1; foreach ($r in $pvRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Parametro Vigente: $($pvRows.Count) filas"

# ── Table 5: Variable Sistema Liq. (60018) ────────────────────────────
$fids = @(1,2,3,4)
$vsRows = @(
    @('ANIOS_ANTIGUEDAD','ANIOS_ANTIGUEDAD','Anios de antiguedad del empleado','true'),
    @('DIAS_HAB',        'DIAS_HAB',        'Dias habiles (Lun-Vie) del periodo','true'),
    @('PCT_ESCALA',      'PCT_ESCALA',      'Escala % de la categoria CCT / 100','true'),
    @('DIAS_PROYECTO',   'DIAS_MAR',        'Dias del proyecto (Fecha Fin - Fecha Inicio)','true'),
    @('DEDUC_GANANCIAS', 'DEDUC_GANANCIAS', 'Deduccion ganancias 4ta anual (cargas de familia + SIRADIG)','true')
)
OpenTable $xw '60018' 'Variable Sistema Liq.' '5'
Field $xw 1 'Cod. Calculo'; Field $xw 2 'Nombre Variable'; Field $xw 3 'Descripcion'; Field $xw 4 'Activo'
OpenData $xw; $n=1; foreach ($r in $vsRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Variable Sistema Liq.: $($vsRows.Count) filas"

# ── Table 6: Concepto Liquidacion (60007) ─────────────────────────────
$fids = @(1,2,3,4,5,6,7,8,10,11,13,14)
$concRows = New-Object System.Collections.ArrayList
# Acumuladores
foreach ($a in $ACUMULADORES) {
    [void]$concRows.Add(@($a[0],$VIG,$a[1],'',$TIPO_INT[$a[2] -replace '[^A-Z]',''],'','',0,0,'true','true',0))
    # Tipo Concepto enum: map accumulator type name to int
    $ti = switch ($a[2]) { 'Haber Remunerativo' {0} 'Haber No Remunerativo' {1} 'Descuento Empleado' {2} 'Contribucion Patronal' {3} default {0} }
    $concRows[$concRows.Count-1][4] = $ti
}
# Conceptos
foreach ($c in $CONCEPTOS) {
    $ti   = $TIPO_INT["$($c[2])"]
    $tliq = $TIPO_LIQ_INT["$($c[3])"]
    $nom50 = if ("$($c[1])".Length -gt 50) { "$($c[1])".Substring(0,50) } else { "$($c[1])" }
    $activo = if ([int]$c[5] -eq 1) { 'true' } else { 'false' }
    [void]$concRows.Add(@($c[0],$VIG,$c[1],$nom50,$ti,$c[23],'', $c[4],0,$activo,'false',$tliq))
}
OpenTable $xw '60007' 'Concepto Liquidacion' '6'
foreach ($pair in @((1,'Codigo'),(2,'Vigencia Desde'),(3,'Descripcion'),(4,'Nombre Impresion'),(5,'Tipo Concepto'),(6,'Formula'),(7,'Condicion'),(8,'Orden Calculo'),(10,'Aplica A'),(11,'Activo'),(13,'Es Acumulador'),(14,'Aplica Tipo Liq.'))) {
    Field $xw $pair[0] $pair[1]
}
OpenData $xw; $n=1; foreach ($r in $concRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Concepto Liquidacion: $($concRows.Count) filas ($($ACUMULADORES.Count) acum + $($CONCEPTOS.Count) conceptos)"

# ── Table 7: Concepto CCT Vigente (60019) ─────────────────────────────
$fids = @(1,2,3)
$cctRows = New-Object System.Collections.ArrayList
foreach ($c in $CONCEPTOS) {
    $flags = @([int]$c[6],[int]$c[7],[int]$c[8],[int]$c[9],[int]$c[10],[int]$c[11],[int]$c[12])
    $applies = @(); for ($i=0; $i -lt 7; $i++) { if ($flags[$i] -eq 1) { $applies += $CCT_CODES[$i] } }
    if ($applies.Count -lt 7) {
        foreach ($cct in $applies) { [void]$cctRows.Add(@($c[0],$VIG,$cct)) }
    }
}
OpenTable $xw '60019' 'Concepto CCT Vigente' '7'
Field $xw 1 'Cod. Concepto'; Field $xw 2 'Vigencia Desde'; Field $xw 3 'Cod. Convenio'
OpenData $xw; $n=1; foreach ($r in $cctRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Concepto CCT Vigente: $($cctRows.Count) filas"

# ── Table 8: Fraccion Acumulador (60017) ──────────────────────────────
$fids = @(1,2,3,4,5)
$fracRows = New-Object System.Collections.ArrayList
foreach ($c in $CONCEPTOS) {
    $tipoK = "$($c[2])"
    $prim = $PRIMARY_ACC[$tipoK]
    if ($prim) { [void]$fracRows.Add(@($c[0],$VIG,$prim,100,'Acumulador principal')) }
    if ($tipoK -eq 'HR' -or $tipoK -eq 'HN') {
        $accFlags = @([int]$c[13],[int]$c[14],[int]$c[15],[int]$c[16],[int]$c[17],[int]$c[18],[int]$c[19],[int]$c[20],[int]$c[21],[int]$c[22])
        for ($i=0; $i -lt 10; $i++) {
            if ($accFlags[$i] -eq 1) { [void]$fracRows.Add(@($c[0],$VIG,$ACC_NAMES[$i],100,"Base $($ACC_NAMES[$i])")) }
        }
    }
}
OpenTable $xw '60017' 'Fraccion Acumulador' '8'
Field $xw 1 'Cod. Concepto'; Field $xw 2 'Vigencia Desde'; Field $xw 3 'Cod. Acumulador'; Field $xw 4 'Porcentaje'; Field $xw 5 'Descripcion'
OpenData $xw; $n=1; foreach ($r in $fracRows) { Rec $xw $n $fids $r; $n++ }
CloseTable $xw
Write-Host "  Fraccion Acumulador: $($fracRows.Count) filas"

# ── Table 9: Tabla Escalonada (60013) ─────────────────────────────────
$fids = @(1,2,3)
OpenTable $xw '60013' 'Tabla Escalonada' '9'
Field $xw 1 'Codigo'; Field $xw 2 'Vigencia Desde'; Field $xw 3 'Descripcion'
OpenData $xw; Rec $xw 1 $fids @('TAB_IMP_4CAT',$VIG,'Impuesto Ganancias 4ta Categoria')
CloseTable $xw

# ── Table 10: Tabla Escalonada Det. (60014) ───────────────────────────
$fids = @(1,2,3,4,5,6,7,8)
OpenTable $xw '60014' 'Tabla Escalonada Det.' '10'
foreach ($p in @((1,'Codigo'),(2,'Vigencia Desde'),(3,'No. Tramo'),(4,'Limite Inferior'),(5,'Limite Superior'),(6,'Monto Fijo'),(7,'Porcentaje'),(8,'Descripcion'))) { Field $xw $p[0] $p[1] }
OpenData $xw
Rec $xw 1 $fids @('TAB_IMP_4CAT',$VIG,1,0,0,0,0,'Completar con tabla AFIP vigente')
CloseTable $xw
Write-Host "  Tabla Escalonada: 1 cabecera + 1 det. placeholder"

# ── Close XML ─────────────────────────────────────────────────────────
$xw.WriteEndElement()  # configurationpackage
$xw.WriteEndElement()  # configurationpackages
$xw.Flush(); $xw.Close()

# ── Guardar XML plano (fallback) y ZIP (.rapidstart) ──────────────────
$xmlBytes = $ms.ToArray()

# 1. XML plano — en caso de que BC acepte XML directamente renombrado a .rapidstart
$xmlPath = [System.IO.Path]::ChangeExtension($OUTPUT, '.xml')
if (Test-Path $xmlPath) { Remove-Item $xmlPath -Force }
[System.IO.File]::WriteAllBytes($xmlPath, $xmlBytes)

# 2. ZIP con extensión .rapidstart — archivo interno nombrado como el código del paquete
$ms.Position = 0
$zipMS = New-Object System.IO.MemoryStream
$zip = New-Object System.IO.Compression.ZipArchive($zipMS, 1, $true)  # 1 = Create
$entry = $zip.CreateEntry("$PKG_CODE.xml")   # BC espera {PkgCode}.xml dentro del ZIP
$es = $entry.Open(); $ms.CopyTo($es); $es.Close()
$zip.Dispose()
if (Test-Path $OUTPUT) { Remove-Item $OUTPUT -Force }
[System.IO.File]::WriteAllBytes($OUTPUT, $zipMS.ToArray())
$ms.Dispose(); $zipMS.Dispose()

$sizeZip = [Math]::Round((Get-Item $OUTPUT).Length / 1KB, 1)
$sizeXml = [Math]::Round((Get-Item $xmlPath).Length / 1KB, 1)
Write-Host ""
Write-Host "Generados:"
Write-Host "  $OUTPUT ($sizeZip KB)  ← probar primero"
Write-Host "  $xmlPath ($sizeXml KB) ← si falla el .rapidstart, renombrar a .rapidstart e importar"
Write-Host ""
Write-Host "EN BC: Paquetes Configuracion → Nuevo (codigo: $PKG_CODE) → Importar Paquete"
