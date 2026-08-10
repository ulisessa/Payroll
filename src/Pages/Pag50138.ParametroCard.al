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
                field("Sufijo CCT"; Rec."Sufijo CCT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, la clave de búsqueda real es Código_CONVENIO_CATEGORÍA (ej: BASICO_ADM_DES). Los valores se ingresan en la solapa inferior con esa clave completa.';
                    trigger OnValidate()
                    begin
                        AplicarCambioDeSufijo();
                    end;
                }
                field("Sufijo Empleado"; Rec."Sufijo Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, la clave de búsqueda real es Código_NOEMPLEADO (ej: BASICO_EMP001). Permite definir un valor distinto por empleado. Excluyente con Sufijo Convenio/Categoría.';
                    trigger OnValidate()
                    begin
                        AplicarCambioDeSufijo();
                    end;
                }
                field("Sufijo Convenio"; Rec."Sufijo Convenio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, la clave de búsqueda real es Código_CONVENIO (ej: COEF_FRANCOS_729/15). Para valores por convenio compartidos por todas las categorías. Excluyente con los otros sufijos.';
                    trigger OnValidate()
                    begin
                        AplicarCambioDeSufijo();
                    end;
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
        SincronizarSufijosSubpagina();
    end;

    // Los tres sufijos son excluyentes: la tabla apaga los otros dos al encender uno, y la subpágina
    // habilita sus columnas (No. Empleado, Convenio, Categoría) según los flags que recibe por
    // SetBaseCodigo. Eso solo ocurría en OnAfterGetRecord, que NO vuelve a correr al tildar un
    // checkbox — de ahí que hiciera falta apretar F5 para que se habilitara la edición.
    local procedure AplicarCambioDeSufijo()
    begin
        SincronizarSufijosSubpagina();
        // Refresca la ficha para que los otros dos checkboxes se muestren destildados. Sin guardar:
        // el registro se persiste solo al salir del campo, como en cualquier ficha.
        CurrPage.Update(false);
        RecalcularClavesSiCorresponde();
    end;

    local procedure SincronizarSufijosSubpagina()
    begin
        CurrPage.VigentesSufijo.Page.SetBaseCodigo(
            Rec.Código, Rec."Sufijo Empleado", Rec."Sufijo CCT", Rec."Sufijo Convenio");
    end;

    // Re-derives the Clave Derivada of every existing "Valores Vigentes" line to the new suffix mode.
    // Without this, lines keep the OLD mode's key after the flag flips and the motor stops finding them —
    // the exact mismatch diagnosed for VAL_CARG_COMP, just triggered by a suffix change instead of a typo.
    local procedure RecalcularClavesSiCorresponde()
    var
        Lineas: Integer;
        Actualizadas: Integer;
    begin
        Lineas := CurrPage.VigentesSufijo.Page.ContarLineas();
        if Lineas = 0 then exit;
        if not Confirm(QstRecalcularClaves, true, Lineas) then exit;
        Actualizadas := CurrPage.VigentesSufijo.Page.RecalcularClaves(Rec."Sufijo Empleado", Rec."Sufijo CCT", Rec."Sufijo Convenio");
        Message(MsgClavesRecalculadas, Actualizadas, Lineas);
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
        QstRecalcularClaves: Label 'Este parámetro tiene %1 línea(s) de valores vigentes. Cambiar el sufijo puede dejarlas con una Clave Derivada del modo anterior, que el motor ya no encontraría. ¿Recalcular la Clave Derivada de todas las líneas según el nuevo modo? Las líneas sin los datos necesarios (ej. sin Convenio/Categoría) quedan sin tocar.';
        MsgClavesRecalculadas: Label '%1 de %2 línea(s) recalculada(s).';
}
