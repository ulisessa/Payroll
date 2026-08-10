namespace UAS.Payroll;

codeunit 50067 "Control Orden Acumuladores"
{
    // Detecta el error de configuración más silencioso del motor: un concepto que ALIMENTA un
    // acumulador con un Orden Cálculo posterior al del concepto que lo LEE.
    //
    // El acumulador se va sumando a medida que los conceptos se calculan en Orden Cálculo, así que
    // quien lo lee ve el subtotal acumulado HASTA SU PUNTO en la corrida, no el total. El resultado
    // es un importe menor al esperado, sin ningún error y sin nada raro en la liquidación: el
    // drill-down del acumulador se arma al final y muestra todos los aportes, así que la fila que
    // falta ni siquiera se ve. Los importes solo cierran cuando alguien los suma a mano.
    //
    // Este control lo encuentra sin liquidar a nadie, comparando dos órdenes por acumulador.
    // La contraparte en tiempo de cálculo vive en Cod50014 (RegistrarLecturasAcumuladores).

    procedure Analizar(FechaRef: Date; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Integer
    var
        Acumulador: Record "Concepto Liquidación";
        VersionMap: Dictionary of [Code[20], Date];
        Conflictos: Integer;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if FechaRef = 0D then
            FechaRef := WorkDate();

        CargarVersionesVigentes(FechaRef, VersionMap);

        Acumulador.SetRange("Es Acumulador", true);
        Acumulador.SetRange(Activo, true);
        Acumulador.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Acumulador.FindSet() then
            exit(0);
        repeat
            // Un acumulador con varias vigencias aparece una sola vez: solo interesa la vigente.
            if EsVersionVigente(Acumulador, VersionMap) then
                if AnalizarAcumulador(Acumulador, FechaRef, VersionMap, Buffer) then
                    Conflictos += 1;
        until Acumulador.Next() = 0;

        Buffer.Reset();
        if Buffer.FindFirst() then;
        exit(Conflictos);
    end;

    local procedure AnalizarAcumulador(
        Acumulador: Record "Concepto Liquidación";
        FechaRef: Date;
        var VersionMap: Dictionary of [Code[20], Date];
        var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Boolean
    var
        OrdenUltAporte: Integer;
        ConceptoUltAporte: Code[20];
        OrdenPrimLectura: Integer;
        ConceptoPrimLectura: Code[20];
        CantAportes: Integer;
        CantLecturas: Integer;
        CodigosConflicto: Text;
        AportesConflicto: Integer;
    begin
        BuscarAportes(Acumulador.Código, FechaRef, VersionMap, OrdenUltAporte, ConceptoUltAporte, CantAportes);
        BuscarLecturas(Acumulador.Código, FechaRef, VersionMap, OrdenPrimLectura, ConceptoPrimLectura, CantLecturas);

        Buffer.Init();
        Buffer."Cód. Acumulador" := Acumulador.Código;
        Buffer.Descripción := Acumulador.Descripción;
        Buffer."Orden Máx. Aporte" := OrdenUltAporte;
        Buffer."Concepto Máx. Aporte" := ConceptoUltAporte;
        Buffer."Orden Mín. Lectura" := OrdenPrimLectura;
        Buffer."Concepto Mín. Lectura" := ConceptoPrimLectura;
        Buffer."Cant. Aportes" := CantAportes;
        Buffer."Cant. Lecturas" := CantLecturas;

        // Sin lecturas no hay nada que pueda salir mal: el acumulador solo se muestra al final,
        // cuando ya recibió todo. Sin aportes tampoco (un acumulador vacío es otro problema).
        if (CantLecturas > 0) and (CantAportes > 0) then begin
            Buffer.Conflicto := LlegaTarde(OrdenUltAporte, ConceptoUltAporte, OrdenPrimLectura, ConceptoPrimLectura);
            if Buffer.Conflicto then begin
                Buffer."Orden Sugerido" := OrdenUltAporte + 1;
                ListarAportesEnConflicto(
                    Acumulador.Código, FechaRef, VersionMap, OrdenPrimLectura, ConceptoPrimLectura,
                    CodigosConflicto, AportesConflicto);
                Buffer."Códigos en Conflicto" := CopyStr(CodigosConflicto, 1, MaxStrLen(Buffer."Códigos en Conflicto"));
                Buffer."Aportes en Conflicto" := AportesConflicto;
            end;
        end;
        Buffer.Insert();
        exit(Buffer.Conflicto);
    end;

    // ── Aportes: filas de Fracción Acumulador vigentes hacia este acumulador ───

    local procedure BuscarAportes(
        CodAcumulador: Code[20];
        FechaRef: Date;
        var VersionMap: Dictionary of [Code[20], Date];
        var OrdenUltimo: Integer;
        var ConceptoUltimo: Code[20];
        var Cantidad: Integer)
    var
        Frac: Record "Fracción Acumulador";
        Orden: Integer;
        Procesados: List of [Code[20]];
    begin
        OrdenUltimo := 0;
        ConceptoUltimo := '';
        Cantidad := 0;

        Frac.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Frac.SetRange("Cód. Acumulador", CodAcumulador);
        Frac.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Frac.FindSet() then
            exit;
        repeat
            // Un concepto puede tener varias vigencias de la misma fracción; cuenta una sola vez.
            if not Procesados.Contains(Frac."Cód. Concepto") then
                if OrdenDeConcepto(Frac."Cód. Concepto", VersionMap, Orden) then begin
                    Procesados.Add(Frac."Cód. Concepto");
                    Cantidad += 1;
                    if (Cantidad = 1) or (Orden > OrdenUltimo) then begin
                        OrdenUltimo := Orden;
                        ConceptoUltimo := Frac."Cód. Concepto";
                    end;
                end;
        until Frac.Next() = 0;
    end;

    // Mismo criterio que el motor: con igual Orden Cálculo, los conceptos corren por Código
    // (SelectConceptos ordena por "Orden Cálculo", Código). Un empate solo es conflicto si el código
    // del que aporta cae después del que lee — comparar solo el orden marcaría como problema la
    // mitad de los empates que en realidad corren bien.
    local procedure LlegaTarde(OrdenAporte: Integer; CodAporte: Code[20]; OrdenLectura: Integer; CodLectura: Code[20]): Boolean
    begin
        if OrdenAporte > OrdenLectura then
            exit(true);
        if OrdenAporte < OrdenLectura then
            exit(false);
        exit(CodAporte > CodLectura);
    end;

    local procedure ListarAportesEnConflicto(
        CodAcumulador: Code[20];
        FechaRef: Date;
        var VersionMap: Dictionary of [Code[20], Date];
        OrdenPrimLectura: Integer;
        ConceptoPrimLectura: Code[20];
        var Codigos: Text;
        var Cantidad: Integer)
    var
        Frac: Record "Fracción Acumulador";
        Orden: Integer;
        Procesados: List of [Code[20]];
    begin
        Codigos := '';
        Cantidad := 0;

        Frac.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Frac.SetRange("Cód. Acumulador", CodAcumulador);
        Frac.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Frac.FindSet() then
            exit;
        repeat
            if not Procesados.Contains(Frac."Cód. Concepto") then
                if OrdenDeConcepto(Frac."Cód. Concepto", VersionMap, Orden) then begin
                    Procesados.Add(Frac."Cód. Concepto");
                    if LlegaTarde(Orden, Frac."Cód. Concepto", OrdenPrimLectura, ConceptoPrimLectura) then begin
                        Cantidad += 1;
                        if Codigos <> '' then
                            Codigos += ', ';
                        Codigos += Frac."Cód. Concepto" + ' (' + Format(Orden) + ')';
                    end;
                end;
        until Frac.Next() = 0;
    end;

    // ── Lecturas: conceptos cuya fórmula o condición nombra al acumulador ──────

    local procedure BuscarLecturas(
        CodAcumulador: Code[20];
        FechaRef: Date;
        var VersionMap: Dictionary of [Code[20], Date];
        var OrdenPrimero: Integer;
        var ConceptoPrimero: Code[20];
        var Cantidad: Integer)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        OrdenPrimero := 0;
        ConceptoPrimero := '';
        Cantidad := 0;

        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Concepto.FindSet() then
            exit;
        repeat
            if EsVersionVigente(Concepto, VersionMap) and (Concepto.Código <> CodAcumulador) then
                if MencionaVariable(Concepto.Fórmula, CodAcumulador) or
                   MencionaVariable(Concepto.Condición, CodAcumulador)
                then begin
                    Cantidad += 1;
                    if (Cantidad = 1) or (Concepto."Orden Cálculo" < OrdenPrimero) then begin
                        OrdenPrimero := Concepto."Orden Cálculo";
                        ConceptoPrimero := Concepto.Código;
                    end;
                end;
        until Concepto.Next() = 0;
    end;

    /// <summary>
    /// True si Texto nombra a Codigo como token completo (no como parte de otro nombre).
    /// </summary>
    /// <remarks>
    /// Sin el chequeo de bordes, BASE_SS daría positivo dentro de BASE_SS_EXENTA y el control
    /// reportaría conflictos que no existen. Se comparte con el motor para que la definición de
    /// "este concepto lee este acumulador" sea una sola en todo el sistema.
    /// </remarks>
    procedure MencionaVariable(Texto: Text; Codigo: Code[20]): Boolean
    var
        TextoMayus: Text;
        CodigoMayus: Text;
        Pos: Integer;
        Desde: Integer;
    begin
        if (Texto = '') or (Codigo = '') then
            exit(false);
        TextoMayus := Texto.ToUpper();
        CodigoMayus := UpperCase(Codigo);

        Desde := 1;
        repeat
            Pos := TextoMayus.IndexOf(CodigoMayus, Desde);
            if Pos = 0 then
                exit(false);
            if EsBordeDeToken(TextoMayus, Pos - 1) and
               EsBordeDeToken(TextoMayus, Pos + StrLen(CodigoMayus))
            then
                exit(true);
            Desde := Pos + 1;
        until Desde > StrLen(TextoMayus);
        exit(false);
    end;

    local procedure EsBordeDeToken(Texto: Text; Posicion: Integer): Boolean
    var
        C: Char;
    begin
        // Fuera del texto cuenta como borde: el token arranca o termina la expresión.
        if (Posicion < 1) or (Posicion > StrLen(Texto)) then
            exit(true);
        C := Texto[Posicion];
        if (C >= 'A') and (C <= 'Z') then exit(false);
        if (C >= '0') and (C <= '9') then exit(false);
        if C = '_' then exit(false);
        exit(true);
    end;

    // ── Versión vigente ───────────────────────────────────────────────────────

    // Mismo criterio que el motor (Cod50014 BuildLatestVersionCache): de cada concepto solo cuenta
    // la vigencia más reciente <= la fecha de referencia. Si el control mirara todas las versiones,
    // reportaría conflictos de fórmulas viejas que el motor ya no ejecuta.
    local procedure CargarVersionesVigentes(FechaRef: Date; var VersionMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Clear(VersionMap);
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Concepto.FindSet() then
            exit;
        repeat
            if not VersionMap.ContainsKey(Concepto.Código) then
                VersionMap.Add(Concepto.Código, Concepto."Vigencia Desde")
            else
                if Concepto."Vigencia Desde" > VersionMap.Get(Concepto.Código) then
                    VersionMap.Set(Concepto.Código, Concepto."Vigencia Desde");
        until Concepto.Next() = 0;
    end;

    local procedure EsVersionVigente(Concepto: Record "Concepto Liquidación"; var VersionMap: Dictionary of [Code[20], Date]): Boolean
    begin
        if not VersionMap.ContainsKey(Concepto.Código) then
            exit(false);
        exit(Concepto."Vigencia Desde" = VersionMap.Get(Concepto.Código));
    end;

    local procedure OrdenDeConcepto(CodConcepto: Code[20]; var VersionMap: Dictionary of [Code[20], Date]; var Orden: Integer): Boolean
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Orden := 0;
        if not VersionMap.ContainsKey(CodConcepto) then
            exit(false); // inactivo o sin versión vigente: el motor no lo va a ejecutar
        if not Concepto.Get(CodConcepto, VersionMap.Get(CodConcepto)) then
            exit(false);
        Orden := Concepto."Orden Cálculo";
        exit(true);
    end;
}
