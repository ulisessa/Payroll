---
tipo: referencia
tags: [dominio, conceptos, recibo, rubros]
fuente: ["Conceptos Liquidación.xlsx (snapshot 17/8/2026, raíz del repo)", src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50053.GestionFrancos.al]
actualizado: 2026-10-04
---

# Rubros típicos de una liquidación embarcada

Mapa de los conceptos que componen el recibo de un tripulante, con su **número**, qué paga y cómo se calcula. Los conceptos son **datos** (tabla [[Tabla - Concepto Liquidación]]), no código: el motor no conoce ningún número.

> [!warning] Cómo leer la columna *Fuente*
> **`snap`** = está en `Conceptos Liquidación.xlsx` de la raíz del repo (exportado el **17/8/2026**; la base viva puede haber cambiado desde entonces — varias fórmulas se tocaron en septiembre). **`lec`** = se sabe por una lección de memoria / validación contra Meta4, **no** verificable en el repo. Una fórmula `snap` puede estar **desactualizada**: ante la duda, abrir el concepto en BC (ver historial en `Historial Fórmula Concepto`). Tipo: **R** remunerativo · **NR** no remunerativo · **D** descuento · **C** contribución · **SS** seguridad social · **Ret** retención.

Tipo de liquidación en que corre (campo `Tipos Liq. Aplicables`; **vacío = comodín**, ver [[vacio-en-tipos-liq-aplicables-es-comodin]]): `CM` cierre de marea, `DEV` devengados, `REG` regular.

## Sueldos y días

| Nº | Concepto | Tipo | Lógica | Fuente |
|---|---|---|---|---|
| 1003 | Sueldo | R | `BASICO` (o `BASICO × TC` si es divisa; `COMPLEMENTO_GU` si grossing-up). Tierra y fuera de convenio. TC **vendedor** | snap + lec |
| 1013 | Sueldo de navegación | R | `DIAS_PROYECTO × PRECIO_NAV × COEF_TANGONERO` (DEV, CM) | snap |
| 1083 | Sueldo de puerto | R | `DIAS_PUERTO × PRECIO_PUERTO × COEF_TANGONERO` (DEV, CM); precio en `_LAN/_CAL` y comprador si está en USD | snap + lec |
| 1073 | Sueldo a órdenes | R | `DIAS_MAR × PRECIO_ORDENES` (días fuera de veda; resta `#DIAS_ART48`) | snap + lec |
| 1076 | Art. 48 párr. 11 CCT 729/15 | R | días de veda (`DIAS_ART48`) sobre `PRECIO_NAV`; sólo marinería | lec |
| 1075 | Art. 19 CCT 729/15 | R | calamar: `DIAS_ART_19 × básico / 30` con cuenta corriente anual | lec |
| 1023 | Sueldo de feriado | R | `BASE_FERIADO / (días) × DIAS_FERIADOS_MAREA`; en el snapshot el divisor es `DIAS_PROYECTO+DIAS_PUERTO`; la lección pedía `DIAS_MAREA` en vez de 30 fijo | snap + lec |
| 1053 | Antigüedad | R | `PRECIO_NAV/30 × pct × (días del período) × coef` (el coef es el **30% del Dto 633/18**, no la pesquería); sin DIAS_GP la antigüedad paga cero sin error | snap + lec |
| 1054 | Antigüedad mensuales | R | `PISO(años×2)/2 × PCT_ANTIG` si no hay `DIAS_ENROLAMIENTO` | snap |

## Francos

| Nº | Concepto | Tipo | Lógica | Fuente |
|---|---|---|---|---|
| 1062 | Francos devengados y liquidados | R (Es Devengo) | `REDONDEAR(COEF_FRANCOS × DIAS_ENROLAMIENTO + 1, 0)`; `Rol Franco = Devengo`; sólo CM. **Cantidad = días, Importe = 0** | snap |
| 1063 | Sueldo de franco | R | `DIAS_FRANCOS_PERIODO`; `Rol Franco = Consumo`; el motor expande a **una línea por categoría de lote**, valuado por [[Valor del franco]]; sólo REG | snap |
| 2803 / 2804 | Indemnización francos no gozados / SAC s/ | R | carga a mano | snap |
| 2083 | A cuenta futuros aumentos francos | R | `VALOR_FRANCO_ACDO/30 × DIAS_FRANCOS_PERIODO × TC_COMPRADOR − (#1063+#1053)`; sólo OF02/OF04 de tangoneros; guarda sobre `ACDO × DIAS = 0` | lec |

## Adicionales por artículo y de tareas

| Nº | Concepto | Tipo | Lógica | Fuente |
|---|---|---|---|---|
| 1533 | Adicional art. 23 | R | 60% del sueldo de navegación; **oficiales** (175/75 y 768/19); `PCT_ADIC_ART23` va en 60 | snap (inactivo en el snapshot) + lec |
| 1543 | Adicional art. 33 | R | `@1013 × PCT_33` (0,60); **marinería** | snap + lec |
| 1547 | Incentivo a la producción | R | `PRECIO_INCENT × DIAS_PROYECTO × COEF_TANGONERO` (Art. 34, en pesos) | snap |
| 2073 | Adicional tareas mecánicas | R | 15% del **garantizado prorrateado** (`PCT_TAR_MEC`); base corregida el 28/9/2026 | lec ([[adicional-tareas-mecanicas]]) |
| 1583 | Adicional trabajos especiales | R | `(Σ producción langostino #2403…) × PCT_TRAB_ESP` | snap |
| 2703 | Adicional zona desfavorable | R | `BASE_IG4 × ZONA_DESF`; condición `COD_ZONA > 0` | snap |

## Producción, garantizado y premios (ver [[Producción y premios]])

| Nº | Concepto | Tipo | Lógica | Fuente |
|---|---|---|---|---|
| 2403…2483 | Producción langostino entero 1-6 / cola 1-3 | R | `PROD_KN_x/1000 × VALOR_x_SOMU × PCT_NORM_TANG × PCT_PROD/100 × 0,9 × TC_CERCANO × COEF_TANGONERO`; sólo CM; **no todos activos** (L4-L6, C3 inactivos) | snap |
| 2493 | Producción langostino cola rota | R | ídem con `PROD_KN_CR` | snap |
| 2498 / 2499 | Producción total langostino SOMU / FC | R (no imprime) | suma de las clasificaciones (acumulador de base; 2498 inactivo en el snapshot) | snap |
| 1093 | Gratificación producción langostino colas | R | diferencia entre valorización de cola y langostino | snap |
| 1343 / 1373 / 1383 | Producción calamar entero / vaina / rejos | R | por kilo y clasificación (`VALOR_CAL_ENT/REJ/VAI`), índice SOMU | snap (sin fórmula en el snapshot) + lec |
| 1393 | Producción langostino cola rota | R | — | snap |
| 1534 | Premio adicional especial de producción | R | `total convenio − (navegación + puerto + antigüedad + art. 23)`; `MAX(producción, garantizado CCT)` en oficiales poteros | snap (fórmula posiblemente desactualizada) + lec |
| 2003 | A cuenta futuros aumentos (175/75) | R | `total empresa − total convenio`; es el **tapón** del grossing-up en oficiales netos al 70% | snap (fórmula posiblemente desactualizada) + lec |
| 2013 | A cuenta futuros aumentos puerto | R | `SALARIO_ASEG_* /30 × DIAS_GP_PERIODO × 1,4 × TC_COMPRADOR − (#1083+#1023+#1053)` | lec |
| 2610 / 2613 | A cuenta de marea / Ajuste de marea | R | `A_CUENTA_MAREA` (fuente: líneas de DEVENGADOS) / carga a mano | snap |
| 1174 | Adicional bodega remunerativo | R | `PROD_KN_MAREA/1000 × VAL_CARG_COMP × COEF_TANGONERO` | snap |

## Anticipos, descuentos de marea y préstamos

| Nº | Concepto | Tipo | Lógica | Fuente |
|---|---|---|---|---|
| 4803 / 4813 / 4823 | Anticipo de poder / llegada / haberes | — | **sin fórmula a propósito**, por novedad; **no son haber del recibo** (viven en el movimiento de pago de Meta4) | lec ([[anticipos-como-novedades]], [[anticipo-no-es-haber-del-recibo]]) |
| 8830 / 8840 / 8850 / 8870 | Descuento anticipo poder / llegada / haberes / haberes ADM | D | novedad con proyecto (migración desde `M4T_CTA_CTE_ANTICIPOS`) | snap + lec |
| 8860 / 4833 | Porcentaje sobre valor (descuento / adelanto) | D / R | — | snap |
| 8883 / 8893 | Embargo judicial / Cuota alimentaria | Ret | novedad; ver [[embargo-cuota-alimentaria-como-retencion]] | snap + lec |
| (según el préstamo) | Descuento de cuotas de préstamo | D | incidencia generada por [[Préstamos y cuotas]] | repo (código) |

## Licencias, ausentismo y vacaciones

| Nº | Concepto | Lógica | Fuente |
|---|---|---|---|
| 4110 | Enfermedad inculpable | `IF(TIPOEMPL=2, #PROM_AUS_MES×COEF, BASE_AUSENTISMO)`; sin par convenio+categoría paga **cero sin error** | lec ([[enfermedad-sin-convenio-paga-cero]]) |
| 4120 / 4125 / 4165 | Accidente (empleador) / ILT (ART) / ILT no rem. | los 10 primeros días a cargo del empleador y el resto ART; el 4120 en cero con muchos días previos es **por diseño** | lec ([[accidente-empleador-y-art]]) |
| 3553 | Vacaciones | `(remuneración)/25 × DIAS_VAC_INICIO`; tripulantes: **promedio de 6 meses** (`VAC_PROMEDIO`) | snap + lec ([[vacaciones-tripulantes-promedio]]) |
| 4743 | Descuento días de vacaciones | `−remuneración/30 × MIN(DIAS_VAC_PERIODO,30)` (tierra; se apaga con `HAY_LIQ_VACACIONES`) | snap + lec ([[vacaciones-tierra-duplica-el-mes]]) |
| 4750…4753 | SAC devengado y cargas | `REG`, `DEV`, `CM` | snap |
| 3613 / 3623 | SAC 1.er / 2.º semestre | `MEJOR_REM_SEM/2 × MESES_TRAB_SEM/6` (AGUINALDO) | snap |
| 4415 / 4416 | Absorción art. 36 CCT SOMU / 729/15 | resta `BASE_ABS_SOMU` / `#1803+#1813+#1893` | snap |

## Cargas de ley (resumen)

Aportes del trabajador **6000** jubilación, **6010** ley 19032, **6030** obra social (SS, REG/DEV/CM) con gemelos SAC (6002/6012/6034) y vacaciones (6003/6013/6035); contribuciones **7000, 7010, 7030, 7050** ART, **7060**, **7070**, **7080**; **5010** Ganancias (Ret); sindicales y solidarios **8522** cuota, **8542** caja compensadora, **8543** fondo de desempleo, **8553** centro de capacitación, **8563** contribución solidaria SOMU, **8593** cuota extraordinaria CAP. Detalle en las notas de descuentos y de [[acumuladores-orden-calculo]]. La fracción que cada concepto aporta a cada base es la tabla [[Tabla - Fracción Acumulador]]; `FRACCIONES_RETIRADAS_VS_META4.md` (raíz) lista las **77 fracciones retiradas** (24 SS, 4 OS, 3 sindicato, 10 SAC, 16 feriado, 17 zona, 3 ausentismo) por no estar marcadas en Meta4 — si un importe no coincide, revisar primero si el concepto está en esa lista.

## Orden de cálculo: qué esperar

Los conceptos corren por `Orden Cálculo` ascendente (los órdenes **no son únicos** entre conceptos). Un concepto que **lee** el resultado de otro (`#1013`, `@2498`, un acumulador) debe tener **orden mayor** que el productor, o devuelve cero sin error ([[concepto-negativo-despues-de-sus-consumidores]], [[control-precedencia-formulas]]). Órdenes del snapshot: 1003 → 10 · 1013 → 15 · 1053 → 50 · 1062 → 55 · 1063 → 60 · 1073 → 65 · 1083 → 80 · producción langostino 141-150 · 1543 → 155 · 1534 → 159 · 2013 → 182 · 2073 → 195 · 2083 → 197 · 2610 → 286 · 1023 → 450 · 2003 → 650 · descuentos de anticipo 790-815 · aportes 900-922 · contribuciones 930-940.

Relacionadas: [[Producción y premios]], [[Francos - ledger FIFO]], [[Convenios del sector (CCT 729-15, 768-19, 175-75, 372-04, SOMU)]], [[Índice Dominio - marea y pagos]].
