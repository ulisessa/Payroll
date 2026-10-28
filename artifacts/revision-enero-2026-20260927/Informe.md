**Revisión funcional y conciliación de enero de 2026 — Meta4 y Business Central**

La revisión encontró errores reales en el cálculo y en la selección de conceptos, pero también diferencias generadas por el comparador. Enero todavía no está conciliado. La prioridad es recuperar los cierres que fallaron, evitar el doble mensual entre Regular y Vacaciones y corregir la comparación del neto antes de ajustar importes.

Se revisaron el motor, la cobertura, el grossing-up, la aplicación de novedades y las dos páginas de comparación. Se contrastaron SQL Server, Oracle y recibos PDF puntuales. No se modificaron datos de negocio, configuración ni código, y no se ejecutaron recálculos. Los únicos archivos creados son este informe y su evidencia, cuya persistencia en el proyecto de OneDrive fue autorizada expresamente.

La extensión instalada y el proyecto declaran **1.0.0.524**. Coincidir en versión no constituye por sí solo una comparación binaria de los objetos publicados. La corrida examinada tiene **517 liquidaciones calculadas, 300 empleados**: 76 Cierre de Marea, 77 Devengados, 218 Regular y 146 Vacaciones. Oracle tiene **681 corridas de enero para 330 empleados**.

Se contrastaron contra Oracle los tres totales de las 681 corridas archivadas: **2.043 valores, sin diferencias**, normalizando nulo a cero. Las cinco diferencias aparentes de buque eran NULL en Oracle frente a texto vacío en BC. Esto valida los totales consultados y la atribución de marea de enero; no certifica todas las columnas de los 116 millones de valores históricos. No hay líneas HIST_REMUN fechadas en 2026.

Durante la revisión se observó un recálculo externo de LIQ-00029184, legajo 00291, a las 23:50 UTC del 27/9. Se incorporó al agregado final; los demás importes y conteos por liquidación permanecieron iguales a la precisión de 0,0001. La evidencia conserva ambas lecturas.

| Magnitud, sobre los mismos 300 empleados | BC | Meta4 | BC menos Meta4 |
|---|---:|---:|---:|
| Bruto | 1.934.067.905,64 | 1.765.897.258,87 | +168.170.646,77 |
| Descuentos | 623.740.488,52 | 580.475.444,44 | +43.265.044,08 |
| Neto | 1.310.327.417,12 | 1.207.406.046,00 | +102.921.371,12 |

Estos son **desvíos observados, no un monto de sobrepago certificado**: incluyen asimetrías de anticipos, corridas sin contraparte y duplicaciones. No deben sumarse a los importes de los hallazgos, que se superponen. En esta comparación mensual, 24 empleados tienen bruto dentro de un centavo; 79, dentro del 1%; 28 tienen neto dentro de un peso. Los 30 empleados de Meta4 sin cálculo BC quedan fuera de esos agregados y deben controlarse por separado.

**1. Prioridad alta: faltan 14 cierres porque el cálculo terminó con error, no por falta de fase de alta.**

Meta4 registra 90 cierres: 30 en A28/marea 59, 30 en HF801/marea 6 y 30 en HF802/marea 6. El registro de procesos de BC confirma **90 intentos, 76 completados y 14 errores “La fecha no es válida.”** Los errores coinciden exactamente con las 14 personas sin cierre en BC.

Todos tienen fase que cubre enero, asignación a su marea y estado NV durante la navegación. No corresponde resolver estos casos inventando otra alta. Los netos de esos 14 recibos de cierre de Meta4 suman **92.307.127**; es el importe de referencia sin contraparte, no un cálculo del motor BC ni un pago pendiente confirmado.

| Proyecto | Cierres Meta4 | Cierres BC | Legajos sin cierre |
|---|---:|---:|---|
| PP-128-000059 | 30 | 24 | 03664, 03772, 04105, 04913, 04914, 04915 |
| PP-801-000006 | 30 | 25 | 04830, 04836, 04839, 04840, 04841 |
| PP-802-000006 | 30 | 27 | 04586, 04826, 04838 |

La ruta sospechosa está localizada: [CalcDiasFeriadosGuardia](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50016.ContextoLiquidacion.al:1508>) recorre estados sin descartar los posteriores a la fecha de cálculo. Los 14 empleados tienen un último GP abierto iniciado entre abril y junio de 2026. Para ese estado, FechaFinEfectiva devuelve 31/12/9999; el bucle llega allí e incrementa otro día. Así, al liquidar enero se procesan estados futuros y una fecha fuera del rango admitido.

El vínculo causal es muy fuerte por código y coincidencia de toda la cohorte. El registro no conserva call stack y no se ejecutó una reproducción de fallo en producción: esa limitación debe mantenerse al describir el punto exacto del error.

Además, [BarrerVacias](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50018.ProcesoLiqPorLotes.al:483>) considera Borrador y elimina cabeceras sin líneas. Eso borra la liquidación que falló, aunque CalcularYDescartarSiVacia intenta conservarla. El error queda únicamente en el registro de procesos.

Acción propuesta: recortar feriados a la cobertura/período, ignorar estados futuros y proteger de la limpieza las liquidaciones con cálculo fallido. Validar primero un caso como 04826 y después los 14.

**2. Prioridad alta: Regular y Vacaciones pagan dos veces componentes del mensual.**

Hay **30 parejas de enero con concepto 1003 en ambos documentos**: 22 con cobertura parcial en Regular y 8 sin días disponibles para Regular. En 28 parejas el sueldo coincide exactamente; las otras dos aplican grossing-up. El patrón está medido en las 30; el exceso contra Meta4 se verificó individualmente en los ejemplos siguientes.

| Legajo | Evidencia |
|---|---|
| 90016 | Vacaciones ocupa 1–31/1 y paga neto 16.261.499,4125. Regular queda sin tramos y paga otros 16.261.499,5742. BC suma 32.522.998,9867 frente a 16.261.500 de Meta4. |
| 90251 | Vacaciones paga bruto 11.793.250, igual a Meta4. Regular sin tramos agrega 8.423.750. |
| 90184 | Vacaciones paga bruto 9.547.952,40, igual a Meta4. Regular sin tramos agrega 6.819.966. |
| 90282 | Vacaciones ya reproduce Meta4: 7.602.596,448 frente a 7.602.596,45. Regular cubre sólo 29–31/1 pero agrega básico completo y zona: 6.406.682,40. |
| 90355 | Vacaciones ya reproduce exactamente 6.592.894,74 de Meta4. Regular tiene diez días y vuelve a pagar el básico completo: 5.783.241. |
| 90302 | Vacaciones y Regular —esta última con tres días— convergen cada una a un neto de 3.540.000. BC termina prácticamente en el doble. |

Las causas se combinan:

- La fórmula de 1003 devuelve BASICO o COMPLEMENTO_GU sin proporcional por cobertura.
- Vacaciones tiene **Sólo Conceptos Declarados = false**. El mecanismo para restringir conceptos existe en [ConceptoAplicaATipoLiq](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50014.MotorLiquidacion.al:1071>), pero la configuración actual deja entrar conceptos generales.
- [ResolverNetoGarantizado](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50014.MotorLiquidacion.al:2119>) y ConvergerGrossingUp resuelven el objetivo completo por documento, sin compensar el mensual ya cubierto por la otra liquidación.
- [DiasEnLaVentana](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50016.ContextoLiquidacion.al:2372>) y DiaEnLaVentana interpretan cero tramos como período completo. El [motor](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50014.MotorLiquidacion.al:124>) continúa después de recalcular una cobertura vacía.

Los ocho Regular sin tramos suman 60.677.978,6781 de haberes, pero **no corresponde retirar automáticamente todo ese importe**. En 90035 y 90299, un AU9 abierto desde diciembre cubre todo enero para el reparto, mientras el contador de vacaciones lo limita al derecho y devuelve cuatro días: debe resolverse la inconsistencia de estado/retorno.

Tampoco se puede omitir toda liquidación sin tramos: existen **63 Vacaciones pagadas en enero cuyo disfrute empieza en febrero**. Son anticipos y no constituyen por sí solos un error. Dentro de ese grupo hay otros 22 empleados con 1003 en ambos documentos; su tratamiento requiere comprobar la regla de anticipo y la imputación.

Acción propuesta: definir y aplicar de forma consistente qué documento paga el mensual y qué documento paga el anticipo/plus de vacaciones. Acotar conceptos y objetivo de grossing-up por esa regla; corregir sólo el cálculo de días no resuelve la duplicación.

**3. Prioridad alta para la conciliación: el comparador añade el anticipo al neto de Meta4, pero compara contra el cierre de BC.**

En las tres mareas examinadas hay 76 anticipos TP4 por 250.000: **19.000.000 en total**. La página los suma al LIQUIDO de Meta4. BC, en cambio, aporta el neto de la cabecera de cierre y ya descuenta esos anticipos mediante 76 líneas 8840, también por 19.000.000.

Ejemplo 03753: cierre Meta4 5.175.079; cierre BC 5.175.078,8275. La página muestra Meta4 5.425.079 al sumarle el anticipo, creando una diferencia adicional falsa de 250.000.

Al comparar los mismos recibos, **43 de 76 casos quedan dentro de 1 peso en bruto, descuentos y neto**. Antes ninguno tenía neto dentro de ese margen. Quedan 33 cierres con alguna diferencia adicional; ese resultado no certifica toda la liquidación mensual.

La causa está en [Cargar, acumulación de neto](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Pages/Pag110051.CompararBCMeta4.al:571>): usa la misma selección para magnitudes con distintas reglas. Para comparar recibos de cierre, el neto debe excluir el pago previo TP4. **El bruto debe seguir recorriendo todas las corridas, incluidos los anticipos, para obtener los deltas correctos.** Filtrar TP4 al leer las cabeceras rompería el acumulado. Si se desea comparar todo el flujo pagado, debe incorporarse también el pago del anticipo del lado BC.

Por otra parte, [Sólo diferencias](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Pages/Pag110051.CompararBCMeta4.al:653>) filtra exclusivamente el bruto. En enero oculta ocho filas con diferencias de descuentos/neto, siete pequeñas compatibles con redondeo y una material: **90364, 750.000 de descuento faltante**.

**4. Oficiales: producción de empresa y novedades de otra marea explican tres déficits grandes.**

Se verificaron los recibos MAR del 13/1, páginas 16, 24 y 28, y las líneas BC. Los importes siguientes excluyen el pequeño redondeo del recibo.

| Legajo | Bruto Meta4/PDF | Bruto BC | Diferencia |
|---|---:|---:|---:|
| 04724 | 14.664.972,56 | 8.322.840,00 | −6.342.132,56 |
| 04837 | 24.793.612,00 | 20.717.885,97 | −4.075.726,03 |
| 04868 | 26.957.217,79 | 20.976.887,64 | −5.980.330,15 |

Navegación, art. 23 y premio CAPECA coinciden donde corresponde. El principal desvío está en **2003, cuenta de futuros aumentos**:

| Legajo | 2003 BC | 2003 PDF |
|---|---:|---:|
| 04724 | −2.833.032,56 | 4.722.640 |
| 04837 | 17.941.317,97 | 23.724.412 |
| 04868 | 7.232.044,85 | 14.805.478 |

Para 04724 está demostrada la falta de **PCT_PROD para 768/19, categoría OF03**, vigente en enero. PROD_EMPRESA usa 0% y sólo computa el componente USD: 6.900 × 1.405 / 30 × 22 = 7.109.300. Después 2003 resta 9.942.332,56 y queda negativo. El porcentaje correcto debe validarse contra el acuerdo; no inferirse por diferencia.

OF01 y OF02 sí tienen PCT_PROD = 2%, pero la combinación de porcentaje, USD, cambio y días tampoco reproduce el acuerdo pagado por Meta4. Su revisión queda pendiente.

También aparecen en esos cierres:

- 1003, sueldo mensual adicional de 1.162.000 / 900.000 / 1.485.000, ausente en los recibos MAR.
- 2013 por 51.540 / 820.568 / 108.103. Esos importes coinciden exactamente con los recibos **PUE del 6/1, marea 5, días 1–2 de enero**; BC los materializó en el cierre de la marea 6.
- En 04837 falta la antigüedad de 13.200 que figura en el recibo.

El neto requiere resolver también descuentos: 04724 tiene 8542 y 8543 en cero y sin fórmula frente a 879.898,35 y 36.662,43; falta además la cuota extraordinaria CAP de 325.247,99. En 04868, 8553 queda en cero y sin fórmula frente a 269.572,18 de Centro de Capacitación. Esto demuestra que corregir el bruto no basta.

**5. Dos diferencias adicionales ya atribuidas.**

**04047: aplicación adicional del concepto 3554 sobre una prestación ILT.** Las incidencias importadas de 4125 y 4165 suman exactamente 11.952.213,60, el bruto Meta4. BC agrega 3554 por **8.593.651,50**, que explica exactamente la diferencia bruta. Su condición vigente sólo pide REMUNERATIVO_BRUTO <> 0 y permite REGULAR; debe revisarse para no volver a generar la separación remunerativo/no remunerativo cuando la prestación ya llega separada. También modifica aportes y Ganancias.

Las fórmulas evaluadas de 4125/4165 no explican sus importes finales porque hay incidencias explícitas importadas que los sustituyen. Este es un ejemplo de por qué el diagnóstico debe revisar también las incidencias.

**90364: descuento 8870 presente como novedad, pero no aplicado.** Meta4 descuenta 750.000. BC tiene la novedad del período 202601 en Pendiente, proyecto PN-ADM-PTOMDY; la Regular calculada tiene proyecto vacío. [ProyectoAplica](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Codeunits/Cod50061.GestionNovedadesLiq.al:183>) exige igualdad cuando la novedad especifica proyecto. Por eso el bruto coincide y el neto BC queda 749.999,9703 por encima. La novedad existe: no corresponde volver a cargarla a ciegas.

Hay otras novedades de enero pendientes, entre ellas 8830 por 11,7 millones, 8850 por 5,55 millones y 8893 por 4,03 millones. No se suman como error confirmado: pueden pertenecer a personas sin liquidación, otra cobertura o reglas aún no verificadas.

**6. Riesgos funcionales secundarios y límites de la revisión.**

- El drilldown pierde descripciones: [Concepto.Get(CodCpt)](<C:/Users/ulises.sasovsky/OneDrive/Documentos/Proyectos/25.2/25.2 - Custom Extensiones/Payroll/src/Pages/Pag110052.DetalleCompMeta4.al:241>) omite Vigencia Desde de una clave compuesta. Los 47 conceptos con líneas comparables de enero carecen de versión con fecha cero. Debe resolver la versión vigente o usar la descripción de la línea.
- Un proyecto no interpretable como marea puede filtrar BC y dejar Meta4 sin filtro de marea. Validar el tipo de proyecto y su equivalencia antes de comparar.
- El reparto de cobertura toma tramos de liquidaciones reabiertas sin comprobar estado/prioridad; puede bloquear una reasignación de días.
- Feriados de marea usa fechas del proyecto sin recortar por incorporación/baja del empleado. Riesgo de pagar un feriado a un relevo que todavía no estaba a bordo; no se atribuyó un importe de enero a esta ruta.
- El control de cobertura todavía usa intervalos de cabecera, insuficientes para los nuevos tramos.
- El catálogo real tiene 1.813 columnas, 522 comparables y sólo dos mapeos verificados. El SAC verificado mencionado en el documento no está configurado así en la base actual. La colisión PRESENTISMO entre dos tablas no duplica importes en enero.
- Los snapshots Before/After de septiembre no demuestran equivalencia total: difieren los hashes de cabeceras, líneas y detalle de variables. Esto tampoco prueba por sí solo un cambio de importes, porque los hashes incluyen otros campos.

El cierre **04190 ya coincide**: bruto BC 6.299.341,224 frente a 6.299.341,22; descuentos 2.740.678,9168 frente a 2.740.678,91; la diferencia de neto es aproximadamente el redondeo de 0,69. La baja y el puerto de otra marea explican por qué una comparación mensual contra sólo ese cierre mostraba un déficit millonario.

No se atribuyó todavía cada diferencia de los 300 empleados. Quedan los 33 cierres residuales, los 16 empleados sin cálculo BC que no pertenecen al grupo de 14 errores, las reglas de anticipos de vacaciones de febrero y parte de los acuerdos/descuentos de oficiales. La validación de Oracle cubre los tres totales de enero, no todas las fórmulas de Meta4.

**Orden propuesto para corregir y validar**

1. Resolver el error de fechas y preservar los cálculos fallidos; recuperar los 14 cierres.
2. Corregir la simetría del neto y el filtro de diferencias para que la herramienta de validación sea confiable.
3. Definir la división mensual/Vacaciones y el objetivo de grossing-up; validar los casos 90016, 90251, 90184, 90282, 90355 y 90302 antes de extender al lote.
4. Completar PCT_PROD y descuentos verificados, corregir la imputación de novedades y la aplicación de 3554 en ILT.
5. Volver a comparar bruto, descuentos y neto por la misma unidad de empleado-mes o empleado-marea, preservando los 43 cierres que hoy ya concilian. El snapshot BC contra BC complementa esa prueba, pero no reemplaza la comparación contra Meta4.

La evidencia adjunta contiene la lectura inicial y final de BC, las 681 corridas Oracle, la comparación mensual y por marea, los 14 errores con sus estados y las 30 parejas de mensual duplicado. Los archivos contienen legajos e importes y deben tratarse como documentación salarial.
