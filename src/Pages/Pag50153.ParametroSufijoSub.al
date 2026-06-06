namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50153 "Parámetro Sufijo Sub"
{
    ApplicationArea = All;
    Caption = 'Valores por Clave Derivada';
    PageType = ListPart;
    SourceTable = "Parámetro Vigente";
    DelayedInsert = true;
    // Used on the Parámetro card for all parameter types.
    // For Sufijo Empleado params: user fills No. Empleado → Cód. Parámetro is auto-computed.
    // For Sufijo CCT params: user types the full derived key (e.g. BASICO_ADM_DES) manually.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    Visible = FIsSufijoEmpleado;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado para el que aplica este valor. Al completarlo se calcula automáticamente la Clave Derivada.';

                    trigger OnValidate()
                    begin
                        if (FBaseCodigo <> '') and (Rec."No. Empleado" <> '') then
                            Rec."Cód. Parámetro" := FBaseCodigo + '_' + Rec."No. Empleado";
                    end;
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave Derivada';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Clave completa derivada del código base. Para sufijo CCT: BASICO_ADM_DES. Para sufijo empleado: se completa automáticamente al ingresar el No. Empleado.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo Valor';
                Image = NewRow;
                ToolTip = 'Inserta una nueva vigencia para la combinación seleccionada.';

                trigger OnAction()
                var
                    NuevoParam: Record "Parámetro Vigente";
                begin
                    Rec.TestField("Cód. Parámetro");
                    NuevoParam := Rec;
                    NuevoParam."Vigencia Desde" := WorkDate();
                    NuevoParam."En Uso" := false;
                    NuevoParam.Descripción := '';
                    if NuevoParam.Insert(true) then
                        CurrPage.Update(false);
                end;
            }
        }
    }

    procedure SetBaseCodigo(BaseCodigo: Code[20]; IsSufijoEmpleado: Boolean)
    begin
        FBaseCodigo := BaseCodigo;
        FIsSufijoEmpleado := IsSufijoEmpleado;
        Rec.FilterGroup(2);
        Rec.SetFilter("Cód. Parámetro", BaseCodigo + '*');
        Rec.FilterGroup(0);
        CurrPage.Update(false);
    end;

    var
        FBaseCodigo: Code[20];
        FIsSufijoEmpleado: Boolean;
}
