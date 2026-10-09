---
aliases: ["Cuándo corresponde una liquidación"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Cuándo corresponde una liquidación

cuatro preguntas parametrizadas deciden si crear una liquidación, sin tener que calcularla para enterarse

Si una liquidación corresponde se decide **antes de crearla**, con cuatro preguntas que salen de
la configuración del tipo y no del código:

1. **Calendario** — `Tipo Liquidación.Meses`, filtro de BC sobre el número de mes (`6|12` para
   el aguinaldo, vacío = todos). Es el único que no mira al empleado.
2. **Disparador** — enum `Disparador Tipo Liq.`: Ninguno, Arribo de marea (Cierre), Marea en
   curso (Devengados), Baja del empleado (Liquidación Final). Reemplaza a las banderas
   `Liquida al Arribo` y `Sólo Proyectos en Curso`, que eran **excluyentes entre sí** —
   una marea o arribó o sigue navegando — y como booleanos permitían escribir estados que no
   significan nada.
3. **Fase de alta** — ¿pertenecía a la empresa ese mes? Ya estaba.
4. **Estados** — tabla `Estado Tipo Liq.`, una o más líneas por tipo: `Modo` (Exige/Excluye),
   `Cód. Estado` (en blanco = cualquiera), `Ventana` (Cobertura / Período / Mes siguiente) y
   `Tipo Proyecto` **del proyecto del estado**. Se crea si alguna Exige da y ninguna Excluye da;
   sin líneas, sin condición.

Las Exige se combinan con **O**: el caso que lo pide son las vacaciones, que se pagan si el
empleado las toma este mes o si las va a tomar el que viene (pago anticipado) — dos líneas del
mismo tipo en vez de dos tipos. Y la Regular pide "un estado del mes cuyo proyecto **no** sea
productivo", porque los días de marea los paga su Cierre; por eso el calificador mira el
proyecto del estado y no el de la liquidación, y un estado sin proyecto cuenta como
improductivo.

**La reliquidación no se puede condicionar por estados** y no es una falla del diseño: no la
dispara un hecho del empleado sino un cambio **posterior** al cálculo — una novedad cargada
tarde, un parámetro o una fórmula con vigencia retroactiva. Queda fuera de la corrida
automática hasta que exista una acción que compare fechas de modificación contra la fecha de
cálculo.

**Lo que esto no puede saber** es si un concepto va a dar importe distinto de cero: eso sólo se
sabe calculando, y para eso queda el descarte de vacías de
[[crear-y-calcular-descarta-vacias]] como red, no como mecanismo principal.

Ver [[lote-tipo-liq-en-blanco]] y [[ventana-liquidacion-es-cobertura]].

## Relacionado

- [[crear-y-calcular-descarta-vacias]]
- [[lote-tipo-liq-en-blanco]]
- [[ventana-liquidacion-es-cobertura]]
- [[acumuladores-orden-calculo]]
- [[cobertura-devengado-tapa-dias]]
- [[cobertura-en-tramos]]
