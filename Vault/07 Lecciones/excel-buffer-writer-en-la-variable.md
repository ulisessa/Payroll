---
aliases: ["El writer de Excel vive en la variable"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
actualizado: 2026-10-04
---

# El writer de Excel vive en la variable

El WorkbookWriter vive en la variable Record "Excel Buffer"; vaciarla con DeleteAll para reusarla lo deja null y la segunda hoja muere con "No se pudo crear el libro de Excel"

`Excel Buffer` guarda el `WorkbookWriter` de .NET en una **global de la tabla** —`XlWrkBkWriter`, línea
164 de `ExcelBuffer.Table.al`—, o sea **en la variable Record**, no en la sesión. El libro abierto es
de esa variable.

Por eso **vaciar el buffer con `DeleteAll()` para reusarlo en una segunda hoja lo rompe**: el writer
queda sin instanciar y `SelectOrAddSheet` muere en su línea 5,

    if IsNull(XlWrkBkWriter) then Error(Text037);   // 'Could not create the Excel workbook.'

El mensaje engaña: dice que no pudo **crear** el libro, y en realidad el libro ya estaba creado y se
perdió la referencia. La primera hoja sale bien y el informe revienta al final.

**El patrón bueno es el de la base**, en `WriteSheet` para su hoja de información: mantiene
`TempInfoExcelBuf` como **buffer aparte** y hace

    SelectOrAddSheet(nombre);                  // sobre el buffer que abrió el libro
    WriteAllToCurrentSheet(TempInfoExcelBuf);  // volcando el OTRO buffer

Nunca vacía el que tiene el writer. Una variable por hoja, y `SelectOrAddSheet` siempre sobre la que
hizo el `CreateNewBook`.

Pasó en `Control Marea Excel Liq.` (Cod110028) el 28/9/2026 y se corrigió así.

**Y para leer el fuente de la base app**: los símbolos lo traen — ver
[[symbolos-final-version-tienen-fuente]]. El `.app` es un ZIP con **40 bytes de cabecera** delante;
hay que buscar la firma `PK\x03\x04` y cortar desde ahí. Extraerlo entero falla por MAX_PATH en
Windows, así que conviene sacar sólo el archivo que se necesita:
`src/System/DataExchange/ExcelBuffer.Table.al`.

## Relacionado

- [[symbolos-final-version-tienen-fuente]]
- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
