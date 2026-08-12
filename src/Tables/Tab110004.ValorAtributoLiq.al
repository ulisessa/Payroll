namespace UAS.Payroll;

// El equivalente a un Valor de Dimensión: la lista cerrada contra la que se valida un atributo de
// tipo Lista.
//
// "Valor Numérico" es la pieza que hace que todo esto llegue a una fórmula. La fórmula no puede ver
// el código "PATAGONIA"; ve el 1,20 que este valor le asigna. Y como el código está validado por
// relación de tabla, renombrar o retipear un valor no rompe fórmulas en silencio, que es lo que sí
// pasaría comparando literales de texto dentro de la fórmula.
table 110004 "Valor Atributo Liq."
{
    Caption = 'Valor de Atributo';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Tipo Atributo"; Code[20])
        {
            Caption = 'Cód. Tipo Atributo';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
        }
        field(2; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; "Valor Numérico"; Decimal)
        {
            Caption = 'Valor Numérico';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
            // Lo que ve la fórmula cuando la entidad tiene este valor asignado.
        }
    }

    keys
    {
        key(PK; "Cód. Tipo Atributo", Código) { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Valor Numérico") { }
    }

    // El valor numérico viaja copiado a cada asignación (ver "Atributo Entidad Liq."), así que
    // cambiarlo acá NO reescribe lo ya asignado — y eso es deliberado: una liquidación vieja tiene
    // que poder recalcularse con el número que se usó, no con el de hoy. Lo que sí hace falta es que
    // quien lo cambia sepa que solo rige para las asignaciones nuevas.
    trigger OnModify()
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        if "Valor Numérico" = xRec."Valor Numérico" then
            exit;
        Atributo.SetRange("Cód. Tipo Atributo", "Cód. Tipo Atributo");
        Atributo.SetRange("Cód. Valor", Código);
        if not Atributo.IsEmpty() then
            Message(MsgValorEnUso, Código, Atributo.Count());
    end;

    var
        MsgValorEnUso: Label 'El valor %1 ya está asignado en %2 registro(s), que conservan el número anterior. El nuevo rige solo para las asignaciones que se carguen desde ahora; para cambiar las vigentes, cargá una vigencia nueva en cada entidad.';
}
