namespace UAS.Payroll;

// Alta y edición de un valor de parámetro. La clave derivada no se escribe: se muestra, y se arma
// sola con el parámetro base más los campos de alcance que se completen.
page 110014 "Ficha Valor Parámetro"
{
    ApplicationArea = All;
    Caption = 'Valor de Parámetro';
    PageType = Card;
    SourceTable = "Parámetro Vigente";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Cód. Parámetro Base"; Rec."Cód. Parámetro Base")
                {
                    ApplicationArea = All;
                    Caption = 'Parámetro';
                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave derivada';
                    Style = Strong;
                    ToolTip = 'La clave con la que el motor busca este valor. Se calcula sola con los campos de alcance de abajo.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor) { ApplicationArea = All; }
                field(Moneda; Rec.Moneda)
                {
                    ApplicationArea = All;
                    ToolTip = 'Si se completa, el valor se considera cargado en moneda extranjera y la fórmula puede convertirlo con la bandera <VARIABLE>_ESFCY.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Notas; Rec.Notas) { ApplicationArea = All; MultiLine = true; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado cuando este valor ya fue utilizado en una liquidación registrada. En ese caso no se modifica: se carga una vigencia nueva.';
                }
            }
            group(GrpAlcance)
            {
                Caption = 'Alcance';
                InstructionalText = 'Dejar todo vacío para el valor por defecto del parámetro. Completar convenio, o convenio y categoría, o empleado, para cargar una excepción. El empleado es excluyente con los otros dos.';

                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }
}
