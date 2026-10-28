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
                field("Edad Máxima Familiar"; Rec."Edad Máxima Familiar")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tope de edad para deducir a un familiar a cargo en Ganancias. Sólo tiene sentido en los tipos de deducción por familiar: HIJO lleva 18 e HIJO_INC no lleva ninguno, porque los incapacitados se deducen sin límite de edad. CERO = sin límite. Si el familiar no tiene fecha de nacimiento cargada, no se aplica.';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; }
            }

            group(Ejes)
            {
                Caption = 'Ejes de atributo';
                // Colapsado por defecto: la enorme mayoría de los parámetros no usa ningún eje, y
                // tres campos vacíos arriba de la lista de valores sugieren que hay algo que llenar.
                InstructionalText = 'Dimensiones, además del convenio y la categoría, por las que se parten los valores de este parámetro. El valor concreto se carga en cada fila de abajo, como el sufijo que el atributo aporta a la clave. El orden manda: el eje 1 es el que más pesa.';

                field("Cód. Tipo Atributo 1"; Rec."Cód. Tipo Atributo 1")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primer eje: el atributo que más pesa al buscar el valor. Sólo sirven los atributos cuyos valores tengan cargado un "Sufijo Parámetro" — por ejemplo TIPOACTIVIDAD, donde Potero aporta CAL y Tangonero aporta LAN.';
                }
                field("Cód. Tipo Atributo 2"; Rec."Cód. Tipo Atributo 2")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Cód. Tipo Atributo 1" <> '';
                    ToolTip = 'Segundo eje. No se puede declarar sin el primero: la búsqueda los suelta de atrás para adelante.';
                }
                field("Cód. Tipo Atributo 3"; Rec."Cód. Tipo Atributo 3")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Cód. Tipo Atributo 2" <> '';
                    ToolTip = 'Tercer eje. No se puede declarar sin el segundo.';
                }
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
            action(DondeSeUsa)
            {
                ApplicationArea = All;
                Caption = 'Dónde se usa';
                Image = Links;
                ToolTip = 'Qué fórmulas y condiciones nombran a este parámetro. Conviene mirarlo con "Incluir sufijos" prendido: la fórmula puede nombrar la forma sufijada —PRECIO_NAV_LAN— y no el nombre base.';

                trigger OnAction()
                var
                    PagUsos: Page "Dónde se Usa";
                begin
                    PagUsos.SetSimbolo(Rec."Nombre Variable");
                    PagUsos.Run();
                end;
            }
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
