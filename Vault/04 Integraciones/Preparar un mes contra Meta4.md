---
tipo: proceso
tema: migracion-meta4
tags: [meta4, migracion, prevuelo, operacion, parametros, auditoria]
fuente: [src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Tables/Tab60008.ParametroVigente.al, src/Tables/Tab110038.NovedadLiquidacion.al, src/Tables/Tab110005.AtributoEntidadLiq.al]
actualizado: 2026-10-21
---

# Preparar un mes contra Meta4

Preparar las entradas del próximo mes y conservar los meses ya liquidados. Este
procedimiento amplía el paso 0 de [[Flujo operativo mensual de liquidación]];
la creación, el cálculo y la aprobación continúan por ese flujo.

Durante el paralelo enero-junio de 2026 se busca reproducir Meta4 mediante las
fórmulas. Una diferencia aceptada, un acuerdo específico o una excepción temporal
deben quedar identificados con su alcance y vigencia. No extenderlos a otro mes
sin revisar su origen. Priorizar conceptos, fuentes, parámetros y atributos
existentes; una novedad debe conservar una entrada real o una diferencia de lógica
documentada. Ver [[un-valor-una-fuente]].

## 1 Definir el universo y el corte

Identificar las corridas originales por empresa, empleado, fase de alta, tipo,
contador, fecha de imputación y buque/marea. Separar pagos de anticipo de recibos
salariales y considerar las fronteras anterior y siguiente del mes. Comparar
claves normalizadas; un conteo mensual coincidente puede ocultar faltantes y dobles.

Guardar las extracciones originales y el plan privado en `.snapshots/`, por mes
y fecha de revisión. Cada cambio necesita clave destino, origen, valor anterior,
valor propuesto y motivo. El vault conserva reglas, resultados de control y enlaces;
los legajos, recibos e importes personales permanecen en los respaldos privados.

## 2 Contrastar entradas por dominio

| Dominio | Fuente Meta4 o respaldo | Control que debe resolver |
| --- | --- | --- |
| Fases y encuadre | `M4T_FASES_ALTA`, historiales de convenio, categoría y puesto | Vigencias, vínculo y catálogo BC resuelto para cada fecha. |
| Básicos y acuerdos | `M4T_VAL_CONVENIO_CATEGORIA`, `M4T_VAL_FASE_ALTA`, condiciones particulares | Precio contractual, moneda, TC y escalones; distinguir fijo y neto garantizado. |
| Novedades | `M4T_VAL_INCIDENCIA` y regla del concepto | Si cada valor significa importe, precio, cantidad o indicador; fecha, tipo y proyecto destino. |
| Anticipos | `M4T_CTA_CTE_ANTICIPOS` | Movimiento, préstamo y vencimiento; aplicación única y conservación de cuotas históricas. |
| Ausencias y vacaciones | `M4T_AUSENTISMOS`, estados y recibo original | Goce, pago, continuidad y cantidad del bloque completo. |
| Proyectos | `M4T_HIST_MAREAS`, `M4T_HIST_EST_BUQUE`, respaldo operativo | Inicio real, hora, primer PL de arribo, estados y asignaciones en fronteras. |
| Producción | `M4T_PROD_SUBMAREA`, `M4T_VAL_ESPECIE_PUESTO`, descargas NAV | Foto al corte, unidades, especies, puesto, parciales y calidad. |
| Fiscal y familia | Parámetros originales, historia familiar y fechas fiscales | Mensual contra mensual; acumulados reconstruidos con vigencias y composición de cada mes. |

Las salidas `M4T_ACUMULADO_RL*` y el recibo sirven para comprobar el resultado;
coincidir con una salida no acredita una entrada manual original. Un patrón de
importes tampoco alcanza para decidir que debe cargarse una novedad.

> [!warning] El mismo código puede tener otra unidad
> En abril, la incidencia Meta4 `1062` era un precio diario de franco, mientras
> el concepto BC `1062` devenga días. Copiar su importe como novedad generó días
> ficticios en la cuenta corriente y pagos finales enormes. Verificar la unidad
> de entrada y el rol configurado, además del número de concepto.

## 3 Resolver las trampas antes de cargar

- **Precios:** resolver primero convenio/categoría y aliases. Un cambio de categoría
  puede explicar el precio sin un nuevo básico personal. No convertir `PR_SUELDO`
  calculado en pesos en contrato fijo si hay divisa o grossing. En marzo los precios
  se encontraron en las dos tablas de valores; `HIST_DATOS_SALARIALES` no los aportó.
- **Puesto:** las tarifas de producción pueden usar `PUESTO`, diferente de la
  categoría salarial. Comparar el par efectivo antes de cambiar encuadre o tarifa.
  Ver [[puesto-vs-categoria-cct]] y [[equivalencia-id-puesto-meta4]].
- **Clasificación salarial:** comprobar el significado y la vigencia en
  `M4T_HIST_TIPOS_SALARIO`. No confundirlo con `M4T_HIST_TIPOS_EMPLEADO`, cuya
  clasificación de producción es otra taxonomía. Un mismo código numérico en
  ambos catálogos no acredita el mapeo a `TIPOEMPLEADO` de BC.
- **Zona:** distinguir zona fiscal de derecho al adicional. La regla original
  `2703` consulta `DATOS_INDIVID.ID_ZONAS_SUBSIDIO`, procedente de
  `M4T_HIST_ZONSUB_ST`; exige zonas `08`/`65` y convenios `FA`/`CA`/`JO`/`MA`,
  además de excluir SAC y anticipos. No toma `ID_ZONA_DGI` ni el domicilio.
  En BC, asignar un código fiscal positivo puede activar `2703` por
  `COD_ZONA > 0`. Cuando la historia y la regla acreditan que no corresponde,
  representar esa decisión salarial con `SIN_ADICIONAL`, número congelado cero,
  y la vigencia respaldada. Ese valor no certifica la zona fiscal/SICOSS.
- **Prima de acuerdos netos:** `PRIMA_VAC_GU` distingue absorción y pago por encima
  del neto. Su ausencia cae numéricamente a cero, pero no demuestra un acuerdo
  `ADENTRO`. Si Meta4 no tiene un indicador equivalente y el contrato no define
  el tratamiento, dejar la carga pendiente de confirmación y fecha; no copiar
  el valor de otros acuerdos ni deducirlo de un mes sin vacaciones.
- **Bonos:** revisar fórmula, condición, vigencia, fracciones, mapeo y tipos de
  corrida pagados. No agregar SAC, promedios o aportes por analogía. Distinguir una
  condición original de una decisión de parametrización tomada para reproducirla.
- **Precios informados:** cargar el precio del feriado con su destino acreditado,
  conservando los días. Comprobar el tratamiento de cero y ausencia del dato.
- **Anticipos:** distinguir ANP/ANL/ANH y sus descuentos de AHA amortizable (`8870`).
  Buscar un préstamo equivalente por sus condiciones y cuotas, además de la fecha
  de concesión. Importar sólo vencimientos conocidos. Anular una novedad redundante
  después de acreditar su cuota y destino; revisar saldos que pueda leer una
  `LIQ_FINAL` anterior. Ver [[Préstamos y cuotas]] y [[anticipos-cta-cte-meta4]].
  Para depurar duplicados, seguir [[novedad-duplicada-por-cuota-de-prestamo]].
- **Vacaciones:** conservar el goce. Distinguir importe informado, cantidad que la
  fórmula valoriza y cero explícito que evita pagar de nuevo. Comprobar que la
  fórmula consuma la cantidad; extender el análisis al bloque ya pagado en otro
  mes. Ver [[vacaciones-fraccionadas-meta4-paga-el-bloque]] y
  [[novedad-en-cero-no-apagaba-el-concepto]].
  Si hay precio manual original, reconstruir además el automático desde
  `TOT_PROMEDIOS` y contrastarlo con otra corrida automática compatible. En abril
  se acreditó una diferencia por precio informado `4056`: el automático de BC
  coincide con otro automático de Meta4. No cambiar la regla de promedio para
  reproducir esa excepción ni confundir `4056` con el precio de enfermedad `4057`.
- **Calendarios:** comprobar el efectivo por convenio/período. Si el paralelo exige
  una excepción, aislarla y conservar todas las otras reglas. Los calendarios
  copiados no se actualizan solos: revisar también sus reglas en el próximo mes.
  Una diferencia con Meta4 no demuestra por sí misma un error normativo.
- **Cobertura y fechas:** validar fase → estado → asignación, sin huecos ni solapes
  nuevos. `M4T_HIST_MAREAS.FEC_INI` puede incluir preparación anterior al zarpe. Comparar la
  población esperada con la alcanzable por la ruta de creación; usar empleado/
  asignación para presencia previa que excluya el filtro por inicio del proyecto.
  Una clasificación NV no permite inventar una hora real de zarpe.
  Revisar diariamente toda la población activa del período, también tierra y
  vínculos que no tienen marea. Distinguir `HIST_ESTADOS`, ausentismos, goce y pago:
  una contradicción entre fuentes no se corrige por mayoría. Un estado de
  vacaciones abierto puede ser obsoleto aunque el empleado tenga fase vigente.
  Para puerto posterior al arribo, revisar cobertura personal sin mover el arribo
  ni la fecha de valoración: ver [[dia-de-puerto-no-estira-la-marea]].
  Verificar también el destino efectivo de cada novedad al crear el mes: proyecto
  vacío puede inferir una marea que tiene cierre y excluirla del final de nómina,
  aunque la cantidad y el tipo sean correctos. En abril afectó a vacaciones no
  gozadas. Un tipo explícito evita el filtro de fecha, pero no el de proyecto.
- **Producción:** seleccionar la foto por fecha de fin y ventana/asignación; no sumar
  fotos anteriores y finales. Confirmar kg/tn y especies. Si el origen acredita un
  ajuste de calidad, aplicarlo por marea y puesto a la base pagable, conservando la
  descarga física. El efecto sobre el
  bruto depende también de mínimos y grossing; conservar los casos parciales.
- **Devengados anteriores:** comprobar alta, buque, marea, tipos y corte temporal.
  Comparar con la base original que se descuenta, distinguiendo importe pagado y
  piso reconstruido con días, precio y TC históricos. Una diferencia heredada del
  mes previo no demuestra selección incorrecta en el mes nuevo.
- **Familia y Ganancias:** comprobar entradas originales, fechas fiscales, porcentajes
  e incapacidades antes de corregir el maestro. No copiar una salida acumulada
  como deducción mensual ni multiplicar el maestro actual por los meses cuando
  cambió la historia. Una foto `FAM_HIST_M4` rige sólo su mes exacto: recuperar la
  original del nuevo mes en su unidad mensual, sin arrastrar enero. Ver
  [[ganancias-familiares-meta4-vs-recibo-historico]].
  `CalcDeduccionesGananciasAcum` reconstruye los meses previos desde el maestro
  familiar actual: restituir fechas anteriores o clasificar un cónyuge con alta
  anterior cambia futuros recálculos. Un alta realmente desde abril preserva enero
  a marzo, pero no recupera las deducciones anteriores del acumulado de abril.
  `FAM_HIST_M4` no protege ese acumulado ni las finales. Conservar las entradas
  históricas requiere dejar estos cambios pendientes hasta definir su alcance.
  Tampoco aislar gastos de una final mediante su día: las finales y regulares no
  arribo valoran al cierre del período. Un gasto del maestro puede entrar en ambas.
- **Descuentos y contribuciones:** distinguir cuota del empleado y costo patronal;
  un SSI con cuota cero puede generar costo por convenio. Ver [[sin-sindicato-paga-segun-convenio]].
  Contrastar fijo ART y ramas de detracción, además de las alícuotas; ver
  [[bases-contribuciones-patronales-meta4]]. Comprobar el orden cierre → devengado
  para que éste lea los acumulados fiscales actuales. Separar redondeo del bruto.

## 4 Aplicar conservando la historia

1. Con los meses protegidos libres de edición y cálculo, capturar filas completas
   y huellas ordenadas por clave, además de toda la configuración histórica.
   Si las guardas detectan actividad, obtener un corte estable sin restaurar los
   cálculos ajenos ni sustituir silenciosamente la referencia.
2. Revisar la versión vigente actual, incluso cambios posteriores a la preparación.
   Agregar vigencias y conservar las futuras. Comprobar fórmulas, cantidad,
   condición, orden, fracciones, restricciones y mapeos que correspondan.
3. Prevalidar en lectura claves, duplicados, columnas y tipos físicos. En SQL no
   asumir que una tabla `$ext` tiene la metadata de la tabla base. Mantener los
   invariantes que normalmente resuelve AL. Ver [[previsualizar-antes-de-migrar]].
4. Aplicar el plan respaldado con transacción y guardas; registrar claves reales y
   resultados. Las pruebas que crean recibos van en empresa/base aislada: un ensayo
   con rollback no sustituye ese aislamiento en la base operativa.
5. Comparar las filas tocadas, los invariantes y la selección efectiva de conceptos,
   parámetros, fracciones y restricciones en cada corte de los meses protegidos.
   Igual cantidad de cabeceras no prueba conservación: verificar también líneas,
   incidencias, variables, Ganancias, coberturas, francos, novedades y cuotas.
6. Tras SQL directo, renovar caché con una ventana libre y confirmar el servicio.
   Repetir el control histórico final. Ver [[sql-directo-deja-cache-rancia]].

## 5 Entregar el mes listo para calcular

Registrar por separado **preparado**, **aplicado**, **creado**, **calculado** y
**comparado**. La carga confirmada no certifica los importes del próximo mes.
Dejar las rutas de creación especiales, cuotas/novedades pendientes, excepciones
con vencimiento y controles posteriores de aplicación única y días cubiertos.

El registro mensual debe enlazar diagnóstico, plan privado, aplicación confirmada,
conservación histórica y diferencias pendientes. Incorporar al procedimiento las
reglas nuevas verificadas; mantener los importes y acuerdos particulares en privado.

## Ejemplos y evidencia de marzo

[[prevuelo-marzo-2026-meta4]] contiene el diagnóstico; el contraste de viajes,
cortes y tarifas está en [[marzo-2026-proyectos-fechas-produccion]]; las cargas y
su comprobación están en [[marzo-2026-cargas-aplicadas-meta4]]. El bono de marzo,
el 5 % de A28/61 y las excepciones de calendario son decisiones fechadas: no son
valores predeterminados para preparar los meses siguientes.

### Control diario de estados y puestos de marzo/abril (21/10/2026)

Se contrastaron 351 empleados activos y 19.999 días. Hay dos vacaciones abiertas
en BC que Meta4 terminó en enero, corregidas con autorización el mismo día;
las excepciones ya
aceptadas de franco/órdenes y la contradicción histórica de otro caso se conservan.
No hay diferencias pendientes de navegación/puerto en los estados de ese alcance.

En puestos hay 294 coincidencias marítimas, un acuerdo individual documentado
que usa un puesto diferente al orgánico de Meta4 y 56 empleados de tierra o DES
para quienes no corresponde exigir un puesto marítimo. No se acreditaron faltantes
ni solapes de PUESTO; los días de navegación/puerto tienen asignación al proyecto.
Puesto y categoría salarial siguen siendo ejes independientes. Este control no
certifica la historia anterior ni posterior al rango revisado.

La revisión y el contraste inicial del precio manual de vacaciones fueron sólo lectura.
Evidencia privada:
`.snapshots/correccion-puerto-vacaciones-estados-puestos-20261021/`, subcarpetas
`historias/`, `puestos/` y `vacaciones/`.

### Aplicación autorizada de estados y precio informado (21/10/2026)

Tras la autorización se cerraron las dos vacaciones al 04/01/2026 y se insertaron
sus retornos ACT desde el 05/01, abiertos y en el mismo proyecto de nómina. No se
alteraron los estados anteriores, las fases ni los puestos. La novedad existente
de vacaciones no gozadas de abril conserva cantidad, fecha, tipo y destino; se
completaron `Valor Unitario` e `Importe` con el precio manual original. Cargar ambos
mantiene también el precio mostrado en el futuro recibo; el importe informado
reemplaza la fórmula, sin multiplicarse nuevamente por la cantidad.

La carga conservó el estado Pendiente y no creó otra novedad ni incidencias.
No se ejecutaron cálculos ni se modificaron fórmulas. Las guardas detectaron
aprobaciones ajenas de enero terminadas durante la preparación; se conservaron y
se tomó un corte estable antes de aplicar. Desde ese corte las 11.633 cabeceras y
todas las tablas operativas salvo los dos destinos autorizados quedaron iguales.
También se cotejaron los demás registros de esas dos tablas, las cuatro capturas
completas de configuración y los campos precisos de las cinco filas afectadas.
BC252 se reinició tras la carga externa y quedó Running. Evidencia privada:
`.snapshots/aplicar-estados-vacaciones-20261021/`, planes, capturas originales,
aplicación con guardas e `integridad-final.json`.
