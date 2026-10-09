---
aliases: ["Confirm de dimensión del Job es inocuo"]
tipo: leccion
tema: integracion-nav
tags: [leccion, integracion-nav, reference]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-11
---

# Confirm de dimensión del Job es inocuo

El diálogo "Ha cambiado una dimensión ¿actualizar las líneas?" del Job no pierde la dimensión; sólo saltea las Job Task

Al aplicar dimensiones sobre `Job` con `Validate`, BC pregunta **"Ha cambiado una dimensión.\\¿Desea actualizar las líneas?"**. Verificado contra la fuente del Base Application 25 (`Job.Table.al` del mirror `StefanMaron/MSDyn365BC.Code.History`, rama `w1-25`):

```al
procedure ValidateShortcutDimCode(FieldNumber: Integer; ShortcutDimCode: Code[20])
begin
    DimMgt.ValidateDimValueCode(FieldNumber, ShortcutDimCode);
    if not IsTemporary then begin
        DimMgt.SaveDefaultDim(Database::Job, "No.", FieldNumber, ShortcutDimCode);  // ya guardó
        UpdateJobTaskDimension(FieldNumber, ShortcutDimCode);                       // acá pregunta
        Modify();
    end;
end;

local procedure UpdateJobTaskDimension(...)
begin
    if GuiAllowed() and (not GetHideValidationDialog()) then
        if not Confirm(UpdateJobTaskDimQst, false) then
            exit;
    // recorre Job Task y les pone la dimensión
end;
```

**Responder "No" NO pierde la dimensión del proyecto**: la Default Dimension y el campo ya se escribieron antes de preguntar. Sólo se saltea la propagación a las **Job Task**.

**Desde el Job Queue no hay diálogo y tampoco hay `exit`**: `GuiAllowed()` es falso, así que ni pregunta ni corta — sigue y actualiza también las líneas. Es el camino correcto y completo para un proceso masivo.

`Job` **no expone `SetHideValidationDialog`** (confirmado en los símbolos de 25.5): ese gancho no existe. Si alguna vez hace falta cortar la propagación a líneas, el evento es `OnBeforeUpdateJobTaskDimension` con `IsHandled`.

**Cómo aplicarlo:** no rediseñar la escritura de dimensiones para esquivar este diálogo. Correr desde el Job Queue y listo.

**Bonus del mismo hallazgo:** la extensión "Final Version Customization" agrega al `Job` los campos **50000..50004** para las dimensiones 3 a 7, cada uno con su `OnValidate` que llama a `ValidateShortcutDimCode`. Escribir sólo la Default Dimension de la 3 deja el campo 50000 en blanco, y ese es el que leen los FlowFilters `Filtro actividad` de la personalización. Para la actividad va `Job.Validate("Global Dimension 3 Code", ...)`, no una Default Dimension a mano. El `OnValidate` de ese campo pregunta si crear el valor de dimensión que no existe (default `false`), así que desatendido falla la fila en vez de inventar códigos.

Relacionado: [[dim2-nav-actividad-bc-marea]], [[symbolos-final-version-tienen-fuente]], [[sincronizacion-valores-dimension]].

## Relacionado

- [[dim2-nav-actividad-bc-marea]]
- [[symbolos-final-version-tienen-fuente]]
- [[sincronizacion-valores-dimension]]
