namespace UAS.Payroll;

/// <summary>Importa una foto mensual de cargas familiares, sin modificar el maestro actual.</summary>
codeunit 110068 "Deducción Familiar Histórica"
{
    procedure Obtener(Empleado: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]; FechaRef: Date; var Importe: Decimal; var Referencia: Text): Boolean
    var
        Periodo: Record "Período Liquidación";
        Valor: Record "Parámetro Vigente";
    begin
        Importe := 0;
        Referencia := '';
        // La foto es mensual; no contiene la deducción anual requerida en una final.
        if TipoLiq = 'LIQ_FINAL' then exit(false);
        if not Periodo.Get(CodPeriodo) then exit(false);
        if (FechaRef < Periodo."Fecha Desde") or (FechaRef > Periodo."Fecha Hasta") then exit(false);
        Valor.SetRange("Cód. Parámetro Base", CodigoParametro());
        Valor.SetRange("No. Empleado", Empleado);
        // Igualdad, no FindLast <= fecha: nunca arrastrar enero a febrero.
        Valor.SetRange("Vigencia Desde", Periodo."Fecha Desde");
        if not Valor.FindFirst() then exit(false);
        Valor.TestField(Moneda, '');
        Valor.TestField("Cód. Convenio", '');
        Valor.TestField("Cód. Categoría", '');
        if Valor.Valor < 0 then Error('Una foto familiar mensual no puede ser negativa.');
        Importe := Valor.Valor;
        Referencia := Valor.Notas;
        if Valor.Next() <> 0 then Error('Hay más de una foto familiar para el empleado y mes.');
        // Cero con fila presente es una declaración sin cargas, no ausencia de datos.
        exit(true);
    end;

    procedure Simular(Payload: Text)
    var
        Raiz, Fila: JsonObject;
        Filas: JsonArray;
        Token: JsonToken;
        Importe: Decimal;
        Referencia: Text;
        Revisados: Dictionary of [Code[20], Boolean];
        Empleado: Code[20];
    begin
        Aplicar(Payload);
        Raiz.ReadFrom(Payload);
        Raiz.Get('familiares', Token);
        Filas := Token.AsArray();
        foreach Token in Filas do begin
            Fila := Token.AsObject();
            if not Obtener(Texto(Fila, 'empleado'), '202601', 'REGULAR', DMY2Date(31, 1, 2026), Importe, Referencia) then
                Error('Falta la foto familiar importada.');
            if Importe <> Monto(Fila, 'conyuge') + Monto(Fila, 'hijos') then Error('Foto familiar incorrecta.');
            if Obtener(Texto(Fila, 'empleado'), '202602', 'REGULAR', DMY2Date(28, 2, 2026), Importe, Referencia) then
                Error('La foto de enero se arrastró a febrero.');
            if Obtener(Texto(Fila, 'empleado'), '202601', 'LIQ_FINAL', DMY2Date(31, 1, 2026), Importe, Referencia) then
                Error('La foto mensual se usó en una final anual.');
            ProbarResultadoMes(Fila);
            Empleado := CopyStr(Texto(Fila, 'empleado'), 1, MaxStrLen(Empleado));
            Revisados.Add(Empleado, true);
        end;
        if Raiz.Get('casos_sac', Token) then begin
            Filas := Token.AsArray();
            foreach Token in Filas do ProbarCasoSAC(Token.AsObject(), Revisados);
        end;
        Error('SIMULACION_FAMILIA_HIST_OK: importación y alcance validados; transacción revertida.');
    end;

    local procedure ProbarResultadoMes(Fila: JsonObject)
    var
        Cab: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Recalculo: Codeunit "Recálculo En Cadena Liq.";
        Token: JsonToken;
        Fuentes: JsonArray;
        ImpuestoBC, ImpuestoMeta4: Decimal;
    begin
        Cab.SetRange("No. Empleado", Texto(Fila, 'empleado'));
        Cab.SetRange("Cód. Período", '202601');
        Cab.SetRange(Estado, Cab.Estado::Calculada);
        Cab.FindFirst();
        Recalculo.EjecutarMesEmpleado(Cab."No.");
        if Cab.FindSet() then repeat
            Linea.SetRange("No. Liquidación", Cab."No.");
            Linea.SetRange("Cód. Concepto", '5010');
            Linea.CalcSums(Importe);
            ImpuestoBC += Linea.Importe;
        until Cab.Next() = 0;
        Fila.Get('fuentes', Token);
        Fuentes := Token.AsArray();
        foreach Token in Fuentes do ImpuestoMeta4 += LeerMonto(Entero(Token.AsObject(), 'entrada'), 'IMPUESTO');
        if Abs(ImpuestoBC - ImpuestoMeta4) >= 0.02 then
            Error('El impuesto mensual simulado difiere: empleado %1; BC %2; Meta4 %3.', Texto(Fila, 'empleado'), ImpuestoBC, ImpuestoMeta4);
    end;

    procedure Aplicar(Payload: Text)
    var
        Raiz, Fila: JsonObject;
        Filas: JsonArray;
        Token: JsonToken;
        Periodo: Record "Período Liquidación";
        Parametro: Record "Parámetro";
        Empleados: Dictionary of [Code[20], Boolean];
        Empleado: Code[20];
    begin
        if not Raiz.ReadFrom(Payload) then Error('Payload inválido.');
        if Texto(Raiz, 'periodo') <> '202601' then Error('Esta importación corresponde a enero 2026.');
        Periodo.Get('202601');
        if Periodo.Estado = Periodo.Estado::Cerrado then Error('Enero está cerrado.');
        Periodo.TestField("Fecha Desde", DMY2Date(1, 1, 2026));
        Periodo.TestField("Fecha Hasta", DMY2Date(31, 1, 2026));
        Raiz.Get('familiares', Token);
        Filas := Token.AsArray();
        if Filas.Count() <> 9 then Error('La revisión comprende nueve casos.');
        if not Parametro.Get(CodigoParametro()) then begin
            Parametro.Init();
            Parametro.Código := CodigoParametro();
            Parametro.Descripción := 'Cargas familiares históricas de Meta4';
            Parametro.Notas := 'Foto mensual por empleado. Sólo rige en el mes exacto; no modifica familiares ni se usa en LIQ_FINAL.';
            Parametro.Insert(true);
        end;
        Parametro.TestField("Nombre Variable", '');
        foreach Token in Filas do begin
            Fila := Token.AsObject();
            Empleado := CopyStr(Texto(Fila, 'empleado'), 1, MaxStrLen(Empleado));
            if Empleados.ContainsKey(Empleado) then Error('Empleado repetido.');
            Empleados.Add(Empleado, true);
            ImportarFila(Fila, Empleado, Periodo);
        end;
        if Raiz.Get('corregir_sac_fiscal', Token) then
            if Token.AsValue().AsBoolean() then CorregirSACFiscal();
    end;

    local procedure CorregirSACFiscal()
    var
        Sac, Sindicato: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        OtroConcepto: Record "Concepto Liquidación";
        Cab: Record "Liquidación";
        OriginalSac, NuevoSac, OriginalSindicato, NuevoSindicato: Text;
    begin
        OriginalSac := 'round(((BASE_IG4 + BASE_EXT_IG4) / 12), 0.0001)';
        NuevoSac := 'ROUND((BASE_IG4 + BASE_EXT_IG4 - #4683) / 12, 0.0001)';
        OriginalSindicato := 'ROUND(BASE_SAC_DEV * (IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) + IF(PCT_SINDICATO = ''PAT'', PCT_CENTRO_CAPACIT, 0) + IF(CONVENIO = ''372/04'' AND (PCT_SINDICATO = ''SSI'' OR PCT_SINDICATO = ''SEC''), 2, 0)) / 100, 0.0001)';
        // Meta4 excluye 4683 de BSAC_MES_RG3976, pero lo incluye en la cuota sindical.
        // Conservar exactamente la base que 4754 recibía ANTES de corregir 4750.
        NuevoSindicato := OriginalSindicato.Replace('BASE_SAC_DEV', 'ROUND((BASE_IG4 + BASE_EXT_IG4) / 12, 0.0001)');
        Sac.Get('4750', DMY2Date(1, 1, 2026));
        Sindicato.Get('4754', DMY2Date(1, 1, 2026));
        if (Normalizar(Sac.Fórmula) = Normalizar(NuevoSac)) and (Normalizar(Sindicato.Fórmula) = Normalizar(NuevoSindicato)) then exit;
        if (Normalizar(Sac.Fórmula) <> Normalizar(OriginalSac)) or (Normalizar(Sindicato.Fórmula) <> Normalizar(OriginalSindicato)) then
            Error('Las fórmulas de SAC fiscal cambiaron respecto de la revisión.');
        Cab.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
        Cab.SetFilter("Fecha Liquidación", '>=%1', DMY2Date(1, 1, 2026));
        Cab.SetFilter(Estado, '>%1', Cab.Estado::Calculada);
        if not Cab.IsEmpty() then Error('Hay liquidaciones protegidas que usan estas fórmulas.');
        Cab.SetFilter("Fecha Liquidación", '>%1', DMY2Date(31, 1, 2026));
        Cab.SetFilter(Estado, '<>%1', Cab.Estado::Borrador);
        if not Cab.IsEmpty() then Error('Hay meses posteriores calculados; revisar su cadena.');
        Fraccion.SetRange("Cód. Acumulador", 'BASE_SAC_DEV');
        Fraccion.SetFilter("Vigencia Desde", '<=%1', DMY2Date(1, 1, 2026));
        Fraccion.SetFilter("Cód. Concepto", '<>%1', '4750');
        if Fraccion.FindSet() then repeat
            OtroConcepto.Get(Fraccion."Cód. Concepto", Fraccion."Vigencia Desde");
            if (OtroConcepto."Vigencia Hasta" = 0D) or
               (OtroConcepto."Vigencia Hasta" >= DMY2Date(1, 1, 2026)) then
                Error('La base de SAC virtual tiene otro aportante vigente.');
        until Fraccion.Next() = 0;
        // Enero conserva una única fórmula por concepto; Modify(true) registra
        // las fórmulas anteriores y nuevas en el historial existente de BC.
        Sac.Validate(Fórmula, NuevoSac);
        Sac.Modify(true);
        Sindicato.Validate(Fórmula, NuevoSindicato);
        Sindicato.Modify(true);
    end;

    local procedure Normalizar(Formula: Text): Text
    var
        Espacios: Text;
        Tabulador, Salto, Retorno: Char;
    begin
        Tabulador := 9;
        Salto := 10;
        Retorno := 13;
        Espacios := ' ' + Format(Tabulador) + Format(Salto) + Format(Retorno);
        exit(UpperCase(DelChr(Formula, '=', Espacios)));
    end;

    local procedure ProbarCasoSAC(Fila: JsonObject; Revisados: Dictionary of [Code[20], Boolean])
    var
        Cab: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Recalculo: Codeunit "Recálculo En Cadena Liq.";
        Empleado: Code[20];
        Sac, Sindicato, Impuesto: Decimal;
    begin
        Empleado := CopyStr(Texto(Fila, 'empleado'), 1, MaxStrLen(Empleado));
        Cab.SetRange("No. Empleado", Empleado);
        Cab.SetRange("Cód. Período", '202601');
        Cab.SetRange(Estado, Cab.Estado::Calculada);
        Cab.FindFirst();
        if not Revisados.ContainsKey(Empleado) then Recalculo.EjecutarMesEmpleado(Cab."No.");
        if Cab.FindSet() then repeat
            Linea.SetRange("No. Liquidación", Cab."No.");
            Linea.SetRange("Cód. Concepto", '4750');
            Linea.CalcSums(Importe);
            Sac += Linea.Importe;
            Linea.SetRange("Cód. Concepto", '4754');
            Linea.CalcSums(Importe);
            Sindicato += Linea.Importe;
            Linea.SetRange("Cód. Concepto", '5010');
            Linea.CalcSums(Importe);
            Impuesto += Linea.Importe;
        until Cab.Next() = 0;
        if Abs(Sac - Monto(Fila, 'sac_esperado')) >= 0.01 then Error('Base de SAC simulada distinta de la verificada.');
        if Abs(Sindicato - Monto(Fila, 'sindicato_esperado')) >= 0.0002 then Error('La corrección modificó la cuota sindical virtual.');
        if Abs(Impuesto - Monto(Fila, 'impuesto_meta4')) >= 0.02 then Error('Ganancias no concilia en el caso SAC %1.', Empleado);
    end;

    local procedure ImportarFila(Fila: JsonObject; Empleado: Code[20]; Periodo: Record "Período Liquidación")
    var
        Cab: Record "Liquidación";
        Historia: Record "Hist. Liq. Meta4";
        ParamVig: Record "Parámetro Vigente";
        Fuentes: JsonArray;
        Token: JsonToken;
        Fuente: JsonObject;
        Importe: Decimal;
        Origen: Text;
        ContadorAnterior: Integer;
    begin
        Cab.SetRange("No. Empleado", Empleado);
        Cab.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
        Cab.SetRange("Cód. Período", Periodo.Código);
        Cab.SetFilter(Estado, '>%1', Cab.Estado::Calculada);
        if not Cab.IsEmpty() then Error('El mes tiene resultados protegidos.');
        Cab.SetRange("Cód. Período");
        Cab.SetFilter("Fecha Liquidación", '>%1', Periodo."Fecha Hasta");
        Cab.SetFilter(Estado, '<>%1', Cab.Estado::Borrador);
        if not Cab.IsEmpty() then Error('Hay resultados posteriores; revisar la cadena completa.');
        if (Monto(Fila, 'conyuge') < 0) or (Monto(Fila, 'hijos') < 0) then Error('Importe histórico negativo.');
        Fila.Get('fuentes', Token);
        Fuentes := Token.AsArray();
        if Fuentes.Count() = 0 then Error('La foto necesita una corrida original verificable.');
        Origen := 'Meta4 enero 2026; entradas/contadores:';
        foreach Token in Fuentes do begin
            Fuente := Token.AsObject();
            Historia.Get(Entero(Fuente, 'entrada'));
            Historia.TestField("No. Empleado", Empleado);
            Historia.TestField("Cód. Sociedad", '01');
            Historia.TestField("Contador Liq.", Entero(Fuente, 'contador'));
            if (Historia."Fecha Imputación" < Periodo."Fecha Desde") or (Historia."Fecha Imputación" > Periodo."Fecha Hasta") then
                Error('La fuente no pertenece al mes importado.');
            if Historia."Contador Liq." <= ContadorAnterior then Error('Fuentes repetidas o fuera de orden.');
            ContadorAnterior := Historia."Contador Liq.";
            if (LeerMonto(Historia."No. Entrada", 'IG_CONYUGE_REM') <> Monto(Fila, 'conyuge')) or
               (LeerMonto(Historia."No. Entrada", 'IG_HIJOS_REM') <> Monto(Fila, 'hijos')) then
                Error('El importe no coincide con todas las corridas originales.');
            Origen += ' ' + Format(Historia."No. Entrada") + '/' + Format(Historia."Contador Liq.");
        end;
        Importe := Monto(Fila, 'conyuge') + Monto(Fila, 'hijos');
        ParamVig.SetRange("Cód. Parámetro Base", CodigoParametro());
        ParamVig.SetRange("No. Empleado", Empleado);
        ParamVig.SetRange("Vigencia Desde", Periodo."Fecha Desde");
        if ParamVig.FindFirst() then begin
            ParamVig.TestField(Valor, Importe);
            ParamVig.TestField(Notas, CopyStr(Origen, 1, MaxStrLen(ParamVig.Notas)));
            if ParamVig.Next() <> 0 then Error('Foto familiar duplicada.');
            exit;
        end;
        ParamVig.Init();
        ParamVig."Cód. Parámetro Base" := CodigoParametro();
        ParamVig."Vigencia Desde" := Periodo."Fecha Desde";
        ParamVig.Validate("No. Empleado", Empleado);
        ParamVig.Valor := Importe;
        ParamVig.Notas := CopyStr(Origen, 1, MaxStrLen(ParamVig.Notas));
        ParamVig.Insert(true);
    end;

    local procedure LeerMonto(Entrada: Integer; NombreColumna: Text): Decimal
    var
        Columna: Record "Columna Hist. Meta4";
        Valor: Record "Valor Hist. Meta4";
    begin
        Columna.SetRange("Nombre Columna", NombreColumna);
        Columna.FindFirst();
        if NombreColumna = 'IMPUESTO' then
            Columna.TestField("Tabla Origen", 'M4T_ACUMULADO_RL')
        else
            Columna.TestField("Tabla Origen", 'M4T_ACUMULADO_RL2');
        if Valor.Get(Entrada, Columna."No.") then exit(Valor.Valor);
        // El archivo literal es disperso: columna ausente = cero, verificado en Oracle.
        exit(0);
    end;

    local procedure CodigoParametro(): Code[20]
    begin exit('FAM_HIST_M4'); end;

    local procedure Texto(Obj: JsonObject; Clave: Text): Text
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsText()); end;

    local procedure Monto(Obj: JsonObject; Clave: Text): Decimal
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsDecimal()); end;

    local procedure Entero(Obj: JsonObject; Clave: Text): Integer
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsInteger()); end;
}
