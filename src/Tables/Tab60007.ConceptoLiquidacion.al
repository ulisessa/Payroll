namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

table 60007 "Concepto Liquidación"
{
    Caption = 'Concepto Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Conceptos Liquidación";
    DrillDownPageId = "Conceptos Liquidación";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Impresión"; Text[50])
        {
            Caption = 'Nombre Impresión';
            DataClassification = CustomerContent;
        }
        field(5; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo Concepto';
            DataClassification = CustomerContent;
        }
        field(6; Fórmula; Text[2048])
        {
            Caption = 'Fórmula';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                Eval: Codeunit "Evaluador Fórmula";
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Decimal;
                ErrTxt: Text;
            begin
                Rec.Fórmula := NormalizarTexto(Rec.Fórmula);
                if Rec.Fórmula = '' then
                    exit;
                // Pass 1: syntax only (lenient)
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(true);
                if not Eval.TryEvalFormula(Rec.Fórmula, Dummy) then
                    Error(ErrSintaxisFormula, GetLastErrorText());
                // Pass 2: variable existence (strict, known vars = 1 to avoid div/0)
                BuildKnownVarsCtx(KnownCtx);
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(false);
                if not Eval.TryEvalFormula(Rec.Fórmula, Dummy) then begin
                    ErrTxt := GetLastErrorText();
                    if ErrTxt.Contains('Variable desconocida') then
                        Error(ErrVariableDesconocida, ErrTxt);
                end;
            end;
        }
        field(7; Condición; Text[2048])
        {
            Caption = 'Condición';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                Eval: Codeunit "Evaluador Fórmula";
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Boolean;
                ErrTxt: Text;
            begin
                Rec.Condición := NormalizarTexto(Rec.Condición);
                if Rec.Condición = '' then
                    exit;
                // Pass 1: syntax only (lenient)
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(true);
                if not Eval.TryEvalCondicion(Rec.Condición, Dummy) then
                    Error(ErrSintaxisCondicion, GetLastErrorText());
                // Pass 2: variable existence (strict)
                BuildKnownVarsCtx(KnownCtx);
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(false);
                if not Eval.TryEvalCondicion(Rec.Condición, Dummy) then begin
                    ErrTxt := GetLastErrorText();
                    if ErrTxt.Contains('Variable desconocida') then
                        Error(ErrVariableDesconocida, ErrTxt);
                end;
            end;
        }
        field(8; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden Cálculo';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        field(10; "Aplica A"; Enum "Aplica A Liq.")
        {
            Caption = 'Aplica A';
            DataClassification = CustomerContent;
        }
        field(11; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(13; "Es Acumulador"; Boolean)
        {
            Caption = 'Es Acumulador';
            DataClassification = CustomerContent;
            // Marks this concept as a named accumulator (no formula; receives values from others).
        }
        field(14; "Aplica Tipo Liq."; Enum "Aplica Tipo Liq. Concepto")
        {
            Caption = 'Aplica a Tipo Liq.';
            DataClassification = CustomerContent;
            // Todos (blank) = applies to all liquidation types.
            // Devengados    = monthly fixed pay during an ongoing voyage (no production).
            // Cierre Marea  = full settlement at voyage end (navigation days + production).
        }
        field(15; "Vigencia CCT Más Reciente"; Date)
        {
            Caption = 'Vigencia CCT Más Reciente';
            FieldClass = FlowField;
            CalcFormula = Max("Concepto CCT Vigente"."Vigencia Desde" WHERE("Cód. Concepto" = FIELD(Código)));
            Editable = false;
            // 0D = no CCT restriction records exist → the concept applies to every CCT.
            // Non-zero = the latest restriction batch's Vigencia Desde; combine with the
            // current Convenio code to determine applicability via "Concepto CCT Vigente".
        }
        field(16; "Variable Cantidad"; Code[30])
        {
            Caption = 'Variable Cantidad';
            DataClassification = CustomerContent;
            // Name of the context variable that represents the quantity for this concept
            // (e.g. DIAS_VAC, TONELADAS, DIAS_MAREA). Printed alongside the amount on the payslip.
            // Leave blank when no quantity applies.
        }
        field(17; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad Cantidad';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(18; "Etiqueta Det. Ganancias"; Text[100])
        {
            Caption = 'Etiqueta en Det. Ganancias';
            DataClassification = CustomerContent;
            // When non-empty, the concept result is written as a "Paso" row in
            // Detalle Ganancias Liq. at calculation time, showing this label
            // in the ganancias detail section of the payslip.
        }
        field(19; "Imprime en Recibo"; Boolean)
        {
            Caption = 'Imprime en Recibo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; Código, "Vigencia Desde")
        {
            Clustered = true;
        }
        key(K2; "Orden Cálculo", Código)
        {
        }
        key(K3; "Aplica A", Activo, "Orden Cálculo")
        {
        }
    }

    var
        ErrSintaxisFormula: Label 'La fórmula contiene un error de sintaxis: %1';
        ErrSintaxisCondicion: Label 'La condición contiene un error de sintaxis: %1';
        ErrVariableDesconocida: Label 'La fórmula referencia variables que no existen en el sistema: %1';

    // Builds a context dictionary with all currently configured variable names set to 1.
    // Used in pass-2 formula validation to detect unknown variable references at save time.
    local procedure BuildKnownVarsCtx(var Ctx: Dictionary of [Text, Decimal])
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Acum: Record "Concepto Liquidación";
    begin
        Clear(Ctx);
        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                if not Ctx.ContainsKey(Param."Nombre Variable") then
                    Ctx.Add(Param."Nombre Variable", 1);
                if not Ctx.ContainsKey(Param."Nombre Variable" + '_ESFCY') then
                    Ctx.Add(Param."Nombre Variable" + '_ESFCY', 1);
            until Param.Next() = 0;

        VarSis.SetRange(Activo, true);
        if VarSis.FindSet() then
            repeat
                if not Ctx.ContainsKey(VarSis."Nombre Variable") then
                    Ctx.Add(VarSis."Nombre Variable", 1);
            until VarSis.Next() = 0;

        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                if not Ctx.ContainsKey(Fuente."Nombre Variable") then
                    Ctx.Add(Fuente."Nombre Variable", 1);
            until Fuente.Next() = 0;

        Acum.SetRange("Es Acumulador", true);
        if Acum.FindSet() then
            repeat
                if not Ctx.ContainsKey(Acum.Código) then
                    Ctx.Add(Acum.Código, 1);
            until Acum.Next() = 0;
    end;

    // Strips newlines and collapses extra spaces so the evaluator (single-line only) can parse the text.
    local procedure NormalizarTexto(Texto: Text): Text
    var
        CR: Char;
        LF: Char;
    begin
        CR := 13;
        LF := 10;
        Texto := Texto.Replace('' + CR + LF, ' ').Replace('' + CR, ' ').Replace('' + LF, ' ');
        while Texto.Contains('  ') do
            Texto := Texto.Replace('  ', ' ');
        exit(Texto.Trim());
    end;
}
