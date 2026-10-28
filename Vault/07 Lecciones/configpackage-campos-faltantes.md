---
aliases: ["Campos que el ConfigPackage no lleva"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
origen: 6fef786a-9ac7-4101-a78d-2cb1c395ef37
actualizado: 2026-08-14
---

# Campos que el ConfigPackage no lleva

Campos de configuración que ConfigPackage_Payroll.xml NO lleva, y por lo tanto no restaura

`ConfigPackage_Payroll.xml` (y el `gen_config.ps1` que lo genera) cubre 10 tablas pero solo un subconjunto de sus campos. Auditado el 2026-08-14 cruzando los `configpackagefield` del XML contra los `field()` no-FlowField de cada tabla:

| Tabla | Campos que NO viajan |
|---|---|
| 60007 Concepto Liquidación | 9 Grupo Costo Laboral · 12 Vigencia Hasta · 16 Variable Cantidad · 17 Unidad Cantidad · 18 Etiqueta Det. Ganancias · 19 Imprime en Recibo · 20 Es Devengo · 21 Variable Base · 22 Tipos Liq. Aplicables · 23 Rol Franco |
| 60008 Parámetro Vigente | 8 No. Empleado · 10 Cód. Parámetro Base · 11 Cód. Convenio · 12 Cód. Categoría · 13 Nivel |
| 60018 Variable Sistema Liq. | 5 Mostrar en Recibo · 6 Etiqueta Recibo · 7 Etiqueta Det. Ganancias · 8 Orden Det. Ganancias · 9 Cód. Acumulador · 10 Tipo Concepto |
| 60017 Fracción Acumulador | 6 Invertir Signo |
| 60019 Concepto CCT Vigente | 4 Cód. Categoría |
| 60016 Parámetro | 7 Antigüedad Máxima Vigencia |
| 60004 Convenio Colectivo | 5 Cámara |

**Por qué:** aplicar el paquete no puede *encender* nada de esa lista, y toda fila que el apply cree en vez de modificar la deja en el valor cero del tipo. Los tres que más duelen: `Invertir Signo` (una fracción que restaba pasa a sumar, y la base de Ganancias sale inflada), los cinco de Parámetro Vigente (todo el mecanismo de sufijos `BASICO_<CONVENIO>_<CATEGORÍA>` no viaja) y `Cód. Acumulador`/`Tipo Concepto` (sin ellos las variables YTD_ACUM/YTD_LINEAS no se pueden restaurar desde el paquete). El paquete además escribía el campo 14 `Aplica Tipo Liq.`, que está obsoleto y el motor no lee — corregido en gen_config.ps1 el 2026-08-14 para que escriba el 22 con códigos.

Tablas que el paquete NO cubre en absoluto: Cód. Estado Empleado (60003), Estado Empleado (60000), Filtro Fuente Datos Liq. (60029), Fuente Datos Liquidación (60015), Tipo Liquidación, Novedades, Préstamos.

**Cómo aplicarlo:** después de cualquier apply del paquete, revisar esos campos a mano. Ver [[rad-json-removed-peligroso]] para por qué hubo que restaurar.

## Relacionado

- [[rad-json-removed-peligroso]]
- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
