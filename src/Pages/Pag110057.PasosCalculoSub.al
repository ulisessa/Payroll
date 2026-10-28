namespace UAS.Payroll;

page 110057 "Pasos Cálculo Sub"
{
    PageType = ListPart;
    SourceTable = "Paso Cálculo Línea";
    SourceTableTemporary = true;
    Editable = false;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(Pasos)
            {
                field(Signo; Rec.Signo) { Caption = 'Operación'; }
                field(Descripción; Rec.Descripción) { Caption = 'Concepto / paso'; StyleExpr = Estilo; }
                field(Valor; Rec.Valor) { Caption = 'Valor'; StyleExpr = Estilo; }
                field(Acumulado; Rec.Acumulado) { Caption = 'Resultado del bloque'; Visible = MostrarAcumulado; StyleExpr = Estilo; }
                field(Término; Rec.Término) { Caption = 'Expresión'; Visible = MostrarExpresion; }
                field(Detalle; Rec.Detalle) { Caption = 'Explicación'; }
            }
            group(Seleccion)
            {
                ShowCaption = false;
                Visible = HayDetalle;
                field(Explicacion; Rec.Detalle) { Caption = 'Detalle del paso seleccionado'; MultiLine = true; }
            }
        }
    }
    var
        Estilo: Text;
        MostrarExpresion: Boolean;
        MostrarAcumulado: Boolean;
        HayDetalle: Boolean;
    trigger OnAfterGetRecord()
    begin
        Estilo := 'Standard';
        if Rec."Es Subtotal" or Rec."Es Total" then
            Estilo := 'Strong';
        if StrPos(Rec.Descripción, 'NO COINCIDE') > 0 then
            Estilo := 'Unfavorable';
    end;
    procedure Cargar(var Datos: Record "Paso Cálculo Línea" temporary; Expresion: Boolean; Acumulado: Boolean)
    begin
        Rec.Copy(Datos, true);
        MostrarExpresion := Expresion;
        MostrarAcumulado := Acumulado;
        Rec.SetFilter(Detalle, '<>%1', '');
        HayDetalle := not Rec.IsEmpty();
        Rec.SetRange(Detalle);
        if Rec.FindFirst() then;
    end;
}
