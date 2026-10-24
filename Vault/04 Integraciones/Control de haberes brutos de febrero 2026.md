---
tipo: proceso
tags: [meta4, conciliacion, haberes, vigencias, vacaciones, licencias]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Tables/Tab110038.NovedadLiquidacion.al]
actualizado: 2026-10-15
---

# Control de haberes brutos de febrero 2026

Revisión limitada a parametrización de conceptos, fuentes de datos, parámetros y novedades originales de Meta4. No se agregaron objetos AL, campos ni tablas. No se cambió la versión de la aplicación ni se publicaron objetos.

Los datos personales, importes y respaldos están fuera del vault, en la evidencia privada de la intervención. Ver también [[prevuelo-febrero-2026-migracion-meta4]] y [[Hallazgos abiertos]].

## Último corte tras la publicación informada por el usuario (15/10/2026)

La nueva captura estable contiene los mismos 486 documentos, todos Calculados; el cierre que
fallaba por saldo FIFO ya tomó el saldo a su fecha. Enero conserva sus 570 cabeceras y las marcas
verificadas anteriores. Los totales cuadran con las líneas y los controles globales de residuos y
de cuenta corriente no encontraron anomalías. La revisión fue exclusivamente de lectura.

Contra la misma importación Meta4, entre 339 empleados comparables las diferencias de bruto
superiores a una unidad monetaria bajaron de 77 a 25: 52 cerraron y no aparecieron nuevas. Los
34 casos de los patrones repetidos anteriores ya concilian por corrida al centavo: feriado,
navegación, puerto y los adicionales contrastados. No se atribuye esa mejora automáticamente al
arreglo FIFO: hubo nuevos recálculos, y esta captura no compara todas las fuentes y parámetros.

Quedan 25 brechas de bruto: siete de producción/grossing de oficiales, siete de Tierra, cinco de
enfermedad, dos de vacaciones, dos de finales, una de guardia/mecánica y una de producción. Otros
cinco casos tienen bruto conciliado pero requieren revisar su composición: cuatro compensaciones
1534/2003 y un residual de 4125 que puede ser de mapeo. No se consideran errores confirmados de
fórmula. Los auxiliares de horas, SUAF y aportes virtuales de SAC se mantienen separados de los
haberes pagados al revisar el detalle; las diferencias exclusivas de redondeo se informan aparte.

Los apartados siguientes conservan el diagnóstico y planes anteriores. No reaplicar esos planes
sobre los casos que ahora concilian sin releer la configuración y las fuentes vigentes.

## Verificación posterior al recálculo del usuario (15/10/2026)

La captura estable posterior contiene los mismos 486 documentos de febrero: 485 Calculados y un
cierre de marea todavía en Borrador. Se recalcularon 62 de los 63 destinos directos previstos;
los cambios relevantes de bruto están dentro de ese alcance. El cierre pendiente conserva su
resultado anterior y todavía no incorporó el auxiliar de precio original de feriado, cuya
configuración y carga ya estaban preparadas: requiere calcularlo, sin duplicar el precio.

Las cabeceras cuadran con las líneas. Los censos globales inicial y final no encontraron líneas
de prueba, huérfanas ni variables de los 54 códigos sintéticos originales. Las 570 cabeceras de
enero y las marcas de las ocho tablas de los 41 recibos reparados coinciden con la validación
estable anterior. La revisión fue sólo en lectura; no ejecutó pruebas ni cálculos. Este control
de consistencia y del efecto del recálculo no certifica todavía el cierre de febrero contra Meta4.

El cotejo offline contra la misma importación histórica de Meta4 conserva 339 empleados
comparables. Las diferencias de bruto mayores a una unidad monetaria bajaron de 111 a 77:
34 quedaron resueltas y no aparecieron nuevas en ese umbral. No se consultó ni reimportó Oracle
para este corte; las diferencias menores al umbral y las causas aún abiertas siguen requiriendo
revisión.

### Revisión por concepto posterior

El saldo mensual no alcanza para dar por conciliados los conceptos: puede compensar navegación
de más con puerto de menos. Se identificaron dos causas repetidas, sin aplicar nuevas correcciones:

- **Feriados en puerto previo al zarpe:** quince empleados de los grupos repetidos tienen un
  feriado omitido en el devengado. Sus cierres ya concilian. El estado PS/PL queda antes de la
  fecha de inicio del proyecto: la cuenta de marea lo recorta y la de guardia lo excluye por
  transcurrir en marea. El modelo de usar los feriados de cobertura cambiaría 28 de los 90
  devengados; los otros 62 conservan la cantidad. En 27 se cotejaron cantidad, precio e importe
  originales al centavo. El restante no tiene las salidas originales de feriado en la corrida
  importada y queda sin certificar. El historial local muestra PS en el feriado y sólo estados
  PS/NV, GP o PL, sin AU1/AU9, pero no es una nueva foto de estados: no aplicar la sustitución
  sin refrescar las guardas ni presentar este modelo como prueba del SAC o grossing-up efectivo.
- **Reparto navegación/puerto:** otros diecinueve empleados tienen diferencias compensadas en
  38 corridas. El reparto candidato reproduce navegación y puerto con los precios actuales;
  también recompone el adicional 1543. El plan debe incluir el incentivo 1547, que sigue usando
  directamente `DIAS_PROYECTO`. La fórmula original de Meta4 vigente desde el 01/08/2025, consultada
  sólo en lectura, usa `@1011` como cantidad navegada. Dos casos arrastran categoría superior
  1603 por sus dependencias. No corregir estas diferencias mediante novedades compensatorias
  ni alterando el contexto de días que utiliza la cuenta corriente de francos.

Además hay cruces que deben depurarse en la comparación: auxiliares de horas de fin de semana
ya contenidos en las horas extras, el importe de maternidad a cargo de SUAF y aportes virtuales
de SAC aceptados del lado Meta4 mientras BC excluye los devengos. No atribuir automáticamente
esas filas a fórmulas salariales incorrectas. El catálogo actual no cambió respecto al utilizado
en el diagnóstico. Las propuestas deben conservar enero y verificarse por concepto, cantidad,
base y tratamiento remunerativo/no remunerativo, además del bruto total.

## Novedades aplicadas

Se cargaron **tres novedades originales de febrero**: dos importes originales de `1583` y un cero explícito de `2073`. Quedaron pendientes, sin asociarse a recibos calculados. La presencia de esas incidencias evita reemplazar por una fórmula lo que en Meta4 es un dato real.

Se ensayó primero con rollback y se comprobó que no cambiaran cabeceras, líneas ni detalles de cálculo. Después de la carga definitiva se reinició `MicrosoftDynamicsNavServer$BC252` y se verificó su estado `Running`. La incorporación de las novedades requiere recalcular sus documentos de febrero; no se recalcularon desde esta intervención. Antes de actuar, comprobar si otra sesión ya los incorporó.

## Histórico y orden de recálculo

La primera foto tenía enero mayormente en Borrador. `CargarAcumHistorico` y fuentes con `Estado<>0` excluyen esas líneas: las vacaciones y el grossing pueden perder enero aunque sus importes viejos sigan visibles.

Otra sesión recalculó enero y febrero. La foto coherente posterior contiene ambos meses calculados y reduce de 171 a 111 las diferencias de bruto superiores a un peso entre 339 empleados comparables de febrero. **Esa reducción corresponde al recálculo externo, no a las tres novedades recién cargadas.** Esas cantidades son un corte de diagnóstico y no certifican el cierre.

Antes de corregir una fórmula, comprobar la fecha de cálculo de sus dependencias y volver a tomar la traza vigente. No modificar filtros para incluir borradores ni fabricar novedades que compensen un histórico omitido.

El control mensual de enero de `1023`, sumando todas las corridas de cada empleado, no muestra diferencias superiores a un peso entre los 271 marítimos con línea BC. Las 113 bases de precio evaluables también coinciden con sus miembros finales dentro de la precisión del archivo. No hay evidencia de este control que justifique cambiar la fórmula de enero.

El usuario confirmó un criterio transitorio de reproducción de Meta4 hasta el **30/06/2026**, incluido el redondeo de francos por liquidación. Desde el **01/07/2026** corresponde el criterio ARB de redondear al pagar; esa frontera no se implementó en esta revisión de febrero. Para tres finales de enero se autorizaron novedades que reproducen la omisión de un feriado por calendario Meta4 desactualizado. Esa carga fue gestionada separadamente y no implica extender el mismo diagnóstico a otras finales ni reescribir lotes o consumos históricos.

## Parametrización aplicada y pendientes

| Tema | Regla demostrada | Estado |
|---|---|---|
| Básico personal | Meta4 tiene vigencias reales diferentes en enero, febrero y marzo. Conservar moneda y fronteras originales | Aplicadas las vigencias originales de febrero y marzo; enero intacto. Ensayo final con rollback y control posterior |
| Antigüedad | Meta4 suma las fases para el cálculo general y permite un porcentaje personal real `1048` | Aplicado desde febrero el parámetro opcional y auxiliar original `1048`, con vencimiento real y fallback. Ensayo final y 33 controles numéricos en el evaluador BC |
| Feriado marítimo | Meta4 tiene novedades reales del precio `1022`; las cantidades BC ya coinciden | Aplicados auxiliar original `1022`, nueva vigencia de `1023` desde febrero y 58 precios originales. Nueve fracciones conservadas; ensayo final y 70 controles numéricos BC |
| Enfermedad continuada | Meta4 conserva `PR_ENFERMEDAD.PRE_ENFER` de la licencia; no recalcula siempre el promedio | Cinco precios originales documentados, con ancla a cada inicio AU1 y seis fuentes para verificar anclas y tramos. Pasaron 42 pruebas numéricas BC; ensayo SQL y ejecución contextual de las fuentes pendientes |
| Maternidad | `4135` descuenta días AU3 comerciales sobre el total original `4040` y divisor mensual 30 | Fuente, composición y nueva vigencia preparadas; ensayo SQL pendiente |

El auxiliar de antigüedad debe estar en **orden 49**, antes del orden efectivo **50** de `1053` para Alimentación. `Variable Cantidad` admite 100 caracteres; usar el auxiliar evita exceder ese límite. El porcentaje opcional usa `-1` como ausencia de dato, de modo que un cero informado siga siendo un dato válido. Al vencer el porcentaje personal se vuelve al cálculo general.

Para maternidad se conserva el orden existente **620**: hay aportes coaplicables del `4040` que llegan después de 360, incluido `4121` a 615. La condición enumera los convenios mensualizados existentes y mantiene sus restricciones. No inferir ese alcance a partir de `TIPOEMPL=2`: el caso de Tierra revisado tiene escalar 1. Los miembros históricos dormidos del total no se reactivan por agregar su fracción.

El plan de maternidad sigue sin aplicar: debe conservar el SAC fiscal original. Meta4 excluye `4135` del total fiscal `3700`, aunque la deducción sí reduce las bases reales de Ganancias y aportes. El candidato consiste en restituir esa deducción negativa sólo en el numerador de `4750`; los aportes virtuales deben mantener su reducción. La regla del SAC de egreso administrativo es un pendiente distinto.

El precio de feriado `1022` es informativo y no integra bases. Su fórmula `-1` distingue ausencia de precio de un cero realmente informado. `1023` lee el valor materializado con `#1022`; cuando falta, ejecuta íntegra su fórmula previa. El auxiliar corre al inicio porque otros conceptos pueden reevaluar `1023` antes de su orden habitual. Cada novedad original se acota por empleado, período, tipo y proyecto; se exige un destino único y ausencia de incidencia previa. No se cambiaron los días ni el recibo de enero.

El precio de enfermedad sólo se usa cuando su vigencia coincide con el inicio de la última AU1; ante una licencia nueva se vuelve al promedio. No darlo de baja al día siguiente del fin: si termina dentro del mes, el parámetro se resuelve al cierre y esa baja quitaría el precio del mismo mes que debe pagarlo.

> [!warning] Límite del precio de enfermedad
> El motor agrega los días AU1 del mes. La propuesta bloquea más de un tramo relevante antes de usar un precio único y exige historia sin solapamientos al cargarla. Es una guarda conservadora: un cierre vacío con un estado posterior o una cobertura parcial puede bloquear un caso que requiere revisión. No identifica por sí sola episodios médicos ni impide que después se cargue una historia inválida.

## Causas que siguen abiertas

- **Feriado marítimo:** se rectificó el diagnóstico preliminar. Las diferencias aritméticas de `4451` no demostraban un momento especial del subtotal: existen precios originales informados en Meta4. La carga aplicada reproduce esos datos y conserva el cálculo general como fallback; falta el recálculo puntual para certificar resultados.
- **Navegación y puerto:** las ventanas equivalentes validan la conservación de días entre navegación, salida/llegada a puerto y guardia. El candidato usa la intersección calendario del historial PS/PL y conserva GP una sola vez. Se comprobaron algebraicamente el bruto completo y las bases de los oficiales con grossing; queda pendiente ejecutar la convergencia en un recálculo autorizado. No se modificaron horas de los proyectos ni estados, y enero conserva su fórmula.
- **Guardia y mecánica:** el factor original depende del indicador `2041`, con novedades auténticas documentadas. Meta4 resta el subtotal específico `1990`, que excluye sueldo de órdenes, y admite la categoría de máquinas que falta en la restricción de `2073`. El candidato copia `1990` como suma informativa antes de `2013`, sin fracciones nuevas. Sus miembros existentes reproducen las cuatro bases de GP coaplicables de febrero; los dos códigos aún no migrados tienen importe original cero en enero y febrero. Sigue sin ensayo SQL ni aplicación. No extender un coeficiente personal a todos los empleados por coincidencia de convenio.
- **Vacaciones:** una diferencia proviene de historia de accidente omitida en el promedio de un mes anterior; otra tiene más unidades pagadas en la salida Meta4 que días de goce en sus estados, sin novedad original que respalde esa cantidad. No alterar el goce ni cargar una cantidad artificial.
- **SAC administrativo:** Meta4 usa mejor remuneración mensual completa y días calendario; el total `3601` no está conservado en el histórico BC y hace falta recortarlo al vínculo actual. No sustituirlo por un básico que sólo coincida en el caso testigo.
- **Básico en moneda extranjera:** hay una diferencia de cotización. Conservar el contrato en su moneda y demostrar la fecha y fuente de TC antes de parametrizar.

## Estado de la aplicación

La conexión directa del 15 de octubre restableció SQL integrado y Oracle de sólo lectura. La foto coherente anterior a los cambios tenía 111 diferencias entre 339 empleados comparables. Esa cifra es histórica: no mide el resultado de las cargas nuevas.

Después se reabrió febrero y otra sesión inició un nuevo recálculo de enero. La observación de las 14:37 UTC todavía mostraba actividad, enero parcialmente recalculado y febrero en Borrador. Las novedades cargadas seguían pendientes en ese corte. No reutilizar esa foto como resultado final ni atribuir a esta intervención los cambios de recibos producidos por el usuario.

La lectura posterior confirmó enero completo y ambos meses sin actividad reciente; febrero seguía reabierto. Se tomó un respaldo coherente nuevo y la validación de archivos de AU1 volvió a pasar. Las escrituras y reinicios siguen coordinándose con la intervención paralela de avisos y variables; cualquier cambio posterior invalida el baseline que corresponda.

Se aplicaron básico, antigüedad y precios originales de feriado con ensayos finales de rollback, guardas de actividad y controles de conservación. Los recibos calculados no se modificaron ni recalcularon desde esta intervención. Los reinicios posteriores se controlan en la evidencia privada. Enfermedad y maternidad siguen preparadas sin aplicar; las pruebas numéricas del evaluador no se presentan como ejecución de fuentes o recibos completos.

La revisión adicional corrigió el identificador automático de filtros en el aplicador y añadió guardas de nombres entre catálogos. Sobre las copias privadas de configuración pasaron 81 controles de conservación de vigencias y fórmulas efectivas de enero. Esa validación no ejecuta las nuevas fuentes ni recibos en BC.

Los intentos de ensayo AU1 durante ese recálculo se interrumpieron por concurrencia y no dejaron una carga aplicada. Hay un respaldo parcial marcado como incompleto; no debe reutilizarse. El aplicador comprueba la actividad antes de tomar bloqueos y vuelve a comprobarla dentro de la transacción.

Para continuar: esperar una ventana sin actividad, repetir el respaldo y los ensayos de las revisiones finales pendientes, probar las nuevas fuentes en BC y aplicar únicamente cambios demostrados. El alcance ya aplicado reúne 63 documentos directos de febrero, sin duplicados; la lista privada separa otros documentos posteriores que sólo requieren revisar dependencias. Esa lista no es una orden de reapertura. Cotejar remunerativo/no remunerativo por concepto y preservar la parametrización de enero.
