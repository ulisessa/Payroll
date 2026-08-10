namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;
using System.IO;
using System.Utilities;

codeunit 50066 "Gestión Novedades Liq."
{
    // Motor de novedades: convierte lo cargado en Novedad Liquidación (que existe antes que la
    // liquidación) en Incidencia Liquidación (que necesita la liquidación creada). Se engancha en
    // Cod50014 exactamente donde ya se enganchan las cuotas de préstamo, y es idempotente: cada
    // recálculo borra lo que generó la corrida anterior y lo vuelve a armar.
    //
    //   AplicarEnLiquidacion   ← desde el motor, solo en Borrador
    //   LimpiarParaRecalculo   ← desde el motor, antes de aplicar
    //   RevertirLiquidacion    ← desde Reabrir / Revertir Aprobación

    // ── Aplicación en la liquidación ──────────────────────────────────────────

    procedure AplicarEnLiquidacion(var Liq: Record "Liquidación")
    var
        Nov: Record "Novedad Liquidación";
        TempAcum: Record "Incidencia Liquidación" temporary;
        RangoDesde: Date;
        RangoHasta: Date;
    begin
        if Liq.Estado <> Liq.Estado::Borrador then
            exit;
        if Liq."Cód. Período" = '' then
            exit;

        CalcularRangoLiquidacion(Liq, RangoDesde, RangoHasta);

        Nov.SetCurrentKey("Cód. Período", Estado);
        Nov.SetRange("Cód. Período", Liq."Cód. Período");
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if not Nov.FindSet() then
            exit;

        // Primera pasada: acumular por concepto. Incidencia Liquidación tiene una sola fila por
        // concepto y liquidación, así que dos novedades del mismo concepto tienen que sumarse — no
        // se puede insertar una fila por novedad.
        repeat
            if NovedadAplica(Nov, Liq, RangoDesde, RangoHasta) then
                AcumularEnTemp(TempAcum, Nov);
        until Nov.Next() = 0;

        // Segunda pasada: materializar y anotar en cada novedad dónde entró (o por qué no).
        if TempAcum.FindSet() then
            repeat
                MaterializarConcepto(Liq, TempAcum, RangoDesde, RangoHasta);
            until TempAcum.Next() = 0;
    end;

    // Borra lo generado por novedades en la corrida anterior y libera las novedades que lo habían
    // originado. No toca incidencias cargadas a mano ni las de préstamos: se identifican por
    // "Desde Novedad", igual que las de cuotas por "Cód. Cuota Préstamo".
    procedure LimpiarParaRecalculo(LiqNo: Code[20])
    var
        Nov: Record "Novedad Liquidación";
        Incid: Record "Incidencia Liquidación";
        Movimientos: List of [Integer];
        Movimiento: Integer;
    begin
        Incid.SetRange("No. Liquidación", LiqNo);
        Incid.SetRange("Desde Novedad", true);
        if not Incid.IsEmpty() then
            Incid.DeleteAll();

        // Se juntan primero las claves y recién después se modifica: el campo que hay que limpiar es
        // el mismo por el que está filtrado el conjunto, y vaciarlo mientras se recorre saca la fila
        // del filtro y puede hacer que Next() saltee las que siguen.
        Nov.SetCurrentKey("No. Liquidación");
        Nov.SetRange("No. Liquidación", LiqNo);
        if Nov.FindSet() then
            repeat
                Movimientos.Add(Nov."No. Movimiento");
            until Nov.Next() = 0;

        foreach Movimiento in Movimientos do
            if Nov.Get(Movimiento) then begin
                Nov."No. Liquidación" := '';
                Nov.Estado := Nov.Estado::Pendiente;
                Nov."Motivo No Aplicada" := '';
                Nov.Modify();
            end;
    end;

    // Desde Reabrir y Revertir Aprobación: la liquidación vuelve a Borrador y las novedades tienen
    // que volver a estar disponibles, si no quedan marcadas como Aplicada contra un cálculo que ya
    // no existe.
    procedure RevertirLiquidacion(LiqNo: Code[20])
    begin
        LimpiarParaRecalculo(LiqNo);
    end;

    // Una liquidación mensual abarca todo el período; un cierre de marea, solo los días del viaje.
    // Sin esta distinción, el mensual y el cierre de marea del mismo período se llevarían las
    // mismas novedades y la que llegara segunda quedaría sin efecto.
    local procedure CalcularRangoLiquidacion(Liq: Record "Liquidación"; var Desde: Date; var Hasta: Date)
    var
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Job: Record Job;
    begin
        if not Periodo.Get(Liq."Cód. Período") then
            exit;
        Desde := Periodo."Fecha Desde";
        Hasta := Periodo."Fecha Hasta";

        if not TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") then
            exit;
        if (Liq."No. Proyecto" = '') or not Job.Get(Liq."No. Proyecto") then
            exit;
        if (Job."Starting Date" <> 0D) and (Job."Starting Date" > Desde) then
            Desde := Job."Starting Date";
        if (Job."Ending Date" <> 0D) and (Job."Ending Date" < Hasta) then
            Hasta := Job."Ending Date";
    end;

    // Regla única de correspondencia novedad → liquidación. Campo selector en blanco = cualquiera.
    local procedure NovedadAplica(Nov: Record "Novedad Liquidación"; Liq: Record "Liquidación"; RangoDesde: Date; RangoHasta: Date): Boolean
    begin
        if (Nov."Cód. Tipo Liq." <> '') and (Nov."Cód. Tipo Liq." <> Liq."Cód. Tipo Liq.") then
            exit(false);
        if (Nov."Cód. Convenio" <> '') and (Nov."Cód. Convenio" <> Liq."Cód. Convenio") then
            exit(false);
        if (Nov."Cód. Categoría" <> '') and (Nov."Cód. Categoría" <> Liq."Cód. Categoría") then
            exit(false);
        if (Nov."No. Empleado" <> '') and (Nov."No. Empleado" <> Liq."No. Empleado") then
            exit(false);
        if (Nov."No. Proyecto" <> '') and (Nov."No. Proyecto" <> Liq."No. Proyecto") then
            exit(false);
        if Nov.Fecha <> 0D then
            if (Nov.Fecha < RangoDesde) or (Nov.Fecha > RangoHasta) then
                exit(false);
        // Ya entró en otra liquidación del mismo período (típico: mensual y cierre de marea del
        // mismo empleado). Cobrarla dos veces sería peor que no cobrarla.
        if (Nov.Estado = Nov.Estado::Aplicada) and (Nov."No. Liquidación" <> '') and (Nov."No. Liquidación" <> Liq."No.") then
            exit(false);
        exit(true);
    end;

    local procedure AcumularEnTemp(var TempAcum: Record "Incidencia Liquidación" temporary; Nov: Record "Novedad Liquidación")
    begin
        if not TempAcum.Get('', Nov."Cód. Concepto") then begin
            TempAcum.Init();
            TempAcum."No. Liquidación" := '';
            TempAcum."Cód. Concepto" := Nov."Cód. Concepto";
            TempAcum."Unidad Cantidad" := Nov."Unidad Cantidad";
            TempAcum.Insert();
        end;

        TempAcum.Cantidad += Nov.Cantidad;
        TempAcum.Importe += Nov.Importe;
        // El Valor Unitario solo se conserva si todas las novedades del concepto coinciden. Cuando
        // difieren no hay un unitario que represente la suma, y dejarlo mentiría en el recibo.
        if TempAcum."Valor Unitario" = 0 then
            TempAcum."Valor Unitario" := Nov."Valor Unitario"
        else
            if TempAcum."Valor Unitario" <> Nov."Valor Unitario" then
                TempAcum."Valor Unitario" := 0;

        if Nov.Observaciones <> '' then
            if TempAcum.Observaciones = '' then
                TempAcum.Observaciones := Nov.Observaciones
            else
                TempAcum.Observaciones := CopyStr(TempAcum.Observaciones + '; ' + Nov.Observaciones, 1, MaxStrLen(TempAcum.Observaciones));
        TempAcum.Modify();
    end;

    local procedure MaterializarConcepto(var Liq: Record "Liquidación"; var TempAcum: Record "Incidencia Liquidación" temporary; RangoDesde: Date; RangoHasta: Date)
    var
        Incid: Record "Incidencia Liquidación";
        Motivo: Text[250];
    begin
        if Incid.Get(Liq."No.", TempAcum."Cód. Concepto") then begin
            // Se respeta lo cargado a mano (o por préstamos) sobre la liquidación: la novedad queda
            // Pendiente con el motivo a la vista, en vez de pisar el ajuste en silencio.
            Motivo := CopyStr(StrSubstNo(MotivoYaExisteTxt, TempAcum."Cód. Concepto", Liq."No."), 1, MaxStrLen(Motivo));
            Registro.AdvertirVariable(
                "Categoría Registro Liq."::Novedad,
                StrSubstNo(RegNovedadSalteadaTxt, TempAcum."Cód. Concepto"),
                '', TempAcum."Cód. Concepto");
        end else begin
            Incid.Init();
            Incid."No. Liquidación" := Liq."No.";
            Incid."Cód. Concepto" := TempAcum."Cód. Concepto";
            Incid.Cantidad := TempAcum.Cantidad;
            Incid."Unidad Cantidad" := TempAcum."Unidad Cantidad";
            Incid."Valor Unitario" := TempAcum."Valor Unitario";
            // Insert sin validar: el Importe ya viene sumado de varias novedades y revalidar
            // Cantidad × Valor Unitario lo pisaría con un número que no es el acumulado.
            Incid.Importe := TempAcum.Importe;
            Incid.Observaciones := TempAcum.Observaciones;
            Incid."Desde Novedad" := true;
            Incid.Insert();
            Registro.InfoImporte(
                "Categoría Registro Liq."::Novedad,
                StrSubstNo(RegNovedadAplicadaTxt, TempAcum."Cód. Concepto"),
                TempAcum."Cód. Concepto", TempAcum.Importe);
        end;

        MarcarNovedades(Liq, TempAcum."Cód. Concepto", RangoDesde, RangoHasta, Motivo);
    end;

    local procedure MarcarNovedades(var Liq: Record "Liquidación"; CodConcepto: Code[20]; RangoDesde: Date; RangoHasta: Date; Motivo: Text[250])
    var
        Nov: Record "Novedad Liquidación";
    begin
        Nov.SetRange("Cód. Período", Liq."Cód. Período");
        Nov.SetRange("Cód. Concepto", CodConcepto);
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if not Nov.FindSet(true) then
            exit;
        repeat
            if NovedadAplica(Nov, Liq, RangoDesde, RangoHasta) then begin
                if Motivo = '' then begin
                    Nov.Estado := Nov.Estado::Aplicada;
                    Nov."No. Liquidación" := Liq."No.";
                end else begin
                    Nov.Estado := Nov.Estado::Pendiente;
                    Nov."No. Liquidación" := '';
                end;
                Nov."Motivo No Aplicada" := Motivo;
                Nov.Modify();
            end;
        until Nov.Next() = 0;
    end;

    // ── Anulación ─────────────────────────────────────────────────────────────

    // Anular una novedad que ya entró en una liquidación obliga a deshacer lo generado: se libera
    // toda la liquidación (se borran las incidencias de novedades y las demás vuelven a Pendiente)
    // y el próximo cálculo la rearma sin esta. Es el mismo camino que un recálculo normal.
    procedure AnularNovedad(var Nov: Record "Novedad Liquidación")
    begin
        if Nov.Estado = Nov.Estado::Anulada then
            exit;
        if (Nov.Estado = Nov.Estado::Aplicada) and (Nov."No. Liquidación" <> '') then begin
            LimpiarParaRecalculo(Nov."No. Liquidación");
            Nov.Get(Nov."No. Movimiento");
        end;
        Nov.Estado := Nov.Estado::Anulada;
        Nov."No. Liquidación" := '';
        Nov."Motivo No Aplicada" := '';
        Nov.Modify();
    end;

    procedure ReactivarNovedad(var Nov: Record "Novedad Liquidación")
    begin
        if Nov.Estado <> Nov.Estado::Anulada then
            exit;
        Nov.Estado := Nov.Estado::Pendiente;
        Nov."Motivo No Aplicada" := '';
        Nov.Modify();
    end;

    // ── Copia y recurrencia ───────────────────────────────────────────────────

    procedure CopiarDePeriodo(PeriodoOrigen: Code[10]; PeriodoDestino: Code[10]): Integer
    var
        Nov: Record "Novedad Liquidación";
        Nueva: Record "Novedad Liquidación";
        Origen: Record "Período Liquidación";
        Destino: Record "Período Liquidación";
        Copiadas: Integer;
    begin
        if (PeriodoOrigen = '') or (PeriodoDestino = '') then
            Error(ErrFaltanPeriodos);
        if PeriodoOrigen = PeriodoDestino then
            Error(ErrMismoPeriodo);
        Origen.Get(PeriodoOrigen);
        ValidarDestinoAbierto(Destino, PeriodoDestino);

        Nov.SetCurrentKey("Cód. Período", Estado);
        Nov.SetRange("Cód. Período", PeriodoOrigen);
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if Nov.FindSet() then
            repeat
                if not ExisteEquivalente(Nov, PeriodoDestino) then begin
                    PrepararCopia(Nov, Nueva, Origen, Destino);
                    Nueva.Insert(true);
                    Copiadas += 1;
                end;
            until Nov.Next() = 0;
        exit(Copiadas);
    end;

    // Genera en el período destino las novedades marcadas Recurrente del período inmediatamente
    // anterior, descontando un período al contador. Se puede correr dos veces sin duplicar: la
    // cadena se identifica por "Novedad Origen", que se propaga desde la novedad raíz.
    procedure GenerarRecurrentes(PeriodoDestino: Code[10]): Integer
    var
        Nov: Record "Novedad Liquidación";
        Nueva: Record "Novedad Liquidación";
        Origen: Record "Período Liquidación";
        Destino: Record "Período Liquidación";
        CodOrigen: Code[10];
        Raiz: Integer;
        Generadas: Integer;
    begin
        ValidarDestinoAbierto(Destino, PeriodoDestino);
        CodOrigen := Destino.PeriodoAnterior(PeriodoDestino);
        if CodOrigen = '' then
            Error(ErrSinPeriodoAnterior, PeriodoDestino);
        Origen.Get(CodOrigen);

        Nov.SetCurrentKey("Cód. Período", Estado);
        Nov.SetRange("Cód. Período", CodOrigen);
        Nov.SetRange(Recurrente, true);
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if Nov.FindSet() then
            repeat
                Raiz := Nov."Novedad Origen";
                if Raiz = 0 then
                    Raiz := Nov."No. Movimiento";
                if not ExisteRecurrente(Raiz, PeriodoDestino) then begin
                    PrepararCopia(Nov, Nueva, Origen, Destino);
                    Nueva."Novedad Origen" := Raiz;
                    if Nov."Períodos Restantes" > 0 then begin
                        Nueva."Períodos Restantes" := Nov."Períodos Restantes" - 1;
                        Nueva.Recurrente := Nueva."Períodos Restantes" > 0;
                    end;
                    Nueva.Insert(true);
                    Generadas += 1;
                end;
            until Nov.Next() = 0;
        exit(Generadas);
    end;

    local procedure PrepararCopia(Nov: Record "Novedad Liquidación"; var Nueva: Record "Novedad Liquidación"; Origen: Record "Período Liquidación"; Destino: Record "Período Liquidación")
    begin
        Nueva := Nov;
        Nueva."No. Movimiento" := 0;
        Nueva."Cód. Período" := Destino.Código;
        Nueva.Fecha := MapearFecha(Nov.Fecha, Origen, Destino);
        Nueva.Estado := Nueva.Estado::Pendiente;
        Nueva."No. Liquidación" := '';
        Nueva."Motivo No Aplicada" := '';
    end;

    // Conserva la posición relativa dentro del período (día 3 de un período → día 3 del siguiente),
    // recortada al destino. Copiar el día del mes tal cual se rompe con períodos de distinto largo.
    local procedure MapearFecha(FechaOrigen: Date; Origen: Record "Período Liquidación"; Destino: Record "Período Liquidación"): Date
    var
        Candidata: Date;
    begin
        if (FechaOrigen = 0D) or (Origen."Fecha Desde" = 0D) then
            exit(Destino."Fecha Hasta");
        Candidata := Destino."Fecha Desde" + (FechaOrigen - Origen."Fecha Desde");
        if Candidata > Destino."Fecha Hasta" then
            exit(Destino."Fecha Hasta");
        if Candidata < Destino."Fecha Desde" then
            exit(Destino."Fecha Desde");
        exit(Candidata);
    end;

    local procedure ExisteEquivalente(Nov: Record "Novedad Liquidación"; PeriodoDestino: Code[10]): Boolean
    var
        Existente: Record "Novedad Liquidación";
    begin
        Existente.SetCurrentKey("Cód. Período", "No. Empleado", "Cód. Concepto");
        Existente.SetRange("Cód. Período", PeriodoDestino);
        Existente.SetRange("No. Empleado", Nov."No. Empleado");
        Existente.SetRange("Cód. Concepto", Nov."Cód. Concepto");
        Existente.SetRange("Cód. Tipo Liq.", Nov."Cód. Tipo Liq.");
        Existente.SetRange("Cód. Convenio", Nov."Cód. Convenio");
        Existente.SetRange("Cód. Categoría", Nov."Cód. Categoría");
        Existente.SetRange("No. Proyecto", Nov."No. Proyecto");
        exit(not Existente.IsEmpty());
    end;

    local procedure ExisteRecurrente(Raiz: Integer; PeriodoDestino: Code[10]): Boolean
    var
        Existente: Record "Novedad Liquidación";
    begin
        Existente.SetCurrentKey("Novedad Origen", "Cód. Período");
        Existente.SetRange("Novedad Origen", Raiz);
        Existente.SetRange("Cód. Período", PeriodoDestino);
        if not Existente.IsEmpty() then
            exit(true);
        // La raíz misma puede ser del período destino si alguien ya la cargó a mano ahí.
        Existente.Reset();
        Existente.SetRange("No. Movimiento", Raiz);
        Existente.SetRange("Cód. Período", PeriodoDestino);
        exit(not Existente.IsEmpty());
    end;

    local procedure ValidarDestinoAbierto(var Destino: Record "Período Liquidación"; PeriodoDestino: Code[10])
    begin
        Destino.Get(PeriodoDestino);
        if Destino.Estado = Destino.Estado::Cerrado then
            Error(ErrDestinoCerrado, PeriodoDestino);
    end;

    // ── Importación desde archivo ─────────────────────────────────────────────

    // Formato esperado, una novedad por fila (la primera fila puede ser encabezado: las filas cuyo
    // empleado o concepto no existan se saltean y se cuentan aparte):
    //   1 No. Empleado | 2 Cód. Concepto | 3 Cantidad | 4 Valor Unitario | 5 Importe
    //   6 Fecha | 7 Cód. Tipo Liq. | 8 Observaciones | 9 No. Proyecto
    procedure ImportarArchivo(CodPeriodo: Code[10]; var Omitidas: Integer): Integer
    var
        Destino: Record "Período Liquidación";
        TempBlob: Codeunit "Temp Blob";
        NombreArchivo: Text;
        InStr: InStream;
        OutStr: OutStream;
    begin
        Omitidas := 0;
        ValidarDestinoAbierto(Destino, CodPeriodo);

        if not UploadIntoStream(DlgSubirTxt, '', FiltroArchivoTxt, NombreArchivo, InStr) then
            exit(0);
        // Se copia a un blob porque el archivo se recorre más de una vez (Excel pide el stream para
        // elegir la hoja y otra vez para leerla) y un stream de upload no se puede rebobinar.
        TempBlob.CreateOutStream(OutStr);
        CopyStream(OutStr, InStr);

        if EsExcel(NombreArchivo) then
            exit(ImportarExcel(TempBlob, CodPeriodo, Omitidas));
        exit(ImportarCsv(TempBlob, CodPeriodo, Omitidas));
    end;

    local procedure EsExcel(NombreArchivo: Text): Boolean
    var
        Minuscula: Text;
    begin
        Minuscula := NombreArchivo.ToLower();
        exit(Minuscula.EndsWith('.xlsx') or Minuscula.EndsWith('.xlsm') or Minuscula.EndsWith('.xls'));
    end;

    local procedure ImportarExcel(var TempBlob: Codeunit "Temp Blob"; CodPeriodo: Code[10]; var Omitidas: Integer): Integer
    var
        TempExcelBuf: Record "Excel Buffer" temporary;
        InStr: InStream;
        NombreHoja: Text[250];
        Fila: Integer;
        UltimaFila: Integer;
        Importadas: Integer;
    begin
        TempBlob.CreateInStream(InStr);
        NombreHoja := TempExcelBuf.SelectSheetsNameStream(InStr);
        if NombreHoja = '' then
            exit(0);

        TempExcelBuf.Reset();
        TempExcelBuf.DeleteAll();
        TempBlob.CreateInStream(InStr);
        TempExcelBuf.OpenBookStream(InStr, NombreHoja);
        TempExcelBuf.ReadSheet();

        TempExcelBuf.Reset();
        if not TempExcelBuf.FindLast() then
            exit(0);
        UltimaFila := TempExcelBuf."Row No.";

        for Fila := 1 to UltimaFila do
            if FilaTieneDatos(TempExcelBuf, Fila) then
                if InsertarImportada(
                    CodPeriodo,
                    Celda(TempExcelBuf, Fila, 1), Celda(TempExcelBuf, Fila, 2), Celda(TempExcelBuf, Fila, 3),
                    Celda(TempExcelBuf, Fila, 4), Celda(TempExcelBuf, Fila, 5), Celda(TempExcelBuf, Fila, 6),
                    Celda(TempExcelBuf, Fila, 7), Celda(TempExcelBuf, Fila, 8), Celda(TempExcelBuf, Fila, 9))
                then
                    Importadas += 1
                else
                    Omitidas += 1;
        exit(Importadas);
    end;

    local procedure Celda(var TempExcelBuf: Record "Excel Buffer" temporary; Fila: Integer; Columna: Integer): Text
    begin
        if TempExcelBuf.Get(Fila, Columna) then
            exit(TempExcelBuf."Cell Value as Text");
        exit('');
    end;

    local procedure FilaTieneDatos(var TempExcelBuf: Record "Excel Buffer" temporary; Fila: Integer): Boolean
    begin
        exit((Celda(TempExcelBuf, Fila, 1) <> '') or (Celda(TempExcelBuf, Fila, 2) <> ''));
    end;

    local procedure ImportarCsv(var TempBlob: Codeunit "Temp Blob"; CodPeriodo: Code[10]; var Omitidas: Integer): Integer
    var
        InStr: InStream;
        Linea: Text;
        Separador: Text[1];
        Importadas: Integer;
    begin
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS do begin
            InStr.ReadText(Linea);
            if DelChr(Linea, '<>', ' ') <> '' then begin
                if Separador = '' then
                    Separador := DetectarSeparador(Linea);
                if InsertarImportada(
                    CodPeriodo,
                    CampoCsv(Linea, Separador, 1), CampoCsv(Linea, Separador, 2), CampoCsv(Linea, Separador, 3),
                    CampoCsv(Linea, Separador, 4), CampoCsv(Linea, Separador, 5), CampoCsv(Linea, Separador, 6),
                    CampoCsv(Linea, Separador, 7), CampoCsv(Linea, Separador, 8), CampoCsv(Linea, Separador, 9))
                then
                    Importadas += 1
                else
                    Omitidas += 1;
            end;
        end;
        exit(Importadas);
    end;

    // El Excel en español exporta con punto y coma, pero un archivo armado a mano puede venir con
    // coma o tabulación. Se decide con la primera línea con datos y se usa para todo el archivo.
    local procedure DetectarSeparador(Linea: Text): Text[1]
    var
        Tab: Char;
    begin
        Tab := 9;
        if StrLen(Linea) - StrLen(DelChr(Linea, '=', ';')) > 0 then
            exit(';');
        if StrLen(Linea) - StrLen(DelChr(Linea, '=', Format(Tab))) > 0 then
            exit(CopyStr(Format(Tab), 1, 1));
        exit(',');
    end;

    local procedure CampoCsv(Linea: Text; Separador: Text[1]; Indice: Integer): Text
    var
        Campos: List of [Text];
        Valor: Text;
    begin
        Campos := Linea.Split(Separador);
        if Indice > Campos.Count then
            exit('');
        Valor := DelChr(Campos.Get(Indice), '<>', ' ');
        exit(DelChr(Valor, '<>', '"'));
    end;

    local procedure InsertarImportada(CodPeriodo: Code[10]; EmpTxt: Text; ConceptoTxt: Text; CantidadTxt: Text; ValorTxt: Text; ImporteTxt: Text; FechaTxt: Text; TipoLiqTxt: Text; ObsTxt: Text; ProyectoTxt: Text): Boolean
    var
        Nov: Record "Novedad Liquidación";
        Emp: Record Employee;
        Concepto: Record "Concepto Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Job: Record Job;
        CodEmpleado: Code[20];
        CodConcepto: Code[20];
        Cantidad: Decimal;
        ValorUnitario: Decimal;
        Importe: Decimal;
        FechaNov: Date;
    begin
        CodEmpleado := CopyStr(DelChr(EmpTxt, '<>', ' '), 1, MaxStrLen(CodEmpleado)).ToUpper();
        CodConcepto := CopyStr(DelChr(ConceptoTxt, '<>', ' '), 1, MaxStrLen(CodConcepto)).ToUpper();
        if (CodEmpleado = '') or (CodConcepto = '') then
            exit(false);
        // Sirve de filtro de encabezado sin tener que reconocer títulos: la fila "No. Empleado /
        // Cód. Concepto" no resuelve contra ninguna tabla y se descarta igual que una fila errónea.
        if not Emp.Get(CodEmpleado) then
            exit(false);
        Concepto.SetRange(Código, CodConcepto);
        if Concepto.IsEmpty() then
            exit(false);

        if not ParseDecimal(CantidadTxt, Cantidad) then
            exit(false);
        if not ParseDecimal(ValorTxt, ValorUnitario) then
            exit(false);
        if not ParseDecimal(ImporteTxt, Importe) then
            exit(false);
        FechaNov := ParseFecha(FechaTxt);

        Nov.Init();
        Nov."No. Movimiento" := 0;
        Nov.Validate("Cód. Período", CodPeriodo);
        Nov.Validate("No. Empleado", CodEmpleado);
        if FechaNov <> 0D then
            Nov.Validate(Fecha, FechaNov);
        if TipoLiqTxt <> '' then begin
            TipoLiqRec.SetRange(Código, CopyStr(DelChr(TipoLiqTxt, '<>', ' '), 1, 20).ToUpper());
            if TipoLiqRec.FindFirst() then
                Nov."Cód. Tipo Liq." := TipoLiqRec.Código;
        end;
        // Un proyecto que no existe se ignora en vez de rechazar la fila: la novedad igual vale para
        // el empleado, y rechazarla entera por una columna opcional escondería el resto del dato.
        if ProyectoTxt <> '' then
            if Job.Get(CopyStr(DelChr(ProyectoTxt, '<>', ' '), 1, 20).ToUpper()) then
                Nov."No. Proyecto" := Job."No.";
        Nov."Cód. Concepto" := CodConcepto;
        Nov.Cantidad := Cantidad;
        Nov."Valor Unitario" := ValorUnitario;
        if Importe <> 0 then
            Nov.Importe := Importe
        else
            if (Cantidad <> 0) and (ValorUnitario <> 0) then
                Nov.Importe := Round(Cantidad * ValorUnitario, 0.01);
        Nov.Observaciones := CopyStr(ObsTxt, 1, MaxStrLen(Nov.Observaciones));
        Nov.Insert(true);
        exit(true);
    end;

    // Tolera los dos formatos que llegan en la práctica: 1.234,56 (es-AR) y 1,234.56 (invariante).
    // Manda el separador que aparece último, que es siempre el decimal.
    local procedure ParseDecimal(Txt: Text; var Valor: Decimal): Boolean
    var
        Limpio: Text;
    begin
        Valor := 0;
        Limpio := DelChr(Txt, '<>', ' ');
        Limpio := DelChr(Limpio, '=', '$ ');
        if Limpio = '' then
            exit(true);

        if Limpio.LastIndexOf(',') > Limpio.LastIndexOf('.') then begin
            Limpio := DelChr(Limpio, '=', '.');
            Limpio := Limpio.Replace(',', '.');
        end else
            Limpio := DelChr(Limpio, '=', ',');

        exit(Evaluate(Valor, Limpio, 9));
    end;

    local procedure ParseFecha(Txt: Text): Date
    var
        Resultado: Date;
    begin
        Txt := DelChr(Txt, '<>', ' ');
        if Txt = '' then
            exit(0D);
        if Evaluate(Resultado, Txt) then
            exit(Resultado);
        if Evaluate(Resultado, Txt, 9) then
            exit(Resultado);
        exit(0D);
    end;

    var
        Registro: Codeunit "Registro Procesos Liq.";
        RegNovedadAplicadaTxt: Label 'Novedad aplicada al concepto %1.';
        RegNovedadSalteadaTxt: Label 'Novedad NO aplicada al concepto %1: la liquidación ya tenía una incidencia cargada a mano o por préstamos.';
        MotivoYaExisteTxt: Label 'La liquidación %2 ya tenía una incidencia para %1 cargada a mano o por préstamos: se respetó esa y la novedad quedó sin aplicar.';
        ErrFaltanPeriodos: Label 'Indicá el período de origen y el de destino.';
        ErrMismoPeriodo: Label 'El período de origen y el de destino son el mismo.';
        ErrDestinoCerrado: Label 'El período %1 está cerrado.';
        ErrSinPeriodoAnterior: Label 'No hay ningún período anterior a %1 del cual generar las novedades recurrentes.';
        DlgSubirTxt: Label 'Seleccioná el archivo de novedades';
        FiltroArchivoTxt: Label 'Excel o CSV (*.xlsx;*.csv;*.txt)|*.xlsx;*.xlsm;*.csv;*.txt';
}
