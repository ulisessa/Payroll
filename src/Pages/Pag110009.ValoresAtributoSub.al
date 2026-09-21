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
                field("Cód. Valor Padre"; Rec."Cód. Valor Padre")
                {
                    ApplicationArea = All;
                    Caption = 'Cuelga de';
                    Visible = TienePadre;
                    ToolTip = 'Valor del atributo del que depende éste. Solo se ofrece cuando el tipo declara un "Depende de": ahí cada valor tiene que decir de cuál cuelga, y es lo que permite repetir el mismo código bajo dos padres distintos.';
                }
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

    trigger OnOpenPage()
    begin
        ActualizarTienePadre();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        ActualizarTienePadre();
    end;

    // La columna solo aparece para los atributos encadenados. En una lista plana sería una columna
    // vacía que invita a completarla y después rebota con un error.
    local procedure ActualizarTienePadre()
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        CodTipo: Code[20];
    begin
        CodTipo := CopyStr(Rec.GetFilter("Cód. Tipo Atributo"), 1, MaxStrLen(CodTipo));
        if CodTipo = '' then
            CodTipo := Rec."Cód. Tipo Atributo";
        TienePadre := false;
        if TipoAtr.Get(CodTipo) then
            TienePadre := TipoAtr."Cód. Tipo Atributo Padre" <> '';
    end;

    var
        TienePadre: Boolean;
}
