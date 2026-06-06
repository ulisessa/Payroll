namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

table 60022 "Ded. Ganancias Empleado"
{
    Caption = 'Deducciones Ganancias del Empleado';
    DataClassification = CustomerContent;
    // Per-employee Ganancias 4th category deduction declarations, versioned by date.
    //
    // Each "version" is the full set of rows sharing the same (No. Empleado, Vigencia Desde).
    // The motor takes the latest version with Vigencia Desde <= FechaRef.
    //
    // Resolution of each line:
    //   Importe Fijo > 0  → use Importe Fijo (prepaga, mortgage interest, domestic service)
    //   Importe Fijo = 0  → DedGananciasVigente.Importe Anual × Cantidad (family headcount)

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "Cód. Tipo"; Code[20])
        {
            Caption = 'Tipo Deducción';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Ded. Ganancias Vigente".Código;

            trigger OnValidate()
            var
                DedVig: Record "Ded. Ganancias Vigente";
            begin
                if Descripción = '' then begin
                    DedVig.SetRange(Código, "Cód. Tipo");
                    if DedVig.FindFirst() then
                        Descripción := DedVig.Descripción;
                end;
            end;
        }
        field(4; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(5; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            InitValue = 1;
            // Headcount for family-member types (HIJO_MENOR, ASCENDIENTE, etc.).
            // Leave 1 for fixed-amount types.
        }
        field(6; "Importe Fijo"; Decimal)
        {
            Caption = 'Importe Fijo Anual';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            // When > 0, overrides the AFIP table amount.
            // Required for expense-based deductions (prepaga, mortgage, domestic service).
        }
        field(7; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Empleado", "Vigencia Desde", "Cód. Tipo") { Clustered = true; }
        key(K2; "No. Empleado", "Vigencia Desde") { }
    }
}
