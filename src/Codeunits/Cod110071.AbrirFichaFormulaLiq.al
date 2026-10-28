namespace UAS.Payroll;

/// <summary>
/// Abre la ficha de lo que está bajo el cursor en el editor de fórmulas: concepto, parámetro, fuente
/// de datos, variable de sistema o atributo.
/// </summary>
/// <remarks>
/// El editor sólo conoce NOMBRES (el catálogo trae el nombre y el tipo de cada variable), así que la
/// resolución nombre → registro vive acá y no en el JavaScript. La comparten el Asistente de Fórmulas
/// y la ficha del Concepto, que son los dos lugares donde está el editor.
///
/// Se abre con Page.Run y no RunModal a propósito: quien consulta una fórmula suele querer comparar
/// dos fichas, y un modal le obligaría a cerrar una para ver la otra.
/// </remarks>
codeunit 110071 "Abrir Ficha Fórmula Liq."
{
    /// <param name="Tipo">'concepto' o el tipo de variable del catálogo (Parámetro, Fuente Datos, Sistema, Atributo).</param>
    procedure Abrir(Tipo: Text; Nombre: Text)
    begin
        if Nombre = '' then
            exit;
        case Tipo of
            'concepto':
                AbrirConcepto(CopyStr(Nombre, 1, 20));
            'Parámetro':
                AbrirParametro(CopyStr(Nombre, 1, 30));
            'Fuente Datos':
                AbrirFuente(CopyStr(Nombre, 1, 30));
            'Sistema':
                AbrirVariableSistema(CopyStr(Nombre, 1, 30));
            'Atributo':
                AbrirAtributo(CopyStr(Nombre, 1, 30));
            else
                Message(MsgSinFicha, Nombre, Tipo);
        end;
    end;

    local procedure AbrirConcepto(Codigo: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        // La versión vigente hoy; si no hay (concepto dado de baja o que arranca más adelante), la
        // última cargada. Mejor una ficha vieja que ninguna.
        Concepto.SetRange(Código, Codigo);
        if Concepto.IsEmpty() then begin
            Message(MsgNoExiste, Codigo);
            exit;
        end;
        Concepto.SetFilter("Vigencia Desde", '<=%1', WorkDate());
        if not Concepto.FindLast() then begin
            Concepto.SetRange("Vigencia Desde");
            Concepto.FindLast();
        end;
        Concepto.SetRange("Vigencia Desde");
        Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    local procedure AbrirParametro(Nombre: Code[30])
    var
        Parametro: Record "Parámetro";
    begin
        // _ESFCY y los demás sufijos son variables derivadas del parámetro, no parámetros propios.
        if not BuscarParametro(Nombre, Parametro) then begin
            Message(MsgNoExiste, Nombre);
            exit;
        end;
        Page.Run(Page::"Parámetro Card", Parametro);
    end;

    local procedure BuscarParametro(Nombre: Code[30]; var Parametro: Record "Parámetro"): Boolean
    begin
        Parametro.SetRange("Nombre Variable", Nombre);
        if Parametro.FindFirst() then
            exit(true);
        if (StrLen(Nombre) > 6) and (CopyStr(Nombre, StrLen(Nombre) - 5) = '_ESFCY') then begin
            Parametro.SetRange("Nombre Variable", CopyStr(Nombre, 1, StrLen(Nombre) - 6));
            exit(Parametro.FindFirst());
        end;
        exit(false);
    end;

    local procedure AbrirFuente(Nombre: Code[30])
    var
        Fuente: Record "Fuente Datos Liquidación";
    begin
        if not Fuente.Get(Nombre) then begin
            Message(MsgNoExiste, Nombre);
            exit;
        end;
        Page.Run(Page::"Fuente Datos Card", Fuente);
    end;

    local procedure AbrirVariableSistema(Nombre: Code[30])
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        // Algunas variables de sistema las inyecta el motor (ES_GROSSING_UP, NETO_GARANTIZADO...) y
        // no tienen fila: para ésas no hay ficha que abrir.
        VarSis.SetRange("Nombre Variable", Nombre);
        if VarSis.IsEmpty() then begin
            Message(MsgSistemaSinFila, Nombre);
            exit;
        end;
        Page.Run(Page::"Variable Sistema Liq.", VarSis);
    end;

    local procedure AbrirAtributo(Nombre: Code[30])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        // NOMBRE_ULT_MAREA es la variable derivada de la del atributo, no otro atributo.
        TipoAtr.SetRange("Nombre Variable", Nombre);
        if not TipoAtr.FindFirst() then
            if (StrLen(Nombre) > 10) and (CopyStr(Nombre, StrLen(Nombre) - 9) = '_ULT_MAREA') then begin
                TipoAtr.SetRange("Nombre Variable", CopyStr(Nombre, 1, StrLen(Nombre) - 10));
                if not TipoAtr.FindFirst() then;
            end;
        if TipoAtr.Código = '' then begin
            Message(MsgNoExiste, Nombre);
            exit;
        end;
        Page.Run(Page::"Ficha Tipo Atributo", TipoAtr);
    end;

    var
        MsgNoExiste: Label 'No se encontró "%1" en la configuración.', Comment = '%1 = nombre';
        MsgSinFicha: Label '"%1" es de tipo "%2" y no tiene ficha propia.', Comment = '%1 = nombre, %2 = tipo';
        MsgSistemaSinFila: Label '"%1" la calcula el motor y no tiene una fila de Variable Sistema que abrir.', Comment = '%1 = nombre';
}
