namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Arma la previa del asiento de sueldos de un período: cuentas, proyectos, debe y haber, y los
/// avisos de lo que quedó afuera. No escribe el diario ni registra.
/// </summary>
/// <remarks>
/// ES UNA ACTIVIDAD DEL PERÍODO, NO DE LA LIQUIDACIÓN. Nada de esto corre al liquidar: se arma con
/// el mes cerrado, leyendo las liquidaciones como quedaron, y armarlo dos veces da lo mismo. Por eso
/// tampoco depende de líneas que el motor escriba para el asiento: sirve para meses calculados antes
/// de que existieran las reglas, y para Aprobadas que ya no se recalculan.
///
/// CADA LÍNEA DE LIQUIDACIÓN VA A UN PAR DE CUENTAS. La regla del concepto (Regla Asiento Liq.) dice
/// la cuenta del debe y la del haber según el tipo de liquidación, el proyecto, una dimensión o un
/// atributo; gana la más específica. Todo se agrupa por cuenta y proyecto, como consolidaba la
/// interfaz de Meta4 (fntConsolidarDiario). Como cada línea entra por los dos lados, el asiento
/// balancea por construcción; lo que no entra sale en los avisos con su importe.
///
/// LAS PROVISIONES SE ASIENTAN POR SALDO. Para el SAC, sus cargas, las vacaciones y los francos se
/// registra el devengado hasta que se liquida; ahí se revierte el devengado y queda lo liquidado en
/// el gasto. Se compara el saldo al cierre del período anterior con el de este y se asienta la
/// diferencia, cada parte con el proyecto de la liquidación que la originó (el devengado de una
/// marea se revierte en esa marea).
///
/// UN PERÍODO YA ASENTADO QUE SE RECALCULA HAY QUE VOLVER A ASENTARLO. El siguiente parte del
/// saldo recalculado, así que no absorbe la diferencia: si el período anterior cambió después de
/// asentarse, esa diferencia queda sin asentar. Cuando exista el registro, marcar las liquidaciones
/// como Contabilizada impide reabrirlas sin revertir antes el asiento.
/// </remarks>
codeunit 110083 "Asiento Sueldos Liq."
{
    Access = Public;

    /// <summary>
    /// Llena Buffer con la previa del período y devuelve el resumen de una línea.
    /// </summary>
    procedure Previsualizar(CodPeriodo: Code[10]; IncluirBorradores: Boolean; var Buffer: Record "Línea Asiento Buffer Liq." temporary): Text
    var
        Liq: Record "Liquidación";
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if CodPeriodo = '' then
            Error(ErrSinPeriodo);
        if not FPeriodo.Get(CodPeriodo) then
            Error(ErrPeriodoInexistente, CodPeriodo);

        Inicializar(IncluirBorradores);
        FTiposLiq := TiposQueContabilizan();
        if FTiposLiq = '' then
            Error(ErrSinTipos);

        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetFilter("Cód. Tipo Liq.", FTiposLiq);
        Liq.SetFilter(Estado, FiltroEstados());
        if Liq.FindSet() then
            repeat
                ProcesarLiquidacion(Liq);
            until Liq.Next() = 0;

        // Lo que queda afuera por el tipo se dice: un tipo nuevo sin Genera Asiento no puede
        // desaparecer del asiento en silencio.
        Liq.SetFilter("Cód. Tipo Liq.", '<>%1', '');
        Liq.SetFilter(Estado, FiltroEstados());
        if Liq.FindSet() then
            repeat
                if not TipoContabiliza(Liq."Cód. Tipo Liq.") then begin
                    FijarOrigen(Liq, 0, '', '', TxtOrigenLiquidacion, '');
                    Avisar('TIPOSIN|' + Liq."Cód. Tipo Liq.", StrSubstNo(AvTipoSinAsiento, Liq."Cód. Tipo Liq."), 0);
                end;
            until Liq.Next() = 0;
            LimpiarOrigen();

        ProcesarProvisiones();

        EscribirBuffer(Buffer);
        exit(StrSubstNo(TxtResumen, FLiquidaciones, FTotalDebe, FTotalHaber, FResiduo, FAvisos));
    end;

    /// <summary>
    /// La previa del período (sin borradores) para invocación administrativa desde el servidor.
    /// </summary>
    /// <remarks>
    /// DEVUELVE EL RESULTADO EN UN ERROR IDENTIFICADO, PREVIA_ASIENTO_JSON:…:FIN_PREVIA_ASIENTO_JSON,
    /// porque Invoke-NAVCodeunit descarta los valores de retorno (el mismo recurso que
    /// DiagnosticarOrdenesJson de Corrección Orden Acum.). Es de sólo lectura: la previa no escribe
    /// nada, así que el error no revierte ningún cambio. Sirve para comparar la previa contra la
    /// simulación de scripts/SembrarAsientoSueldos.sql sin abrir el cliente.
    /// </remarks>
    procedure DiagnosticarPreviaJson(CodPeriodo: Text)
    var
        Buffer: Record "Línea Asiento Buffer Liq." temporary;
        Raiz: JsonObject;
        Lineas: JsonArray;
        Linea: JsonObject;
        Resumen: Text;
        Salida: Text;
    begin
        Resumen := Previsualizar(CopyStr(CodPeriodo, 1, 10), false, Buffer);
        Raiz.Add('resumen', Resumen);
        Raiz.Add('debe', FTotalDebe);
        Raiz.Add('haber', FTotalHaber);
        if Buffer.FindSet() then
            repeat
                Clear(Linea);
                Linea.Add('clase', Format(Buffer.Clase));
                Linea.Add('cuenta', Buffer.Cuenta);
                Linea.Add('proyecto', Buffer."No. Proyecto");
                Linea.Add('importe', Buffer.Importe);
                Linea.Add('cantidad', Buffer.Cantidad);
                Linea.Add('mensaje', Buffer.Mensaje);
                Lineas.Add(Linea);
            until Buffer.Next() = 0;
        Raiz.Add('lineas', Lineas);
        Raiz.WriteTo(Salida);
        Error('PREVIA_ASIENTO_JSON:%1:FIN_PREVIA_ASIENTO_JSON', Salida);
    end;

    /// <summary>
    /// De dónde sale una línea de la previa: cada línea de liquidación, partida de provisión o
    /// lote de francos que aportó a esa cuenta y proyecto (o que disparó ese aviso), con su importe.
    /// ClaveOrigen es el campo Clave Origen de la línea de la previa.
    /// </summary>
    /// <remarks>
    /// SE VUELVE A ARMAR LA PREVIA, siguiendo sólo esa clave. Guardar el origen de todas las
    /// líneas al armarla serían decenas de miles de filas para mirar una; rearmarla son unos
    /// segundos y da exactamente lo mismo, porque es el mismo cálculo. La suma de los orígenes de
    /// una cuenta es su importe antes del redondeo a centavos.
    /// </remarks>
    procedure Origenes(CodPeriodo: Code[10]; IncluirBorradores: Boolean; ClaveOrigen: Text; var Origen: Record "Línea Asiento Buffer Liq." temporary)
    var
        Buffer: Record "Línea Asiento Buffer Liq." temporary;
    begin
        Origen.Reset();
        Origen.DeleteAll();
        if ClaveOrigen = '' then
            exit;
        FClaveObjetivo := ClaveOrigen;
        FOrigenes.Reset();
        FOrigenes.DeleteAll();
        FSecOrigen := 0;
        Previsualizar(CodPeriodo, IncluirBorradores, Buffer);
        FClaveObjetivo := '';
        if FOrigenes.FindSet() then
            repeat
                Origen := FOrigenes;
                Origen.Insert();
            until FOrigenes.Next() = 0;
    end;

    /// <summary>
    /// Los orígenes de una línea de la previa para invocación administrativa: el argumento es el
    /// período y la clave separados por punto y coma (202601;6110002|PP-802-000006). Devuelve el
    /// resultado en un error identificado ORIGEN_ASIENTO_JSON:…:FIN_ORIGEN_ASIENTO_JSON, como
    /// DiagnosticarPreviaJson. De sólo lectura.
    /// </summary>
    procedure DiagnosticarOrigenesJson(Argumento: Text)
    var
        Origen: Record "Línea Asiento Buffer Liq." temporary;
        Partes: List of [Text];
        Raiz: JsonObject;
        Lineas: JsonArray;
        Linea: JsonObject;
        Total: Decimal;
        Salida: Text;
    begin
        Partes := Argumento.Split(';');
        if Partes.Count() <> 2 then
            Error(ErrArgumentoOrigenes);
        Origenes(CopyStr(Partes.Get(1), 1, 10), false, Partes.Get(2), Origen);
        if Origen.FindSet() then
            repeat
                Clear(Linea);
                Linea.Add('liquidacion', Origen."No. Liquidación");
                Linea.Add('linea', Origen."No. Línea Liq.");
                Linea.Add('tipo', Origen."Cód. Tipo Liq.");
                Linea.Add('proyecto', Origen."No. Proyecto");
                Linea.Add('concepto', Origen."Cód. Concepto");
                Linea.Add('origen', Origen.Origen);
                Linea.Add('detalle', Origen.Mensaje);
                Linea.Add('importe', Origen.Importe);
                Lineas.Add(Linea);
                Total += Origen.Importe;
            until Origen.Next() = 0;
        Raiz.Add('clave', Partes.Get(2));
        Raiz.Add('origenes', Origen.Count());
        Raiz.Add('total', Total);
        Raiz.Add('lineas', Lineas);
        Raiz.WriteTo(Salida);
        Error('ORIGEN_ASIENTO_JSON:%1:FIN_ORIGEN_ASIENTO_JSON', Salida);
    end;

    local procedure Inicializar(IncluirBorradores: Boolean)
    var
        Regla: Record "Regla Asiento Liq.";
        Concepto: Record "Concepto Liquidación";
        ConceptoFrancos: Code[20];
        Motivo: Text;
    begin
        Clear(FEsAcumulador);
        Clear(FProvision);
        Clear(FImporteCuenta);
        Clear(FConceptosCuenta);
        Clear(FConceptoCuentaVisto);
        Clear(FLiqsCuenta);
        Clear(FLiqCuentaVista);
        Clear(FCuentaPorValor);
        Clear(FCoincide);
        Clear(FValorAtributo);
        Clear(FValorDimension);
        Clear(FEntidadAtributo);
        Clear(FAltaVigente);
        Clear(FValorLote);
        Clear(FCoefLiq);
        FFechaCotizacion := 0D;
        FUltimoErrorPrecio := '';
        Clear(FTipoContabiliza);
        Clear(FAvisoTexto);
        Clear(FAvisoCant);
        Clear(FAvisoImporte);
        FReglas.Reset();
        FReglas.DeleteAll();
        FIncluirBorradores := IncluirBorradores;
        FLiquidaciones := 0;
        FTotalDebe := 0;
        FTotalHaber := 0;
        FAvisos := 0;
        FResiduo := 0;
        LimpiarOrigen();

        // Las reglas se copian a una temporal: un mes son decenas de miles de líneas y cada una
        // resuelve su regla. La provisión es del concepto (la tabla lo valida), así que alcanza con
        // la primera fila de cada uno. Una fila incompleta (un par a medio cargar, una cuenta que
        // falta) se deja afuera y se avisa: la tabla sólo exige la fila completa al insertarla.
        if Regla.FindSet() then
            repeat
                if Regla.Incompleta(Motivo) then
                    Avisar('REGLAINC|' + Regla."Cód. Concepto" + '|' + Regla.ClaveVariante() + '|' + Format(Regla."Vigencia Desde", 0, 9),
                        StrSubstNo(AvReglaIncompleta, Regla."Cód. Concepto", Motivo), 0)
                else begin
                    FReglas := Regla;
                    FReglas.Insert(false);
                    if Regla.Provisión <> Regla.Provisión::" " then
                        if not FProvision.ContainsKey(Regla."Cód. Concepto") then begin
                            // Las reglas también entran por SQL, sin el OnInsert que lo impide.
                            if Regla.Provisión = Regla.Provisión::Francos then begin
                                if ConceptoFrancos <> '' then
                                    Error(ErrFrancosEnDosConceptos, ConceptoFrancos, Regla."Cód. Concepto");
                                ConceptoFrancos := Regla."Cód. Concepto";
                            end;
                            FProvision.Add(Regla."Cód. Concepto", Regla.Provisión);
                        end;
                end;
            until Regla.Next() = 0;
        if FReglas.IsEmpty() then
            Error(ErrSinReglas);

        // Las líneas que el motor escribe para los acumuladores no son importes del recibo: si se
        // contaran, un acumulador que suma haberes duplicaría el gasto.
        Concepto.SetRange("Es Acumulador", true);
        Concepto.SetLoadFields(Código);
        if Concepto.FindSet() then
            repeat
                if not FEsAcumulador.ContainsKey(Concepto.Código) then
                    FEsAcumulador.Add(Concepto.Código, true);
            until Concepto.Next() = 0;

        GLSetup.Get();
    end;

    local procedure TiposQueContabilizan(): Text
    var
        TipoLiq: Record "Tipo Liquidación";
        Filtro: Text;
    begin
        TipoLiq.SetRange("Genera Asiento", true);
        if TipoLiq.FindSet() then
            repeat
                if Filtro <> '' then
                    Filtro += '|';
                Filtro += '''' + TipoLiq.Código + '''';
            until TipoLiq.Next() = 0;
        exit(Filtro);
    end;

    local procedure TipoContabiliza(CodTipo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
        Contabiliza: Boolean;
    begin
        if FTipoContabiliza.Get(CodTipo, Contabiliza) then
            exit(Contabiliza);
        if TipoLiq.Get(CodTipo) then
            Contabiliza := TipoLiq."Genera Asiento";
        FTipoContabiliza.Add(CodTipo, Contabiliza);
        exit(Contabiliza);
    end;

    local procedure FiltroEstados(): Text
    var
        Liq: Record "Liquidación";
    begin
        if FIncluirBorradores then
            exit(StrSubstNo('%1|%2|%3|%4', Liq.Estado::Borrador, Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada));
        exit(StrSubstNo('%1|%2|%3', Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada));
    end;

    local procedure ProcesarLiquidacion(Liq: Record "Liquidación")
    var
        Lin: Record "Línea Liquidación";
        Fila: Record "Regla Asiento Liq.";
        Ambigua: Boolean;
    begin
        FLiquidaciones += 1;

        Lin.SetRange("No. Liquidación", Liq."No.");
        Lin.SetFilter(Importe, '<>0');
        Lin.SetLoadFields("Cód. Concepto", "Descripción Concepto", "Tipo Concepto", Importe);
        if Lin.FindSet() then
            repeat
                // Una provisión no contabiliza la línea: entra después, por la variación del saldo.
                if not FEsAcumulador.ContainsKey(Lin."Cód. Concepto") and not FProvision.ContainsKey(Lin."Cód. Concepto") then begin
                    FijarOrigen(Liq, Lin."No. Línea", Lin."Cód. Concepto", Lin."Descripción Concepto", TxtOrigenLinea, '');
                    if ResolverRegla(Lin."Cód. Concepto", Liq, ImporteEnJuego(Lin), Fila, Ambigua) then begin
                        if not Fila."No Contabiliza" then
                            ImputarImporte(Liq, Fila, Lin.Importe, Lin."Cód. Concepto");
                    end else
                        // Un informativo sin regla no es un olvido: no lleva plata.
                        if not Ambigua and (Lin."Tipo Concepto" <> Lin."Tipo Concepto"::Informativo) then
                            Avisar('SINREGLA|' + Lin."Cód. Concepto",
                                StrSubstNo(AvSinRegla, Lin."Cód. Concepto", Lin."Descripción Concepto"), Lin.Importe);
                end;
            until Lin.Next() = 0;
    end;

    // Un informativo no lleva plata: si su regla falla, el aviso no suma su importe.
    local procedure ImporteEnJuego(Lin: Record "Línea Liquidación"): Decimal
    begin
        if Lin."Tipo Concepto" = Lin."Tipo Concepto"::Informativo then
            exit(0);
        exit(Lin.Importe);
    end;

    /// <summary>
    /// La regla que manda para un concepto en una liquidación: de cada variante de filtros, la
    /// última vigencia a la fecha; de las variantes que coinciden, la que tiene más filtros.
    /// Importe es lo que queda sin imputar si la regla es ambigua, para el aviso.
    /// </summary>
    local procedure ResolverRegla(CodConcepto: Code[20]; Liq: Record "Liquidación"; Importe: Decimal; var Fila: Record "Regla Asiento Liq."; var Ambigua: Boolean): Boolean
    var
        Variante: Text;
        UltimaVariante: Text;
        VarianteGanadora: Text;
        VarianteEmpatada: Text;
        Mejor: Integer;
        Especificidad: Integer;
        Hay: Boolean;
    begin
        Ambigua := false;
        FReglas.Reset();
        FReglas.SetRange("Cód. Concepto", CodConcepto);
        FReglas.SetFilter("Vigencia Desde", '<=%1', Liq."Fecha Liquidación");
        // La clave ordena por filtros y después por fecha: al revés, la primera fila de cada
        // variante es la vigente.
        FReglas.Ascending(false);
        if not FReglas.FindSet() then
            exit(false);
        Mejor := -1;
        repeat
            Variante := FReglas.ClaveVariante();
            if Variante <> UltimaVariante then begin
                UltimaVariante := Variante;
                if Coincide(FReglas, Liq) then begin
                    Especificidad := FReglas.Especificidad();
                    if Especificidad > Mejor then begin
                        Mejor := Especificidad;
                        Fila := FReglas;
                        VarianteGanadora := Variante;
                        VarianteEmpatada := '';
                        Hay := true;
                    end else
                        if Especificidad = Mejor then
                            VarianteEmpatada := Variante;
                end;
            end;
        until FReglas.Next() = 0;

        // DOS FILAS IGUAL DE ESPECÍFICAS que coinciden son un error de carga: cualquiera de las
        // dos podría ser la buena. Se avisa por concepto y el importe no se imputa.
        if VarianteEmpatada <> '' then begin
            Ambigua := true;
            Avisar('AMBIG|' + CodConcepto, StrSubstNo(AvReglaAmbigua, CodConcepto,
                ConvertStr(VarianteGanadora, '¦', ' '), ConvertStr(VarianteEmpatada, '¦', ' ')), Importe);
            exit(false);
        end;
        exit(Hay);
    end;

    local procedure Coincide(Regla: Record "Regla Asiento Liq."; Liq: Record "Liquidación"): Boolean
    begin
        if Regla."Filtro Tipo Liq." <> '' then
            if not CoincideFiltro(Liq."Cód. Tipo Liq.", Regla."Filtro Tipo Liq.") then
                exit(false);
        if Regla."Filtro Proyecto" <> '' then begin
            if Liq."No. Proyecto" = '' then
                exit(false);
            if not CoincideFiltro(Liq."No. Proyecto", Regla."Filtro Proyecto") then
                exit(false);
        end;
        if Regla."Cód. Dimensión Filtro" <> '' then
            if not CoincideFiltro(ValorDimension(Regla."Cód. Dimensión Filtro", Liq), Regla."Filtro Valor Dimensión") then
                exit(false);
        if Regla."Cód. Atributo Filtro" <> '' then
            if not CoincideFiltro(ValorAtributo(Regla."Cód. Atributo Filtro", Liq), Regla."Filtro Valor Atributo") then
                exit(false);
        exit(true);
    end;

    /// <remarks>
    /// El filtro se evalúa con la misma sintaxis que en cualquier lista de BC, sobre un registro
    /// temporal. Se guarda el resultado: los mismos filtros se preguntan miles de veces por mes.
    /// </remarks>
    local procedure CoincideFiltro(Valor: Code[20]; Filtro: Text): Boolean
    var
        Clave: Text;
        Resultado: Boolean;
    begin
        Clave := Filtro + '¦' + Valor;
        if FCoincide.Get(Clave, Resultado) then
            exit(Resultado);
        FFiltro.Reset();
        FFiltro.DeleteAll();
        FFiltro."No." := Valor;
        FFiltro.Insert(false);
        FFiltro.SetFilter("No.", Filtro);
        Resultado := not FFiltro.IsEmpty();
        FCoincide.Add(Clave, Resultado);
        exit(Resultado);
    end;

    /// <remarks>
    /// Primero la dimensión por defecto del proyecto (la marea o la nómina), después la del
    /// empleado: una dimensión de sede la lleva el proyecto, una de sector el empleado.
    /// </remarks>
    local procedure ValorDimension(CodDimension: Code[20]; Liq: Record "Liquidación"): Code[20]
    var
        DimDefecto: Record "Default Dimension";
        Clave: Text;
        Valor: Code[20];
    begin
        Clave := CodDimension + '|' + Liq."No. Proyecto" + '|' + Liq."No. Empleado";
        if FValorDimension.Get(Clave, Valor) then
            exit(Valor);
        if (Liq."No. Proyecto" <> '') and DimDefecto.Get(Database::Job, Liq."No. Proyecto", CodDimension) then
            Valor := DimDefecto."Dimension Value Code"
        else
            if DimDefecto.Get(Database::Employee, Liq."No. Empleado", CodDimension) then
                Valor := DimDefecto."Dimension Value Code";
        FValorDimension.Add(Clave, Valor);
        exit(Valor);
    end;

    /// <remarks>
    /// A la misma fecha que usa el motor para los atributos (FechaAtributosDeCobertura): el
    /// sindicato con el que se retuvo la cuota es el que tiene que recibirla.
    /// </remarks>
    local procedure ValorAtributo(CodTipoAtributo: Code[20]; Liq: Record "Liquidación"): Code[20]
    var
        Atributo: Record "Atributo Entidad Liq.";
        TipoAtributo: Record "Tipo Atributo Liq.";
        Contexto: Codeunit "Contexto Liquidación";
        TipoEntidad: Enum "Tipo Entidad Estado";
        Clave: Text;
        Valor: Code[20];
        Entidad: Integer;
    begin
        Clave := CodTipoAtributo + '|' + Liq."No.";
        if FValorAtributo.Get(Clave, Valor) then
            exit(Valor);
        if not FEntidadAtributo.Get(CodTipoAtributo, Entidad) then begin
            if TipoAtributo.Get(CodTipoAtributo) then
                Entidad := TipoAtributo."Tipo Entidad".AsInteger();
            FEntidadAtributo.Add(CodTipoAtributo, Entidad);
        end;
        if Entidad = TipoEntidad::Empleado.AsInteger() then
            Valor := Atributo.ValorVigente(CodTipoAtributo, TipoEntidad::Empleado, Liq."No. Empleado",
                Contexto.FechaAtributosDeCobertura(Liq."Cód. Tipo Liq.", TipoEntidad::Empleado, Liq."Fecha Liquidación", Liq."Cobertura Hasta"))
        else
            if (Entidad = TipoEntidad::Proyecto.AsInteger()) and (Liq."No. Proyecto" <> '') then
                Valor := Atributo.ValorVigente(CodTipoAtributo, TipoEntidad::Proyecto, Liq."No. Proyecto", Liq."Fecha Liquidación");
        FValorAtributo.Add(Clave, Valor);
        exit(Valor);
    end;

    /// <summary>
    /// El importe al debe de una cuenta y al haber de la otra; negativo, al revés. Si falta una de
    /// las dos, no entra ninguna: media línea desbalancearía el asiento sin decir por qué.
    /// </summary>
    local procedure ImputarImporte(Liq: Record "Liquidación"; Fila: Record "Regla Asiento Liq."; Importe: Decimal; Etiqueta: Text)
    var
        CuentaDebe: Code[20];
        CuentaHaber: Code[20];
    begin
        CuentaDebe := CuentaDelLado(Liq, Fila, Lado::Debe, Importe);
        CuentaHaber := CuentaDelLado(Liq, Fila, Lado::Haber, Importe);
        if (CuentaDebe = '') or (CuentaHaber = '') then begin
            Avisar('SINCTA|' + Fila."Cód. Concepto", StrSubstNo(AvSinCuenta, Fila."Cód. Concepto"), Importe);
            exit;
        end;
        Sumar(CuentaDebe, Liq, Importe, Etiqueta);
        Sumar(CuentaHaber, Liq, -Importe, Etiqueta);
    end;

    local procedure CuentaDelLado(Liq: Record "Liquidación"; Fila: Record "Regla Asiento Liq."; LadoPedido: Enum "Lado Asiento Liq."; Importe: Decimal): Code[20]
    var
        Valor: Code[20];
        CodCuenta: Code[20];
    begin
        if (Fila."Cód. Atributo Cuenta" <> '') and (Fila."Lado Atributo" = LadoPedido) then begin
            Valor := ValorAtributo(Fila."Cód. Atributo Cuenta", Liq);
            if Valor <> '' then
                CodCuenta := CuentaPorDimension(Fila."Dimensión Cuenta", Valor);
            if CodCuenta <> '' then
                exit(CodCuenta);
            // Sin cuenta fija de respaldo el importe no entra y lo avisa SINCTA, con el mismo
            // importe: avisarlo también acá lo contaría dos veces.
            if FijaDelLado(Fila, LadoPedido) <> '' then
                Avisar('SINATR|' + Fila."Cód. Concepto" + '|' + Valor,
                    StrSubstNo(AvSinCuentaAtributo, Fila."Cód. Concepto", Fila."Cód. Atributo Cuenta", ValorOGuion(Valor)), Importe);
        end;
        exit(FijaDelLado(Fila, LadoPedido));
    end;

    local procedure FijaDelLado(Fila: Record "Regla Asiento Liq."; LadoPedido: Enum "Lado Asiento Liq."): Code[20]
    begin
        if LadoPedido = Lado::Debe then
            exit(Fila."Cuenta Debe");
        exit(Fila."Cuenta Haber");
    end;

    /// <remarks>
    /// Es la relación que ya usaba la interfaz de Meta4 en fntSincronizarSindicatoAPagar: la cuenta
    /// cuyo valor por defecto de la dimensión es el código del sindicato. Allá dos cuentas con el
    /// mismo valor eran un error que frenaba todo; acá se toma la primera y se avisa.
    /// </remarks>
    local procedure CuentaPorDimension(CodDimension: Code[20]; Valor: Code[20]): Code[20]
    var
        DimDefecto: Record "Default Dimension";
        Clave: Text;
        CodCuenta: Code[20];
    begin
        Clave := CodDimension + '|' + Valor;
        if FCuentaPorValor.Get(Clave, CodCuenta) then
            exit(CodCuenta);

        DimDefecto.SetRange("Table ID", Database::"G/L Account");
        DimDefecto.SetRange("Dimension Code", CodDimension);
        DimDefecto.SetRange("Dimension Value Code", Valor);
        if DimDefecto.FindFirst() then begin
            CodCuenta := CopyStr(DimDefecto."No.", 1, MaxStrLen(CodCuenta));
            if DimDefecto.Count() > 1 then
                Avisar('DIMDUP|' + Clave, StrSubstNo(AvDimensionDuplicada, CodDimension, Valor, CodCuenta), 0);
        end;
        FCuentaPorValor.Add(Clave, CodCuenta);
        exit(CodCuenta);
    end;

    local procedure Sumar(CodCuenta: Code[20]; Liq: Record "Liquidación"; ConSigno: Decimal; Etiqueta: Text)
    var
        NoProyecto: Code[20];
        Clave: Text;
        Lista: Text;
    begin
        NoProyecto := ProyectoDeLaCuenta(CodCuenta, Liq);
        Clave := CodCuenta + '|' + NoProyecto;
        if FClaveObjetivo = Clave then
            RegistrarOrigen(ConSigno);
        if FImporteCuenta.ContainsKey(Clave) then
            FImporteCuenta.Set(Clave, FImporteCuenta.Get(Clave) + ConSigno)
        else begin
            FImporteCuenta.Add(Clave, ConSigno);
            FConceptosCuenta.Add(Clave, '');
            FLiqsCuenta.Add(Clave, 0);
        end;

        if not FConceptoCuentaVisto.ContainsKey(Clave + '|' + Etiqueta) then begin
            FConceptoCuentaVisto.Add(Clave + '|' + Etiqueta, true);
            Lista := FConceptosCuenta.Get(Clave);
            if StrLen(Lista) + StrLen(Etiqueta) + 2 <= 245 then begin
                if Lista <> '' then
                    Lista += ', ';
                Lista += Etiqueta;
            end else
                if not Lista.EndsWith('…') then
                    Lista += ' …';
            FConceptosCuenta.Set(Clave, Lista);
        end;

        if not FLiqCuentaVista.ContainsKey(Clave + '|' + Liq."No.") then begin
            FLiqCuentaVista.Add(Clave + '|' + Liq."No.", true);
            FLiqsCuenta.Set(Clave, FLiqsCuenta.Get(Clave) + 1);
        end;
    end;

    /// <remarks>
    /// "Registro por proyectos" es el campo de la cuenta que ya decidía esto en NAV: Sin código no
    /// lleva proyecto, Igual código lleva siempre el de la cuenta, y el resto lleva el de la
    /// liquidación. Las cuentas de pasivo están en Sin código, así que el neto a pagar o la cuota
    /// sindical quedan en una sola línea para todo el mes. La liquidación de DEVENGADOS lleva el
    /// proyecto de la marea en curso, así que su gasto queda en la marea.
    /// </remarks>
    local procedure ProyectoDeLaCuenta(CodCuenta: Code[20]; Liq: Record "Liquidación"): Code[20]
    var
        CuentaGL: Record "G/L Account";
    begin
        if not CuentaGL.Get(CodCuenta) then begin
            Avisar('NOCTA|' + CodCuenta, StrSubstNo(AvCuentaInexistente, CodCuenta), 0);
            exit('');
        end;
        case CuentaGL."Registro por proyectos" of
            CuentaGL."Registro por proyectos"::"Sin código":
                exit('');
            CuentaGL."Registro por proyectos"::"Igual código":
                exit(CopyStr(CuentaGL."No. proyecto", 1, 20));
        end;
        if Liq."No. Proyecto" = '' then
            Avisar('SINPROY|' + CodCuenta, StrSubstNo(AvCuentaSinProyecto, CodCuenta), 0);
        exit(Liq."No. Proyecto");
    end;

    // ── Provisiones ──────────────────────────────────────────────────────────

    local procedure ProcesarProvisiones()
    var
        Regla: Record "Regla Asiento Liq.";
        CodConcepto: Code[20];
    begin
        FHayPeriodoAnterior := HayPeriodoAnteriorAsentable();
        foreach CodConcepto in FProvision.Keys() do
            case FProvision.Get(CodConcepto) of
                Regla.Provisión::Conceptos:
                    ProvisionPorConceptos(CodConcepto);
                Regla.Provisión::Francos:
                    ProvisionDeFrancos(CodConcepto);
            end;
    end;

    /// <remarks>
    /// EL SALDO AL CIERRE DEL PERÍODO ANTERIOR YA ESTÁ ASENTADO si ese período tuvo liquidaciones
    /// que contabilizan. Si no las tuvo, es el primer asiento: lo que ya había (los francos del
    /// saldo inicial al 31/12/2025, desde Meta4) no es gasto del mes. El mes asienta sólo su
    /// movimiento y el stock sale como aviso, para asentarlo una vez contra resultados anteriores.
    /// </remarks>
    local procedure HayPeriodoAnteriorAsentable(): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetFilter("Cód. Período", '<%1', FPeriodo.Código);
        Liq.SetFilter("Cód. Tipo Liq.", FTiposLiq);
        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        exit(not Liq.IsEmpty());
    end;

    /// <remarks>
    /// SE REGISTRA EL DEVENGADO HASTA QUE SE LIQUIDA. Por empleado, período por período: lo que el
    /// concepto devengó queda abierto, y en el período en que un concepto que lo liquida pagó algo
    /// se cierra todo, con el devengado de ese mismo período incluido. Es la regla del usuario para
    /// el SAC, sus cargas y las vacaciones, y lo que hacía Meta4 con PROV_SAC en la liquidación del
    /// aguinaldo y en la final: el gasto queda por lo liquidado.
    ///
    /// SE ASIENTA POR PARTIDA, NO POR EMPLEADO. Si el período no liquida, entra el devengado del
    /// período, cada línea con su liquidación; si liquida, se revierte cada partida abierta con la
    /// liquidación que la originó. Así el devengado de una marea se revierte en esa marea, y el de
    /// la nómina en la nómina: sumarlo por empleado y mandarlo al proyecto de una sola liquidación
    /// cruzaba proyectos.
    /// </remarks>
    local procedure ProvisionPorConceptos(CodConcepto: Code[20])
    var
        Lin: Record "Línea Liquidación";
        Definicion: Record "Regla Asiento Liq.";
        Devengado: Dictionary of [Text, Decimal];
        LineaDelDevengado: Dictionary of [Text, Integer];
        LiqsDelPeriodo: Dictionary of [Text, Text];
        Liquidado: Dictionary of [Text, Boolean];
        PeriodosEmpleado: Dictionary of [Code[20], Text];
        Periodos: List of [Text];
        Abiertos: List of [Text];
        CodPeriodoLinea: Text;
        NoLiq: Text;
        Empleado: Code[20];
        Clave: Text;
        SaldoInicial: Decimal;
        Importe: Decimal;
        TocaElPeriodo: Boolean;
    begin
        FReglas.Reset();
        FReglas.SetRange("Cód. Concepto", CodConcepto);
        FReglas.FindFirst();
        Definicion := FReglas;

        Lin.SetCurrentKey("Cód. Concepto", "No. Empleado", "Fecha Liquidación");
        // Armado a mano y no con %1|%2: un valor sustituido se toma literal, y la lista de los que
        // liquidan trae sus propios |.
        Lin.SetFilter("Cód. Concepto", CodConcepto + '|' + Definicion."Conceptos Consumo");
        Lin.SetFilter("Cód. Período", '..%1', FPeriodo.Código);
        Lin.SetFilter("Cód. Tipo Liq.", FTiposLiq);
        Lin.SetFilter(Estado, FiltroEstados());
        Lin.SetFilter(Importe, '<>0');
        Lin.SetLoadFields("Cód. Concepto", "No. Empleado", "Cód. Período", Importe, Estado, "No. Liquidación");
        if Lin.FindSet() then
            repeat
                // Un borrador sólo cuenta en el período que se está mirando: los anteriores ya se
                // asentaron como quedaron.
                if (Lin.Estado <> Lin.Estado::Borrador) or (Lin."Cód. Período" = FPeriodo.Código) then begin
                    Clave := Lin."No. Empleado" + '|' + Lin."Cód. Período";
                    if Lin."Cód. Concepto" = CodConcepto then begin
                        SumarEn(Devengado, Clave + '|' + Lin."No. Liquidación", Lin.Importe);
                        // La línea que se muestra como origen de la partida (una por liquidación).
                        if not LineaDelDevengado.ContainsKey(Clave + '|' + Lin."No. Liquidación") then
                            LineaDelDevengado.Add(Clave + '|' + Lin."No. Liquidación", Lin."No. Línea");
                        AgregarLiquidacion(LiqsDelPeriodo, Clave, Lin."No. Liquidación");
                    end else
                        if not Liquidado.ContainsKey(Clave) then
                            Liquidado.Add(Clave, true);
                    AgregarPeriodo(PeriodosEmpleado, Lin."No. Empleado", Lin."Cód. Período");
                end;
            until Lin.Next() = 0;

        foreach Empleado in PeriodosEmpleado.Keys() do begin
            Periodos := PeriodosEmpleado.Get(Empleado).Split('|');
            OrdenarTexto(Periodos);
            // Los períodos anteriores con devengado todavía sin liquidar.
            Clear(Abiertos);
            TocaElPeriodo := false;
            foreach CodPeriodoLinea in Periodos do
                if CodPeriodoLinea = FPeriodo.Código then
                    TocaElPeriodo := true
                else
                    if Liquidado.ContainsKey(Empleado + '|' + CodPeriodoLinea) then
                        Clear(Abiertos)
                    else
                        Abiertos.Add(CodPeriodoLinea);

            if not FHayPeriodoAnterior then
                foreach CodPeriodoLinea in Abiertos do
                    SaldoInicial += DevengadoDelPeriodo(Devengado, LiqsDelPeriodo, Empleado + '|' + CodPeriodoLinea);

            if TocaElPeriodo then
                if Liquidado.ContainsKey(Empleado + '|' + FPeriodo.Código) then begin
                    // Se liquidó: se revierte cada partida abierta con su liquidación. Lo devengado
                    // en este mismo período nunca se asentó, así que no hay nada que revertir.
                    foreach CodPeriodoLinea in Abiertos do
                        foreach NoLiq in ListaDeLiquidaciones(LiqsDelPeriodo, Empleado + '|' + CodPeriodoLinea) do begin
                            Clave := Empleado + '|' + CodPeriodoLinea + '|' + NoLiq;
                            Importe := ImporteEn(Devengado, Clave);
                            if Importe <> 0 then
                                ImputarProvision(CodConcepto, CopyStr(NoLiq, 1, 20), -Importe, LineaDelDevengado.Get(Clave),
                                    TxtOrigenReversion, StrSubstNo(TxtDetalleReversion, CodPeriodoLinea));
                        end;
                end else
                    foreach NoLiq in ListaDeLiquidaciones(LiqsDelPeriodo, Empleado + '|' + FPeriodo.Código) do begin
                        Clave := Empleado + '|' + FPeriodo.Código + '|' + NoLiq;
                        Importe := ImporteEn(Devengado, Clave);
                        if Importe <> 0 then
                            ImputarProvision(CodConcepto, CopyStr(NoLiq, 1, 20), Importe, LineaDelDevengado.Get(Clave), TxtOrigenDevengado, '');
                    end;
        end;
        if SaldoInicial <> 0 then
            Avisar('PROVINI|' + CodConcepto, StrSubstNo(AvSaldoInicialProvision, CodConcepto), SaldoInicial);
    end;

    local procedure AgregarLiquidacion(var LiqsDelPeriodo: Dictionary of [Text, Text]; Clave: Text; NoLiq: Code[20])
    var
        Lista: Text;
    begin
        if not LiqsDelPeriodo.Get(Clave, Lista) then begin
            LiqsDelPeriodo.Add(Clave, NoLiq);
            exit;
        end;
        if not ('|' + Lista + '|').Contains('|' + NoLiq + '|') then
            LiqsDelPeriodo.Set(Clave, Lista + '|' + NoLiq);
    end;

    local procedure ListaDeLiquidaciones(var LiqsDelPeriodo: Dictionary of [Text, Text]; Clave: Text): List of [Text]
    var
        Lista: Text;
        Vacia: List of [Text];
    begin
        if LiqsDelPeriodo.Get(Clave, Lista) then
            exit(Lista.Split('|'));
        exit(Vacia);
    end;

    local procedure DevengadoDelPeriodo(var Devengado: Dictionary of [Text, Decimal]; var LiqsDelPeriodo: Dictionary of [Text, Text]; Clave: Text): Decimal
    var
        NoLiq: Text;
        Total: Decimal;
    begin
        foreach NoLiq in ListaDeLiquidaciones(LiqsDelPeriodo, Clave) do
            Total += ImporteEn(Devengado, Clave + '|' + NoLiq);
        exit(Total);
    end;

    /// <remarks>
    /// LOS FRANCOS SE REVIERTEN POR LOTE. Cada lote de la cuenta corriente es el devengado de una
    /// liquidación (un cierre de marea, un devengado de la marea en curso) y se registra a lo que
    /// valía ese día. Cuando una liquidación consume días de un lote, el saldo del lote baja y la
    /// provisión se revierte por esos días a ese valor; lo liquidado queda en el gasto. Un lote no
    /// se revaloriza: lo que cambió el precio entre el devengado y el pago queda en el gasto.
    ///
    /// EL VALOR ES EL DEL 1063, POR LA TERNA DEL LOTE: Gestión Francos.ValuarMatriz resuelve
    /// VALOR_FRANCO con la pesquería del buque del lote, el par de la liquidación que lo originó y la
    /// fecha del lote (con las cotizaciones de esa fecha, porque el de oficiales está en dólares), y
    /// se multiplica por el COEF_PESQUERIA de esa misma liquidación, como hace el 1063. Es lo que
    /// pagaría el 1063 si el franco se liquidara donde se devengó. Antes se tomaba el
    /// VALOR_FRANCO_DIA guardado en la liquidación, que sólo se guarda donde algo lo usa: después de
    /// recalcular enero quedaron 56 días sin valor.
    ///
    /// Se cuentan los lotes de la fase vigente a la fecha, como hace la cuenta corriente: la baja
    /// paga el saldo con el 2803, que no consume lotes, así que después de la baja el saldo es cero.
    ///
    /// No se usa FRANCO_DEVENG: multiplica por VALOR_FRANCO, que es mensual (el 1063 lo divide por
    /// 30), y da unas treinta veces de más.
    /// </remarks>
    local procedure ProvisionDeFrancos(CodConcepto: Code[20])
    var
        Mov: Record "Movimiento Franco Liq.";
        LoteEmpleado: Dictionary of [Integer, Code[20]];
        LoteFecha: Dictionary of [Integer, Date];
        LoteLiq: Dictionary of [Integer, Code[20]];
        LoteLinea: Dictionary of [Integer, Integer];
        LoteProyecto: Dictionary of [Integer, Code[20]];
        LoteConvenio: Dictionary of [Integer, Code[20]];
        LoteCategoria: Dictionary of [Integer, Code[20]];
        DiasAhora: Dictionary of [Integer, Decimal];
        DiasAntes: Dictionary of [Integer, Decimal];
        LotesPorFecha: Dictionary of [Text, Text];
        Fechas: List of [Text];
        TextoFecha: Text;
        TextoLote: Text;
        FechaLote: Date;
        Lote: Integer;
        LineaOrigen: Integer;
        Empleado: Code[20];
        NoLiq: Code[20];
        Detalle: Text;
        FechaAnterior: Date;
        Ahora: Decimal;
        Antes: Decimal;
        Valor: Decimal;
        Importe: Decimal;
        SaldoInicial: Decimal;
        DiasSinValor: Decimal;
    begin
        FechaAnterior := FPeriodo."Fecha Desde" - 1;
        Mov.SetCurrentKey("No. Empleado", Tipo, "Fecha Devengamiento", "No. Movimiento");
        Mov.SetRange("Fecha Devengamiento", 0D, FPeriodo."Fecha Hasta");
        Mov.SetLoadFields("No. Empleado", "No. Lote", Tipo, Cantidad, "Fecha Devengamiento", "No. Liquidación", "No. Línea Origen",
            "No. Proyecto", "Cód. Convenio", "Cód. Categoría");
        if Mov.FindSet() then
            repeat
                // El lote es el movimiento de devengo; consumos y reversiones lo nombran en No. Lote.
                if Mov.Tipo = Mov.Tipo::Devengo then
                    if not LoteEmpleado.ContainsKey(Mov."No. Movimiento") then begin
                        LoteEmpleado.Add(Mov."No. Movimiento", Mov."No. Empleado");
                        LoteFecha.Add(Mov."No. Movimiento", Mov."Fecha Devengamiento");
                        LoteLiq.Add(Mov."No. Movimiento", Mov."No. Liquidación");
                        LoteLinea.Add(Mov."No. Movimiento", Mov."No. Línea Origen");
                        LoteProyecto.Add(Mov."No. Movimiento", Mov."No. Proyecto");
                        LoteConvenio.Add(Mov."No. Movimiento", Mov."Cód. Convenio");
                        LoteCategoria.Add(Mov."No. Movimiento", Mov."Cód. Categoría");
                    end;
                if Mov."No. Lote" <> 0 then begin
                    SumarEnLote(DiasAhora, Mov."No. Lote", Mov.Cantidad);
                    if Mov."Fecha Devengamiento" <= FechaAnterior then
                        SumarEnLote(DiasAntes, Mov."No. Lote", Mov.Cantidad);
                end;
            until Mov.Next() = 0;

        // Los lotes que se mueven, agrupados por fecha: las cotizaciones del franco se le prestan al
        // ledger una vez por fecha y no una vez por lote.
        foreach Lote in LoteEmpleado.Keys() do
            if (DiasVigentes(DiasAhora, Lote, LoteEmpleado.Get(Lote), LoteFecha.Get(Lote), FPeriodo."Fecha Hasta") > 0) or
               (DiasVigentes(DiasAntes, Lote, LoteEmpleado.Get(Lote), LoteFecha.Get(Lote), FechaAnterior) > 0)
            then
                AgregarLoteAFecha(LotesPorFecha, Format(LoteFecha.Get(Lote), 0, 9), Lote);
        Fechas := LotesPorFecha.Keys();
        OrdenarTexto(Fechas);

        // CADA LOTE SE ASIENTA CON SU LIQUIDACIÓN DE ORIGEN: el devengado de una marea se registra
        // y se revierte en esa marea. Si el origen ya no existe o es de un tipo que no contabiliza
        // (los lotes del saldo inicial), con la última liquidación del empleado.
        foreach TextoFecha in Fechas do begin
            Evaluate(FechaLote, TextoFecha, 9);
            foreach TextoLote in LotesPorFecha.Get(TextoFecha).Split('|') do begin
                Evaluate(Lote, TextoLote);
                Empleado := LoteEmpleado.Get(Lote);
                Ahora := DiasVigentes(DiasAhora, Lote, Empleado, FechaLote, FPeriodo."Fecha Hasta");
                Antes := DiasVigentes(DiasAntes, Lote, Empleado, FechaLote, FechaAnterior);
                Valor := ValorDelLote(Empleado, LoteLiq.Get(Lote), FechaLote, LoteProyecto.Get(Lote), LoteConvenio.Get(Lote), LoteCategoria.Get(Lote));
                if Valor = 0 then
                    DiasSinValor += Ahora
                else begin
                    if not FHayPeriodoAnterior then
                        SaldoInicial += Antes * Valor;
                    Importe := (Ahora - Antes) * Valor;
                    if Importe <> 0 then begin
                        NoLiq := LoteLiq.Get(Lote);
                        LineaOrigen := LoteLinea.Get(Lote);
                        if not LiquidacionQueContabiliza(NoLiq) then begin
                            NoLiq := UltimaLiquidacion(Empleado, FPeriodo."Fecha Hasta");
                            LineaOrigen := 0;
                        end;
                        Detalle := StrSubstNo(TxtDetalleLote, Lote, Antes, Ahora, Round(Valor, 0.01));
                        if NoLiq = '' then begin
                            LimpiarOrigen();
                            FCtxDetalle := CopyStr(Detalle, 1, MaxStrLen(FCtxDetalle));
                            Avisar('FRSINLIQ|' + CodConcepto, StrSubstNo(AvFrancoSinLiquidacion, CodConcepto), Importe);
                        end else
                            ImputarProvision(CodConcepto, NoLiq, Importe, LineaOrigen, TxtOrigenLote, Detalle);
                    end;
                end;
            end;
        end;
        if SaldoInicial <> 0 then
            Avisar('PROVINI|' + CodConcepto, StrSubstNo(AvSaldoInicialProvision, CodConcepto), SaldoInicial);
        if DiasSinValor <> 0 then
            Avisar('FRSINVALOR|' + CodConcepto, StrSubstNo(AvFrancoSinValor, CodConcepto, DiasSinValor, FUltimoErrorPrecio), 0);
        // Reabrir una liquidación revierte sus movimientos de la cuenta corriente, así que en
        // Borrador su consumo de días no está: su 1063 entra al gasto pero la provisión no se
        // revierte. Se dice en vez de simularlo.
        if FIncluirBorradores and HayBorradoresEnElPeriodo() then
            Avisar('FRBORRADOR|' + CodConcepto, StrSubstNo(AvFrancoBorrador, CodConcepto), 0);
    end;

    // Los días del lote a la fecha, si el lote es de la fase vigente; si no, cero.
    local procedure DiasVigentes(var Dias: Dictionary of [Integer, Decimal]; Lote: Integer; Empleado: Code[20]; FechaLote: Date; Fecha: Date): Decimal
    begin
        if not LoteDeLaFase(Empleado, FechaLote, Fecha) then
            exit(0);
        exit(DiasDelLote(Dias, Lote));
    end;

    local procedure AgregarLoteAFecha(var LotesPorFecha: Dictionary of [Text, Text]; Clave: Text; Lote: Integer)
    var
        Lista: Text;
    begin
        if LotesPorFecha.Get(Clave, Lista) then
            LotesPorFecha.Set(Clave, Lista + '|' + Format(Lote))
        else
            LotesPorFecha.Add(Clave, Format(Lote));
    end;

    /// <summary>
    /// Si el lote es de la fase del empleado vigente a la fecha. Sin fase vigente ningún lote
    /// cuenta, y la fase termina el día de la baja: con una baja el último día del mes, la final de
    /// ese mes ya pagó el saldo con el 2803 y la provisión se revierte en ese mismo mes.
    /// </summary>
    local procedure LoteDeLaFase(Empleado: Code[20]; FechaLote: Date; Fecha: Date): Boolean
    var
        Fase: Record "Fase Alta Empleado";
        Clave: Text;
        Alta: Date;
    begin
        Clave := Empleado + '|' + Format(Fecha, 0, 9);
        if not FAltaVigente.Get(Clave, Alta) then begin
            Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
            Fase.SetRange("No. Empleado", Empleado);
            Fase.SetRange("Fecha Alta", 0D, Fecha);
            Alta := 0D;
            if Fase.FindLast() then
                if (Fase."Fecha Baja" = 0D) or (Fase."Fecha Baja" > Fecha) then
                    Alta := Fase."Fecha Alta";
            FAltaVigente.Add(Clave, Alta);
        end;
        exit((Alta <> 0D) and (FechaLote >= Alta));
    end;

    /// <remarks>
    /// Una instancia de Gestión Francos nace sin cotizaciones y el precio de los oficiales está en
    /// dólares: se le prestan las de la fecha, como hacen Francos por Tripulante y Lotes de Franco
    /// Consumidos (lección tc-del-franco-ventana-de-una-linea). La moneda la dice el ledger.
    /// </remarks>
    local procedure PublicarCotizacionesFranco(Fecha: Date)
    var
        CtxBuilder: Codeunit "Contexto Liquidación";
        TiposCambio: Dictionary of [Text, Decimal];
    begin
        if (FFechaCotizacion = Fecha) and (Fecha <> 0D) then
            exit;
        CtxBuilder.TiposCambioFrancosAFecha('', Fecha, FFrancos.MonedaDelPrecio(Fecha), TiposCambio);
        FFrancos.PublicarTiposCambio(TiposCambio);
        FFechaCotizacion := Fecha;
    end;

    /// <summary>
    /// El valor por día con que se devengó el lote: VALOR_FRANCO por la terna del lote (lo que
    /// resuelve Gestión Francos.ValuarMatriz, con el par de la liquidación que lo originó) por el
    /// COEF_PESQUERIA de esa liquidación. Cero si no hay precio para la terna.
    /// </summary>
    /// <remarks>
    /// SI LA TERNA NO TIENE PRECIO A LA FECHA DEL LOTE, la de la primera liquidación del empleado
    /// después del lote. Es el caso del saldo inicial: los lotes son del 31/12/2025 y los precios de
    /// BC arrancan el 1/1/2026, así que a su fecha ninguno vale nada; el primer momento en que BC
    /// valuó esos francos es su primera liquidación. La fecha no depende del período que se mira,
    /// así que el lote vale lo mismo al cierre anterior y a este, y la variación es sólo de días.
    /// </remarks>
    local procedure ValorDelLote(Empleado: Code[20]; NoLiqOrigen: Code[20]; FechaLote: Date; NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20]): Decimal
    var
        Liq: Record "Liquidación";
        Clave: Text;
        Documento: Code[20];
        DocumentoPosterior: Code[20];
        FechaPosterior: Date;
        Valor: Decimal;
    begin
        Clave := StrSubstNo('%1|%2|%3|%4|%5|%6', Empleado, NoLiqOrigen, Format(FechaLote, 0, 9), NoProyecto, Convenio, Categoria);
        if FValorLote.Get(Clave, Valor) then
            exit(Valor);

        // El par que paga es el de la liquidación de origen si existe (como en el 1063, que usa el
        // de la liquidación que paga); si ya no está, el del lote.
        Liq.SetLoadFields("No.");
        if (NoLiqOrigen <> '') and Liq.Get(NoLiqOrigen) then
            Documento := NoLiqOrigen;
        if not PrecioDelLote(Empleado, NoLiqOrigen, Documento, FechaLote, FechaLote, NoProyecto, Convenio, Categoria, Valor) then begin
            // Con la fecha, también el par de esa liquidación, como el 1063 toma el de la que paga:
            // dos lotes del saldo inicial traen un par que no existe (175/75 OF01, 768/19 OF02; la
            // categoría OF decide el convenio) y por el par del lote no tendrían precio nunca.
            DocumentoPosterior := PrimeraLiquidacionDespues(Empleado, FechaLote, FechaPosterior);
            if (DocumentoPosterior = '') or
               not PrecioDelLote(Empleado, NoLiqOrigen, DocumentoPosterior, FechaLote, FechaPosterior, NoProyecto, Convenio, Categoria, Valor)
            then
                // Un lote sin precio no corta la previa (el cálculo sí corta: ahí el cero se paga).
                Valor := 0;
        end;
        if Valor <> 0 then
            Valor := Valor * CoefPesqueriaDelLote(Empleado, Documento, FechaLote);
        FValorLote.Add(Clave, Valor);
        exit(Valor);
    end;

    // El precio por día de un franco del lote a FechaPrecio, con las cotizaciones de esa fecha.
    local procedure PrecioDelLote(Empleado: Code[20]; NoLiqOrigen: Code[20]; Documento: Code[20]; FechaLote: Date; FechaPrecio: Date; NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Precio: Decimal): Boolean
    var
        Filas: Record "Lote Franco Buffer Liq." temporary;
    begin
        Precio := 0;
        PublicarCotizacionesFranco(FechaPrecio);
        Filas.Init();
        Filas."No. Línea" := 1;
        Filas."No. Empleado" := Empleado;
        Filas."No. Liquidación Origen" := NoLiqOrigen;
        Filas."Fecha Lote" := FechaLote;
        Filas."No. Proyecto" := NoProyecto;
        Filas."Cód. Convenio" := Convenio;
        Filas."Cód. Categoría" := Categoria;
        Filas."Días Tomados" := 1;
        Filas.Insert();
        if not TryValuarLote(Filas, Documento, FechaPrecio) then begin
            FUltimoErrorPrecio := CopyStr(GetLastErrorText(), 1, MaxStrLen(FUltimoErrorPrecio));
            exit(false);
        end;
        Filas.FindFirst();
        Precio := Filas."Valor Franco";
        exit(Precio <> 0);
    end;

    [TryFunction]
    local procedure TryValuarLote(var Filas: Record "Lote Franco Buffer Liq." temporary; Documento: Code[20]; Fecha: Date)
    begin
        FFrancos.ValuarMatriz(Filas, Documento, Fecha);
    end;

    // La primera liquidación del empleado posterior a la fecha (la de menor fecha y, a igual
    // fecha, menor número): devuelve su número y su fecha.
    local procedure PrimeraLiquidacionDespues(Empleado: Code[20]; Fecha: Date; var FechaPrimera: Date): Code[20]
    var
        Liq: Record "Liquidación";
        Primera: Code[20];
    begin
        FechaPrimera := 0D;
        Liq.SetCurrentKey("Cód. Período", "No. Empleado");
        Liq.SetRange("No. Empleado", Empleado);
        Liq.SetFilter("Fecha Liquidación", '>%1', Fecha);
        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        Liq.SetLoadFields("No.", "Fecha Liquidación");
        if Liq.FindSet() then
            repeat
                if (FechaPrimera = 0D) or (Liq."Fecha Liquidación" < FechaPrimera) or
                   ((Liq."Fecha Liquidación" = FechaPrimera) and (Liq."No." < Primera))
                then begin
                    FechaPrimera := Liq."Fecha Liquidación";
                    Primera := Liq."No.";
                end;
            until Liq.Next() = 0;
        exit(Primera);
    end;

    /// <summary>
    /// El COEF_PESQUERIA con que el 1063 multiplica el valor: el de la liquidación de origen y, si
    /// ya no está (o es un saldo inicial, que no lo calcula), el de la última liquidación del
    /// empleado hasta la fecha del lote o la primera después. Uno si no hay ninguna.
    /// </summary>
    local procedure CoefPesqueriaDelLote(Empleado: Code[20]; NoLiqOrigen: Code[20]; FechaLote: Date): Decimal
    var
        Liq: Record "Liquidación";
        Coeficiente: Decimal;
    begin
        if CoefDeLiquidacion(NoLiqOrigen, Coeficiente) then
            exit(Coeficiente);
        Liq.SetCurrentKey("Cód. Período", "No. Empleado");
        Liq.SetRange("No. Empleado", Empleado);
        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        Liq.SetLoadFields("No.");
        Liq.SetRange("Fecha Liquidación", 0D, FechaLote);
        Liq.Ascending(false);
        if Liq.FindSet() then
            repeat
                if CoefDeLiquidacion(Liq."No.", Coeficiente) then
                    exit(Coeficiente);
            until Liq.Next() = 0;
        Liq.SetFilter("Fecha Liquidación", '>%1', FechaLote);
        Liq.Ascending(true);
        if Liq.FindSet() then
            repeat
                if CoefDeLiquidacion(Liq."No.", Coeficiente) then
                    exit(Coeficiente);
            until Liq.Next() = 0;
        exit(1);
    end;

    local procedure CoefDeLiquidacion(NoLiq: Code[20]; var Coeficiente: Decimal): Boolean
    var
        Lin: Record "Línea Liquidación";
    begin
        if NoLiq = '' then
            exit(false);
        if FCoefLiq.Get(NoLiq, Coeficiente) then
            exit(Coeficiente <> 0);
        Lin.SetRange("No. Liquidación", NoLiq);
        Lin.SetRange("Cód. Concepto", ConceptoCoefPesqueriaTok);
        Lin.SetLoadFields(Importe);
        Coeficiente := 0;
        if Lin.FindFirst() then
            Coeficiente := Lin.Importe;
        FCoefLiq.Add(NoLiq, Coeficiente);
        exit(Coeficiente <> 0);
    end;

    local procedure LiquidacionQueContabiliza(NoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
    begin
        if NoLiq = '' then
            exit(false);
        Liq.SetLoadFields("Cód. Tipo Liq.");
        if not Liq.Get(NoLiq) then
            exit(false);
        exit(TipoContabiliza(Liq."Cód. Tipo Liq."));
    end;

    local procedure HayBorradoresEnElPeriodo(): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("Cód. Período", FPeriodo.Código);
        Liq.SetFilter("Cód. Tipo Liq.", FTiposLiq);
        Liq.SetRange(Estado, Liq.Estado::Borrador);
        exit(not Liq.IsEmpty());
    end;

    /// <summary>
    /// La última liquidación del empleado hasta la fecha, de los tipos que contabilizan: da el
    /// proyecto y las reglas de la variación de su provisión.
    /// </summary>
    local procedure UltimaLiquidacion(Empleado: Code[20]; Fecha: Date): Code[20]
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetCurrentKey("Cód. Período", "No. Empleado");
        Liq.SetRange("No. Empleado", Empleado);
        Liq.SetRange("Fecha Liquidación", 0D, Fecha);
        Liq.SetFilter("Cód. Tipo Liq.", FTiposLiq);
        Liq.SetFilter(Estado, FiltroEstados());
        Liq.SetLoadFields("No.");
        if Liq.FindLast() then
            exit(Liq."No.");
        exit('');
    end;

    local procedure SumarEnLote(var Dias: Dictionary of [Integer, Decimal]; Lote: Integer; Cantidad: Decimal)
    begin
        if Dias.ContainsKey(Lote) then
            Dias.Set(Lote, Dias.Get(Lote) + Cantidad)
        else
            Dias.Add(Lote, Cantidad);
    end;

    // Un lote no queda negativo: si los movimientos de una fecha dejaran consumido más de lo
    // devengado, es un problema de la cuenta corriente y no una provisión negativa.
    local procedure DiasDelLote(var Dias: Dictionary of [Integer, Decimal]; Lote: Integer): Decimal
    var
        Cantidad: Decimal;
    begin
        if Dias.Get(Lote, Cantidad) then
            if Cantidad > 0 then
                exit(Cantidad);
        exit(0);
    end;

    /// <summary>
    /// Asienta una partida de provisión con la liquidación que la originó. NoLinea, Origen y
    /// Detalle sólo describen la partida para el drilldown de la previa.
    /// </summary>
    local procedure ImputarProvision(CodConcepto: Code[20]; NoLiq: Code[20]; Importe: Decimal; NoLinea: Integer; Origen: Text; Detalle: Text)
    var
        Liq: Record "Liquidación";
        Fila: Record "Regla Asiento Liq.";
        Ambigua: Boolean;
    begin
        Liq.Get(NoLiq);
        FijarOrigen(Liq, NoLinea, CodConcepto, TxtProvision, Origen, Detalle);
        if not ResolverRegla(CodConcepto, Liq, Importe, Fila, Ambigua) then begin
            if not Ambigua then
                Avisar('SINREGLA|' + CodConcepto, StrSubstNo(AvSinRegla, CodConcepto, TxtProvision), Importe);
            exit;
        end;
        if not Fila."No Contabiliza" then
            ImputarImporte(Liq, Fila, Importe, 'PROV:' + CodConcepto);
    end;

    local procedure SumarEn(var Importes: Dictionary of [Text, Decimal]; Clave: Text; Importe: Decimal)
    begin
        if Importes.ContainsKey(Clave) then
            Importes.Set(Clave, Importes.Get(Clave) + Importe)
        else
            Importes.Add(Clave, Importe);
    end;

    local procedure ImporteEn(var Importes: Dictionary of [Text, Decimal]; Clave: Text): Decimal
    var
        Importe: Decimal;
    begin
        if Importes.Get(Clave, Importe) then
            exit(Importe);
        exit(0);
    end;

    local procedure AgregarPeriodo(var PeriodosEmpleado: Dictionary of [Code[20], Text]; Empleado: Code[20]; CodPeriodo: Code[10])
    var
        Lista: Text;
    begin
        if not PeriodosEmpleado.Get(Empleado, Lista) then begin
            PeriodosEmpleado.Add(Empleado, CodPeriodo);
            exit;
        end;
        if not ('|' + Lista + '|').Contains('|' + CodPeriodo + '|') then
            PeriodosEmpleado.Set(Empleado, Lista + '|' + CodPeriodo);
    end;

    // ── Salida ───────────────────────────────────────────────────────────────

    local procedure EscribirBuffer(var Buffer: Record "Línea Asiento Buffer Liq." temporary)
    var
        CuentaGL: Record "G/L Account";
        Claves: List of [Text];
        Clave: Text;
        Partes: List of [Text];
        Importe: Decimal;
        Linea: Integer;
    begin
        // Las claves ordenadas dejan las cuentas en el orden del plan y, dentro de cada cuenta,
        // los proyectos en orden: es como se lee un mayor.
        Claves := FImporteCuenta.Keys();
        OrdenarTexto(Claves);
        foreach Clave in Claves do begin
            Importe := Round(FImporteCuenta.Get(Clave), 0.01);
            if Importe <> 0 then begin
                Partes := Clave.Split('|');
                Linea += 1;
                Buffer.Init();
                Buffer."No. Línea" := Linea;
                Buffer.Clase := Buffer.Clase::Cuenta;
                Buffer.Cuenta := CopyStr(Partes.Get(1), 1, MaxStrLen(Buffer.Cuenta));
                Buffer."No. Proyecto" := CopyStr(Partes.Get(2), 1, MaxStrLen(Buffer."No. Proyecto"));
                if CuentaGL.Get(Buffer.Cuenta) then
                    Buffer."Nombre Cuenta" := CuentaGL.Name;
                Buffer.Conceptos := CopyStr(FConceptosCuenta.Get(Clave), 1, MaxStrLen(Buffer.Conceptos));
                Buffer.Cantidad := FLiqsCuenta.Get(Clave);
                Buffer."Clave Origen" := CopyStr(Clave, 1, MaxStrLen(Buffer."Clave Origen"));
                AsignarImporte(Buffer, Importe);
                Buffer.Insert();
                FResiduo += Importe;
            end;
        end;

        // EL REDONDEO VA A LA CUENTA DE NAV (Config. contabilidad, CuentaRedondeo) y con el
        // proyecto de ajustes, como hacía fntConsolidarDiario. Cada línea entra por los dos lados,
        // así que lo único que queda es el redondeo a centavos de cada cuenta; más de un peso es
        // un aviso.
        if FResiduo <> 0 then begin
            Linea += 1;
            Buffer.Init();
            Buffer."No. Línea" := Linea;
            Buffer.Clase := Buffer.Clase::Redondeo;
            Buffer.Cuenta := GLSetup.CuentaRedondeo;
            if CuentaGL.Get(Buffer.Cuenta) then
                Buffer."Nombre Cuenta" := CuentaGL.Name;
            Buffer."No. Proyecto" := GLSetup."No. proyecto ajustes";
            AsignarImporte(Buffer, -FResiduo);
            if Abs(FResiduo) > ToleranciaRedondeo() then
                Buffer.Mensaje := StrSubstNo(AvRedondeoGrande, FResiduo);
            Buffer.Insert();
            if Abs(FResiduo) > ToleranciaRedondeo() then
                FAvisos += 1;
        end;

        Claves := FAvisoTexto.Keys();
        OrdenarTexto(Claves);
        foreach Clave in Claves do begin
            Linea += 1;
            Buffer.Init();
            Buffer."No. Línea" := Linea;
            Buffer.Clase := Buffer.Clase::Aviso;
            Buffer.Mensaje := CopyStr(FAvisoTexto.Get(Clave), 1, MaxStrLen(Buffer.Mensaje));
            Buffer.Cantidad := FAvisoCant.Get(Clave);
            Buffer.Importe := Round(FAvisoImporte.Get(Clave), 0.01);
            Buffer."Clave Origen" := CopyStr(Clave, 1, MaxStrLen(Buffer."Clave Origen"));
            Buffer.Insert();
            FAvisos += 1;
        end;
    end;

    local procedure AsignarImporte(var Buffer: Record "Línea Asiento Buffer Liq." temporary; Importe: Decimal)
    begin
        Buffer.Importe := Importe;
        if Importe > 0 then begin
            Buffer.Debe := Importe;
            FTotalDebe += Importe;
        end else begin
            Buffer.Haber := -Importe;
            FTotalHaber += -Importe;
        end;
    end;

    local procedure Avisar(Clave: Text; Texto: Text; Importe: Decimal)
    begin
        // Un aviso que viene de una liquidación (sin regla, sin cuenta, sin proyecto…) también
        // tiene origen: la liquidación y la línea que lo dispararon.
        if FClaveObjetivo = Clave then
            if (FCtxLiq."No." <> '') or (FCtxDetalle <> '') then
                RegistrarOrigen(Importe);
        if FAvisoTexto.ContainsKey(Clave) then begin
            FAvisoCant.Set(Clave, FAvisoCant.Get(Clave) + 1);
            FAvisoImporte.Set(Clave, FAvisoImporte.Get(Clave) + Importe);
        end else begin
            FAvisoTexto.Add(Clave, Texto);
            FAvisoCant.Add(Clave, 1);
            FAvisoImporte.Add(Clave, Importe);
        end;
    end;

    // ── Origen (drilldown) ───────────────────────────────────────────────────

    /// <summary>
    /// Lo que se está imputando en este momento: la liquidación, la línea y qué clase de origen es.
    /// Lo leen Sumar y Avisar cuando se piden los orígenes de una clave.
    /// </summary>
    local procedure FijarOrigen(Liq: Record "Liquidación"; NoLinea: Integer; CodConcepto: Code[20]; Descripcion: Text; Origen: Text; Detalle: Text)
    begin
        FCtxLiq := Liq;
        FCtxNoLinea := NoLinea;
        FCtxConcepto := CodConcepto;
        FCtxDescripcion := CopyStr(Descripcion, 1, MaxStrLen(FCtxDescripcion));
        FCtxOrigen := CopyStr(Origen, 1, MaxStrLen(FCtxOrigen));
        FCtxDetalle := CopyStr(Detalle, 1, MaxStrLen(FCtxDetalle));
    end;

    local procedure LimpiarOrigen()
    var
        Ninguna: Record "Liquidación";
    begin
        FijarOrigen(Ninguna, 0, '', '', '', '');
    end;

    // Sin AsignarImporte: los orígenes no son líneas del asiento y no suman a los totales.
    local procedure RegistrarOrigen(Importe: Decimal)
    begin
        FSecOrigen += 1;
        FOrigenes.Init();
        FOrigenes."No. Línea" := FSecOrigen;
        FOrigenes.Clase := FOrigenes.Clase::Origen;
        FOrigenes."No. Liquidación" := FCtxLiq."No.";
        FOrigenes."No. Empleado" := FCtxLiq."No. Empleado";
        FOrigenes."Cód. Tipo Liq." := FCtxLiq."Cód. Tipo Liq.";
        FOrigenes."No. Proyecto" := FCtxLiq."No. Proyecto";
        FOrigenes."No. Línea Liq." := FCtxNoLinea;
        FOrigenes."Cód. Concepto" := FCtxConcepto;
        FOrigenes."Descripción Concepto" := FCtxDescripcion;
        FOrigenes.Origen := FCtxOrigen;
        FOrigenes.Mensaje := FCtxDetalle;
        FOrigenes.Importe := Importe;
        if Importe > 0 then
            FOrigenes.Debe := Importe
        else
            FOrigenes.Haber := -Importe;
        FOrigenes.Insert();
    end;

    // List of [Text] no tiene Sort() en AL (ver la lección orden-calculo-del-lote): inserción
    // directa, que alcanza para unos cientos de claves. EL WHILE ESTÁ PARTIDO A PROPÓSITO, como en
    // OrdenarClaves de Lotes Liquidación Liq.: `while (j >= 1) and (Lista.Get(j) > Actual)`
    // compila, pero AL no cortocircuita y con j = 0 evalúa Get(0), que revienta en ejecución.
    local procedure OrdenarTexto(var Lista: List of [Text])
    var
        i: Integer;
        j: Integer;
        Actual: Text;
    begin
        for i := 2 to Lista.Count() do begin
            Actual := Lista.Get(i);
            j := i - 1;
            while j >= 1 do begin
                if Lista.Get(j) <= Actual then
                    break;
                Lista.Set(j + 1, Lista.Get(j));
                j -= 1;
            end;
            Lista.Set(j + 1, Actual);
        end;
    end;

    local procedure ToleranciaRedondeo(): Decimal
    begin
        exit(1);
    end;

    local procedure ValorOGuion(Valor: Code[20]): Text
    begin
        if Valor = '' then
            exit(TxtSinValor);
        exit(Valor);
    end;

    var
        GLSetup: Record "General Ledger Setup";
        FPeriodo: Record "Período Liquidación";
        FReglas: Record "Regla Asiento Liq." temporary;
        FFiltro: Record Job temporary;
        Lado: Enum "Lado Asiento Liq.";
        FEsAcumulador: Dictionary of [Code[20], Boolean];
        FProvision: Dictionary of [Code[20], Integer];
        FImporteCuenta: Dictionary of [Text, Decimal];
        FConceptosCuenta: Dictionary of [Text, Text];
        FConceptoCuentaVisto: Dictionary of [Text, Boolean];
        FLiqsCuenta: Dictionary of [Text, Integer];
        FLiqCuentaVista: Dictionary of [Text, Boolean];
        FCuentaPorValor: Dictionary of [Text, Code[20]];
        FCoincide: Dictionary of [Text, Boolean];
        FValorAtributo: Dictionary of [Text, Code[20]];
        FValorDimension: Dictionary of [Text, Code[20]];
        FEntidadAtributo: Dictionary of [Code[20], Integer];
        FTipoContabiliza: Dictionary of [Code[20], Boolean];
        FAltaVigente: Dictionary of [Text, Date];
        FValorLote: Dictionary of [Text, Decimal];
        FCoefLiq: Dictionary of [Code[20], Decimal];
        FFrancos: Codeunit "Gestión Francos";
        FFechaCotizacion: Date;
        FUltimoErrorPrecio: Text[250];
        FHayPeriodoAnterior: Boolean;
        FOrigenes: Record "Línea Asiento Buffer Liq." temporary;
        FCtxLiq: Record "Liquidación";
        FClaveObjetivo: Text;
        FSecOrigen: Integer;
        FCtxNoLinea: Integer;
        FCtxConcepto: Code[20];
        FCtxDescripcion: Text[100];
        FCtxOrigen: Text[30];
        FCtxDetalle: Text[250];
        FAvisoTexto: Dictionary of [Text, Text];
        FAvisoCant: Dictionary of [Text, Integer];
        FAvisoImporte: Dictionary of [Text, Decimal];
        FTiposLiq: Text;
        FIncluirBorradores: Boolean;
        FLiquidaciones: Integer;
        FAvisos: Integer;
        FTotalDebe: Decimal;
        FTotalHaber: Decimal;
        FResiduo: Decimal;
        ConceptoCoefPesqueriaTok: Label 'COEF_PESQUERIA', Locked = true;
        ErrSinPeriodo: Label 'Elegí el período del asiento.';
        ErrPeriodoInexistente: Label 'El período %1 no existe.', Comment = '%1=período';
        ErrSinTipos: Label 'Ningún tipo de liquidación tiene marcado Genera Asiento. Marcalo en Tipos de Liquidación para los que se contabilizan (no en la historia migrada ni en los saldos iniciales).';
        ErrSinReglas: Label 'No hay reglas del asiento cargadas. Cargalas en Reglas del asiento de sueldos.';
        TxtResumen: Label '%1 liquidaciones · Debe %2 · Haber %3 · Diferencia llevada a redondeo %4 · %5 avisos', Comment = '%1=liquidaciones, %2=debe, %3=haber, %4=diferencia, %5=avisos';
        TxtSinValor: Label '(sin valor)';
        TxtProvision: Label '(provisión)';
        TxtOrigenLinea: Label 'Línea';
        TxtOrigenLiquidacion: Label 'Liquidación';
        TxtOrigenDevengado: Label 'Provisión: devengado';
        TxtOrigenReversion: Label 'Provisión: reversión';
        TxtOrigenLote: Label 'Lote de francos';
        TxtDetalleReversion: Label 'Revierte el devengado de %1', Comment = '%1=período del devengado';
        TxtDetalleLote: Label 'Lote %1: de %2 a %3 días, a %4 por día', Comment = '%1=lote, %2=días al cierre anterior, %3=días al cierre, %4=valor por día';
        ErrArgumentoOrigenes: Label 'El argumento es el período y la clave separados por punto y coma: 202601;6110002|PP-802-000006.';
        AvSinRegla: Label 'Concepto %1 %2 liquidó importe y no tiene regla del asiento.', Comment = '%1=concepto, %2=descripción';
        AvReglaAmbigua: Label 'Concepto %1: dos reglas igual de específicas coinciden ("%2" y "%3"). Acotá los filtros; el importe no se imputó.', Comment = '%1=concepto, %2 y %3=filtros';
        AvSinCuenta: Label 'Concepto %1: a su regla le falta la cuenta de un lado; el importe no se imputó.', Comment = '%1=concepto';
        AvSinCuentaAtributo: Label 'Concepto %1: el atributo %2 vale %3 y no hay cuenta con ese valor de dimensión; fue a la cuenta fija.', Comment = '%1=concepto, %2=tipo atributo, %3=valor';
        AvDimensionDuplicada: Label 'Hay más de una cuenta con la dimensión %1 = %2; se usó %3.', Comment = '%1=dimensión, %2=valor, %3=cuenta';
        AvCuentaInexistente: Label 'La cuenta %1 no existe en el plan de cuentas.', Comment = '%1=cuenta';
        AvCuentaSinProyecto: Label 'La cuenta %1 lleva proyecto y hay liquidaciones sin proyecto: quedaron sin imputar a ninguno.', Comment = '%1=cuenta';
        AvSaldoInicialProvision: Label 'Provisión %1: saldo al inicio del período que no viene de un período asentado (saldo inicial). No entra en el asiento del mes: asentarlo una vez contra resultados de ejercicios anteriores.', Comment = '%1=concepto';
        AvFrancoSinValor: Label 'Provisión %1: %2 días de francos en lotes sin precio para su terna (VALOR_FRANCO por pesquería, convenio y categoría); no se provisionaron. Último error: %3', Comment = '%1=concepto, %2=días, %3=mensaje del ledger';
        AvFrancoBorrador: Label 'Provisión %1: hay liquidaciones en Borrador en el período. Reabrir revirtió sus movimientos de francos, así que su consumo no revierte la provisión aunque su pago entre al gasto: calcularlas antes de mirar los francos.', Comment = '%1=concepto';
        AvTipoSinAsiento: Label 'Hay liquidaciones de tipo %1 en el período y el tipo no tiene marcado Genera Asiento: no entraron.', Comment = '%1=tipo de liquidación';
        AvReglaIncompleta: Label 'Regla del concepto %1 incompleta, no se usó: %2', Comment = '%1=concepto, %2=qué falta';
        ErrFrancosEnDosConceptos: Label 'La provisión de lotes de francos está en los conceptos %1 y %2: es una sola cuenta corriente y se asentaría dos veces. Dejala en uno.', Comment = '%1 y %2=conceptos';
        AvFrancoSinLiquidacion: Label 'Provisión %1: hay empleados con saldo de francos y ninguna liquidación con VALOR_FRANCO_DIA; no se imputó.', Comment = '%1=concepto';
        AvRedondeoGrande: Label 'La diferencia es de %1: más que un redondeo.', Comment = '%1=importe';
}
