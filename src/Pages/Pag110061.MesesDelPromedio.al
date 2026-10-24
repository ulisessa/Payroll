namespace UAS.Payroll;

// El detalle mes a mes de la ventana del promedio de vacaciones.
//
// El resumen dice que el promedio quedó corto; esta vista dice QUÉ MES lo hundió. Hay tres maneras
// de que un mes arruine el promedio y las tres se ven acá:
//
//   - cuenta en el divisor y no aporta base  → hueco en la historia;
//   - aporta una fracción y pesa un mes entero → el mes del ingreso o del egreso, trabajado a medias;
//   - queda fuera de la fase vigente → no debería estar en la ventana.
//
// El segundo caso es el que desparramó los ratios en enero de 2026: a un tripulante que entró el 25
// de noviembre, ese mes le aportaba una fracción y le sumaba un mes entero al divisor.
page 110061 "Meses del Promedio"
{
    ApplicationArea = All;
    Caption = 'Meses del promedio';
    PageType = List;
    UsageCategory = None;
    SourceTable = "Vac. Mes Buffer Liq.";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Cabecera)
            {
                Caption = 'Empleado';
                field(EmpleadoTxt; EmpleadoTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Empleado';
                    Editable = false;
                }
                field(TotalBase; TotalBase)
                {
                    ApplicationArea = All;
                    Caption = 'Base acumulada';
                    Editable = false;
                    AutoFormatType = 1;
                }
                field(MesesQueCuentan; MesesQueCuentan)
                {
                    ApplicationArea = All;
                    Caption = 'Meses que cuentan';
                    Editable = false;
                }
                field(PromedioTxt; PromedioTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Promedio mensual';
                    Editable = false;
                    AutoFormatType = 1;
                }
            }

            repeater(Grilla)
            {
                field("Cód. Período"; Rec."Cód. Período") { ApplicationArea = All; }
                field("Mes Desde"; Rec."Mes Desde") { ApplicationArea = All; }
                field("Mes Hasta"; Rec."Mes Hasta") { ApplicationArea = All; }
                field(Base; Rec.Base)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cuenta en el Divisor"; Rec."Cuenta en el Divisor") { ApplicationArea = All; }
                field("Días Cubiertos"; Rec."Días Cubiertos")
                {
                    ApplicationArea = All;
                    ToolTip = 'Días del mes en los que el empleado estuvo de alta.';
                }
                field("Días del Mes"; Rec."Días del Mes") { ApplicationArea = All; }
                field(Completo; Rec.Completo)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                    ToolTip = 'Un mes incompleto aporta una fracción al numerador pero pesa un mes entero en el divisor.';
                }
                field(Observación; Rec.Observación)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
            }
        }
    }

    var
        EmpleadoTxt: Text;
        TotalBase: Decimal;
        PromedioTxt: Decimal;
        MesesQueCuentan: Integer;
        EstiloFila: Text;

    /// <summary>Carga el buffer ya armado por el codeunit de análisis.</summary>
    procedure Cargar(var Origen: Record "Vac. Mes Buffer Liq." temporary; EmployeeNo: Code[20]; Nombre: Text)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        EmpleadoTxt := EmployeeNo + ' - ' + Nombre;
        TotalBase := 0;
        MesesQueCuentan := 0;

        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
                TotalBase += Origen.Base;
                if Origen."Cuenta en el Divisor" then
                    MesesQueCuentan += 1;
            until Origen.Next() = 0;

        if MesesQueCuentan > 0 then
            PromedioTxt := TotalBase / MesesQueCuentan;
        if Rec.FindFirst() then;
    end;

    trigger OnAfterGetRecord()
    begin
        case true of
            Rec."Cuenta en el Divisor" and (Rec.Base = 0):
                EstiloFila := 'Unfavorable';
            not Rec.Completo:
                EstiloFila := 'Attention';
            else
                EstiloFila := 'Standard';
        end;
    end;
}
