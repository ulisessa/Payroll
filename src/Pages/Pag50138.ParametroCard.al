namespace UAS.Payroll;

page 50138 "Parámetro Card"
{
    ApplicationArea = All;
    Caption = 'Parámetro';
    PageType = Card;
    SourceTable = "Parámetro";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Código; Rec.Código)
                {
                    ApplicationArea = All;
                    Editable = Rec.Código = '';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre con el que este parámetro se expone en el contexto de fórmulas. Vacío = no se carga automáticamente.';
                }
                field("Sufijo CCT"; Rec."Sufijo CCT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, la clave de búsqueda real es Código_CONVENIO_CATEGORÍA (ej: BASICO_ADM_DES). Los valores se ingresan en la solapa inferior con esa clave completa.';
                }
                field("Sufijo Empleado"; Rec."Sufijo Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, la clave de búsqueda real es Código_NOEMPLEADO (ej: BASICO_EMP001). Permite definir un valor distinto por empleado. Excluyente con Sufijo Convenio/Categoría.';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; }
            }

            part(VigentesSufijo; "Parámetro Sufijo Sub")
            {
                ApplicationArea = All;
                Caption = 'Valores Vigentes';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CurrPage.VigentesSufijo.Page.SetBaseCodigo(Rec.Código, Rec."Sufijo Empleado");
    end;
}
