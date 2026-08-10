namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 60012 "Línea Liquidación"
{
    Caption = 'Línea Liquidación';
    DataClassification = CustomerContent;
    // All amounts are stored as positive values. TipoConcepto determines sign:
    //   Haber Rem / Haber No Rem  → adds to neto
    //   Descuento / Retención     → subtracts from neto
    //   Contribución Patronal     → employer side, excluded from neto
    // The motor and report apply sign logic based on TipoConcepto.

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(3; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
        }
        field(4; "Descripción Concepto"; Text[100])
        {
            Caption = 'Descripción Concepto';
            DataClassification = CustomerContent;
        }
        field(5; "Nombre Impresión"; Text[50])
        {
            Caption = 'Nombre Impresión';
            DataClassification = CustomerContent;
        }
        field(6; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo Concepto';
            DataClassification = CustomerContent;
        }
        field(7; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(8; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden Cálculo';
            DataClassification = CustomerContent;
        }
        field(9; "Fórmula Aplicada"; Text[2048])
        {
            Caption = 'Fórmula Aplicada';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(11; "Fuente Parámetros"; Text[2048])
        {
            Caption = 'Fuente Parámetros';
            DataClassification = CustomerContent;
            Editable = false;
            // Pipe-separated list of "PARAM_CODE|DATE" pairs identifying which
            // ParametroVigente records were used, for audit traceability.
        }
        field(12; "Vigencia Concepto"; Date)
        {
            Caption = 'Vigencia Concepto';
            DataClassification = CustomerContent;
            Editable = false;
            // The VigenciaDesde of the ConceptoLiquidación version used.
        }
        field(13; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
        }
        field(14; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad';
            DataClassification = CustomerContent;
        }
        field(15; "Fórmula Evaluada"; Text[2048])
        {
            Caption = 'Fórmula con Valores';
            DataClassification = CustomerContent;
            Editable = false;
        }

        // ── Campos desnormalizados de la cabecera ─────────────────────────────
        // Permiten consultar Línea Liquidación sin join a Liquidación.
        // Se escriben en el motor al crear la línea y se sincronizan en cada
        // recálculo (DeleteLineas + recreación). Estado se setea a Calculada;
        // las transiciones a Aprobada/Contabilizada requieren sincronización
        // adicional en los flujos de aprobación y contabilización.

        field(16; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = Employee."No.";
            Editable = false;
        }
        field(17; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
            Editable = false;
        }
        field(18; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            Editable = false;
        }
        field(30; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo Liquidación';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
            Editable = false;
        }
        field(20; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
            Editable = false;
        }
        field(21; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(22; Estado; Enum "Estado Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(23; "Fecha Liquidación"; Date)
        {
            Caption = 'Fecha Liquidación';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(24; "Imprime en Recibo"; Boolean)
        {
            Caption = 'Imprime en Recibo';
            DataClassification = CustomerContent;
            Editable = false;
            InitValue = true;
        }
        field(25; "Grupo Costo Laboral"; Enum "Grupo Costo Laboral Liq.")
        {
            Caption = 'Grupo Costo Laboral';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(27; "Base Cálculo"; Decimal)
        {
            Caption = 'Base Cálculo';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(26; "Es Devengo"; Boolean)
        {
            Caption = 'Is Accrual';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "No. Línea")
        {
            Clustered = true;
            SumIndexFields = Importe;
        }
        // "Es Devengo" va en el MEDIO a propósito: los dos únicos consumidores de esta SIFT
        // (UpdateTotals y CalcNetoDesdeBD en Cod50014) filtran siempre por los tres campos.
        // Con "Es Devengo" fuera de la clave, ese filtro impedía usar el índice acumulado y
        // ambos degradaban a suma con escaneo — CalcNetoDesdeBD, además, dentro del loop de
        // convergencia de Grossing Up. Si agregás un CalcSums que filtre No. Liquidación +
        // Tipo Concepto SIN "Es Devengo", no va a poder usar esta SIFT.
        key(K2; "No. Liquidación", "Es Devengo", "Tipo Concepto")
        {
            SumIndexFields = Importe;
        }
        key(K3; "No. Liquidación", "Orden Cálculo", "No. Línea")
        {
        }
        key(K4; "No. Empleado", "Fecha Liquidación", "Tipo Concepto")
        {
            SumIndexFields = Importe;
        }
        key(K5; "No. Empleado", "Cód. Período", "Tipo Concepto")
        {
            SumIndexFields = Importe;
        }
    }

    trigger OnDelete()
    var
        Det: Record "Detalle Variable Línea Liq.";
    begin
        Det.SetRange("No. Liquidación", "No. Liquidación");
        Det.SetRange("No. Línea", "No. Línea");
        Det.DeleteAll();
    end;
}
