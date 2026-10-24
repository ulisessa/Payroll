namespace UAS.Payroll;

/// <summary>
/// Las operaciones de lote sobre Liquidación —calcular, reabrir, aprobar, eliminar— en un solo lugar.
/// </summary>
/// <remarks>
/// Estaban escritas dentro de Lista Liquidaciones. Cuando el Árbol de Liquidaciones necesitó las
/// mismas acciones sobre el nodo donde uno está parado, copiarlas habría sido otra copia de una
/// lógica que ya hubo que arreglar varias veces: el bucle que se cortaba al modificar el campo
/// filtrado, el Codeunit.Run que devuelve el registro sin filtros, la sesión de registro compartida.
///
/// Cada procedimiento recibe un Record "Liquidación" YA FILTRADO al alcance que se quiere procesar y
/// NO le toca los filtros. No es una cuestión de estilo: cuando el alcance viene de
/// CurrPage.SetSelectionFilter, la plataforma puede expresar la selección copiando los filtros de la
/// página, y volver a filtrar acá un campo que la página ya filtraba REEMPLAZA ese filtro en vez de
/// acotarlo — la selección se ensancharía sola. El estado se verifica registro por registro.
/// </remarks>
codeunit 50076 "Lotes Liquidación Liq."
{
    Access = Public;

    /// <summary>
    /// Calcula las liquidaciones del alcance que estén en Borrador, Calculada o Aprobada.
    /// </summary>
    procedure Calcular(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Progreso: Codeunit "Progreso Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Total: Integer;
        Procesadas: Integer;
        Calculadas: Integer;
        Fallidas: Integer;
        Omitidas: Integer;
    begin
        // En ORDEN DE CÁLCULO y no en el del alcance: el tope de SIPA, Ganancias y los francos leen
        // lo que ya está liquidado, así que quién corre primero cambia los importes. Ver
        // RecolectarNumerosEnOrdenDeCalculo.
        if not RecolectarNumerosEnOrdenDeCalculo(Origen, Numeros) then begin
            Message(MsgSinSeleccion);
            exit;
        end;
        Total := Numeros.Count();

        // Una corrida = una sesión: los registros quedan agrupados y se pueden mirar todos juntos
        // desde cualquiera de ellos.
        Registro.IniciarSesion();
        Progreso.AbrirLote(Total);
        foreach Numero in Numeros do begin
            if Liq.Get(Numero) then begin
                Procesadas += 1;
                // El nombre sale del campo desnormalizado de la propia liquidación: en un lote de
                // cientos, un Get contra Employee por vuelta sería una lectura de más por nada.
                Progreso.Registro(Liq."No.", Liq."No. Empleado" + '  ' + Liq."Nombre Empleado");

                // Solo Borrador. Una liquidación ya calculada —o aprobada— se omite: recalcular en
                // lote lo que ya estaba listo es trabajo perdido cuando el alcance son cientos, y
                // sobre todo es silencioso, porque nada distingue en el resultado lo que hacía falta
                // recalcular de lo que ya estaba bien. Para rehacer una, se la reabre y vuelve a
                // Borrador, que es la forma explícita de decir "esta hay que calcularla de nuevo".
                if Liq.Estado = Liq.Estado::Borrador then begin
                    if Motor.LiquidarConRegistro(Liq) then
                        Calculadas += 1
                    else
                        Fallidas += 1;
                end else
                    Omitidas += 1;
            end;
            Progreso.FinalizarRegistro();
        end;
        Progreso.Cerrar();

        // EL RESUMEN ENTRA AL REGISTRO, NO A UN CARTEL. Antes esto terminaba en dos o tres Message
        // encadenados que había que cerrar uno por uno y que no dejaban rastro: al aceptarlos, lo
        // que decían se perdía. Ahora son una entrada más de la sesión, así que el informe los
        // lleva adentro junto con los avisos de cada liquidación, y después quedan consultables
        // desde "Registros de proceso".
        //
        // VA ANTES DE MostrarAvisosDeLaSesion -para que el informe ya los incluya- y antes de
        // CerrarSesion, que es la que olvida el Guid.
        //
        // El tiempo sale del progreso, que lo congeló al cerrar: acá la ventana ya no está.
        if Omitidas > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Información, "Categoría Registro Liq."::General,
                StrSubstNo(MsgOmitidas, Omitidas));

        // Una liquidación que falla ya no aborta el lote: queda anotada y el proceso sigue. Antes,
        // un error en la número 50 se llevaba puestas las 49 anteriores.
        //
        // EL RESUMEN CON FALLAS VA COMO ADVERTENCIA Y NO COMO INFORMACIÓN, y no es cosmético: el
        // informe se abre contando advertencias y errores, así que una corrida con fallas lo abre
        // sola aunque no haya nada más que decir.
        if Fallidas > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::General,
                StrSubstNo(MsgCalculadasConFallas, Calculadas, Fallidas, Progreso.TranscurridoTexto()))
        else
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Información, "Categoría Registro Liq."::General,
                StrSubstNo(MsgCalculadas, Calculadas, Progreso.TranscurridoTexto()));

        Registro.MostrarAvisosDeLaSesion();
        Registro.CerrarSesion();
    end;

    /// <summary>
    /// Devuelve a Borrador las liquidaciones del alcance que estén en Calculada.
    /// </summary>
    procedure Reabrir(var Origen: Record "Liquidación")
    var
        Gestion: Codeunit "Gestión Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Reabiertas: Integer;
        Bloqueadas: Integer;
        Motivos: List of [Text];
        Motivo: Text;
        Detalle: Text;
        Mostrados: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccionReabrir);
            exit;
        end;

        Registro.IniciarSesion();
        Gestion.ReabrirSeleccion(Numeros, Reabiertas, Bloqueadas, Motivos);
        Registro.CerrarSesion();

        if Bloqueadas > 0 then begin
            // Los primeros cinco: en un lote grande la lista entera no cabe en un mensaje.
            foreach Motivo in Motivos do
                if Mostrados < 5 then begin
                    Detalle += '\' + Motivo;
                    Mostrados += 1;
                end;
            if Motivos.Count() > Mostrados then
                Detalle += StrSubstNo(TxtYMas, Motivos.Count() - Mostrados);
            Message(MsgReabiertasBloqueadas, Reabiertas, Numeros.Count(), Bloqueadas, Detalle);
        end else
            Message(MsgReabiertas, Reabiertas, Numeros.Count());
    end;

    /// <summary>
    /// Aprueba las liquidaciones del alcance que estén en Calculada.
    /// </summary>
    /// <remarks>
    /// A diferencia de Gestión Liquidación.Aprobar —que tira Error si el estado no es el esperado—
    /// acá las que no están en Calculada se omiten y se informan al final: en un lote es normal que
    /// convivan estados, y abortar por la primera dejaría el resto sin aprobar.
    /// </remarks>
    procedure Aprobar(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Aprobadas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccionAprobar);
            exit;
        end;

        Registro.IniciarSesion();
        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Calculada then begin
                    Gestion.Aprobar(Liq);
                    Aprobadas += 1;
                end;
        Registro.CerrarSesion();

        Message(MsgAprobadas, Aprobadas, Numeros.Count());
    end;

    /// <summary>
    /// Devuelve a Calculada las liquidaciones del alcance que estén Aprobadas. Pide una sola confirmación.
    /// </summary>
    /// <remarks>
    /// Las que no están Aprobadas (Contabilizadas incluidas) se omiten y se informan al final. La
    /// confirmación va acá y no por liquidación: Gestión Liquidación.RevertirAprobacion pregunta cada vez.
    /// </remarks>
    procedure RevertirAprobacion(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Revertidas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccionReabrir);
            exit;
        end;

        if not Confirm(StrSubstNo(QstRevertirAprobacion, Numeros.Count())) then
            exit;

        Registro.IniciarSesion();
        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Aprobada then begin
                    Gestion.RevertirAprobacionSinConfirmar(Liq);
                    Revertidas += 1;
                end;
        Registro.CerrarSesion();

        Message(MsgAprobacionesRevertidas, Revertidas, Numeros.Count());
    end;

    /// <summary>
    /// Elimina las liquidaciones del alcance que estén en Borrador. Pide confirmación.
    /// </summary>
    procedure Eliminar(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Eliminadas: Integer;
        Omitidas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then
            exit;

        // La pregunta lleva el tamaño del alcance: desde el árbol se puede estar parado en un nodo
        // de período, y "las seleccionadas" no da ninguna idea de si son tres o trescientas.
        if not Confirm(StrSubstNo(QstEliminar, Numeros.Count())) then
            exit;

        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Borrador then begin
                    Liq.Delete(true);
                    Eliminadas += 1;
                end else
                    Omitidas += 1;

        Message(MsgEliminadas, Eliminadas, Omitidas);
    end;

    /// <summary>Elimina únicamente borradores vacíos, injustificados y revisados por su PK y rowversion.</summary>
    /// <remarks>Petición: array de 1 a 10 objetos {numero, rowversion}, ambos textos. Sin filtros implícitos.</remarks>
    procedure EliminarBorradoresVaciosJson(Peticion: Text)
    var
        Filas: JsonArray;
        Token: JsonToken;
        Fila: JsonObject;
        Liq: Record "Liquidación";
        Numeros: List of [Code[20]];
        Revisiones: Dictionary of [Code[20], BigInteger];
        Claves: List of [Text];
        Numero: Code[20];
        Texto: Text;
        Revision: BigInteger;
    begin
        if StrLen(Peticion) > 10000 then
            Error('La petición excede el tamaño permitido.');
        if not Filas.ReadFrom(Peticion) then
            Error('La petición debe ser un array JSON de liquidaciones explícitas.');
        if (Filas.Count() < 1) or (Filas.Count() > 10) then
            Error('Indicá entre 1 y 10 liquidaciones explícitas.');
        foreach Token in Filas do begin
            if not Token.IsObject() then
                Error('Cada liquidación debe ser un objeto con numero y rowversion.');
            Fila := Token.AsObject();
            Claves := Fila.Keys();
            if Claves.Count() <> 2 then
                Error('Cada liquidación debe contener únicamente numero y rowversion.');
            Texto := LeerTextoBorradorJson(Fila, 'numero');
            if (Texto = '') or (StrLen(Texto) > MaxStrLen(Numero)) or (Texto <> Texto.Trim()) then
                Error('numero debe ser una clave explícita de hasta 20 caracteres, sin espacios exteriores.');
            Numero := CopyStr(Texto, 1, MaxStrLen(Numero));
            if Numeros.Contains(Numero) then
                Error('La petición repite la liquidación %1.', Numero);
            Texto := LeerTextoBorradorJson(Fila, 'rowversion');
            if not Evaluate(Revision, Texto, 9) then
                Error('rowversion debe ser una cadena con un entero positivo de 64 bits.');
            if (Revision <= 0) or (Format(Revision, 0, 9) <> Texto) then
                Error('rowversion debe ser una cadena con un entero positivo sin formato adicional.');
            Numeros.Add(Numero);
            Revisiones.Add(Numero, Revision);
        end;

        Liq.LockTable();
        // Validar TODO antes del primer Delete. Cualquier error revierte la llamada completa;
        // no usar TryFunction ni Commit: OnDelete conserva la limpieza y reversión normales.
        foreach Numero in Numeros do begin
            Liq.Get(Numero);
            ValidarBorradorVacio(Liq, Revisiones.Get(Numero));
        end;
        foreach Numero in Numeros do begin
            Liq.Get(Numero);
            Liq.Delete(true);
        end;
    end;

    local procedure LeerTextoBorradorJson(Fila: JsonObject; Campo: Text): Text
    var
        Token: JsonToken;
        Literal: Text;
    begin
        if not Fila.Get(Campo, Token) then
            Error('Falta el campo %1.', Campo);
        if not Token.IsValue() then
            Error('El campo %1 debe ser una cadena JSON.', Campo);
        Token.WriteTo(Literal);
        if CopyStr(Literal, 1, 1) <> '"' then
            Error('El campo %1 debe ser una cadena JSON.', Campo);
        exit(Token.AsValue().AsText());
    end;

    local procedure ValidarBorradorVacio(Liq: Record "Liquidación"; Revision: BigInteger)
    var
        Linea: Record "Línea Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Novedad: Record "Novedad Liquidación";
        Cuota: Record "Cuota Préstamo";
        Dependiente: Record "Liquidación";
        Movimiento: Record "Movimiento Franco Liq.";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Consumidor: Code[20];
    begin
        if Liq.SystemRowVersion <> Revision then
            Error('La liquidación %1 cambió desde la revisión.', Liq."No.");
        if Liq.Estado <> Liq.Estado::Borrador then
            Error('La liquidación %1 no está en Borrador.', Liq."No.");
        Liq.TestField("No. Empleado");
        Liq.TestField("Cód. Período");
        Liq.TestField("Cód. Tipo Liq.");
        Periodo.Get(Liq."Cód. Período");
        Periodo.TestField("Fecha Desde");
        Periodo.TestField("Fecha Hasta");
        if Periodo."Fecha Hasta" < Periodo."Fecha Desde" then
            Error('El período de %1 tiene fechas inválidas.', Liq."No.");
        Tipo.Get(Liq."Cód. Tipo Liq.");
        Liq.TestField("Total Haberes", 0);
        Liq.TestField("Total Descuentos", 0);
        Liq.TestField("Total Contribuciones", 0);
        Liq.TestField("Neto a Pagar", 0);
        Liq.TestField("Haberes Ordinarios Gravados", 0);
        Linea.LockTable();
        Linea.SetRange("No. Liquidación", Liq."No.");
        if not Linea.IsEmpty() then Error('La liquidación %1 tiene líneas.', Liq."No.");
        Incidencia.LockTable();
        Incidencia.SetRange("No. Liquidación", Liq."No.");
        if not Incidencia.IsEmpty() then Error('La liquidación %1 tiene incidencias.', Liq."No.");
        Novedad.LockTable();
        Novedad.SetRange("No. Liquidación", Liq."No.");
        if not Novedad.IsEmpty() then Error('La liquidación %1 tiene novedades vinculadas.', Liq."No.");
        // Guarda conservadora: tampoco retirar un destino potencial de novedades del empleado
        // o colectivas. No intenta duplicar la distribución por fechas/proyecto del motor.
        Novedad.Reset();
        Novedad.SetRange("Cód. Período", Liq."Cód. Período");
        Novedad.SetFilter(Estado, '<>%1', Novedad.Estado::Anulada);
        if Novedad.FindSet() then
            repeat
                // Una fila sin concepto ni cantidad/importe/unitario no aporta una novedad.
                // Un cero explícito con concepto, o un valor sin concepto, sigue bloqueando.
                if ((Novedad."Cód. Concepto" <> '') or (Novedad.Cantidad <> 0) or
                    (Novedad.Importe <> 0) or (Novedad."Valor Unitario" <> 0)) and
                   ((Novedad."No. Empleado" = '') or (Novedad."No. Empleado" = Liq."No. Empleado")) and
                   ((Novedad."Cód. Tipo Liq." = '') or (Novedad."Cód. Tipo Liq." = Liq."Cód. Tipo Liq."))
                then
                    Error('La liquidación %1 puede ser destino de novedades; revisalas antes de eliminarla.', Liq."No.");
            until Novedad.Next() = 0;
        Dependiente.SetRange("No. Liq. Origen", Liq."No.");
        if not Dependiente.IsEmpty() then Error('La liquidación %1 tiene otra liquidación dependiente.', Liq."No.");
        Cuota.LockTable();
        Cuota.SetRange("No. Liquidación", Liq."No.");
        if not Cuota.IsEmpty() then Error('La liquidación %1 es destino de cuotas.', Liq."No.");
        Cuota.SetRange("No. Liquidación");
        Cuota.SetRange("No. Liquidación Aplicada", Liq."No.");
        if not Cuota.IsEmpty() then Error('La liquidación %1 tiene cuotas aplicadas.', Liq."No.");
        Movimiento.LockTable();
        if not Cuenta.PuedeRevertir(Liq."No.", Consumidor) then
            Error('La liquidación %1 tiene un lote consumido por %2.', Liq."No.", Consumidor);
        if Proceso.EstadosJustifican(Liq."No. Empleado", Liq."Cód. Período", Liq."Cód. Tipo Liq.", Liq."No. Proyecto") then
            Error('Los estados todavía justifican la liquidación %1.', Liq."No.");
    end;

    /// <summary>
    /// Los números de liquidación del alcance, en una lista.
    /// </summary>
    /// <remarks>
    /// Las claves se juntan ANTES de tocar nada, y todos los bucles de este codeunit recorren la
    /// lista y no el registro. Hay dos razones distintas y las dos muerden:
    ///
    ///  · Reabrir y Eliminar cambian el Estado, que suele ser justo el campo por el que la página
    ///    está filtrada: al modificarlo el registro se cae del filtro y el Next() siguiente devuelve
    ///    0, así que el lote procesaba solo el primero y se cortaba sin avisar.
    ///  · Calcular resuelve con Ejecutor.Run(Liq), y un Codeunit.Run con parámetro de registro
    ///    devuelve el registro sin filtros ni marcas: después de la primera vuelta el recorrido se
    ///    escapaba del alcance y seguía por liquidaciones de otros períodos.
    /// </remarks>
    /// <summary>
    /// Igual que RecolectarNumeros, pero devuelve los números en el orden en que hay que CALCULARLOS:
    /// por empleado, dentro del empleado por período, y dentro del período por el Orden del Tipo de
    /// Liquidación.
    /// </summary>
    /// <remarks>
    /// EL ORDEN NO ES COSMÉTICO, decide importes. Varias cosas del cálculo leen lo que ya está
    /// liquidado y por lo tanto dependen de quién corrió primero:
    ///
    ///  - El TOPE DE SIPA sobre el SAC devengado (4751, 4752, 4753) se agota en el mes: la primera
    ///    liquidación consume el tope y la segunda no debe volver a aportar. Si la regular corre
    ///    antes que la de vacaciones, el reparto entre las dos sale distinto del de Meta4 —el total
    ///    del mes es el mismo, pero el recibo de cada una no—.
    ///  - GANANCIAS resta YTD_RETENIDO_ANUAL, que es lo retenido en las liquidaciones ANTERIORES.
    ///  - Los FRANCOS se consumen FIFO contra los lotes que haya en ese momento.
    ///
    /// Ordenado así, un lote da lo mismo que calcular cada liquidación a mano en el orden natural.
    /// Sin esto el alcance salía en orden de "No.", que es el de creación: una liquidación creada
    /// después podía calcularse antes que la que la precede en el mes.
    ///
    /// Se ordena con una clave de texto y no con una SetCurrentKey porque el Orden NO es un campo de
    /// Liquidación sino de Tipo Liquidación, y no hay forma de pedirle a la base que ordene por un
    /// campo de otra tabla. El +10000 rellena el Orden a cinco dígitos para que "2" no se ordene
    /// después de "10"; Tab50578 obliga a que el Orden sea único y en la práctica es de un dígito.
    /// </remarks>
    local procedure RecolectarNumerosEnOrdenDeCalculo(var Origen: Record "Liquidación"; var Numeros: List of [Code[20]]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
        OrdenPorTipo: Dictionary of [Code[20], Integer];
        Claves: List of [Text];
        Clave: Text;
        Orden: Integer;
    begin
        Clear(Numeros);
        Origen.SetLoadFields("No.", "No. Empleado", "Cód. Período", "Cód. Tipo Liq.");
        if not Origen.FindSet() then
            exit(false);
        repeat
            // El Orden se cachea por tipo: un lote de cientos comparte unos pocos tipos, y sin esto
            // sería un Get contra Tipo Liquidación por liquidación.
            if not OrdenPorTipo.ContainsKey(Origen."Cód. Tipo Liq.") then begin
                // Una liquidación sin tipo —las viejas, anteriores a la migración— queda con Orden 0
                // y por lo tanto primero, que es lo más parecido a "no sé, calculala antes".
                Orden := 0;
                if TipoLiq.Get(Origen."Cód. Tipo Liq.") then
                    Orden := TipoLiq.Orden;
                OrdenPorTipo.Add(Origen."Cód. Tipo Liq.", Orden);
            end;
            Claves.Add(
                Origen."No. Empleado" + '|' + Origen."Cód. Período" + '|' +
                Format(10000 + OrdenPorTipo.Get(Origen."Cód. Tipo Liq.")) + '|' + Origen."No.");
        until Origen.Next() = 0;

        OrdenarClaves(Claves);
        foreach Clave in Claves do
            Numeros.Add(CopyStr(Clave.Substring(Clave.LastIndexOf('|') + 1), 1, 20));
        exit(Numeros.Count() > 0);
    end;

    /// <summary>Ordena una lista de textos de menor a mayor, por inserción.</summary>
    /// <remarks>
    /// A mano porque el tipo List de AL NO TIENE Sort(): tiene Add, Get, Set, Contains y poco más.
    /// Es O(n²), y está bien para lo que ordena —un lote son cientos de liquidaciones, y unos miles
    /// de comparaciones de texto no se notan al lado de un solo cálculo—. Si algún día un lote fuera
    /// de decenas de miles, acá es donde hay que agrupar por clave en vez de ordenar fila por fila.
    ///
    /// EL WHILE ESTÁ PARTIDO A PROPÓSITO. La forma natural sería
    /// `while (j >= 1) and (Items.Get(j) > Actual)`, pero AL NO CORTOCIRCUITA: con j = 0 evalúa
    /// igual el segundo operando y Get(0) revienta por índice fuera de rango. El break adentro es
    /// lo que hace que la guarda sirva de algo.
    /// </remarks>
    local procedure OrdenarClaves(var Items: List of [Text])
    var
        i: Integer;
        j: Integer;
        Actual: Text;
    begin
        for i := 2 to Items.Count() do begin
            Actual := Items.Get(i);
            j := i - 1;
            while j >= 1 do begin
                if Items.Get(j) <= Actual then
                    break;
                Items.Set(j + 1, Items.Get(j));
                j -= 1;
            end;
            Items.Set(j + 1, Actual);
        end;
    end;

    local procedure RecolectarNumeros(var Origen: Record "Liquidación"; var Numeros: List of [Code[20]]): Boolean
    begin
        Clear(Numeros);
        Origen.SetLoadFields("No.");
        // Solo se junta la clave: el registro completo se relee después, uno por uno.
        if not Origen.FindSet() then
            exit(false);
        repeat
            Numeros.Add(Origen."No.");
        until Origen.Next() = 0;
        exit(true);
    end;

    var
        MsgSinSeleccion: Label 'No hay liquidaciones en el alcance seleccionado.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s).\\Tiempo total: %2.', Comment = '%1=cantidad, %2=duración del lote';
        MsgCalculadasConFallas: Label '%1 liquidación(es) calculada(s), %2 con error.\\Las que fallaron quedaron sin calcular; el motivo de cada una está en Registros de Proceso.\\Tiempo total: %3.', Comment = '%1=calculadas, %2=fallidas, %3=duración del lote';
        MsgOmitidas: Label '%1 liquidación(es) del alcance quedaron sin calcular porque no están en Borrador. Las que ya están calculadas o aprobadas no se rehacen solas: reabrilas si querés recalcularlas.';
        TxtYMas: Label '\...y %1 más.', Comment = '%1 = cantidad de bloqueadas no listadas';
        QstRevertirAprobacion: Label '¿Revertir la aprobación de las liquidaciones Aprobadas de las %1 del alcance? Vuelven a Calculada.', Comment = '%1=cantidad del alcance';
        MsgAprobacionesRevertidas: Label '%1 aprobación(es) revertida(s) sobre %2 del alcance. El resto no estaba en estado Aprobada.', Comment = '%1=revertidas, %2=alcance';
        MsgSinSeleccionReabrir: Label'No hay liquidaciones en el alcance seleccionado.';
        MsgReabiertas: Label '%1 liquidación(es) reabierta(s) sobre %2 del alcance. El resto no estaba en estado Calculada.';
        MsgReabiertasBloqueadas: Label '%1 liquidación(es) reabierta(s) sobre %2 del alcance.\\%3 no se reabrieron:%4\\Si es por una liquidación posterior, usá "Recalcular en cadena" desde el primer período afectado; si es por francos, incluí en la selección a la liquidación que los consume.', Comment = '%1=reabiertas, %2=alcance, %3=bloqueadas, %4=detalle por liquidación';
        MsgSinSeleccionAprobar: Label 'No hay liquidaciones en el alcance seleccionado.';
        MsgAprobadas: Label '%1 liquidación(es) aprobada(s) sobre %2 del alcance. El resto no estaba en estado Calculada.';
        QstEliminar: Label '¿Eliminar las liquidaciones en estado Borrador del alcance seleccionado (%1 en total)? Las que no estén en Borrador se omitirán.';
        MsgEliminadas: Label '%1 liquidación(es) eliminada(s). %2 omitida(s) por no estar en Borrador.';
        // Los #n# son campos de texto y el @n@ es la barra de avance, que va de 0 a 10000.
        // El campo del empleado va más ancho que el resto: lleva número y nombre, y recortado a 20
        // caracteres el apellido quedaba cortado justo en los casos que uno quiere reconocer.
}
