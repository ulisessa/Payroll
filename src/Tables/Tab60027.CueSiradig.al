namespace UAS.Payroll;

table 60027 "Cue SIRADIG"
{
    Caption = 'Cue SIRADIG';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Pendientes"; Integer)
        {
            Caption = 'Pendientes de Procesar';
            FieldClass = FlowField;
            CalcFormula = count("Importación SIRADIG" where(Estado = const("Pendiente Procesar")));
            Editable = false;
        }
        field(3; "Con Errores"; Integer)
        {
            Caption = 'Con Errores';
            FieldClass = FlowField;
            CalcFormula = count("Importación SIRADIG" where(Estado = const("Error en Procesamiento")));
            Editable = false;
        }
        field(4; "Procesados"; Integer)
        {
            Caption = 'Procesados Exitosamente';
            FieldClass = FlowField;
            CalcFormula = count("Importación SIRADIG" where(Estado = const("Procesado Exitosamente")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
