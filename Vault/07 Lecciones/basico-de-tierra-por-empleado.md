---
aliases: ["Básico de tierra: por empleado"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Básico de tierra: por empleado

en FA y 372/04 el básico es por empleado, no por convenio+categoría; y cuatro lo tienen en divisa vía grossing-up

**El básico del personal de tierra es por EMPLEADO, no por convenio+categoría.** En FA, la
categoría FA55 tiene cuatro empleados con 5.500.000 · 5.338.902 · 4.700.000 · 3.843.040; FA22,
tres con 4.038.257 · 2.715.449 · 1.261.491. En 372/04 pasa lo mismo (CA10: tres entre 1.271.184
y 1.347.455). Tiene sentido: es personal fuera de convenio, cada sueldo se negocia.

`Parámetro Vigente` ya tiene el campo `No. Empleado`, así que el nivel existe — lo que no sirve
es cargarlos por categoría como los de tripulación.

**Cuatro de FA cobran en divisa por grossing-up**, y para ésos el `PR_SUELDO` en pesos de Meta4 es
el **resultado**, no una entrada:

```
90212  EUR 6.000     90361  USD 5.000
90016  USD 9.000     90302  EUR 2.000
```

Cargarles un `BASICO` en pesos congelaría el resultado del mes en que se cargó y rompería el
mecanismo — el neto objetivo ya está en `NETO_GU`, en su divisa. Hay que excluirlos.

Ver [[grossing-up-tapa-errores]] y [[un-valor-una-fuente]].

## Relacionado

- [[grossing-up-tapa-errores]]
- [[un-valor-una-fuente]]
- [[art19-calamar-cuenta-corriente]]
- [[cct-175-75-remuneracion-navegacion]]
- [[cct-729-15-articulos]]
