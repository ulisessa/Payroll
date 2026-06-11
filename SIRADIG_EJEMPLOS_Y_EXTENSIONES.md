# Ejemplos y Extensiones - Importación SIRADIG

## 📚 Ejemplos de Código

### Ejemplo 1: Importar desde Codeunit

```al
// En tu codeunit de procesamiento batch o acción
procedure ImportarSiradigDelMes()
var
    Orquestador: Codeunit "Orquestador SIRADIG";
    CarpetaSiradig: Text;
    AñoMes: Text;
begin
    // Construir ruta dinámicamente
    AñoMes := Format(Today(), 0, '<Year4><Month,2>');
    CarpetaSiradig := StrSubstNo('C:\SIRADIG\%1\', AñoMes);

    // Importar y procesar automáticamente
    Orquestador.ImportarYProcesarCarpeta(CarpetaSiradig, true);
end;
```

### Ejemplo 2: Procesar Importaciones Pendientes (Cron)

```al
// Crear un Job Queue entry que ejecute periódicamente
// This would call:
procedure ProcesarImportacionesPendientesAutomaticamente()
var
    Orquestador: Codeunit "Orquestador SIRADIG";
begin
    Orquestador.ProcesarImportacionesPendientes();
end;

// Job Queue Setup:
// Object Type: Codeunit
// Object ID: 50025 (Orquestador SIRADIG)
// Function: ProcesarImportacionesPendientesAutomaticamente()
// Frequency: Diariamente a las 22:00
```

### Ejemplo 3: Validar Importación Antes de Procesar

```al
// Extender Cod50024 para agregar validación personalizada
procedure ValidarImportacionAntesDeProc(var RegistroImportacion: Record "Importación SIRADIG"): Boolean
var
    DedGanancias: Record "Ded. Ganancias Empleado";
begin
    // Validación 1: Verificar que no hay deducciones duplicadas en el mismo período
    DedGanancias.SetRange("No. Empleado", RegistroImportacion."No. Empleado");
    if DedGanancias.FindSet() then
        // Lógica de validación...

    // Validación 2: Verificar montos razonables
    if RegistroImportacion."Deducciones Importadas" > 50 then
        Error('Cantidad de deducciones anormalmente alta');

    exit(true);
end;
```

### Ejemplo 4: Notificar Cambios Importantes

```al
// Extender Cod50024.ProcesarDeduccionesDelXml para notificar cambios
procedure NotificarCambioDeduccion(
    NoEmpleado: Code[20];
    CodigoDeduccion: Code[20];
    MontoAnterior: Decimal;
    MontoNuevo: Decimal
)
var
    UserNotif: Notification;
begin
    if Abs(MontoNuevo - MontoAnterior) > 10000 then begin
        UserNotif.Message := StrSubstNo(
            'Cambio significativo de deducción %1 para empleado %2: %3 → %4',
            CodigoDeduccion,
            NoEmpleado,
            MontoAnterior,
            MontoNuevo
        );
        UserNotif.Send();
    end;
end;
```

---

## 🔧 Extensiones Recomendadas

### 1. Reporte de Importaciones

```al
report 50090 "Importaciones SIRADIG - Resumen"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;

    dataset
    {
        dataitem(RegistroImportacion; "Importación SIRADIG")
        {
            RequestFilterFields = "Período", Estado;

            column(CUIL_Empleado; "CUIL Empleado")
            { }
            column(No_Empleado; "No. Empleado")
            { }
            column(Periodo; "Período")
            { }
            column(Deducciones_Importadas; "Deducciones Importadas")
            { }
            column(Cargas_Familia_Importadas; "Cargas Familia Importadas")
            { }
            column(Estado; Estado)
            { }
            column(Fecha_Importacion; "Fecha Importación")
            { }
        }
    }

    // Layout: RDLC o Excel
}
```

### 2. Página de Asistente (Wizard)

```al
page 50162 "Asistente Importación SIRADIG"
{
    ApplicationArea = All;
    Caption = 'Asistente de Importación SIRADIG';
    PageType = NavigatePage;

    layout
    {
        area(Content)
        {
            group(Step1)
            {
                Visible = CurrentStep = 1;
                Caption = 'Seleccionar Carpeta';

                field(CarpetaOrigen; CarpetaOrigenVar)
                {
                    Caption = 'Carpeta con archivos SIRADIG';
                    AssistEdit = true;

                    trigger OnAssistEdit()
                    begin
                        // Implementar diálogo de carpeta
                    end;
                }
            }

            group(Step2)
            {
                Visible = CurrentStep = 2;
                Caption = 'Opciones de Procesamiento';

                field(ProcesarAutomaticamente; ProcesarAutomaticamenteVar)
                {
                    Caption = 'Procesar automáticamente después de importar';
                }
                field(NotificarCambios; NotificarCambiosVar)
                {
                    Caption = 'Notificar cambios significativos';
                }
            }

            group(Step3)
            {
                Visible = CurrentStep = 3;
                Caption = 'Resumen';

                field(ArchivosEncontrados; ArchivosEncontradosVar)
                {
                    Caption = 'Archivos a procesar';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Siguiente)
            {
                Caption = 'Siguiente';
                trigger OnAction()
                begin
                    if CurrentStep < 3 then
                        CurrentStep += 1;
                end;
            }
            action(Anterior)
            {
                Caption = 'Anterior';
                trigger OnAction()
                begin
                    if CurrentStep > 1 then
                        CurrentStep -= 1;
                end;
            }
            action(Procesar)
            {
                Caption = 'Procesar';
                trigger OnAction()
                begin
                    ProcesarImportacion();
                end;
            }
        }
    }

    var
        CurrentStep: Integer;
        CarpetaOrigenVar: Text;
        ProcesarAutomaticamenteVar: Boolean;
        NotificarCambiosVar: Boolean;
        ArchivosEncontradosVar: Integer;
}
```

### 3. Tabla de Mapeos Personalizados

```al
table 60027 "Mapeo SIRADIG - Deducción Local"
{
    Caption = 'Mapeo SIRADIG - Deducción Local';

    fields
    {
        field(1; "Código SIRADIG"; Code[20])
        {
            Caption = 'Código SIRADIG';
        }
        field(2; "Código Deducción Local"; Code[20])
        {
            Caption = 'Código Deducción Local';
        }
        field(3; "Descripción"; Text[100])
        {
            Caption = 'Descripción del Mapeo';
        }
        field(4; Activo; Boolean)
        {
            Caption = 'Activo';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Código SIRADIG") { }
    }
}
```

### 4. Extensión a Tab60022 para Auditoría

```al
tableextension 60022 "Ded. Ganancias Empleado Ext" extends "Ded. Ganancias Empleado"
{
    fields
    {
        field(50025; "Origen Importación"; Code[20])
        {
            Caption = 'Origen Importación';
            TableRelation = "Importación SIRADIG"."No.";
            // Vincular con registro de importación
        }
        field(50026; "Fecha Última Actualización"; DateTime)
        {
            Caption = 'Fecha Última Actualización SIRADIG';
            Editable = false;
        }
    }
}
```

---

## 🔍 Validaciones Adicionales a Considerar

### Validación 1: Período Válido

```al
procedure ValidarPeriodo(Periodo: Integer): Boolean
begin
    // El período debe ser un año válido (2020-2099)
    if (Periodo < 2020) or (Periodo > 2099) then
        exit(false);
    exit(true);
end;
```

### Validación 2: Montos Razonables

```al
procedure ValidarMontosRazonables(CodigoDeduccion: Code[20]; Monto: Decimal): Boolean
var
    DedGananciasVig: Record "Ded. Ganancias Vigente";
begin
    // Validar que el monto no es excesivamente diferente del histórico
    DedGananciasVig.SetRange(Código, CodigoDeduccion);
    if DedGananciasVig.FindFirst() then
        if Monto > DedGananciasVig."Importe Anual" * 2 then
            exit(false); // Monto muy alto comparado con referencia AFIP

    exit(true);
end;
```

### Validación 3: Familiares Válidos

```al
procedure ValidarFamiliarValido(
    TipoDoc: Code[20];
    NroDoc: Text;
    Parentesco: Code[10]
): Boolean
begin
    // Validar que el tipo de documento existe
    if not ValidarTipoDocumento(TipoDoc) then
        exit(false);

    // Validar que el número de documento es válido
    if StrLen(DelChr(NroDoc, '=', '0123456789')) > 0 then
        exit(false);

    // Validar que el parentesco es válido
    if not ValidarCodigoParentesco(Parentesco) then
        exit(false);

    exit(true);
end;
```

---

## 🔄 Integración con Liquidación

### Recalcular Liquidaciones Pendientes Después de Importación

```al
procedure RecalcularLiquidacionesDespuesDeImportacion(
    var RegistroImportacion: Record "Importación SIRADIG"
)
var
    Liquidacion: Record Liquidación;
    ProcesadorLiq: Codeunit "Procesador Liquidación";
begin
    // Buscar todas las liquidaciones del empleado que sean posteriores a la importación
    Liquidacion.SetRange("No. Empleado", RegistroImportacion."No. Empleado");
    Liquidacion.SetFilter(Fecha, '>%1', RegistroImportacion."Fecha Importación");
    Liquidacion.SetRange(Estado, "Estado Liq."::Borrador);

    if Liquidacion.FindSet() then begin
        repeat
            // Recalcular deducciones en la liquidación
            ProcesadorLiq.RecalcularDeduccionesEnLiquidacion(Liquidacion);
        until Liquidacion.Next() = 0;

        Message('Se recalcularon %1 liquidaciones pendientes.', Liquidacion.Count);
    end;
end;
```

---

## 📊 Consultas SQL para Análisis

### Deducciones Importadas por Período

```sql
SELECT
    'Período' = im.Período,
    'Empleados' = COUNT(DISTINCT im."No. Empleado"),
    'Deducciones Total' = SUM(im."Deducciones Importadas"),
    'Familiares Total' = SUM(im."Cargas Familia Importadas"),
    'Estado' = CASE im.Estado
        WHEN 0 THEN 'Pendiente'
        WHEN 1 THEN 'Exitoso'
        WHEN 2 THEN 'Advertencias'
        WHEN 3 THEN 'Error'
    END
FROM "Importación SIRADIG" im
GROUP BY im.Período, im.Estado
ORDER BY im.Período DESC, im.Estado
```

### Empleados sin Importación Reciente

```sql
SELECT
    e."No.",
    e.Name,
    e."Social Security No." AS CUIL,
    'Última Importación' = MAX(im."Fecha Importación")
FROM Employee e
LEFT JOIN "Importación SIRADIG" im ON e."No." = im."No. Empleado"
GROUP BY e."No.", e.Name, e."Social Security No."
HAVING MAX(im."Fecha Importación") < DATEADD(MONTH, -3, GETDATE())
    OR MAX(im."Fecha Importación") IS NULL
ORDER BY 4
```

---

## 🚨 Procedimiento de Rollback

Si una importación causa problemas, seguir estos pasos:

```al
procedure RollbackImportacion(
    var RegistroImportacion: Record "Importación SIRADIG"
)
var
    DedGananciasEmp: Record "Ded. Ganancias Empleado";
    EmpleadoRelativo: Record "Employee Relative";
begin
    // Paso 1: Eliminar deducciones importadas por este registro
    DedGananciasEmp.SetRange("No. Empleado", RegistroImportacion."No. Empleado");
    DedGananciasEmp.SetRange("Origen Importación", Format(RegistroImportacion."No."));
    if DedGananciasEmp.FindSet() then
        DedGananciasEmp.DeleteAll();

    // Paso 2: Eliminar familiares importados por este registro
    // (Nota: Employee Relative no tiene campo de origen, usar fecha/usuario como criterio)
    EmpleadoRelativo.SetRange("Employee No.", RegistroImportacion."No. Empleado");
    // Agregar filtro por rango de fechas si es necesario

    // Paso 3: Marcar importación como revertida
    RegistroImportacion.Estado := "Estado Importación SIRADIG"::"Pendiente Procesar";
    RegistroImportacion."Mensajes Error" := 'Revertida manualmente';
    RegistroImportacion.Modify();

    Message('Importación revertida exitosamente.');
end;
```

---

## 📋 Checklist de Implementación Avanzada

- [ ] Implementar validaciones adicionales de montos y períodos
- [ ] Crear reporte de importaciones
- [ ] Crear asistente (wizard) para facilitar uso
- [ ] Integrar con sistema de Job Queue para procesamiento automático
- [ ] Crear tabla de mapeos personalizados si se requiere
- [ ] Extender Tab60022 para auditoría de origen
- [ ] Implementar recálculo de liquidaciones pendientes
- [ ] Crear dashboard con resumen de importaciones
- [ ] Documentar procedimiento de rollback
- [ ] Crear pruebas unitarias

---

**Última actualización**: 2026-06-11
