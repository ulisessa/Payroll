namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>Carga controlada del prevuelo de febrero desde fuentes de Meta4 verificadas.</summary>
codeunit 110067 "Migrar Febrero Meta4"
{
    procedure Simular(Payload: Text)
    var
        Raiz: JsonObject;
        Filas: JsonArray;
        Token: JsonToken;
    begin
        Aplicar(Payload);
        Raiz.ReadFrom(Payload);
        Lista(Raiz, 'prestamos', Filas);
        foreach Token in Filas do ProbarCuotas(Token.AsObject());
        Error('SIMULACION_FEBRERO_OK: validación completa; todos los cambios se revierten.');
    end;

    local procedure ProbarCuotas(Fila: JsonObject)
    var
        Cuota: Record "Cuota Préstamo";
        Cab1: Record "Liquidación";
        Cab2: Record "Liquidación";
        Incid: Record "Incidencia Liquidación";
        Gestion: Codeunit "Gestión Préstamos";
        Importe: Decimal;
    begin
        Cuota.SetRange("No. Préstamo", Texto(Fila, 'numero'));
        Cuota.SetRange("Cód. Período", '202602');
        Cuota.CalcSums(Importe);
        Importe := Cuota.Importe;
        if Importe <= 0 then Error('El préstamo no tiene cuota para febrero.');
        CrearPrueba(Cab1, Texto(Fila, 'empleado'), '1');
        CrearPrueba(Cab2, Texto(Fila, 'empleado'), '2');
        Gestion.AplicarCuotasEnLiquidacion(Cab1);
        Incid.Get(Cab1."No.", '8870');
        Incid.TestField(Importe, Importe);
        Gestion.AplicarCuotasEnLiquidacion(Cab2);
        if Incid.Get(Cab2."No.", '8870') then Error('La cuota se aplicó dos veces en febrero.');
        Gestion.LimpiarParaRecalculo(Cab1."No.");
        Gestion.AplicarCuotasEnLiquidacion(Cab1);
        Incid.Get(Cab1."No.", '8870');
        Incid.TestField(Importe, Importe);
        Gestion.MarcarCuotasAplicadas(Cab1."No.", Cab1."Fecha Liquidación");
        if Cuota.FindSet() then repeat Cuota.TestField(Estado, Cuota.Estado::Aplicada); until Cuota.Next() = 0;
        Gestion.RevertirCuotasLiquidacion(Cab1."No.");
        if Cuota.FindSet() then repeat
            Cuota.TestField(Estado, Cuota.Estado::Pendiente);
            Cuota.TestField("No. Liquidación", '');
            Cuota.TestField("No. Liquidación Aplicada", '');
        until Cuota.Next() = 0;
        Gestion.AplicarCuotasEnLiquidacion(Cab2);
        Incid.Get(Cab2."No.", '8870');
        Incid.TestField(Importe, Importe);
    end;

    local procedure CrearPrueba(var Cab: Record "Liquidación"; Empleado: Text; Sufijo: Text)
    begin
        Cab.Init();
        Cab."No." := CopyStr('TEST-M4-Q' + Sufijo + '-' + Empleado, 1, 20);
        Cab."Cód. Período" := '202602';
        Cab."Cód. Tipo Liq." := 'REGULAR';
        Cab."Fecha Liquidación" := DMY2Date(28, 2, 2026);
        Cab.Validate("No. Empleado", Empleado);
        Cab.Insert(true);
    end;

    procedure Aplicar(Payload: Text)
    var
        Raiz: JsonObject;
        Filas: JsonArray;
        Token: JsonToken;
        Fila: JsonObject;
        Periodo: Record "Período Liquidación";
        Cab: Record "Liquidación";
    begin
        if not Raiz.ReadFrom(Payload) then Error('Payload JSON inválido.');
        if Texto(Raiz, 'periodo') <> '202602' then Error('Esta migración corresponde a febrero 2026.');
        Periodo.Get('202602');
        if Periodo.Estado = Periodo.Estado::Cerrado then Error('Febrero está cerrado.');
        Cab.SetRange("Cód. Período", '202602');
        Cab.SetFilter(Estado, '<>%1', Cab.Estado::Borrador);
        if not Cab.IsEmpty() then Error('Febrero ya tiene resultados: revisar antes de cargar datos.');

        Lista(Raiz, 'catalogos', Filas);
        foreach Token in Filas do begin Fila := Token.AsObject(); Categoria(Fila); end;
        Lista(Raiz, 'atributos', Filas);
        foreach Token in Filas do begin Fila := Token.AsObject(); Atributo(Fila); end;
        Lista(Raiz, 'puestos', Filas);
        if Filas.Count() > 0 then TipoPuestoOrigen();
        foreach Token in Filas do begin Fila := Token.AsObject(); PuestoOrigen(Fila); end;
        Lista(Raiz, 'prestamos', Filas);
        foreach Token in Filas do begin Fila := Token.AsObject(); Prestamo(Fila); end;
        Lista(Raiz, 'novedades', Filas);
        foreach Token in Filas do begin Fila := Token.AsObject(); Novedad(Fila); end;
    end;

    local procedure Categoria(Fila: JsonObject)
    var
        Cat: Record "Categoría CCT";
    begin
        if Cat.Get(Texto(Fila, 'convenio'), Texto(Fila, 'codigo')) then exit;
        Cat.Init();
        Cat."Cód. Convenio" := CopyStr(Texto(Fila, 'convenio'), 1, 20);
        Cat.Código := CopyStr(Texto(Fila, 'codigo'), 1, 20);
        Cat.Descripción := CopyStr(Texto(Fila, 'descripcion'), 1, MaxStrLen(Cat.Descripción));
        Cat.Insert(true);
    end;

    local procedure Atributo(Fila: JsonObject)
    var
        Atr: Record "Atributo Entidad Liq.";
        Emp: Record Employee;
        Desde: Date;
        Hasta: Date;
        Valor: Code[20];
        Padre: Code[20];
    begin
        Emp.Get(Texto(Fila, 'empleado'));
        Desde := Fecha(Fila, 'desde');
        Hasta := Fecha(Fila, 'hasta');
        Valor := CopyStr(Texto(Fila, 'valor'), 1, 20);
        Padre := CopyStr(Texto(Fila, 'padre'), 1, 20);
        if Atr.Get(Atr."Tipo Entidad"::Empleado, Emp."No.", Texto(Fila, 'tipo'), Desde) then begin
            if (Atr."Cód. Valor" = Valor) and (Atr."Cód. Valor Padre" = Padre) and (Atr."Vigencia Hasta" = Hasta) then exit;
            if (Atr."Cód. Valor" <> Texto(Fila, 'anterior_valor')) or
               (Atr."Cód. Valor Padre" <> Texto(Fila, 'anterior_padre')) or
               (Atr."Vigencia Hasta" <> Fecha(Fila, 'anterior_hasta')) then
                Error('El atributo %1 de %2 cambió desde el respaldo.', Atr."Cód. Tipo Atributo", Emp."No.");
            Atr."Cód. Valor Padre" := Padre;
            Atr.Validate("Cód. Valor", Valor);
            Atr.Validate("Vigencia Hasta", Hasta);
            Atr.Modify(true);
        end else begin
            Atr.Init();
            Atr."Tipo Entidad" := Atr."Tipo Entidad"::Empleado;
            Atr."Cód. Entidad" := Emp."No.";
            Atr."Cód. Tipo Atributo" := CopyStr(Texto(Fila, 'tipo'), 1, 20);
            Atr."Vigencia Desde" := Desde;
            Atr."Vigencia Hasta" := Hasta;
            Atr."Cód. Valor Padre" := Padre;
            Atr.Validate("Cód. Valor", Valor);
            Atr.Insert(true);
        end;
    end;

    local procedure TipoPuestoOrigen()
    var
        Tipo: Record "Tipo Atributo Liq.";
    begin
        if Tipo.Get('PUESTO_META4') then begin
            Tipo.TestField("Tipo Dato", Tipo."Tipo Dato"::Lista);
            Tipo.TestField("Espejo De", Tipo."Espejo De"::Ninguno);
            exit;
        end;
        Tipo.Init();
        Tipo.Código := 'PUESTO_META4';
        Tipo.Descripción := 'Puesto Meta4 (tierra)';
        Tipo."Tipo Dato" := Tipo."Tipo Dato"::Lista;
        Tipo."Tipo Entidad" := Tipo."Tipo Entidad"::Empleado;
        Tipo."Cód. Clase" := 'EMPLEADO';
        // Informativo: sin variable, padre ni espejo de remuneración/producción.
        Tipo.Insert(true);
    end;

    local procedure PuestoOrigen(Fila: JsonObject)
    var
        Valor: Record "Valor Atributo Liq.";
        Emp: Record Employee;
        Atr: Record "Atributo Entidad Liq.";
        Desde: Date;
    begin
        Emp.Get(Texto(Fila, 'empleado'));
        Desde := Fecha(Fila, 'desde');
        if not Valor.Get('PUESTO_META4', '', Texto(Fila, 'valor')) then begin
            Valor.Init();
            Valor."Cód. Tipo Atributo" := 'PUESTO_META4';
            Valor.Código := CopyStr(Texto(Fila, 'valor'), 1, 20);
            Valor.Descripción := CopyStr(Texto(Fila, 'descripcion'), 1, MaxStrLen(Valor.Descripción));
            Valor.Insert(true);
        end;
        if Atr.Get(Atr."Tipo Entidad"::Empleado, Emp."No.", 'PUESTO_META4', Desde) then begin
            Atr.TestField("Cód. Valor", Valor.Código);
            Atr.TestField("Vigencia Hasta", Fecha(Fila, 'hasta'));
            exit;
        end;
        Atr.Init();
        Atr."Tipo Entidad" := Atr."Tipo Entidad"::Empleado;
        Atr."Cód. Entidad" := Emp."No.";
        Atr."Cód. Tipo Atributo" := 'PUESTO_META4';
        Atr."Vigencia Desde" := Desde;
        Atr."Vigencia Hasta" := Fecha(Fila, 'hasta');
        Atr.Validate("Cód. Valor", Valor.Código);
        Atr.Insert(true);
    end;

    local procedure Prestamo(Fila: JsonObject)
    var
        Pr: Record "Préstamo Empleado";
        Cuota: Record "Cuota Préstamo";
        Filas: JsonArray;
        Token: JsonToken;
        Q: JsonObject;
        Cab: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        i: Integer;
        Importe: Decimal;
        Numero: Integer;
        Periodo: Code[10];
        Documento: Code[20];
    begin
        Lista(Fila, 'cuotas', Filas);
        if Pr.Get(Texto(Fila, 'numero')) then begin
            Pr.TestField("No. Empleado", Texto(Fila, 'empleado'));
            Pr.TestField("Importe Total", Monto(Fila, 'importe'));
            Pr.TestField("Cód. Concepto Descuento", '8870');
            Pr.TestField("Cant. Cuotas", Filas.Count());
        end else begin
            Pr.Init();
            Pr."No." := CopyStr(Texto(Fila, 'numero'), 1, 20);
            Pr.Validate("No. Empleado", Texto(Fila, 'empleado'));
            Pr.Fecha := Fecha(Fila, 'fecha');
            Pr.Tipo := Pr.Tipo::Anticipo;
            Pr.Descripción := 'Anticipo administrativo Meta4';
            Pr."Importe Total" := Monto(Fila, 'importe');
            Pr."Cant. Cuotas" := Filas.Count();
            Pr."Cód. Concepto Descuento" := '8870';
            Pr.Observaciones := CopyStr(Texto(Fila, 'observaciones'), 1, 250);
            Pr.Insert(true);
        end;
        for i := 0 to Filas.Count() - 1 do begin
            Filas.Get(i, Token); Q := Token.AsObject();
            Importe := Monto(Q, 'importe');
            Periodo := CopyStr(Texto(Q, 'periodo'), 1, 10);
            Documento := CopyStr(Texto(Q, 'documento'), 1, 20);
            Numero := Entero(Q, 'numero_existente');
            if Importe <= 0 then Error('La cuota debe ser positiva.');
            if Periodo < '202602' then begin
                Cab.Get(Documento);
                Cab.TestField("No. Empleado", Pr."No. Empleado");
                Cab.TestField("Cód. Período", Periodo);
                Cab.TestField(Estado, Cab.Estado::Calculada);
                Lin.SetRange("No. Liquidación", Documento);
                Lin.SetRange("Cód. Concepto", '8870');
                Lin.CalcSums(Importe);
                if Lin.Importe <> Importe then Error('La cuota histórica no coincide con 8870.');
            end;
            Cuota.Reset();
            if Numero = 0 then begin
                Cuota.SetRange("No. Préstamo", Pr."No.");
                Cuota.SetRange("Cód. Período", Periodo);
                if Cuota.FindFirst() then begin
                    Cuota.TestField(Importe, Importe);
                    Cuota.TestField("No. Liquidación", Documento);
                end else begin
                    Clear(Cuota);
                    Cuota."No. Préstamo" := Pr."No.";
                    Cuota.Importe := Importe;
                    Cuota."Cód. Período" := Periodo;
                    Cuota."No. Liquidación" := Documento;
                    Cuota.Insert(true);
                end;
            end else begin
                Cuota.Get(Pr."No.", Numero);
                Cuota.TestField(Importe, Importe);
                if (Cuota."Cód. Período" <> Periodo) or (Cuota."No. Liquidación" <> Documento) then begin
                    Cuota.TestField(Estado, Cuota.Estado::Pendiente);
                    Cuota.TestField("Cód. Período", '');
                    Cuota.TestField("No. Liquidación", '');
                    Cuota."Cód. Período" := Periodo;
                    Cuota."No. Liquidación" := Documento;
                    Cuota.Modify(true);
                end;
            end;
        end;
    end;

    local procedure Novedad(Fila: JsonObject)
    var
        Nov: Record "Novedad Liquidación";
        Origen: Text;
    begin
        Origen := Texto(Fila, 'origen');
        Nov.SetRange("Cód. Período", '202602');
        Nov.SetRange("No. Empleado", Texto(Fila, 'empleado'));
        Nov.SetRange("Cód. Concepto", '8850');
        Nov.SetRange(Observaciones, Origen);
        if Nov.FindFirst() then begin
            Nov.TestField(Importe, Monto(Fila, 'importe'));
            Nov.TestField("No. Proyecto", Texto(Fila, 'proyecto'));
            Nov.TestField(Fecha, Fecha(Fila, 'fecha'));
            exit;
        end;
        Nov.Init();
        Nov.Validate("Cód. Período", '202602');
        Nov.Validate("No. Empleado", Texto(Fila, 'empleado'));
        // TP1 se imputa a la regular; TP10 al cierre de su marea.
        Nov.Validate("No. Proyecto", Texto(Fila, 'proyecto'));
        Nov.Validate(Fecha, Fecha(Fila, 'fecha'));
        Nov."Cód. Tipo Liq." := CopyStr(Texto(Fila, 'tipo'), 1, 20);
        Nov."Cód. Concepto" := '8850';
        Nov.Importe := Monto(Fila, 'importe');
        Nov.Observaciones := CopyStr(Origen, 1, 250);
        Nov.Insert(true);
    end;

    local procedure Lista(Obj: JsonObject; Clave: Text; var Valores: JsonArray)
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); Valores := Token.AsArray(); end;

    local procedure Texto(Obj: JsonObject; Clave: Text): Text
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsText()); end;

    local procedure Fecha(Obj: JsonObject; Clave: Text): Date
    var D: Date; T: Text;
    begin
        T := Texto(Obj, Clave);
        if T = '' then exit(0D);
        if not Evaluate(D, T, 9) then Error('Fecha ISO inválida: %1.', Clave);
        exit(D);
    end;

    local procedure Monto(Obj: JsonObject; Clave: Text): Decimal
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsDecimal()); end;

    local procedure Entero(Obj: JsonObject; Clave: Text): Integer
    var Token: JsonToken;
    begin Obj.Get(Clave, Token); exit(Token.AsValue().AsInteger()); end;
}
