---
tipo: guia
tags: [interfaz, atributos, parametros, empleado, proyecto]
fuente: [src/Pages/Pag110011.AtributosDeEntidad.al, src/Pages/Pag110030.AtributosEntidadSub.al, src/Pages/Pag50154.ParametrosVigentesList.al, src/Codeunits/Cod110035.AtributosEntidadUI.al, src/PageExtensions/PagExt50351.JobCardExt.al, src/PageExtensions/PagExt50358.JobListExt.al, src/PermissionSets/PermSet50302.LiqPescaLectura.al]
actualizado: 2026-10-16
---

# Carga de atributos y parámetros desde las fichas

## Atributos

- Al buscar un valor ya asignado, se muestran las alternativas del atributo y del padre correcto,
  con el valor actual seleccionado. El código existente no filtra la lista. Si se escribió otro
  texto, se conserva la búsqueda por ese texto; sin coincidencias se vuelven a mostrar las opciones.
- **Mostrar historial completo** está arriba de la lista y de la sección de atributos de la ficha.
  La lista completa también promueve la acción de historial en la barra de acciones.
- **Ver historial** del FactBox abre realmente las vigencias anteriores y futuras: OnOpenPage
  respeta el modo solicitado. Al cerrar, el FactBox recarga sus valores vigentes.
- En la ficha de empleado se pueden agregar filas. Al iniciar un alta, la subpágina abre el
  historial antes de insertar, para que el filtro de ids del resumen no esconda la vigencia nueva.
  El vínculo sigue restringido al empleado. Cambiar de empleado reconstruye el resumen de esa entidad.
- El alta desde el historial abierto por el FactBox propone explícitamente entidad y tipo:
  no depende de que el filtro fijo se pueda leer desde el grupo de filtros de usuario.

## Acceso desde proyectos

La lista y la ficha de proyecto tienen la acción **Atributos**, promovida en la barra
de acciones. Abre el historial completo del proyecto seleccionado, con vigencias
anteriores, actuales y futuras. El selector **Mostrar historial completo** permite
cambiar a las vigencias actuales sin perder el filtro del proyecto.

Ambos accesos reutilizan `AbrirHistorialEntidad`: fija tipo `Proyecto` y código en
el grupo de filtros 4 y los propone explícitamente al agregar filas. La fecha de
vigencia queda a completar por el usuario. La acción se deshabilita si el número
de proyecto está vacío. El rol **Liq. Pesca - Lectura** puede ejecutar el auxiliar
de interfaz y mantiene sólo lectura sobre los datos.

## Parámetros desde su origen

Los accesos abren **Parámetros Vigentes**, la misma tabla real y sus validaciones:

| Origen | Acción | Alcance |
|---|---|---|
| Ficha de empleado | Parámetros del empleado | No. Empleado exacto |
| Convenios colectivos | Parámetros del convenio | Convenio exacto, incluidas sus categorías |
| Categorías CCT | Parámetros de la categoría | Convenio y categoría exactos |
| Ficha del tipo de atributo | Parámetros del atributo | Parámetros que declaran ese tipo como eje |
| Catálogo y subpágina de valores | Parámetros del valor | Tipo de atributo y su Sufijo Parámetro |
| Asignaciones de atributos | Parámetros del atributo | El tipo o el valor de la fila seleccionada |

En empleado, convenio y categoría, una fila nueva propone los campos del origen, sin poner una
fecha de vigencia automáticamente. Se pueden editar las filas sin bloqueo y agregar nuevas
versiones. Las filas **En Uso** conservan los controles de la tabla; no se libera ni modifica el
historial utilizado en una liquidación por entrar desde otra ficha.

Desde atributos, el selector **Parámetro** muestra sólo los que usan ese tipo como eje. Se consulta
un parámetro por vez. Desde un valor se fija su sufijo en el eje que realmente declara el parámetro;
no se busca el mismo texto indiscriminadamente en los tres ejes. La nueva fila propone base y sufijo.
Los ejes segundo y tercero se muestran en esta vista contextual. Si el tipo no es eje de ningún
parámetro, o el valor no tiene sufijo, la pantalla explica la configuración que falta.

La vista incluye las vigencias históricas del alcance seleccionado; no pretende mostrar parámetros
genéricos heredados como si fueran excepciones de ese empleado o categoría.

## Verificación

Cambios de interfaz y navegación, sin tablas u objetos nuevos ni cambios a Commit.
Compilación AL realizada; requiere publicación completa para probar en el cliente de BC.
La navegación, alta y edición en el cliente no se dan por verificadas sólo por compilar.
Los accesos de proyecto del 16/10/2026 compilaron con cero errores; su presentación
en el cliente queda pendiente de publicar.

Ver [[Atributos tipados]], [[Parámetros y vigencias]] y [[Publicar en BC (no usar RAD)]].
