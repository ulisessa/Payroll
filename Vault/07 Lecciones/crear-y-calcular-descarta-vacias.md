---
aliases: ["Crear y calcular descarta vacías"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Crear y calcular descarta vacías

la acción combinada va de a una y espía el número de la serie, así la liquidación vacía se descarta sin dejar hueco en la numeración

**Crear y Calcular Liquidaciones** (en Períodos Liquidación) corre todos los tipos activos en
su `Orden` y, liquidación por liquidación, **crea → calcula → decide**. La que sale sin ninguna
línea con importe se borra en el acto.

**Va de a una y no en dos pasadas** porque "no hay conceptos con valor" recién se sabe después
de calcular. Creando todo primero quedan cientos de vacías de SALDO_INICIAL, LIQ_FINAL y
AGUINALDO que hay que salir a borrar a mano y que además ya se llevaron su número.

**El número se ESPÍA, no se consume.** `NextLiqNo` usa `NoSeries.PeekNextNo` mientras está en
este modo; recién si la liquidación sobrevive al cálculo se llama a `ConsumirLiqNo`. Si se
descarta, nadie consumió nada y la siguiente toma el mismo número. **Esto vale porque el lote
es de a uno**: si alguna vez se paraleliza, el espiado deja de ser seguro y hay que volver a
consumir siempre y aceptar los huecos.

Dos detalles que muerden:

- **Vacía = ninguna línea con importe**, no "sin líneas". El motor deja igual las informativas
  y las de cantidad (días, coeficientes), que no son plata.
- **Hay que reabrirla para borrarla**: el `OnDelete` de Liquidación se niega si no está en
  Borrador, y después de calcular está Calculada. Se pasa por `Gestión Liquidación.Reabrir` en
  vez de saltear el trigger con un `Delete(false)`, que dejaría las líneas huérfanas.
- **Una que FALLA no se descarta**: no se sabe si está vacía porque no corresponde o porque se
  rompió. Queda anotada en su registro, como en [[lote-tipo-liq-en-blanco]].

**Es idempotente, y eso pedía una pieza más.** Crear ya lo era —`LiqExiste` corta antes de
insertar, así que una segunda corrida no duplica ni pide número nuevo— y calcular también,
porque sólo toma Borrador. Lo que faltaba es que **converja**: mientras el proceso sólo agregue
y nunca saque, el resultado depende de la historia de corridas y no de los datos.

La barrida final saca del período las liquidaciones **vacías**, incluidas las que venían de una
corrida anterior con otra configuración. Alcance = el de la corrida: con un tipo elegido barre
ese tipo, sin tipo los que entran en la corrida completa, y nunca un tipo que la corrida no
miró.

**Las que tienen importe pero que las guardas de hoy ya no crearían se cuentan y se informan,
no se borran.** Pueden haberse creado a mano a propósito, y borrar plata en silencio porque
cambió un parámetro es exactamente lo que no hay que hacer. Ver
[[cuando-corresponde-una-liquidacion]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[cuando-corresponde-una-liquidacion]]
- [[acumuladores-orden-calculo]]
- [[cobertura-devengado-tapa-dias]]
- [[cobertura-en-tramos]]
