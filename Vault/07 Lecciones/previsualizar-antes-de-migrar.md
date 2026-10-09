---
aliases: ["Previsualizar antes de migrar"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, feedback]
actualizado: 2026-10-04
---

# Previsualizar antes de migrar

**En una frase:** Toda corrección masiva va con previsualización y controles de dirección antes del UPDATE

Antes de correr un `UPDATE` de migración sobre miles de filas, escribir primero un
bloque que muestre **qué cambiaría**, con controles que puedan fallar. Sin eso, un
error de regla se ve igual que un dato migrado y no lo detecta ningún control
posterior.

**Por qué:** el 17/9/2026, corrigiendo la derivación de las asignaciones `PN-`, tres
versiones seguidas de la regla parecían razonables y estaban mal. Las tres las
atrapó la previsualización, cada una por un control distinto:

- `BajaAntesDelAlta` → cerraba once nóminas de tierra con fechas de los noventa.
- `CambiaLaFecha` → movía 4.700 filas en vez de las 170 del problema.
- `SeAdelanta` → separa alargar (la corrección buscada) de recortar.

**Cómo aplicarlo:** el control útil no cuenta filas, verifica una **invariante que
la corrección no puede romper** —una baja no puede ser anterior a su alta— y una
de **dirección** —si la corrección alarga, nada puede acortarse—.

Y el verificador tiene que referirse **exactamente al mismo conjunto** que la
corrección. Ese día falló de las dos maneras opuestas: un control dio 0/0 con una
fila todavía mal porque acotaba de MENOS (compartía el filtro `Fecha Inicio >= 2026`
con lo que verificaba), y otro marcó 9 diferencias falsas porque acotaba de MÁS
(verificaba "todo lo que empieza el 6/10/2025" en vez de las filas tocadas). La
forma robusta es anotar las claves afectadas en una `#temp` ANTES del `UPDATE` y
verificar contra esa tabla. Ver [[nomina-no-es-intervalo-presencia]] y
[[tres-capas-fase-estado-asignacion]].

**Y un control de invariante SOBRE UN ESTADO PREEXISTENTE tiene que medir la
diferencia, no el absoluto.** El 18/9/2026, corrigiendo estados de navegación de la
marea A28/59, el control de contigüidad contaba huecos en toda la historia de los
cinco empleados y devolvió 44, así que la guarda hizo ROLLBACK de una corrección que
estaba bien: los 44 eran huecos históricos de entre 2013 y 2025, ajenos al cambio. La
forma correcta son dos mediciones: **diferencia** contra un conteo tomado antes del
UPDATE (tiene que dar 0 huecos nuevos) y **absoluto pero acotado a los días que se
tocan**. La ventana se ajusta a lo tocado y nada más: puesta de diciembre a febrero
seguía atrapando un hueco propio de un empleado en diciembre.

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
