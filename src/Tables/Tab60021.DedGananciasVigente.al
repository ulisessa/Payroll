namespace UAS.Payroll;

table 60021 "Ded. Ganancias Vigente"
{
    Caption = 'Tabla Deducciones Ganancias';
    DataClassification = CustomerContent;
    // AFIP-published annual deduction amounts by type, versioned by effective date.
    // Each new AFIP resolution inserts new rows; old rows are kept for reliquidation/audit.
    //
    // Standard type codes:
    //   CONYUGE       Cónyuge / unión convivencial
    //   HIJO_MENOR    Hijo/a menor de 18 años
    //   HIJO_INCAP    Hijo/a incapacitado/a (sin límite de edad)
    //   ASCENDIENTE   Padre, madre, abuelo/a, suegro/a
    //   HERMANO       Hermano/a menor de 18 años
    //   OTROS         Otros a cargo (art. 30 LIG)
    //
    // Amount-based deductions (Cantidad always = 1, Importe Fijo used in employee record):
    //   PREPAGA        Cuotas de prepaga médica (hasta el 5% de ganancia neta)
    //   HIPOTECA       Intereses de crédito hipotecario (1ra vivienda, tope anual)
    //   SERV_DOM       Remuneración personal doméstico (hasta valor MNI anual)

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; "Importe Anual"; Decimal)
        {
            Caption = 'Importe Acumulado';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            ToolTip = 'Importe acumulado al período de vigencia. Para enero = 1/12 del anual; para febrero = 2/12; etc. Mismo criterio que MNI_ANUAL y DESP_4CAT_ANUAL.';
        }
        field(5; "Aplica Cantidad"; Boolean)
        {
            Caption = 'Aplica Cantidad';
            DataClassification = CustomerContent;
            // True = multiply by Cantidad in employee declaration (family members).
            // False = fixed amount entered in Importe Fijo on the employee record.
        }
    }

    keys
    {
        key(PK; Código, "Vigencia Desde") { Clustered = true; }
    }
}
