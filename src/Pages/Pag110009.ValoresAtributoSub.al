namespace UAS.Payroll;

page 110009 "Valores Atributo Sub"
{
    ApplicationArea = All;
    Caption = 'Valores permitidos';
    PageType = ListPart;
    SourceTable = "Valor Atributo Liq.";
    // Sin AutoSplitKey: solo sirve cuando el último campo de la clave primaria es un Integer de
    // número de línea, y acá la clave es (Cód. Tipo Atributo, Código), dos códigos que carga la
    // persona. DelayedInsert sí, para que la fila se escriba recién con el código completo.
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Valor Numérico"; Rec."Valor Numérico")
                {
                    ApplicationArea = All;
                    ToolTip = 'El número que ve la fórmula cuando una entidad tiene este valor asignado. Cambiarlo NO reescribe lo ya asignado: cada asignación conserva el número con el que se cargó, para que un recálculo viejo dé lo mismo que dio.';
                }
            }
        }
    }
}
