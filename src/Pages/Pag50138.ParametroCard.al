namespace UAS.Payroll;

page 50138 "Parámetro Card"
{
    ApplicationArea = All;
    Caption = 'Parámetro';
    PageType = Card;
    SourceTable = "Parámetro";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Código; Rec.Código)
                {
                    ApplicationArea = All;
                    // Editable también sobre un parámetro ya existente: cambiarlo lo renombra, y el
                    // OnRename de la tabla arrastra los valores vigentes con su clave derivada. Antes
                    // solo se podía renombrar desde la lista, donde la plataforma sí lo permitía —
                    // una inconsistencia que además dejaba el rename sin cascada.
                    ToolTip = 'Código del parámetro. Cambiarlo lo renombra y arrastra todos sus valores vigentes, reconstruyendo la clave derivada de cada uno con el código nuevo.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre con el que este parámetro se expone en el contexto de fórmulas. Vacío = no se carga automáticamente.';
                }
                field("Antigüedad Máxima Vigencia"; Rec."Antigüedad Máxima Vigencia")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fórmula de fecha (ej. -1M, -35D). Si se completa, al calcular una liquidación se avisa cuando el último valor vigente es anterior a esa antigüedad respecto a la fecha de liquidación. Útil para parámetros que la AFIP actualiza periódicamente (MNI, Deducción Especial). Vacío = sin chequeo.';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; }
            }

            part(VigentesSufijo; "Parámetro Sufijo Sub")
            {
                ApplicationArea = All;
                Caption = 'Valores Vigentes';
                SubPageLink = "Cód. Parámetro Base" = FIELD(Código);
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LiberarEnUso)
            {
                ApplicationArea = All;
                Caption = 'Liberar "En Uso"';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Libera los bloqueos "En Uso" de los valores vigentes de este parámetro que ya no estén referenciados por liquidaciones activas.';
                trigger OnAction()
                begin
                    LiberarEnUsoPorParametro(Rec.Código);
                    CurrPage.VigentesSufijo.Page.Update(false);
                end;
            }
            action(Copiar)
            {
                ApplicationArea = All;
                Caption = 'Copiar como...';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Dlg: Page "Nuevo Codigo Dialog";
                    NuevoCodigo: Code[20];
                begin
                    Dlg.SetCodigo(CopyStr(Rec.Código + '_2', 1, 100));
                    if Dlg.RunModal() <> Action::OK then exit;
                    NuevoCodigo := CopyStr(Dlg.GetCodigo(), 1, 20);
                    if NuevoCodigo = '' then exit;
                    Rec.CopiarEn(NuevoCodigo);
                    Message(MsgCopiado, NuevoCodigo);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CurrPage.VigentesSufijo.Page.SetBaseCodigo(Rec.Código);
    end;

    local procedure LiberarEnUsoPorParametro(CodParametro: Code[20])
    var
        ParamVig: Record "Parámetro Vigente";
        Liq: Record "Liquidación";
        Limpiados: Integer;
    begin
        ParamVig.SetRange("Cód. Parámetro Base", CodParametro);
        ParamVig.SetRange("En Uso", true);
        if not ParamVig.FindSet(true) then begin
            Message(MsgSinBloqueos);
            exit;
        end;
        repeat
            if ParamVig."No. Empleado" <> '' then
                Liq.SetRange("No. Empleado", ParamVig."No. Empleado")
            else
                Liq.Reset();
            Liq.SetFilter(Estado, '%1|%2|%3',
                Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
            if Liq.IsEmpty() then begin
                ParamVig."En Uso" := false;
                ParamVig.Modify();
                Limpiados += 1;
            end;
            Liq.Reset();
        until ParamVig.Next() = 0;
        Message(MsgLimpiados, Limpiados, CodParametro);
    end;

    var
        MsgCopiado: Label 'Parámetro copiado como ''%1''.';
        MsgSinBloqueos: Label 'Este parámetro no tiene valores vigentes bloqueados.';
        MsgLimpiados: Label '%1 bloqueo(s) liberado(s) del parámetro ''%2''.';
}
