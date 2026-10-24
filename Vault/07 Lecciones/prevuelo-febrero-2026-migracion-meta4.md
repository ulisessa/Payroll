---
tipo: leccion
tags: [meta4, migracion, febrero, anticipos, atributos, salarios]
fuente: [scripts/MigrarPrevueloFebrero.ps1, src/Codeunits/Cod110067.MigrarFebreroMeta4.al, src/Tables/Tab110038.NovedadLiquidacion.al, src/Tables/Tab60008.ParametroVigente.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-12
---

# Prevuelo de febrero de 2026 contra Meta4

Revisión y carga en Migr2013R2/ArbuTest desde Oracle ARBPRO, completadas el 12/10/2026.
Aplicación **1.0.0.638** publicada; la carga se ejecutó mediante AL, sin SQL directo ni reinicio.
Febrero permanece Creado y sin liquidaciones. Fuentes, payload y respaldos privados en
`.snapshots/carga-febrero-20261012`; la auditoría previa está en
`.snapshots/auditoria-febrero-20261012/casos.json`.

## Cobertura confirmada

- Archivo literal: **624 corridas de 340 empleados** en febrero.
- Los 340 tienen ficha y fase de alta en BC. Revisión diaria del 01 al 28: cero días dentro de
  fases sin estado y cero estados con proyecto sin asignación vigente al inicio del tramo.
- **622 novedades** de febrero después de la carga; todas las nuevas tienen concepto vigente.
- Horas extras de tierra ya están cargadas: 10 novedades del 1803, 10 del 1813 y una del 1893.
  Las notas antiguas que las dan por pendientes no describen la situación actual.
- Hay vigencias del 01/02 para topes SIPA/obra social, deducciones y familia de Ganancias,
  precios de navegación/puerto/órdenes/francos y valores de grossing-up de marea.
- Febrero existe en estado **Creado**, calendario BASE; todavía no tiene liquidaciones.
  Enero tiene sus 570 liquidaciones Calculadas y debe alimentar los acumulados y francos de febrero.

## Carga aplicada

### Anticipos administrativos amortizables

Se crearon **tres préstamos** y se completó el existente, sin duplicarlo. Quedan **13 cuotas**
con los períodos e importes registrados en la cuenta corriente de Meta4; **cuatro** son de
febrero. Las dos cuotas históricas de enero quedan vinculadas a las liquidaciones Calculadas
que ya descontaron esos importes. No se marcaron Aplicadas por fuera del flujo de aprobación.
El concepto usado es el existente **8870**; no hay novedades 8870 duplicando esas cuotas.

Se conservan la concesión y el plan conocido, no sólo el resultado del recibo. En un préstamo,
la fuente sólo programa cuotas hasta junio y su suma es menor que la concesión: se dejó esa
limitación en Observaciones, sin inventar vencimientos para el saldo restante. La fila D de
importe cero de otro préstamo no se convirtió en una cuota cobrable. Ver [[anticipos-cta-cte-meta4]].

### Anticipos de haberes

Se agregaron **cuatro novedades 8850**: tres empleados sin novedad y un movimiento adicional
del empleado con suma diferente. BC queda con **135 novedades para 49 empleados**, y las sumas
por empleado coinciden con los 135 D de ANH de Meta4. Las 131 anteriores se conservaron.
TP1 se cargó en REGULAR sin proyecto; TP10 en CIERRE_MAREA y su proyecto verificado. Fecha de
imputación y concesión/fecha/ordinal originales quedan trazados; no se fusionaron movimientos.

### Convenio y categoría

Se corrigieron las categorías y padres de los dos casos detectados, incluido el tramo histórico
intermedio de categoría y el encuadre posterior de abril que estaba cruzado. Se creó la categoría
histórica CA12 con su descripción de Meta4. También se cargaron dos vigencias de categoría de
febrero detectadas al comparar valores, una de ellas responsable del cambio de básico.

Se cargaron **12 puestos de tierra** como atributo informativo de lista **PUESTO_META4**,
con cinco códigos y descripciones originales. No tiene variable ni espejo de cálculo: PUESTO
continúa siendo el eje de producción de a bordo. DES no se inventó como cargo. La comparación
de puestos debe normalizar vínculos/vigencias: filas abiertas de contratos antiguos no son
puestos actuales. Se conservó el override de producción de garantía documentado en
[[puesto-vs-categoria-cct]], y el puesto utilizado en el recibo histórico cuando diverge de una
modificación posterior del historial de Oracle.

### Básico personal

**La conclusión inicial de que faltaba un básico personal era incorrecta.** El cambio de
PR_SUELDO se origina en el paso de CA02 a CA09 desde febrero. La tarifa CA09 ya existe en BC:
se cargó la categoría, sin duplicar el precio con un parámetro personal. Los parámetros de
básico y grossing-up quedaron iguales al respaldo. El otro caso sin básico de categoría
resuelve con su parámetro personal ya existente, coincidente con PR_SUELDO de Meta4.
No usar el bruto de fuera de convenio como precio: puede ser USD/EUR con TC o grossing-up.

## Configuración a revisar

- BASE tiene cuatro entradas fijas Nonworking de febrero: **08, 09, 16 y 17**, todas sin
  descripción. El motor incluye entradas fijas para calcular feriados. Revisar el motivo de
  08/09 antes de calcular; esta auditoría no determinó su justificación laboral/local.
- Cuatro novedades con importe sustituyen fórmulas de 2013, 4115, 4125 y 4165. No se eliminaron:
  distinguir ajustes manuales reales de resultados calculados copiados desde Meta4.

## Validación y límites

La utilidad AL permite Simular (rollback por error deliberado) y Aplicar. Se probó la carga,
el no duplicado al repetirla y las cuatro cuotas: aplicación única entre dos liquidaciones,
recálculo, marcado como Aplicada y reversión a Pendiente. Ocho conjuntos respaldados quedaron
idénticos tras la simulación. La carga definitiva no cambió las 570 cabeceras de enero.
No se crearon liquidaciones de febrero para probar el cálculo completo; se verificaron
los datos, sus relaciones y el ciclo de cuotas. La presencia de tarifas no certifica todas
las fórmulas ni cada estado contra Oracle. Calendario y cuatro ajustes manuales siguen abiertos.

Ver [[Migración desde Meta4 - mapa y orden de ejecución]], [[Flujo operativo mensual de liquidación]]
y [[migracion-novedades-meta4]].
