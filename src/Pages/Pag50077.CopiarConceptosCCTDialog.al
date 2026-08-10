namespace UAS.Payroll;

page 50077 "Copiar Conceptos CCT Dialog"
{
    // Destino para "Copiar conceptos a otro convenio" (herramienta "Conceptos por Convenio").
    // Solo recolecta datos: la copia y la confirmación las hace la página que lo invoca.
    Caption = 'Copiar conceptos a otro convenio';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            group(Origen)
            {
                Caption = 'Origen';
                Editable = false;

                field(ConvenioOrigen; ConvenioOrigen)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    ToolTip = 'Convenio desde el que se copian las asignaciones de conceptos.';
                }
                field(CategoriaOrigen; CategoriaOrigen)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    ToolTip = 'Categoría de origen. Vacío = asignaciones que aplican a todo el convenio.';
                }
            }
            group(Destino)
            {
                Caption = 'Destino';

                field(ConvenioDestino; ConvenioDestino)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    TableRelation = "Convenio Colectivo".Código;
                    ToolTip = 'Convenio al que se copian las asignaciones. Puede ser el mismo que el de origen si se copia hacia otra categoría.';
                    trigger OnValidate()
                    begin
                        CategoriaDestino := '';
                    end;
                }
                field(CategoriaDestino; CategoriaDestino)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría (opcional)';
                    ToolTip = 'Vacío = la copia aplica a todas las categorías del convenio destino. Cargada = se copia solo a esa categoría.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Categoria: Record "Categoría CCT";
                    begin
                        if ConvenioDestino = '' then
                            Error(ErrSinConvenioDestino);
                        Categoria.SetRange("Cód. Convenio", ConvenioDestino);
                        if Page.RunModal(Page::"Categorías CCT", Categoria) <> Action::LookupOK then
                            exit(false);
                        CategoriaDestino := Categoria.Código;
                        exit(true);
                    end;
                }
                field(VigenciaDestino; VigenciaDestino)
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia Desde';
                    ToolTip = 'Fecha con la que se crean las filas nuevas en el destino.';
                }
            }
        }
    }

    procedure SetOrigen(CodConvenio: Code[20]; CodCategoria: Code[20]; Vigencia: Date)
    begin
        ConvenioOrigen := CodConvenio;
        CategoriaOrigen := CodCategoria;
        VigenciaDestino := Vigencia;
    end;

    procedure GetDestino(var CodConvenio: Code[20]; var CodCategoria: Code[20]; var Vigencia: Date)
    begin
        CodConvenio := ConvenioDestino;
        CodCategoria := CategoriaDestino;
        Vigencia := VigenciaDestino;
    end;

    var
        ConvenioOrigen: Code[20];
        CategoriaOrigen: Code[20];
        ConvenioDestino: Code[20];
        CategoriaDestino: Code[20];
        VigenciaDestino: Date;
        ErrSinConvenioDestino: Label 'Seleccioná primero el Cód. Convenio de destino.';
}
