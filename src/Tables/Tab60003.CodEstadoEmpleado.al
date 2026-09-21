namespace UAS.Payroll;

table 60003 "Cód. Estado Empleado"
{
    Caption = 'Cód. Estado Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Cód. Estados Empleado";
    DrillDownPageId = "Cód. Estados Empleado";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Tipo Empleado"; Enum "Aplica A Liq.")
        {
            Caption = 'Tipo Empleado';
            DataClassification = CustomerContent;
        }
        field(4; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(5; "Tipo Estado"; Enum "Tipo Estado Empleado")
        {
            Caption = 'Tipo Estado';
            DataClassification = CustomerContent;
            // Alta: opens an employment period for seniority calculation.
            // Baja: closes the current employment period.
            // Vacaciones: its effective window is capped at the LCT day entitlement when counting DIAS_VAC_PERIODO.
            // Normal: all other states (Enfermedad, Suspensión, etc.) — included in seniority automatically.
        }
        field(6; "Ámbito"; Enum "Ámbito Estado")
        {
            Caption = 'Ámbito';
            DataClassification = CustomerContent;
            // Whether this state applies to employees, vessels, or both. Vessels use a subset.
        }
        field(7; "Estado Siguiente"; Code[20])
        {
            Caption = 'Estado Siguiente';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;
            // Auto-transition target: when this state's condition ends (e.g. francos balance used up),
            // the entity moves to this state. Blank = terminal (stays until a new state is set).
        }
        field(8; "Devenga Francos"; Boolean)
        {
            Caption = 'Devenga Francos';
            DataClassification = CustomerContent;
            // Productive/embarked state: its calendar days on a marea count toward DIAS_ENROLAMIENTO,
            // the base for the franco accrual. Francos are enjoyed later in a "Tipo Estado = Francos" state.
        }
        field(9; "Descripción Ampliada"; Text[250])
        {
            Caption = 'Descripción Ampliada';
            DataClassification = CustomerContent;
            // El detalle que no entra en la Descripción: qué genera la causal, contra qué artículo
            // se paga, qué mirar antes de usarla. Nació para traer los comentarios de los motivos de
            // baja de Meta4 —"Genera Indemnización por antigüedad (100%)", "El código no debe ser
            // borrado o modificado"— que se perderían al migrar y que son justamente lo que uno
            // necesita leer cuando duda entre dos códigos parecidos.
        }
        field(10; "Transcurre en Marea"; Boolean)
        {
            Caption = 'Transcurre en Marea';
            DataClassification = CustomerContent;
            // ¿Estos días transcurren A BORDO, dentro de una marea? Sí para navegación y los días de
            // puerto de la marea —salida y llegada—; no para guardia en puerto, dique y pilotaje,
            // que son trabajo en tierra o fuera del viaje.
            //
            // NO ES LO MISMO QUE "Devenga Francos", y confundirlas costó caro. Esa bandera contesta
            // "¿está trabajando?" y por eso GP, DQ y PI la tienen en Sí: la guardia en puerto se
            // trabaja y genera francos. La migración la usó además para decidir a qué proyecto va el
            // estado, y ahí falla: coinciden para NV, PS y PL, pero GP/DQ/PI devengan francos SIN
            // estar en ninguna marea.
            //
            // El resultado fue 12.324 guardias en puerto colgadas del proyecto de la marea anterior,
            // una de ellas 3.904 días después del arribo — porque el ID_MAREA de Meta4 se congela
            // cuando el barco llega y la gente queda en tierra.
            //
            // Quién la lee: ResolverProyectoInactividad (Cod50017), para mandar al proyecto de
            // nómina el estado que deja la marea.
        }
    }

    keys
    {
        key(PK; Código)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Tipo Empleado") { }
    }
}
