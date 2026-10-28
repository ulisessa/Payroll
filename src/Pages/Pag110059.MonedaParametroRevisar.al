namespace UAS.Payroll;

// Valores de parámetro cuya declaración de moneda no cierra.
//
// Desde que "Convertir Param. por TC" está encendida, el motor convierte cada parámetro en divisa
// leyendo su "Variable Tipo de Cambio". Una fila con moneda y sin esa variable CORTA el cálculo
// (ver ConvertirParametrosEnDivisa en Contexto Liquidación). Esta pantalla las encuentra antes, para
// que el corte no aparezca a mitad de un lote de quinientas liquidaciones.
//
// El segundo diagnóstico es el que de verdad cuesta ver, y es el que casi rompió la migración: una
// fila SIN moneda dentro de un parámetro cuyas demás filas sí la tienen. Ahí no hay error de
// ninguna clase — el número entra al cálculo como si fueran pesos y sale mil cuatrocientas veces
// más chico—. Ocho de las dieciséis filas de USD_MAREA estaban así.
//
// Mezclar es LEGÍTIMO en los parámetros que de verdad convive en dos monedas: el básico de tierra
// está en dólares para cuatro empleados y en pesos para el resto, y PRECIO_PUERTO igual: ARS para
// marinería y USD para oficiales, en el mismo parámetro.
// Por eso la pantalla no corrige sola ni ordena corregir: muestra las dos cuentas —cuántas filas en
// divisa y cuántas en pesos— y deja la lectura a quien sabe qué se pactó.
page 110059 "Moneda de Parámetro a Revisar"
{
    ApplicationArea = All;
    Caption = 'Moneda de parámetro a revisar';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Parámetro Vigente";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave';
                    StyleExpr = EstiloFila;
                    ToolTip = 'La fila de valor cuya declaración de moneda no cierra.';
                }
                field(Variable; Variable)
                {
                    ApplicationArea = All;
                    Caption = 'Variable';
                    ToolTip = 'Con qué nombre llega este parámetro a las fórmulas.';
                }
                field(Diagnóstico; Diagnóstico)
                {
                    ApplicationArea = All;
                    Caption = 'Diagnóstico';
                    StyleExpr = EstiloFila;
                }
                field(Moneda; Rec.Moneda)
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco significa pesos. El motor sólo convierte las filas que declaran una moneda.';
                }
                field("Cód. Variable TC"; Rec."Cód. Variable TC")
                {
                    ApplicationArea = All;
                    Caption = 'Variable Tipo de Cambio';
                }
                field(Valor; Rec.Valor) { ApplicationArea = All; }
                field(EnDivisa; EnDivisa)
                {
                    ApplicationArea = All;
                    Caption = 'Filas en divisa';
                    ToolTip = 'Cuántas filas de este mismo parámetro declaran una moneda.';
                }
                field(EnPesos; EnPesos)
                {
                    ApplicationArea = All;
                    Caption = 'Filas en pesos';
                    ToolTip = 'Cuántas filas de este mismo parámetro no declaran moneda. Si son pocas contra muchas en divisa, probablemente sea una carga incompleta y no una convivencia real.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refrescar)
            {
                ApplicationArea = All;
                Caption = 'Volver a revisar';
                Image = Refresh;
                ToolTip = 'Rehace la revisión sobre los datos actuales.';
                trigger OnAction()
                begin
                    Cargar();
                    CurrPage.Update(false);
                end;
            }
            action(VerParametros)
            {
                ApplicationArea = All;
                Caption = 'Abrir Árbol de Parámetros';
                Image = Hierarchy;
                ToolTip = 'Abre la pantalla donde se corrige la moneda y su variable de tipo de cambio.';
                RunObject = Page "Árbol de Parámetros";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(RefrescarProm; Refrescar) { }
            }
        }
    }

    var
        Diagnóstico: Text;
        Variable: Text;
        EstiloFila: Text;
        EnDivisa: Integer;
        EnPesos: Integer;
        DiagMap: Dictionary of [Text, Text];
        DivisaMap: Dictionary of [Code[50], Integer];
        PesosMap: Dictionary of [Code[50], Integer];
        DiagSinTC: Label 'Declara moneda y no declara con qué convertirse: CORTA el cálculo.';
        DiagSinMoneda: Label 'No declara moneda, pero las demás filas de este parámetro sí: entraría como pesos.';
        MsgSinHallazgos: Label 'Ninguna fila de valor tiene la moneda mal declarada.';

    trigger OnOpenPage()
    begin
        Cargar();
        if Rec.IsEmpty() then
            Message(MsgSinHallazgos);
    end;

    trigger OnAfterGetRecord()
    begin
        Variable := VariableDe(Rec."Cód. Parámetro Base");
        Diagnóstico := '';
        if DiagMap.ContainsKey(ClaveFila()) then
            Diagnóstico := DiagMap.Get(ClaveFila());

        // La fila que corta el cálculo se pinta de rojo; la sospechosa, de amarillo. La diferencia
        // importa: una hay que arreglarla para poder liquidar, la otra hay que leerla.
        if Rec.Moneda <> '' then
            EstiloFila := 'Unfavorable'
        else
            EstiloFila := 'Ambiguous';

        EnDivisa := 0;
        EnPesos := 0;
        if DivisaMap.ContainsKey(Rec."Cód. Parámetro Base") then
            EnDivisa := DivisaMap.Get(Rec."Cód. Parámetro Base");
        if PesosMap.ContainsKey(Rec."Cód. Parámetro Base") then
            EnPesos := PesosMap.Get(Rec."Cód. Parámetro Base");
    end;

    local procedure ClaveFila(): Text
    begin
        exit(Rec."Cód. Parámetro Base" + '|' + Rec."Cód. Parámetro" + '|' + Format(Rec."Vigencia Desde", 0, 9));
    end;

    local procedure Cargar()
    var
        Origen: Record "Parámetro Vigente";
        Clave: Text;
    begin
        Rec.DeleteAll();
        Clear(DiagMap);
        Clear(DivisaMap);
        Clear(PesosMap);

        // Primera vuelta: contar, por parámetro base, cuántas filas van en divisa y cuántas en
        // pesos. Hace falta antes de juzgar cualquier fila, porque el segundo diagnóstico es
        // relativo a sus hermanas y no absoluto.
        if Origen.FindSet() then
            repeat
                if Origen.Moneda <> '' then
                    Sumar(DivisaMap, Origen."Cód. Parámetro Base")
                else
                    Sumar(PesosMap, Origen."Cód. Parámetro Base");
            until Origen.Next() = 0;

        // Segunda vuelta: quedarse con las que no cierran. No se puede filtrar en SQL porque el
        // segundo criterio depende del recuento de arriba.
        if Origen.FindSet() then
            repeat
                Clave := Origen."Cód. Parámetro Base" + '|' + Origen."Cód. Parámetro" + '|' + Format(Origen."Vigencia Desde", 0, 9);
                if (Origen.Moneda <> '') and (Origen."Cód. Variable TC" = '') then begin
                    Rec := Origen;
                    Rec.Insert(false);
                    DiagMap.Set(Clave, DiagSinTC);
                end else
                    if (Origen.Moneda = '') and DivisaMap.ContainsKey(Origen."Cód. Parámetro Base") then begin
                        Rec := Origen;
                        Rec.Insert(false);
                        DiagMap.Set(Clave, DiagSinMoneda);
                    end;
            until Origen.Next() = 0;

        if Rec.FindFirst() then;
    end;

    local procedure Sumar(var Mapa: Dictionary of [Code[50], Integer]; Clave: Code[50])
    begin
        if Mapa.ContainsKey(Clave) then
            Mapa.Set(Clave, Mapa.Get(Clave) + 1)
        else
            Mapa.Set(Clave, 1);
    end;

    local procedure VariableDe(CodBase: Code[50]): Text
    var
        Param: Record "Parámetro";
    begin
        if Param.Get(CodBase) then
            exit(Param."Nombre Variable");
        exit('');
    end;
}
