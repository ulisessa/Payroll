namespace UAS.Payroll;

page 50159 "Variables Cálculo Línea"
{
    ApplicationArea = All;
    Caption = 'Variables del Cálculo';
    PageType = List;
    SourceTable = "Detalle Variable Línea Liq.";
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Variable';
                }
                field(TipoVariable; TipoVariable)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo';
                    Width = 12;
                    ToolTip = 'De dónde sale la variable: Parámetro, Sistema, Fuente Datos, Acumulador o Concepto.';
                }
                field(DescripciónVariable; DescripciónVariable)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    // Sin esto hay que ir a buscar a otra pantalla qué es "1013", "PCT_PROD" o
                    // "DIAS_VAC". Es la misma información que ofrece el autocompletado del editor de
                    // fórmulas, acá donde se está mirando el resultado.
                    ToolTip = 'Descripción de la variable, tomada de su tabla de configuración. Vacío = la variable no está configurada en ninguna (típicamente quedó huérfana de un renombre).';

                    trigger OnDrillDown()
                    var
                        Concepto: Record "Concepto Liquidación";
                    begin
                        if BuscarConcepto(Concepto) then
                            Page.Run(Page::"Concepto Liq. Card", Concepto);
                    end;
                }
                field(Valor; ValorVisible)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerAcumulador)
            {
                ApplicationArea = All;
                Caption = 'Detalle Acumulador';
                Image = Totals;
                ToolTip = 'Si esta variable es un acumulador, muestra qué conceptos lo alimentaron (con el valor que tenían al momento del cálculo) y con qué importe.';
                Enabled = EsAcumulador;
                trigger OnAction()
                var
                    DetPage: Page "Detalle Acumulador Liq.";
                begin
                    DetPage.LoadFromLiquidacion(Rec."No. Liquidación", CopyStr(Rec."Nombre Variable", 1, 20));
                    // El valor que ESTA línea usó, para contrastarlo con la suma real de los aportes:
                    // si difieren, la línea leyó el acumulador antes de que terminara de llenarse.
                    DetPage.SetValorUsado(Rec.Valor);
                    DetPage.Caption := Rec."Nombre Variable";
                    DetPage.RunModal();
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Catalogo: Codeunit "Catálogo Variables Liq.";
    begin
        // El catálogo ya resuelve nombre → tipo + descripción para las cinco familias de variables
        // (constantes del motor, parámetros, variables de sistema, fuentes de datos y acumuladores)
        // leyendo las tablas de configuración reales. Se carga una vez por apertura, en vez de
        // consultar cuatro tablas por cada fila de la grilla — y como es la misma fuente que alimenta
        // al editor de fórmulas, las descripciones no pueden divergir entre las dos pantallas.
        Catalogo.CargarCatalogo(CatalogoVar, '', '', '');
    end;

    trigger OnAfterGetRecord()
    begin
        ValorVisible := FormatValor();
        ResolverVariable();
    end;

    local procedure ResolverVariable()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        TipoVariable := '';
        DescripciónVariable := '';
        EsAcumulador := false;

        if CatalogoVar.Get(CopyStr(NombreSinPrefijo(), 1, MaxStrLen(CatalogoVar.Nombre))) then begin
            TipoVariable := CatalogoVar.Tipo;
            DescripciónVariable := CatalogoVar.Descripción;
            EsAcumulador := CatalogoVar.Tipo = TipoAcumuladorTok;
            exit;
        end;

        // El catálogo solo incluye los conceptos marcados como acumulador. Una referencia @CÓDIGO o
        // #CÓDIGO a un concepto común no está ahí, y es de las que más se ven en este detalle.
        if BuscarConcepto(Concepto) then begin
            TipoVariable := TipoConceptoTok;
            DescripciónVariable := Concepto.Descripción;
            exit;
        end;

        ResolverBanderaMoneda();
    end;

    // Cada parámetro expone además un compañero <VAR>_ESFCY que vale 1 cuando su valor está cargado
    // en moneda extranjera (ver Cod50016). Sin esto la fila queda sin descripción y parece una
    // variable suelta, cuando en realidad pertenece al parámetro de al lado.
    local procedure ResolverBanderaMoneda()
    var
        Param: Record "Parámetro";
        Raiz: Text;
    begin
        Raiz := NombreSinPrefijo().ToUpper();
        if not Raiz.EndsWith(SufijoMonedaTok) then
            exit;
        Raiz := CopyStr(Raiz, 1, StrLen(Raiz) - StrLen(SufijoMonedaTok));
        if Raiz = '' then
            exit;

        Param.SetRange("Nombre Variable", CopyStr(Raiz, 1, 30));
        if not Param.FindFirst() then
            exit;
        TipoVariable := TipoParametroTok;
        DescripciónVariable := CopyStr(StrSubstNo(DescMonedaTxt, Param."Nombre Variable"), 1, MaxStrLen(DescripciónVariable));
    end;

    local procedure NombreSinPrefijo(): Text
    var
        NombreVar: Text;
    begin
        // @CÓDIGO y #CÓDIGO se registran CON el prefijo en el log (ver WriteVariableDetail en
        // Cod50014): el prefijo distingue cuál de los dos mecanismos se usó, pero la variable detrás
        // es el mismo nombre pelado.
        NombreVar := Rec."Nombre Variable";
        if NombreVar.StartsWith('@') or NombreVar.StartsWith('#') then
            NombreVar := CopyStr(NombreVar, 2);
        exit(NombreVar);
    end;

    local procedure BuscarConcepto(var Concepto: Record "Concepto Liquidación"): Boolean
    var
        NombreVar: Text;
    begin
        NombreVar := NombreSinPrefijo();
        if NombreVar = '' then
            exit(false);

        Concepto.Reset();
        Concepto.SetRange(Código, CopyStr(NombreVar, 1, 20));
        exit(Concepto.FindLast());
    end;

    local procedure FormatValor(): Text
    begin
        if IsPercentageVariable(Rec."Nombre Variable") then begin
            // ≤ 1 → fracción (0,85 → 85%); > 1 → ya es porcentaje entero (78 → 78%, no 7800%).
            if Abs(Rec.Valor) <= 1 then
                exit(Format(Round(Rec.Valor * 100, 0.000001)) + '%');
            exit(Format(Round(Rec.Valor, 0.000001)) + '%');
        end;
        exit(Format(Round(Rec.Valor, 0.000001)));
    end;

    local procedure IsPercentageVariable(VariableName: Text): Boolean
    begin
        VariableName := VariableName.ToUpper();
        exit(VariableName.StartsWith('PCT_') or VariableName.Contains('_PCT') or VariableName.Contains('PORC'));
    end;

    var
        CatalogoVar: Record "Variable Liq. Test" temporary;
        ValorVisible: Text[50];
        TipoVariable: Text[20];
        DescripciónVariable: Text[100];
        EsAcumulador: Boolean;
        TipoAcumuladorTok: Label 'Acumulador', Locked = true;
        TipoConceptoTok: Label 'Concepto', Locked = true;
        TipoParametroTok: Label 'Parámetro', Locked = true;
        SufijoMonedaTok: Label '_ESFCY', Locked = true;
        DescMonedaTxt: Label 'Indica si el valor de %1 está cargado en moneda extranjera (1) o no (0).';
}
