---
aliases: ["Períodos en formato aaaamm"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Períodos en formato aaaamm

**En una frase:** los códigos de período son aaaamm desde el 26/9/2026; antes eran MENSmmaaaa y ordenaban mal entre años

Los códigos de `Período Liquidación` son **aaaamm** (`202601`) desde el 26/9/2026. Antes eran
`MENSmmaaaa` (`MENS012026`), que con el mes delante del año ordena `MENS012026` **antes** que
`MENS122025`: en cuanto hay más de un ejercicio la lista se mezcla. `Árbol de Liquidaciones` ya
tenía escrito un rodeo por esto — ordena por la fecha invertida en vez de por el código.

Fue **migración de datos pura**: nadie genera los códigos (los períodos se cargan a mano) y
nadie los parsea. Los 36 períodos de 2024-2026 más las cinco tablas que los referencian —
Línea Liquidación 110.965, Registro Proceso Liq. 41.179, Liquidación 10.625, Novedad
Liquidación 4.712, Cuota Préstamo 1 —, con el invariante de que ninguna fila quedara
referenciando un período inexistente y de que las líneas e importes por período no cambiaran.

**Se deshace**: el mapeo es biyectivo. Y después de correrlo hay que reiniciar el service tier
o publicar — ver [[sql-directo-deja-cache-rancia]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
