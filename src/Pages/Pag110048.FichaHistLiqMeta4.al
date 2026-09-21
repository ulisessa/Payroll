namespace UAS.Payroll;

page 110048 "Ficha Hist. Liq. Meta4"
{
    ApplicationArea = All;
    Caption = 'Liquidación Meta4';
    PageType = Card;
    UsageCategory = None;
    SourceTable = "Hist. Liq. Meta4";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Apellido Empleado"; Rec."Apellido Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Apellido según el padrón ACTUAL de BC. Queda vacío si el empleado ya no existe: el archivo no afirma nombres que no puede verificar.';
                }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("Fecha Imputación"; Rec."Fecha Imputación") { ApplicationArea = All; }
                field("Fecha Pago"; Rec."Fecha Pago") { ApplicationArea = All; }
                field("Tipo Imputación"; Rec."Tipo Imputación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código crudo de Meta4. No se traduce porque Meta4 no expone ninguna tabla de dominio que diga qué es cada número; lo que sabemos se dedujo mirando qué trae cargado cada tipo.';
                }
                field("Contador Liq."; Rec."Contador Liq.") { ApplicationArea = All; }
                field("Cód. Buque Meta4"; Rec."Cód. Buque Meta4") { ApplicationArea = All; }
                field("No. Marea Meta4"; Rec."No. Marea Meta4")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marea que ESTA corrida paga. Un mismo mes puede tener corridas de mareas distintas: la anterior en la liquidación de puerto, la que cierra, y la siguiente en la mensual.';
                }
            }
            group(Origen)
            {
                Caption = 'Origen en Meta4';
                field("Cód. Sociedad"; Rec."Cód. Sociedad") { ApplicationArea = All; }
                field("Cód. Empresa Meta4"; Rec."Cód. Empresa Meta4") { ApplicationArea = All; }
                field("Cód. Convenio Meta4"; Rec."Cód. Convenio Meta4") { ApplicationArea = All; }
                field("Fecha Alta Empleado"; Rec."Fecha Alta Empleado") { ApplicationArea = All; }
                field("No. Entrada"; Rec."No. Entrada") { ApplicationArea = All; }
            }
            part(Valores; "Valores Hist. Meta4")
            {
                ApplicationArea = All;
                Caption = 'Valores';
                SubPageLink = "No. Entrada" = field("No. Entrada");
                UpdatePropagation = Both;
            }
        }
    }
}
