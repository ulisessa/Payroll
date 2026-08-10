namespace UAS.Payroll;

codeunit 50068 "Registro Procesos Liq."
{
    SingleInstance = true;

    // Bitácora de los procesos de liquidación: un registro por operación, con sus errores,
    // advertencias y acciones. Reemplaza al Text en memoria que acumulaba advertencias y se perdía
    // al cerrar el mensaje — y sobre todo, hace que un cálculo que falla deje rastro.
    //
    // SingleInstance a propósito: cualquier codeunit que participe del cálculo (novedades,
    // préstamos, el motor) puede anotar en el registro activo sin que haya que pasarlo por
    // parámetro por toda la cadena de llamadas.
    //
    // POR QUÉ SE BUFFEREA EN UNA TABLA TEMPORAL:
    // Si un cálculo falla, la plataforma revierte TODO lo que se escribió en la transacción — el
    // registro incluido, que es justo lo que hay que conservar. Los registros temporales no
    // participan de la transacción, así que las entradas se juntan en memoria y se escriben recién
    // al cerrar la operación, cuando ya se sabe si hubo rollback o no.

    var
        TempEntrada: Record "Entrada Registro Liq." temporary;
        FActivo: Boolean;
        FSesion: Guid;
        FTipoProceso: Enum "Tipo Proceso Liq.";
        FLiqNo: Code[20];
        FEmpleadoNo: Code[20];
        FNombreEmpleado: Text[100];
        FCodPeriodo: Code[10];
        FCodTipoLiq: Code[20];
        FInicio: DateTime;
        FUltimoRegistro: Integer;
        FResumen: Text;
        MsgInterrumpidoTxt: Label 'El proceso anterior quedó sin cerrar (probablemente terminó en un error no controlado) y sus anotaciones se descartaron.';
        MsgSinDetalleTxt: Label 'Proceso completado.';

    // ── Sesión (agrupa una corrida por lote) ──────────────────────────────────

    procedure IniciarSesion(): Guid
    begin
        FSesion := CreateGuid();
        exit(FSesion);
    end;

    procedure CerrarSesion()
    begin
        Clear(FSesion);
    end;

    // ── Apertura y cierre ─────────────────────────────────────────────────────

    procedure Iniciar(TipoProceso: Enum "Tipo Proceso Liq."; Liq: Record "Liquidación")
    begin
        IniciarInterno(TipoProceso);
        FLiqNo := Liq."No.";
        FEmpleadoNo := Liq."No. Empleado";
        FNombreEmpleado := Liq."Nombre Empleado";
        FCodPeriodo := Liq."Cód. Período";
        FCodTipoLiq := Liq."Cód. Tipo Liq.";
    end;

    procedure IniciarProceso(TipoProceso: Enum "Tipo Proceso Liq."; CodPeriodo: Code[10])
    begin
        IniciarInterno(TipoProceso);
        FCodPeriodo := CodPeriodo;
    end;

    local procedure IniciarInterno(TipoProceso: Enum "Tipo Proceso Liq.")
    var
        HabiaProcesoAbierto: Boolean;
    begin
        // Un proceso anterior sin cerrar significa que alguien se salteó el Finalizar (típicamente
        // un error que nadie atrapó). Como el codeunit es SingleInstance, ese estado sobrevive en la
        // sesión y llega hasta acá.
        //
        // NO se escribe acá: Iniciar tiene que dejar la transacción intacta. El llamador arranca un
        // Codeunit.Run inmediatamente después, y la plataforma no le deja abrir su ámbito de
        // transacción si ya hubo escrituras ("Se produjo un error y la transacción se detuvo"). Se
        // descarta el buffer viejo y queda constancia en el registro nuevo.
        HabiaProcesoAbierto := FActivo;

        TempEntrada.Reset();
        TempEntrada.DeleteAll();
        Clear(FLiqNo);
        Clear(FEmpleadoNo);
        Clear(FNombreEmpleado);
        Clear(FCodPeriodo);
        Clear(FCodTipoLiq);
        FTipoProceso := TipoProceso;
        FInicio := CurrentDateTime();
        FResumen := '';
        FActivo := true;

        if HabiaProcesoAbierto then
            Advertir("Categoría Registro Liq."::General, MsgInterrumpidoTxt);
    end;

    procedure Finalizar()
    begin
        if not FActivo then
            exit;
        Escribir(SeveridadMaxima(), MensajeResumen());
    end;

    /// <summary>
    /// Cierra el proceso dejando asentado el error que lo abortó.
    /// </summary>
    /// <remarks>
    /// Hace Commit: se llama después de que la plataforma revirtió el trabajo fallido, y quien la
    /// llama vuelve a lanzar el error para que el usuario lo vea. Sin el Commit, ese Error se
    /// llevaría puesto también al registro que acabamos de escribir, que es exactamente lo que este
    /// mecanismo existe para evitar.
    /// </remarks>
    procedure FinalizarConError(TextoError: Text)
    begin
        if not FActivo then
            exit;
        RegistrarError("Categoría Registro Liq."::General, CopyStr(TextoError, 1, 250), TextoError);
        Escribir("Severidad Registro Liq."::Error, CopyStr(TextoError, 1, 250));
        Commit();
    end;

    procedure Activo(): Boolean
    begin
        exit(FActivo);
    end;

    procedure UltimoRegistro(): Integer
    begin
        exit(FUltimoRegistro);
    end;

    /// <summary>Resumen de la última operación cerrada, para mostrarlo al usuario.</summary>
    procedure GetResumen(): Text
    begin
        exit(FResumen);
    end;

    // ── Anotaciones ───────────────────────────────────────────────────────────

    procedure Info(Categoria: Enum "Categoría Registro Liq."; Mensaje: Text)
    begin
        Agregar("Severidad Registro Liq."::Información, Categoria, Mensaje, '', '', '', 0);
    end;

    procedure InfoImporte(Categoria: Enum "Categoría Registro Liq."; Mensaje: Text; CodConcepto: Code[20]; ImporteEntrada: Decimal)
    begin
        Agregar("Severidad Registro Liq."::Información, Categoria, Mensaje, '', CodConcepto, '', ImporteEntrada);
    end;

    procedure Advertir(Categoria: Enum "Categoría Registro Liq."; Mensaje: Text)
    begin
        Agregar("Severidad Registro Liq."::Advertencia, Categoria, Mensaje, '', '', '', 0);
    end;

    procedure AdvertirVariable(Categoria: Enum "Categoría Registro Liq."; Mensaje: Text; NombreVariable: Code[30]; CodConcepto: Code[20])
    begin
        Agregar("Severidad Registro Liq."::Advertencia, Categoria, Mensaje, '', CodConcepto, NombreVariable, 0);
    end;

    procedure RegistrarError(Categoria: Enum "Categoría Registro Liq."; Mensaje: Text; Detalle: Text)
    begin
        Agregar("Severidad Registro Liq."::Error, Categoria, Mensaje, Detalle, '', '', 0);
    end;

    /// <summary>
    /// Parte un texto con varias líneas (separadas por \) en una entrada por línea.
    /// </summary>
    /// <remarks>
    /// Es el puente con lo que ya existía: los avisos del motor y las advertencias de parámetros se
    /// venían armando como un solo texto con separadores. Una entrada por línea las hace filtrables
    /// y contables en vez de un bloque que hay que leer entero.
    /// </remarks>
    procedure AgregarTexto(Severidad: Enum "Severidad Registro Liq."; Categoria: Enum "Categoría Registro Liq."; Texto: Text)
    var
        Lineas: List of [Text];
        Linea: Text;
    begin
        if Texto = '' then
            exit;
        Lineas := Texto.Replace('\\', '\').Split('\');
        foreach Linea in Lineas do
            if Linea.Trim() <> '' then
                Agregar(Severidad, Categoria, Linea.Trim(), '', '', '', 0);
    end;

    local procedure Agregar(
        Severidad: Enum "Severidad Registro Liq.";
        Categoria: Enum "Categoría Registro Liq.";
        Mensaje: Text;
        Detalle: Text;
        CodConcepto: Code[20];
        NombreVariable: Code[30];
        ImporteEntrada: Decimal)
    var
        Siguiente: Integer;
    begin
        // Anotar sin proceso abierto no es un error del que valga la pena avisar: hay caminos de
        // cálculo que se invocan desde herramientas de diagnóstico, y ahí simplemente no hay dónde
        // guardar. Se descarta en silencio antes que reventar un cálculo por una anotación.
        if not FActivo then
            exit;
        if Mensaje = '' then
            exit;

        TempEntrada.Reset();
        if TempEntrada.FindLast() then
            Siguiente := TempEntrada."No. Línea" + 10000
        else
            Siguiente := 10000;

        TempEntrada.Init();
        TempEntrada."No. Registro" := 0;
        TempEntrada."No. Línea" := Siguiente;
        TempEntrada.Severidad := Severidad;
        TempEntrada.Categoría := Categoria;
        TempEntrada.Mensaje := CopyStr(Mensaje, 1, MaxStrLen(TempEntrada.Mensaje));
        TempEntrada.Detalle := CopyStr(Detalle, 1, MaxStrLen(TempEntrada.Detalle));
        TempEntrada."Cód. Concepto" := CodConcepto;
        TempEntrada."Nombre Variable" := NombreVariable;
        TempEntrada."Fecha Hora" := CurrentDateTime();
        TempEntrada.Importe := ImporteEntrada;
        TempEntrada.Insert();
    end;

    // ── Escritura ─────────────────────────────────────────────────────────────

    local procedure Escribir(ResultadoFinal: Enum "Severidad Registro Liq."; MensajeFinal: Text)
    var
        Registro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Errores: Integer;
        Advertencias: Integer;
    begin
        FActivo := false;
        ContarPorSeveridad(Errores, Advertencias);

        Registro.Init();
        Registro."No. Registro" := 0;
        Registro."No. Sesión" := FSesion;
        Registro."Tipo Proceso" := FTipoProceso;
        Registro."No. Liquidación" := FLiqNo;
        Registro."No. Empleado" := FEmpleadoNo;
        Registro."Nombre Empleado" := FNombreEmpleado;
        Registro."Cód. Período" := FCodPeriodo;
        Registro."Cód. Tipo Liq." := FCodTipoLiq;
        Registro."Fecha Hora Inicio" := FInicio;
        Registro."Fecha Hora Fin" := CurrentDateTime();
        Registro."Duración (ms)" := CalcularDuracion(Registro."Fecha Hora Fin");
        Registro.Usuario := CopyStr(UserId(), 1, MaxStrLen(Registro.Usuario));
        Registro.Resultado := ResultadoFinal;
        Registro."Cant. Errores" := Errores;
        Registro."Cant. Advertencias" := Advertencias;
        Registro.Mensaje := CopyStr(MensajeFinal, 1, MaxStrLen(Registro.Mensaje));
        Registro.Insert();
        FUltimoRegistro := Registro."No. Registro";

        TempEntrada.Reset();
        if TempEntrada.FindSet() then
            repeat
                Entrada := TempEntrada;
                Entrada."No. Registro" := Registro."No. Registro";
                Entrada.Insert();
            until TempEntrada.Next() = 0;

        FResumen := ArmarResumen(Registro);
        TempEntrada.Reset();
        TempEntrada.DeleteAll();
    end;

    local procedure CalcularDuracion(Fin: DateTime): Integer
    var
        Milisegundos: Duration;
    begin
        if FInicio = 0DT then
            exit(0);
        Milisegundos := Fin - FInicio;
        exit(Milisegundos div 1);
    end;

    local procedure ContarPorSeveridad(var Errores: Integer; var Advertencias: Integer)
    begin
        Errores := 0;
        Advertencias := 0;
        TempEntrada.Reset();
        TempEntrada.SetRange(Severidad, TempEntrada.Severidad::Error);
        Errores := TempEntrada.Count();
        TempEntrada.SetRange(Severidad, TempEntrada.Severidad::Advertencia);
        Advertencias := TempEntrada.Count();
        TempEntrada.Reset();
    end;

    local procedure SeveridadMaxima(): Enum "Severidad Registro Liq."
    begin
        TempEntrada.Reset();
        TempEntrada.SetCurrentKey("No. Registro", Severidad);
        if TempEntrada.FindLast() then begin
            // El enum está ordenado de menos a más grave, así que la última fila por severidad es la
            // peor que ocurrió.
            exit(TempEntrada.Severidad);
        end;
        exit("Severidad Registro Liq."::Información);
    end;

    local procedure MensajeResumen(): Text
    begin
        // Manda el primer error; si no hubo, la primera advertencia.
        TempEntrada.Reset();
        TempEntrada.SetCurrentKey("No. Registro", Severidad);
        TempEntrada.SetRange(Severidad, TempEntrada.Severidad::Error);
        if TempEntrada.FindFirst() then
            exit(TempEntrada.Mensaje);
        TempEntrada.SetRange(Severidad, TempEntrada.Severidad::Advertencia);
        if TempEntrada.FindFirst() then
            exit(TempEntrada.Mensaje);
        TempEntrada.Reset();
        exit(MsgSinDetalleTxt);
    end;

    local procedure ArmarResumen(Registro: Record "Registro Proceso Liq."): Text
    var
        Texto: TextBuilder;
    begin
        if (Registro."Cant. Errores" = 0) and (Registro."Cant. Advertencias" = 0) then
            exit('');

        TempEntrada.Reset();
        TempEntrada.SetFilter(Severidad, '<>%1', TempEntrada.Severidad::Información);
        if TempEntrada.FindSet() then
            repeat
                if Texto.Length() > 0 then
                    Texto.Append('\');
                Texto.Append(TempEntrada.Mensaje);
            until TempEntrada.Next() = 0;
        TempEntrada.Reset();
        exit(Texto.ToText());
    end;
}
