namespace UAS.Payroll;

table 60018 "Variable Sistema Liq."
{
    Caption = 'Variable Sistema Liquidación';
    DataClassification = CustomerContent;
    // Maps a system-computed value to a configurable variable name in the formula
    // context. The calculation logic is fixed in code (Contexto Liquidación); only
    // the variable name exposed to formulas is configurable here.
    //
    // Available computation codes (Cód. Cálculo):
    //   ANIOS_ANTIGUEDAD  — years from Employee."Employment Date" to period end
    //   DIAS_HAB          — working days (Mon–Fri) in the liquidation period
    //   DIAS_HAB_ANIO     — working days in the full calendar year of the reference date
    //   DIAS_ALTA_ANIO    — working days within active employment in the calendar year
    //   DIAS_PROYECTO     — navigation days for the linked Job
    //   PCT_ESCALA        — Categoría CCT."% Escala" / 100
    //   VACACIONES_ANUALES — Art. 150 LCT: annual vacation days by seniority
    //   VACACIONES_PROP_DIAS — proportional vacation days (DIAS_ALTA_ANIO / 20, rounded down)
    //   DIAS_VAC_PERIODO  — calendar days in Vacaciones state overlapping the billing period
    //   DEDUC_GANANCIAS   — annual deductions: cargas de familia + gastos deducibles (AFIP tables)
    //   MES_ANUAL         — calendar month number of the reference date (1–12)
    //   TIPO_LIQ          — current liquidation type as integer (Enum "Tipo Liq.".AsInteger())
    //   YTD_ACUM          — YTD sum of lines for concepts that feed "Cód. Acumulador" (Restar=false).
    //                       Requires "Cód. Acumulador". Multiple variables can share this code with
    //                       different accumulators (e.g. HAB_GRAV_ANUAL→BASE_IG4, HAB_EXTORD_ANUAL→BASE_EXT_IG4).
    //   YTD_LINEAS        — YTD sum of Línea Liquidación by "Tipo Concepto". Requires "Tipo Concepto".

    fields
    {
        field(1; "Cód. Cálculo"; Code[30])
        {
            Caption = 'Cód. Cálculo';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(5; "Mostrar en Recibo"; Boolean)
        {
            Caption = 'Mostrar en Recibo';
            DataClassification = CustomerContent;
        }
        field(6; "Etiqueta Recibo"; Text[100])
        {
            Caption = 'Etiqueta Recibo';
            DataClassification = CustomerContent;
        }
        field(7; "Etiqueta Det. Ganancias"; Text[100])
        {
            Caption = 'Etiqueta en Det. Ganancias';
            DataClassification = CustomerContent;
            // When non-empty, the motor writes a Tipo::Paso row in Detalle Ganancias Liq.
            // using this label and Orden Det. Ganancias as position.
        }
        field(8; "Orden Det. Ganancias"; Integer)
        {
            Caption = 'Orden en Det. Ganancias';
            DataClassification = CustomerContent;
        }
        field(9; "Cód. Acumulador"; Code[20])
        {
            Caption = 'Cód. Acumulador';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código WHERE("Es Acumulador" = CONST(true));
            // Required when Cód. Cálculo = YTD_ACUM.
        }
        field(10; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo Concepto';
            DataClassification = CustomerContent;
            // Required when Cód. Cálculo = YTD_LINEAS.
        }
    }

    keys
    {
        key(PK; "Nombre Variable") { Clustered = true; }
    }
}
