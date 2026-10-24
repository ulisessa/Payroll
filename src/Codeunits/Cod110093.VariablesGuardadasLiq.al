namespace UAS.Payroll;

/// <summary>
/// Las variables con las que se calculó una liquidación, completas: las guardadas en "Resumen Variable Liq." más los parámetros
/// que el resumen omite porque ya están registrados en "Uso Parámetro Liq.".
/// </summary>
/// <remarks>
/// POR QUÉ EXISTE. SaveResumenVariables dejó de guardar un parámetro cuando su versión quedó registrada en el uso del parámetro y su
/// valor es exactamente el de esa versión (ver Cod50014): repetirlo en cada liquidación eran 141.780 de 350.622 filas. El valor no se
/// pierde, pero ya no está en el resumen: quien lo lea tiene que pasar por acá y no por un Get directo sobre la tabla.
///
/// Las filas guardadas ganan siempre: una liquidación calculada antes de este cambio tiene el resumen completo y se lee tal cual.
/// </remarks>
codeunit 110093 "Variables Guardadas Liq."
{
    Access = Public;

    /// <summary>
    /// Deja en Destino todas las variables de la liquidación: las del resumen y, para cada parámetro omitido, la fila reconstruida.
    /// </summary>
    procedure Cargar(LiqNo: Code[20]; var Destino: Record "Resumen Variable Liq." temporary)
    var
        Guardada: Record "Resumen Variable Liq.";
        Uso: Record "Uso Parámetro Liq.";
        ParamVig: Record "Parámetro Vigente";
    begin
        Destino.Reset();
        Destino.DeleteAll();
        if LiqNo = '' then
            exit;

        Guardada.SetRange("No. Liquidación", LiqNo);
        if Guardada.FindSet() then
            repeat
                Destino := Guardada;
                Destino.Insert();
            until Guardada.Next() = 0;

        Uso.SetRange("No. Liquidación", LiqNo);
        if Uso.FindSet() then
            repeat
                if not EsAliasHistorico(Uso."Nombre Variable") then
                    if not Destino.Get(LiqNo, Uso."Nombre Variable") then
                        if ParamVig.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then
                            AgregarReconstruida(Destino, LiqNo, Uso."Nombre Variable", ParamVig);
            until Uso.Next() = 0;
        Destino.Reset();
    end;

    /// <summary>
    /// Una variable de la liquidación, del resumen o reconstruida desde el uso del parámetro. Falso si no la tuvo.
    /// </summary>
    procedure Obtener(LiqNo: Code[20]; Nombre: Code[30]; var Fila: Record "Resumen Variable Liq."): Boolean
    var
        Guardada: Record "Resumen Variable Liq.";
        Uso: Record "Uso Parámetro Liq.";
        ParamVig: Record "Parámetro Vigente";
    begin
        if Guardada.Get(LiqNo, Nombre) then begin
            Fila := Guardada;
            exit(true);
        end;
        if EsAliasHistorico(Nombre) then
            exit(false);
        if not Uso.Get(LiqNo, Nombre) then
            exit(false);
        if not ParamVig.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then
            exit(false);
        Clear(Fila);
        AgregarReconstruida(Fila, LiqNo, Nombre, ParamVig);
        exit(true);
    end;

    /// <summary>
    /// El detalle de variables de una línea (o de todas, con LineNo = 0): las filas guardadas más, para cada nombre de las filas ~USO,
    /// una fila armada con el valor que la liquidación guardó en su resumen.
    /// </summary>
    /// <remarks>
    /// El motor no escribe una fila por línea para una variable cuyo valor es el mismo que el final de la liquidación: anota su
    /// nombre en la fila ~USO de la línea (FlushDetalleDiferido, Cod50014) y el valor sale del resumen. Esto lo deshace para quien
    /// lee, con el mismo aspecto que tenía el detalle completo. Las liquidaciones calculadas antes de ese cambio no tienen filas ~USO
    /// y se leen tal cual. Una variable que el resumen no tiene vale cero: es el único caso en que no está —no se guardan los ceros—.
    /// </remarks>
    procedure CargarDetalle(LiqNo: Code[20]; LineNo: Integer; var Destino: Record "Detalle Variable Línea Liq." temporary)
    var
        PorLinea: Record "Detalle Variable Línea Liq." temporary;
        Firmas: Dictionary of [Text, Text];
        Mixtas: List of [Text];
        Nombre: Text;
        Firma: Text;
    begin
        Destino.Reset();
        Destino.DeleteAll();
        ExpandirDetalle(LiqNo, LineNo, PorLinea);
        if not PorLinea.FindSet() then
            exit;

        // Una línea: tal cual, cada variable en su línea.
        if LineNo <> 0 then begin
            repeat
                Destino := PorLinea;
                Destino.Insert();
            until PorLinea.Next() = 0;
            exit;
        end;

        // Toda la liquidación: una variable que vale lo mismo (y con el mismo código) en TODAS las líneas que la leen va una sola
        // vez, en la línea 0 —"vale para todas"—. Si en alguna línea vale otra cosa se muestra línea por línea, para no esconder la
        // diferencia. Los tramos y ACUM_PARAM_CCT son de su línea y no se agrupan nunca.
        repeat
            if EsAgrupable(PorLinea) then begin
                Nombre := PorLinea."Nombre Variable";
                Firma := Format(PorLinea.Valor, 0, 9) + '|' + PorLinea."Código Atributo";
                if not Firmas.ContainsKey(Nombre) then
                    Firmas.Add(Nombre, Firma)
                else
                    if (Firmas.Get(Nombre) <> Firma) and not Mixtas.Contains(Nombre) then
                        Mixtas.Add(Nombre);
            end;
        until PorLinea.Next() = 0;

        PorLinea.FindSet();
        repeat
            Destino := PorLinea;
            if EsAgrupable(PorLinea) and not Mixtas.Contains(PorLinea."Nombre Variable") then begin
                Destino."No. Línea" := 0;
                if Destino.Insert() then;
            end else
                Destino.Insert();
        until PorLinea.Next() = 0;
        Destino.Reset();
    end;

    // Cada línea con sus variables: las filas guardadas y una por cada entrada de las filas ~USO (NOMBRE o NOMBRE=CÓDIGO), con el
    // valor del resumen de la liquidación.
    local procedure ExpandirDetalle(LiqNo: Code[20]; LineNo: Integer; var PorLinea: Record "Detalle Variable Línea Liq." temporary)
    var
        Det: Record "Detalle Variable Línea Liq.";
        Completas: Record "Resumen Variable Liq." temporary;
        Entradas: List of [Text];
        Entrada: Text;
        Nombre: Text;
        Codigo: Text;
        Cargadas: Boolean;
    begin
        PorLinea.Reset();
        PorLinea.DeleteAll();
        if LiqNo = '' then
            exit;
        Det.SetRange("No. Liquidación", LiqNo);
        if LineNo <> 0 then
            Det.SetRange("No. Línea", LineNo);
        if not Det.FindSet() then
            exit;
        repeat
            if Det."Nombre Variable".StartsWith('~USO') then begin
                // Las variables del resumen se cargan una vez por llamada y sólo si hace falta.
                if not Cargadas then begin
                    Cargar(LiqNo, Completas);
                    Cargadas := true;
                end;
                Entradas := Det.Detalle.Split('|');
                foreach Entrada in Entradas do
                    if Entrada <> '' then begin
                        Nombre := Entrada;
                        Codigo := '';
                        if Entrada.Contains('=') then begin
                            Nombre := Entrada.Substring(1, Entrada.IndexOf('=') - 1);
                            Codigo := Entrada.Substring(Entrada.IndexOf('=') + 1);
                        end;
                        if not PorLinea.Get(Det."No. Liquidación", Det."No. Línea", Nombre) then begin
                            PorLinea.Init();
                            PorLinea."No. Liquidación" := Det."No. Liquidación";
                            PorLinea."No. Línea" := Det."No. Línea";
                            PorLinea."Nombre Variable" := CopyStr(Nombre, 1, MaxStrLen(PorLinea."Nombre Variable"));
                            PorLinea."Código Atributo" := CopyStr(Codigo, 1, MaxStrLen(PorLinea."Código Atributo"));
                            if Completas.Get(LiqNo, CopyStr(Nombre, 1, MaxStrLen(Completas."Nombre Variable"))) then
                                PorLinea.Valor := Completas.Valor;
                            PorLinea.Insert();
                        end;
                    end;
            end else begin
                PorLinea := Det;
                if PorLinea.Insert() then;
            end;
        until Det.Next() = 0;
    end;

    local procedure EsAgrupable(Fila: Record "Detalle Variable Línea Liq."): Boolean
    begin
        exit((Fila.Detalle = '') and not Fila."Snapshot Tramo" and not Fila."Nombre Variable".StartsWith('TRAMO('));
    end;

    /// <summary>
    /// ¿Se puede omitir esta variable del resumen? Sólo si un parámetro registrado en el uso de ESTA liquidación vale exactamente
    /// lo mismo, está en pesos (o sin moneda) y no se imprime en el recibo.
    /// </summary>
    /// <remarks>
    /// Se decide al escribir, con la tabla de uso ya llena, y no por suposición: si el registro falló, o el valor del contexto
    /// difiere del de la versión (UsarParCCT, un redondeo, un override), la fila se guarda como siempre y no se pierde nada.
    /// Uso se carga una vez por liquidación (Omitibles) en vez de un Get por variable.
    /// </remarks>
    procedure CargarOmitibles(LiqNo: Code[20]; var Omitibles: Dictionary of [Text, Decimal])
    var
        Uso: Record "Uso Parámetro Liq.";
        ParamVig: Record "Parámetro Vigente";
    begin
        Clear(Omitibles);
        Uso.SetRange("No. Liquidación", LiqNo);
        if Uso.FindSet() then
            repeat
                if not EsAliasHistorico(Uso."Nombre Variable") then
                    if ParamVig.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then
                        if ParamVig.Moneda = '' then
                            if not Omitibles.ContainsKey(Uso."Nombre Variable") then
                                Omitibles.Add(Uso."Nombre Variable", ParamVig.Valor);
            until Uso.Next() = 0;
    end;

    // HIST_CCT~n son alias de auditoría de las vigencias históricas de ACUM_PARAM_CCT, no variables de fórmula.
    local procedure EsAliasHistorico(Nombre: Text): Boolean
    begin
        exit(Nombre.StartsWith('HIST_CCT~'));
    end;

    local procedure AgregarReconstruida(var Destino: Record "Resumen Variable Liq."; LiqNo: Code[20]; Nombre: Text; ParamVig: Record "Parámetro Vigente")
    var
        Param: Record "Parámetro";
    begin
        Destino.Init();
        Destino."No. Liquidación" := LiqNo;
        Destino."Nombre Variable" := CopyStr(Nombre, 1, MaxStrLen(Destino."Nombre Variable"));
        Destino.Valor := ParamVig.Valor;
        Destino.Etiqueta := Destino."Nombre Variable";
        Param.SetRange("Nombre Variable", Destino."Nombre Variable");
        if Param.FindFirst() then
            Destino.Etiqueta := CopyStr(Param.Descripción, 1, MaxStrLen(Destino.Etiqueta));
        Destino."Mostrar en Recibo" := false;
        // Sólo en el buffer: sobre la tabla real no se escribe nunca, la fila reconstruida es de lectura.
        if Destino.IsTemporary() then
            Destino.Insert();
    end;
}
