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
    //   DIAS_FERIADOS     — calendar days in the period with a date-specific holiday entry in the
    //                       período's Cód. Calendario (Base Calendar Change, Nonworking=true). Requires
    //                       a calendar configured with the actual holiday dates; excludes ordinary weekends.
    //                       Use for Regular/Devengados. For Cierre Marea use DIAS_FERIADOS_MAREA instead —
    //                       this one spans the full período, not the marea's own window.
    //   DIAS_FERIADOS_MAREA — same holiday criteria as DIAS_FERIADOS, but only within the marea's own
    //                       window for this liquidation (like DIAS_PROYECTO/DIAS_PUERTO) — días feriados
    //                       efectivamente a bordo. Para recargo por feriado trabajado en la marea.
    //   DIAS_HAB_ANIO     — working days in the full calendar year of the reference date
    //   DIAS_ALTA_ANIO    — working days within active employment in the calendar year
    //   DIAS_PROYECTO     — navigation days for the linked Job
    //   DIAS_PUERTO       — port (boundary) days of the marea within the billing window
    //   DIAS_ENROLAMIENTO — calendar days enrolled on the vessel across the whole marea (accruing states)
    //   DIAS_FRANCOS_PERIODO — calendar days in a Francos state within the billing period (francos consumed)
    //   PAGO_FRANCOS_FIFO — amount for the francos consumed this period, FIFO, each lot at its category value
    //   FRANCOS_CONSUMIDOS — francos actually consumed this period = min(días en Francos, saldo disponible)
    //   SALDO_FRANCOS     — pending franco balance (accrued − consumed) for the employee
    //   PCT_ESCALA        — Categoría CCT."% Escala" / 100
    //   VACACIONES_ANUALES — Art. 150 LCT: annual vacation days by seniority
    //   VACACIONES_PROP_DIAS — proportional vacation days (DIAS_ALTA_ANIO / 20, rounded down)
    //   DIAS_VAC_PERIODO  — calendar days in Vacaciones state overlapping the billing period
    //   DEDUC_GANANCIAS   — annual deductions: cargas de familia + gastos deducibles (AFIP tables)
    //   MES_ANUAL         — calendar month number of the reference date (1–12)
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

            trigger OnLookup()
            var
                Codigos: TextBuilder;
                Opciones: Text;
                Seleccion: Integer;
            begin
                Opciones := 'ANIOS_ANTIGUEDAD,DIAS_HAB,DIAS_FERIADOS,DIAS_FERIADOS_MAREA,DIAS_HAB_ANIO,DIAS_ALTA_ANIO,DIAS_PROYECTO,DIAS_PUERTO,DIAS_ENROLAMIENTO,DIAS_FRANCOS_PERIODO,PAGO_FRANCOS_FIFO,FRANCOS_CONSUMIDOS,SALDO_FRANCOS,PCT_ESCALA,VACACIONES_ANUALES,VACACIONES_PROP_DIAS,DIAS_VAC_PERIODO,DIAS_VAC_INICIO,DEDUC_GANANCIAS,MES_ANUAL,YTD_ACUM,YTD_LINEAS';
                Seleccion := StrMenu(Opciones, 0, 'Seleccione un código de cálculo');
                if Seleccion > 0 then
                    Validate("Cód. Cálculo", CopyStr(SelectStr(Seleccion, Opciones), 1, MaxStrLen("Cód. Cálculo")));
            end;
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
