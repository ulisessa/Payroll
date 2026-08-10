namespace UAS.Payroll;

// Vista plana de "Concepto CCT Vigente" sin el filtro de Vigencia Desde que impone la subpágina
// de la ficha del concepto (Pag50147) — esa solo muestra las filas que coinciden con la vigencia
// del Concepto Liquidación actualmente abierto. Acá se ve TODA la historia de restricciones CCT
// de un código, para diagnosticar por qué un concepto no aplica a un convenio esperado.
page 50197 "Concepto CCT Vigente List"
{
    ApplicationArea = All;
    Caption = 'Concepto CCT Vigente (todas las vigencias)';
    PageType = List;
    SourceTable = "Concepto CCT Vigente";
    UsageCategory = Administration;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
            }
        }
    }
}
