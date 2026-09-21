namespace UAS.Payroll;

page 110047 "Historia Liq. Meta4"
{
    ApplicationArea = All;
    Caption = 'Historia de Liquidaciones (Meta4)';
    PageType = List;
    UsageCategory = History;
    SourceTable = "Hist. Liq. Meta4";
    SourceTableView = sorting("Fecha Imputación") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    CardPageId = "Ficha Hist. Liq. Meta4";

    // 485.000 filas. La vista arranca por lo más reciente porque es lo que se consulta casi siempre;
    // lo viejo se busca filtrando por legajo, que es el índice que existe para eso.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Legajo en Meta4. Coincide con el de BC, pero puede tratarse de alguien que ya no está en el padrón.';
                }
                field("Apellido Empleado"; Rec."Apellido Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Apellido según el padrón ACTUAL de BC. Queda vacío si el empleado ya no existe: el archivo no afirma nombres que no puede verificar.';
                }
                field("Nombre Empleado"; Rec."Nombre Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre según el padrón ACTUAL de BC. Queda vacío si el empleado ya no existe: el archivo no afirma nombres que no puede verificar.';
                }
                field("Fecha Imputación"; Rec."Fecha Imputación") { ApplicationArea = All; }
                field("Fecha Pago"; Rec."Fecha Pago")
                {
                    ApplicationArea = All;
                    ToolTip = 'Distingue varias corridas dentro del mismo mes.';
                }
                field("Tipo Imputación"; Rec."Tipo Imputación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código crudo de Meta4, sin traducir. 1 es la corrida habitual, 3 vacaciones, 4 anticipos, 14 liquidación final, 99 indemnización.';
                }
                field("Contador Liq."; Rec."Contador Liq.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden real de las corridas. No coincide con la fecha: para saber cuál fue la última de un mes hay que mirar este número, no el calendario.';
                }
                field("Cód. Buque Meta4"; Rec."Cód. Buque Meta4")
                {
                    ApplicationArea = All;
                    ToolTip = 'Buque con el código de Meta4 (A28, HF801).';
                }
                field("No. Marea Meta4"; Rec."No. Marea Meta4")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marea que ESTA corrida paga. Un mismo mes puede tener corridas de tres mareas distintas: la anterior en la liquidación de puerto, la que cierra, y la siguiente en la mensual.';
                }
                field("Cód. Convenio Meta4"; Rec."Cód. Convenio Meta4")
                {
                    ApplicationArea = All;
                    ToolTip = 'Convenio con los códigos de Meta4 (MR, OF, FA...), no con los de BC.';
                }
                field("Fecha Alta Empleado"; Rec."Fecha Alta Empleado")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Parte de la clave en Meta4: un reingreso abre otra serie de liquidaciones.';
                }
                field("Cód. Sociedad"; Rec."Cód. Sociedad") { ApplicationArea = All; Visible = false; }
                field("Cód. Empresa Meta4"; Rec."Cód. Empresa Meta4") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Valores)
            {
                ApplicationArea = All;
                Caption = 'Valores';
                Image = View;
                ToolTip = 'Abre todos los valores registrados en esta liquidación.';
                RunObject = page "Ficha Hist. Liq. Meta4";
                RunPageOnRec = true;
            }
            action(Columnas)
            {
                ApplicationArea = All;
                Caption = 'Catálogo de columnas';
                Image = List;
                ToolTip = 'Las columnas de Meta4 y cuántas veces se usó cada una.';
                RunObject = page "Columnas Hist. Meta4";
            }
        }
    }
}
