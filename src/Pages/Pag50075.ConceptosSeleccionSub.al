namespace UAS.Payroll;

page 50075 "Conceptos Selección Sub"
{
    // Checkbox list of concepts for the "Conceptos por Convenio" tool: tildar/destildar escribe
    // directamente la fila de "Concepto CCT Vigente" del convenio (y categoría) en contexto.
    // El tilde refleja la fila EXACTA (convenio + la categoría elegida, en blanco si no se eligió
    // ninguna); la columna Estado avisa cuándo el concepto igual aplica por otra vía, para que
    // destildar nunca borre algo que el usuario no está viendo.
    PageType = ListPart;
    Caption = 'Conceptos';
    SourceTable = "Tipo Liq. Selección Buffer";
    SourceTableTemporary = true;
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Marcado; Rec.Marcado)
                {
                    ApplicationArea = All;
                    Caption = 'Asignado';
                    ToolTip = 'Tildar asigna el concepto al convenio (y categoría) en contexto; destildar quita esa asignación.';

                    trigger OnValidate()
                    begin
                        Alternar(Rec.Código, Rec.Marcado);
                        // Update(TRUE) y no (false): con origen temporal, un refresco sin guardar
                        // vuelve a leer el buffer —donde el tilde todavía no se escribió— y el
                        // casillero se borra solo, aunque la asignación sí se haya hecho. Se veía
                        // como "no me deja asignar" cuando en realidad ya estaba asignado.
                        CurrPage.Update(true);
                    end;
                }
                field(Código; Rec.Código) { ApplicationArea = All; Editable = false; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; Editable = false; }
                field(Estado; FEstado)
                {
                    ApplicationArea = All;
                    Caption = 'Estado';
                    Editable = false;
                    ToolTip = 'Cómo aplica hoy el concepto a este convenio: sin restricciones, por el convenio completo, o solo por la categoría elegida.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FEstado := EstadoDelConcepto(Rec.Código);
    end;

    procedure SetContexto(CodConvenio: Code[20]; CodCategoria: Code[20]; Vigencia: Date)
    begin
        FConvenio := CodConvenio;
        FCategoria := CodCategoria;
        FVigencia := Vigencia;
    end;

    procedure CargarLista(var Origen: Record "Tipo Liq. Selección Buffer" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
            until Origen.Next() = 0;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Asigna o quita los conceptos MARCADOS en la lista. Devuelve cuántos tocó.
    /// </summary>
    /// <remarks>
    /// "Asignar todos los listados" opera sobre todo lo que se está mostrando, que con un filtro
    /// ancho son cientos. Esto es lo del medio: lo que el usuario tildó a mano en la grilla.
    ///
    /// La selección se relee del buffer de la página —Todos comparte su tabla temporal— en vez de
    /// usar lo que devuelve SetSelectionFilter: con origen temporal, la plataforma copia los
    /// registros marcados y no siempre copia el registro entero. Si no hay nada marcado, se opera
    /// sobre la fila donde está el cursor, que es lo que el usuario ve seleccionado.
    /// </remarks>
    procedure AplicarASeleccion(Asignar: Boolean) Cuantos: Integer
    var
        Todos: Record "Tipo Liq. Selección Buffer" temporary;
        Marcados: Record "Tipo Liq. Selección Buffer" temporary;
    begin
        Todos.Copy(Rec, true);
        CurrPage.SetSelectionFilter(Marcados);
        if Marcados.FindSet() then begin
            repeat
                if Todos.Get(Marcados.Código) then begin
                    Alternar(Todos.Código, Asignar);
                    Cuantos += 1;
                end;
            until Marcados.Next() = 0;
            exit;
        end;

        if Rec.Código = '' then
            exit;
        Alternar(Rec.Código, Asignar);
        Cuantos := 1;
    end;

    // Alta/baja de la fila exacta (convenio + categoría en contexto). Al quitar se borran TODAS las
    // vigencias de esa combinación: con versionado por convenio, dejar una vieja la seguiría aplicando.
    local procedure Alternar(CodConcepto: Code[20]; Asignar: Boolean)
    var
        CCTVig: Record "Concepto CCT Vigente";
        Nuevo: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Concepto", CodConcepto);
        CCTVig.SetRange("Cód. Convenio", FConvenio);
        CCTVig.SetRange("Cód. Categoría", FCategoria);

        if Asignar then begin
            if not CCTVig.IsEmpty() then
                exit;
            Nuevo.Init();
            Nuevo."Cód. Concepto" := CodConcepto;
            Nuevo."Vigencia Desde" := FVigencia;
            Nuevo."Cód. Convenio" := FConvenio;
            Nuevo."Cód. Categoría" := FCategoria;
            if Nuevo.Insert() then;
        end else
            CCTVig.DeleteAll();
    end;

    local procedure EstadoDelConcepto(CodConcepto: Code[20]): Text
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        // Sin ninguna fila → el concepto no está restringido y aplica a todos los convenios.
        CCTVig.SetRange("Cód. Concepto", CodConcepto);
        if CCTVig.IsEmpty() then
            exit(SinRestriccionTxt);

        if FCategoria = '' then
            exit('');

        // Con categoría elegida: avisar si aplica por la fila de "todo el convenio", que esta
        // herramienta no toca (destildar acá no la borraría).
        CCTVig.SetRange("Cód. Convenio", FConvenio);
        CCTVig.SetRange("Cód. Categoría", '');
        if not CCTVig.IsEmpty() then
            exit(PorConvenioTxt);
        exit('');
    end;

    var
        FConvenio: Code[20];
        FCategoria: Code[20];
        FVigencia: Date;
        FEstado: Text;
        SinRestriccionTxt: Label 'Sin restricción (aplica a todos)';
        PorConvenioTxt: Label 'Ya aplica por el convenio completo';
}
