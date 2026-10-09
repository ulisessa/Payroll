---
aliases: ["Enfermedad sin convenio paga cero"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Enfermedad sin convenio paga cero

Un hueco de vigencia en CONVENIO/CATEGORIA deja sin básico al empleado y el acumulador BASE_AUSENTISMO queda en cero, así que la enfermedad paga cero sin ningún error

> [!warning] Un hueco de vigencia en CONVENIO/CATEGORIA deja BASE_AUSENTISMO en cero y la enfermedad paga cero sin ningún error.

El 4110 usa `IF(TIPOEMPL = 2, #PROM_AUS_MES × COEF, BASE_AUSENTISMO)`. Los valores numéricos del
atributo TIPOEMPLEADO son **MENSUAL 1, TRIPUL 2, JORNAL 3**, así que la rama del promedio es la de
**tripulantes** y los mensualizados van por `BASE_AUSENTISMO`, que se alimenta de los conceptos
**1003, 1053, 2103 y 2703** al 100% (tabla `Fracción Acumulador`).

El legajo 80668 cobró cero de enfermedad en enero de 2026 contra 1.531.955,30 de Meta4. La cadena:
sus vigencias de CONVENIO y CATEGORIA terminan el 30/6/2024 y la siguiente arranca el 1/4/2026, así
que **en enero no tiene par convenio+categoría**; sin él no se le calcula el básico; sin básico los
cuatro conceptos que alimentan `BASE_AUSENTISMO` dan cero; y la enfermedad paga cero. Ningún paso
avisa. SINDICATO y OBRA_SOCIAL sí cubren enero, así que el empleado estaba activo: el hueco es de la
migración de atributos, no de la realidad.

Al 28/9/2026 hay **4 empleados con liquidación en enero y ninguna vigencia de TIPOEMPLEADO**
(80334, 80509, 80668, 90448); los dos primeros tienen convenio FA vigente y el 90448 no tiene
convenio en ninguna fecha.

**Por qué:** el síntoma aparece tres capas debajo de la causa, y cargar el atributo que falta —
TIPOEMPLEADO— no arregla nada: la rama de mensualizado también da cero mientras falte el convenio.

**Cómo aplicarlo:** ante un concepto que paga cero sin error, subir por la cadena hasta el par
convenio+categoría antes de tocar fórmulas o acumuladores, como en
[[tres-capas-fase-estado-asignacion]]. Un control barato: buscar empleados con liquidación en el
período y sin CONVENIO vigente a la fecha de cierre. Relacionado:
[[ventana-promedio-ausentismo]], [[acumuladores-orden-calculo]].

## Relacionado

- [[tres-capas-fase-estado-asignacion]]
- [[ventana-promedio-ausentismo]]
- [[acumuladores-orden-calculo]]
- [[accidente-empleador-y-art]]
- [[exclusividad-vacaciones]]
