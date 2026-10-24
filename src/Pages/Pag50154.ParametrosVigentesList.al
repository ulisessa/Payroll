namespace UAS.Payroll;

page 50154 "Parámetros Vigentes"
{
    ApplicationArea = All;
    Caption = 'Parámetros Vigentes';
    PageType = List;
    SourceTable = "Parámetro Vigente";
    UsageCategory = Administration;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            group(OrigenAtributo)
            {
                Caption = 'Parámetros del atributo';
                Visible = ContextoAtributo;
                field(ParametroDelAtributo; ParametroAtributo)
                {
                    ApplicationArea = All;
                    Caption = 'Parámetro';
                    ToolTip = 'Elegí el parámetro que usa este atributo como eje para consultar o cargar sus vigencias.';
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Param: Record "Parámetro";
                    begin
                        FiltrarParametrosAtributo(Param);
                        if Page.RunModal(Page::Parámetros, Param) <> Action::LookupOK then
                            exit(false);
                        ParametroAtributo := Param.Código;
                        Text := ParametroAtributo;
                        AplicarOrigen();
                        CurrPage.Update(false);
                        exit(true);
                    end;
                    trigger OnValidate()
                    begin
                        AplicarOrigen();
                        CurrPage.Update(false);
                    end;
                }
            }
            repeater(Lines)
            {
                field("Cód. Parámetro Base"; Rec."Cód. Parámetro Base")
                {
                    ApplicationArea = All;
                    Editable = not ContextoAtributo;
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro") { ApplicationArea = All; }
                field(FNombreVar; FNombreVar)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Variable';
                    Editable = false;
                    ToolTip = 'Nombre con el que este parámetro se usa en las fórmulas. Vacío para códigos con sufijo CCT/Categoría.';
                }
                // Componentes de la clave derivada: hacen visible POR QUÉ un valor aplica a una
                // liquidación y cuál gana en la cascada específico → genérico (ver LoadParametros
                // en "Contexto Liquidación"). Fila sin ninguno de los tres = valor por defecto.
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado al que aplica este valor. Vacío = el valor no es una excepción por empleado.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Convenio al que aplica este valor. Vacío = valor genérico, usado cuando no hay uno más específico.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Categoría a la que aplica este valor. Se carga junto con el convenio.';
                }
                // Los ejes de atributo. Acá SÍ van visibles de entrada, al revés que en la subpágina
                // de la ficha: esta lista cruza parámetros de todos los ejes y es donde se busca
                // "quién tiene cargado CAL". En la ficha se ocultan porque ahí el parámetro es uno y
                // la mayoría no usa ninguno.
                field("Sufijo Atributo 1"; Rec."Sufijo Atributo 1")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Valor del primer eje de atributo, como el sufijo que aporta a la clave. Qué atributo es lo declara la ficha del parámetro.';
                }
                field("Sufijo Atributo 2"; Rec."Sufijo Atributo 2")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    Visible = ContextoAtributo;
                }
                field("Sufijo Atributo 3"; Rec."Sufijo Atributo 3")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    Visible = ContextoAtributo;
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("Cód. Variable TC"; Rec."Cód. Variable TC") { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LimpiarEnUso)
            {
                ApplicationArea = All;
                Caption = 'Limpiar bloqueos "En Uso"';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Resetea el flag "En Uso" en todos los parámetros vigentes cuando no existen liquidaciones calculadas, aprobadas o contabilizadas.';
                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    ParamVig: Record "Parámetro Vigente";
                    Limpiados: Integer;
                begin
                    ParamVig.SetRange("En Uso", true);
                    if ParamVig.FindSet(true) then
                        repeat
                            if ParamVig."No. Empleado" <> '' then begin
                                Liq.SetRange("No. Empleado", ParamVig."No. Empleado");
                                Liq.SetFilter(Estado, '%1|%2|%3',
                                    Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
                                if Liq.IsEmpty() then begin
                                    ParamVig."En Uso" := false;
                                    ParamVig.Modify();
                                    Limpiados += 1;
                                end;
                                Liq.Reset();
                            end else begin
                                Liq.SetFilter(Estado, '%1|%2|%3',
                                    Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
                                if Liq.IsEmpty() then begin
                                    ParamVig."En Uso" := false;
                                    ParamVig.Modify();
                                    Limpiados += 1;
                                end;
                                Liq.Reset();
                            end;
                        until ParamVig.Next() = 0;
                    Message('%1 bloqueo(s) liberado(s).', Limpiados);
                    CurrPage.Update(false);
                end;
            }
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo Valor';
                Image = NewRow;
                Promoted = true;
                PromotedCategory = New;
                ToolTip = 'Inserta una nueva vigencia para el parámetro seleccionado, preservando el valor anterior para auditoría.';

                trigger OnAction()
                var
                    NuevoParam: Record "Parámetro Vigente";
                begin
                    Rec.TestField("Cód. Parámetro");
                    NuevoParam := Rec;
                    NuevoParam."Vigencia Desde" := WorkDate();
                    NuevoParam."En Uso" := false;
                    NuevoParam.Descripción := '';
                    NuevoParam.Insert(true);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Param: Record "Parámetro";
    begin
        FNombreVar := '';
        if (Rec."Cód. Parámetro Base" <> '') and Param.Get(Rec."Cód. Parámetro Base") then
            FNombreVar := Param."Nombre Variable"
        else if StrLen(Rec."Cód. Parámetro") <= 20 then
            if Param.Get(Rec."Cód. Parámetro") then
                FNombreVar := Param."Nombre Variable";
    end;

    trigger OnOpenPage()
    begin
        if ContextoActivo then
            AplicarOrigen();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if not ContextoActivo then
            exit;
        Rec."No. Empleado" := EmpleadoOrigen;
        Rec."Cód. Convenio" := ConvenioOrigen;
        Rec."Cód. Categoría" := CategoriaOrigen;
        if ContextoAtributo then begin
            Rec."Cód. Parámetro Base" := ParametroAtributo;
            case EjeAtributo of
                1: Rec."Sufijo Atributo 1" := SufijoOrigen;
                2: Rec."Sufijo Atributo 2" := SufijoOrigen;
                3: Rec."Sufijo Atributo 3" := SufijoOrigen;
            end;
        end;
    end;

    procedure SetOrigen(Empleado: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    begin
        ContextoActivo := true;
        EmpleadoOrigen := Empleado;
        ConvenioOrigen := Convenio;
        CategoriaOrigen := Categoria;
    end;

    procedure SetAtributo(TipoAtributo: Code[20]; Sufijo: Code[10])
    var
        Param: Record "Parámetro";
    begin
        ContextoActivo := true;
        ContextoAtributo := true;
        TipoAtributoOrigen := TipoAtributo;
        SufijoOrigen := Sufijo;
        FiltrarParametrosAtributo(Param);
        if Param.FindFirst() then
            ParametroAtributo := Param.Código
        else
            Error('No hay parámetros que usen el atributo %1 como eje. Configurá primero el eje en la ficha del parámetro.', TipoAtributo);
    end;

    local procedure FiltrarParametrosAtributo(var Param: Record "Parámetro")
    begin
        Param.FilterGroup(-1);
        Param.SetRange("Cód. Tipo Atributo 1", TipoAtributoOrigen);
        Param.SetRange("Cód. Tipo Atributo 2", TipoAtributoOrigen);
        Param.SetRange("Cód. Tipo Atributo 3", TipoAtributoOrigen);
        Param.FilterGroup(0);
    end;

    local procedure AplicarOrigen()
    var
        Param: Record "Parámetro";
        GrupoAnterior: Integer;
    begin
        if ContextoAtributo then begin
            Param.Get(ParametroAtributo);
            EjeAtributo := 0;
            if Param."Cód. Tipo Atributo 1" = TipoAtributoOrigen then EjeAtributo := 1;
            if Param."Cód. Tipo Atributo 2" = TipoAtributoOrigen then EjeAtributo := 2;
            if Param."Cód. Tipo Atributo 3" = TipoAtributoOrigen then EjeAtributo := 3;
            if EjeAtributo = 0 then
                Error('El parámetro %1 no usa el atributo %2 como eje.', ParametroAtributo, TipoAtributoOrigen);
        end;
        GrupoAnterior := Rec.FilterGroup();
        Rec.FilterGroup(2);
        if EmpleadoOrigen <> '' then Rec.SetRange("No. Empleado", EmpleadoOrigen);
        if ConvenioOrigen <> '' then Rec.SetRange("Cód. Convenio", ConvenioOrigen);
        if CategoriaOrigen <> '' then Rec.SetRange("Cód. Categoría", CategoriaOrigen);
        if ContextoAtributo then begin
            Rec.SetRange("Cód. Parámetro Base", ParametroAtributo);
            Rec.SetRange("Sufijo Atributo 1");
            Rec.SetRange("Sufijo Atributo 2");
            Rec.SetRange("Sufijo Atributo 3");
            if SufijoOrigen <> '' then
                case EjeAtributo of
                    1: Rec.SetRange("Sufijo Atributo 1", SufijoOrigen);
                    2: Rec.SetRange("Sufijo Atributo 2", SufijoOrigen);
                    3: Rec.SetRange("Sufijo Atributo 3", SufijoOrigen);
                end;
        end;
        Rec.FilterGroup(GrupoAnterior);
    end;

    var
        FNombreVar: Text[30];
        ContextoActivo: Boolean;
        ContextoAtributo: Boolean;
        EmpleadoOrigen: Code[20];
        ConvenioOrigen: Code[20];
        CategoriaOrigen: Code[20];
        TipoAtributoOrigen: Code[20];
        SufijoOrigen: Code[10];
        ParametroAtributo: Code[20];
        EjeAtributo: Integer;
}
