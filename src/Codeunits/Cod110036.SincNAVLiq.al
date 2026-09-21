namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Aplica sobre las tablas reales lo que el job de SQL Agent dejó en las tablas de staging.
/// Pensado para correr desatendido desde una Entrada de Proyecto (Job Queue) cada 15 minutos.
/// </summary>
/// <remarks>
/// La división de trabajo con el lado SQL es la que sostiene todo el diseño: el linked server sólo
/// transporta filas hasta el staging, y el alta contra Job, Employee y las tablas de descarga la
/// hace AL. Un MERGE directo contra las tablas de BC sería más corto y estaría mal: no crearía la
/// fase de alta en Estado Empleado —sin la cual la antigüedad da cero y los francos no devengan—,
/// no materializaría las Default Dimensions de Buque y Marea, no dispararía el cierre de
/// asignaciones al cargar la fecha de arribo, y dejaría al service tier sirviendo el caché viejo.
///
/// El orden de las entidades no es alfabético ni casual: un valor de dimensión tiene que existir
/// antes que el proyecto que lo usa, y un proyecto antes que su descarga. Lo que depende de algo que
/// todavía no llegó no falla, espera: queda en Pendiente con el motivo anotado y se vuelve a
/// intentar en la próxima corrida, hasta el máximo de intentos de Config. HHRR. Ahí sí pasa a Error,
/// que es un estado que alguien tiene que mirar.
///
/// Las cinco tablas de staging comparten a propósito los campos 90 a 95 —Estado Sinc, Observacion,
/// Intentos, Marca Origen, Traido El, Procesado El— con el mismo número y el mismo significado. Ese
/// contrato es lo que permite escribir el resultado con un solo procedimiento por RecordRef en vez
/// de cinco copias de lo mismo.
/// </remarks>
codeunit 110036 "Sinc NAV Liq."
{
    var
        TxtEsperaProyecto: Label 'Espera al proyecto %1, que todavía no llegó de NAV.', Comment = '%1 = No. de proyecto';
        TxtSinCodigoAlta: Label 'No se puede dar el alta: definí "Cód. Estado de Alta (Sinc. NAV)" en Config. Recursos Humanos. Hay más de un código activo de tipo Alta y la sincronización no elige por su cuenta.';
        TxtVencidoIntentos: Label 'Se agotaron los %1 intentos. Último motivo: %2', Comment = '%1 = intentos; %2 = motivo';
        TxtResumen: Label '%1 aplicadas, %2 en espera, %3 con error.', Comment = '%1 %2 %3 = cantidades';
        TxtNadaPendiente: Label 'Sin filas pendientes.';

    trigger OnRun()
    begin
        ProcesarTodo();
    end;

    /// <summary>
    /// Aplica todo lo pendiente, en orden de dependencia. Devuelve cuántas filas se aplicaron.
    /// </summary>
    procedure ProcesarTodo() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
    begin
        Ctrl.AsegurarFilas();
        // Los valores de dimensión van PRIMERO aunque su ordinal en el enum sea el último: el
        // proyecto los necesita existiendo antes de su Job.Validate. El ordinal no se puede
        // reordenar porque está guardado en "Ctrl Sinc NAV".Entidad y en el script T-SQL.
        Aplicadas += ProcesarValoresDim();
        Aplicadas += ProcesarEmpleados();
        Aplicadas += ProcesarProyectos();
        Aplicadas += ProcesarDescargasCab();
        Aplicadas += ProcesarDescargasLin();
        // El informe del capitán va después de las descargas por la misma razón de dependencia: su
        // clave es el proyecto, que tiene que existir. Entre cabecera y líneas, la cabecera primero.
        Aplicadas += ProcesarInformeCapCab();
        Aplicadas += ProcesarInformeCapLin();
        Aplicadas += ProcesarDiaAbordoCab();
        Aplicadas += ProcesarDiaAbordoLin();
    end;

    procedure ProcesarEntidad(Entidad: Enum "Entidad Sinc NAV"): Integer
    begin
        case Entidad of
            "Entidad Sinc NAV"::"Valor Dimension":
                exit(ProcesarValoresDim());
            "Entidad Sinc NAV"::Empleado:
                exit(ProcesarEmpleados());
            "Entidad Sinc NAV"::Proyecto:
                exit(ProcesarProyectos());
            "Entidad Sinc NAV"::"Descarga Cabecera":
                exit(ProcesarDescargasCab());
            "Entidad Sinc NAV"::"Descarga Linea":
                exit(ProcesarDescargasLin());
            "Entidad Sinc NAV"::"Informe Cap Cabecera":
                exit(ProcesarInformeCapCab());
            "Entidad Sinc NAV"::"Informe Cap Linea":
                exit(ProcesarInformeCapLin());
            "Entidad Sinc NAV"::"Dia Abordo Cabecera":
                exit(ProcesarDiaAbordoCab());
            "Entidad Sinc NAV"::"Dia Abordo Linea":
                exit(ProcesarDiaAbordoLin());
        end;
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Diario de abordo
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarDiaAbordoCab() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Dia Abordo Cab NAV";
        Job: Record Job;
        RecRef: RecordRef;
        Claves: List of [Code[20]];
        Clave: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Dia Abordo Cabecera") then
            exit(0);

        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                Claves.Add(Stg."No Proyecto");
            until Stg.Next() = 0;

        foreach Clave in Claves do
            if Stg.Get(Clave) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Dia Abordo Cabecera", Clave, 0, '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;

        RegistrarEnControl("Entidad Sinc NAV"::"Dia Abordo Cabecera", Aplicadas, EnEspera, ConError);
    end;

    local procedure ProcesarDiaAbordoLin() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Dia Abordo Lin NAV";
        Job: Record Job;
        RecRef: RecordRef;
        ClavesProyecto: List of [Code[20]];
        ClavesLinea: List of [Integer];
        Indice: Integer;
        NoProyecto: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Dia Abordo Linea") then
            exit(0);

        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                ClavesProyecto.Add(Stg."No Proyecto");
                ClavesLinea.Add(Stg."Line No");
            until Stg.Next() = 0;

        for Indice := 1 to ClavesProyecto.Count() do begin
            NoProyecto := ClavesProyecto.Get(Indice);
            if Stg.Get(NoProyecto, ClavesLinea.Get(Indice)) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Dia Abordo Linea", NoProyecto, ClavesLinea.Get(Indice), '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;
        end;

        RegistrarEnControl("Entidad Sinc NAV"::"Dia Abordo Linea", Aplicadas, EnEspera, ConError);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Informe del capitán
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarInformeCapCab() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Informe Cap Cab NAV";
        Job: Record Job;
        RecRef: RecordRef;
        Claves: List of [Code[20]];
        Clave: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Informe Cap Cabecera") then
            exit(0);

        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                Claves.Add(Stg."No Proyecto");
            until Stg.Next() = 0;

        foreach Clave in Claves do
            if Stg.Get(Clave) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Informe Cap Cabecera", Clave, 0, '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;

        RegistrarEnControl("Entidad Sinc NAV"::"Informe Cap Cabecera", Aplicadas, EnEspera, ConError);
    end;

    local procedure ProcesarInformeCapLin() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Informe Cap Lin NAV";
        Job: Record Job;
        RecRef: RecordRef;
        ClavesProyecto: List of [Code[20]];
        ClavesLinea: List of [Integer];
        Indice: Integer;
        NoProyecto: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Informe Cap Linea") then
            exit(0);

        // Clave compuesta: dos listas paralelas recorridas por índice, igual que en las líneas de
        // descarga. Concatenar en un texto obligaría a parsear después para volver a separar.
        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                ClavesProyecto.Add(Stg."No Proyecto");
                ClavesLinea.Add(Stg."Line No");
            until Stg.Next() = 0;

        for Indice := 1 to ClavesProyecto.Count() do begin
            NoProyecto := ClavesProyecto.Get(Indice);
            if Stg.Get(NoProyecto, ClavesLinea.Get(Indice)) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Informe Cap Linea", NoProyecto, ClavesLinea.Get(Indice), '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;
        end;

        RegistrarEnControl("Entidad Sinc NAV"::"Informe Cap Linea", Aplicadas, EnEspera, ConError);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Valores de dimensión
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarValoresDim() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Valor Dim NAV";
        RecRef: RecordRef;
        ClavesDim: List of [Code[20]];
        ClavesCod: List of [Code[20]];
        Indice: Integer;
        CodDim: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Valor Dimension") then
            exit(0);

        // Clave compuesta de dos códigos, en dos listas paralelas recorridas por índice: el mismo
        // patrón que las líneas de descarga, donde la segunda mitad es un entero.
        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                ClavesDim.Add(Stg."Cod Dimension");
                ClavesCod.Add(Stg.Codigo);
            until Stg.Next() = 0;

        for Indice := 1 to ClavesDim.Count() do begin
            CodDim := ClavesDim.Get(Indice);
            if Stg.Get(CodDim, ClavesCod.Get(Indice)) then begin
                RecRef.GetTable(Stg);
                if EjecutarFila("Entidad Sinc NAV"::"Valor Dimension", CodDim, 0, '', ClavesCod.Get(Indice), RecRef) then
                    Aplicadas += 1
                else
                    ConError += 1;
            end;
        end;

        RegistrarEnControl("Entidad Sinc NAV"::"Valor Dimension", Aplicadas, EnEspera, ConError);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Empleados
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarEmpleados() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Empleado NAV";
        Empl: Record Employee;
        RecRef: RecordRef;
        Claves: List of [Code[20]];
        Clave: Code[20];
        CodAlta: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::Empleado) then
            exit(0);

        Claves := ClavesPendientesEmpleado();
        CodAlta := ResolverCodEstadoAlta();

        foreach Clave in Claves do
            if Stg.Get(Clave) then begin
                RecRef.GetTable(Stg);
                // Sin código de alta no se crea el empleado: quedaría en la lista sin fase abierta y
                // liquidando con antigüedad cero, que es peor que no estar. Las modificaciones de
                // empleados que ya existen siguen pasando, porque ésas no abren ninguna fase.
                if (CodAlta = '') and not Empl.Get(Clave) then begin
                    MarcarResultado(RecRef, "Estado Sinc NAV"::Error, TxtSinCodigoAlta, false);
                    ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::Empleado, Clave, 0, CodAlta, '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;

        RegistrarEnControl("Entidad Sinc NAV"::Empleado, Aplicadas, EnEspera, ConError);
    end;

    local procedure ClavesPendientesEmpleado() Claves: List of [Code[20]]
    var
        Stg: Record "Stg Empleado NAV";
    begin
        // Las claves se juntan ANTES de aplicar. El filtro es por "Estado Sinc" = Pendiente y el
        // proceso escribe justamente ese campo: iterando el registro directo, la primera fila que se
        // marca como procesada se sale del conjunto filtrado y el recorrido corta ahí.
        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                Claves.Add(Stg."No Empleado");
            until Stg.Next() = 0;
    end;

    local procedure ResolverCodEstadoAlta(): Code[20]
    var
        HRSetup: Record "Human Resources Setup";
        CodEstado: Record "Cód. Estado Empleado";
    begin
        if HRSetup.Get() then
            if HRSetup."Cód. Estado Alta Sinc." <> '' then
                exit(HRSetup."Cód. Estado Alta Sinc.");

        // Sin configuración explícita se acepta el caso obvio —hay un solo código de alta activo— y
        // se corta en el ambiguo. Elegir el primero de varios sería adivinar con qué código se abre
        // la antigüedad de una persona.
        CodEstado.SetRange("Tipo Estado", CodEstado."Tipo Estado"::Alta);
        CodEstado.SetRange(Activo, true);
        if CodEstado.Count() = 1 then begin
            CodEstado.FindFirst();
            exit(CodEstado.Código);
        end;

        exit('');
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Proyectos
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarProyectos() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Proyecto NAV";
        RecRef: RecordRef;
        Claves: List of [Code[20]];
        Clave: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::Proyecto) then
            exit(0);

        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                Claves.Add(Stg."No Proyecto");
            until Stg.Next() = 0;

        foreach Clave in Claves do
            if Stg.Get(Clave) then begin
                RecRef.GetTable(Stg);
                if EjecutarFila("Entidad Sinc NAV"::Proyecto, Clave, 0, '', '', RecRef) then
                    Aplicadas += 1
                else
                    ConError += 1;
            end;

        RegistrarEnControl("Entidad Sinc NAV"::Proyecto, Aplicadas, EnEspera, ConError);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Descargas
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure ProcesarDescargasCab() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Descarga Cab NAV";
        Job: Record Job;
        RecRef: RecordRef;
        Claves: List of [Code[20]];
        Clave: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Descarga Cabecera") then
            exit(0);

        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                Claves.Add(Stg."No Proyecto");
            until Stg.Next() = 0;

        foreach Clave in Claves do
            if Stg.Get(Clave) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Descarga Cabecera", Clave, 0, '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;

        RegistrarEnControl("Entidad Sinc NAV"::"Descarga Cabecera", Aplicadas, EnEspera, ConError);
    end;

    local procedure ProcesarDescargasLin() Aplicadas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Stg: Record "Stg Descarga Lin NAV";
        Job: Record Job;
        RecRef: RecordRef;
        ClavesProyecto: List of [Code[20]];
        ClavesLinea: List of [Integer];
        Indice: Integer;
        NoProyecto: Code[20];
        EnEspera: Integer;
        ConError: Integer;
    begin
        if not Ctrl.ObtenerHabilitada("Entidad Sinc NAV"::"Descarga Linea") then
            exit(0);

        // Clave compuesta: dos listas paralelas recorridas por índice. Un solo texto concatenado
        // sería más corto y obligaría a parsear después para volver a separar proyecto de línea.
        Stg.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
        if Stg.FindSet() then
            repeat
                ClavesProyecto.Add(Stg."No Proyecto");
                ClavesLinea.Add(Stg."Line No");
            until Stg.Next() = 0;

        for Indice := 1 to ClavesProyecto.Count() do begin
            NoProyecto := ClavesProyecto.Get(Indice);
            if Stg.Get(NoProyecto, ClavesLinea.Get(Indice)) then begin
                RecRef.GetTable(Stg);
                if not Job.Get(Stg."No Proyecto") then begin
                    if Diferir(RecRef, StrSubstNo(TxtEsperaProyecto, Stg."No Proyecto")) then
                        EnEspera += 1
                    else
                        ConError += 1;
                end else
                    if EjecutarFila("Entidad Sinc NAV"::"Descarga Linea", NoProyecto, ClavesLinea.Get(Indice), '', '', RecRef) then
                        Aplicadas += 1
                    else
                        ConError += 1;
            end;
        end;

        RegistrarEnControl("Entidad Sinc NAV"::"Descarga Linea", Aplicadas, EnEspera, ConError);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Reproceso manual
    // ────────────────────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Devuelve a Pendiente las filas en Error de una entidad y les pone el contador de intentos en
    /// cero. Es explícito a propósito: una fila que falló no se reintenta sola.
    /// </summary>
    procedure ReprocesarErrores(Entidad: Enum "Entidad Sinc NAV") Reabiertas: Integer
    var
        StgEmp: Record "Stg Empleado NAV";
        StgProy: Record "Stg Proyecto NAV";
        StgCab: Record "Stg Descarga Cab NAV";
        StgLin: Record "Stg Descarga Lin NAV";
        StgDim: Record "Stg Valor Dim NAV";
        RecRef: RecordRef;
        FldEstado: FieldRef;
        FldIntentos: FieldRef;
        Posiciones: List of [Text];
        Posicion: Text;
    begin
        case Entidad of
            "Entidad Sinc NAV"::"Valor Dimension":
                RecRef.GetTable(StgDim);
            "Entidad Sinc NAV"::Empleado:
                RecRef.GetTable(StgEmp);
            "Entidad Sinc NAV"::Proyecto:
                RecRef.GetTable(StgProy);
            "Entidad Sinc NAV"::"Descarga Cabecera":
                RecRef.GetTable(StgCab);
            "Entidad Sinc NAV"::"Descarga Linea":
                RecRef.GetTable(StgLin);
        end;

        FldEstado := RecRef.Field(90);
        FldIntentos := RecRef.Field(92);

        // Mismo cuidado que en el proceso: el filtro es por el campo que se va a escribir, así que
        // primero se juntan las posiciones y recién después se toca nada. Con RecordRef la posición
        // es la clave primaria serializada, y sirve igual para las cuatro tablas.
        FldEstado.SetRange("Estado Sinc NAV"::Error);
        if RecRef.FindSet() then
            repeat
                Posiciones.Add(RecRef.GetPosition());
            until RecRef.Next() = 0;

        RecRef.Reset();
        foreach Posicion in Posiciones do begin
            RecRef.SetPosition(Posicion);
            if RecRef.Find('=') then begin
                FldEstado.Value := "Estado Sinc NAV"::Pendiente.AsInteger();
                FldIntentos.Value := 0;
                RecRef.Modify(true);
                Reabiertas += 1;
            end;
        end;
        RecRef.Close();
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Motor común
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure EjecutarFila(Entidad: Enum "Entidad Sinc NAV"; Clave1: Code[20]; Clave2: Integer; CodAlta: Code[20]; Clave3: Code[20]; var RecRef: RecordRef): Boolean
    var
        Aplicador: Codeunit "Aplicar Fila Sinc NAV";
        SinDialogo: Codeunit "Sin Dialogo Dim Job";
        Aplicada: Boolean;
    begin
        // Clear antes de cada fila: la instancia se reusa en todo el lote y no puede arrastrar el
        // contexto de la anterior.
        Clear(Aplicador);
        Aplicador.SetContexto(Entidad, Clave1, Clave2, CodAlta, Clave3);

        // COMMIT ANTES DEL RUN, y no es opcional. BC prohíbe leer el valor de retorno de
        // Codeunit.Run() con una transacción de escritura abierta —el "OK := Codeunit.Run() no está
        // permitido" del mensaje—, porque el Run necesita bloquear tablas que la transacción ya
        // tiene tomadas. Y acá el valor de retorno ES el mecanismo: es lo que distingue la fila que
        // se aplicó de la que hay que anotar en Error.
        //
        // Cuando el lote empieza siempre hay escrituras pendientes de la etapa anterior:
        // Ctrl.AsegurarFilas() en ProcesarTodo, y el RegistrarEnControl de la entidad previa. De la
        // segunda fila en adelante no haría falta —MarcarResultado confirma cada una— pero el commit
        // va igual en todas: es una línea contra depender de que ninguna otra ruta escriba antes.
        //
        // No se pierde nada: cada fila ya era su propia unidad de trabajo por diseño.
        Commit();

        // EL INTERRUPTOR DEL DIÁLOGO DE DIMENSIONES VA ACÁ Y NO ADENTRO DEL APLICADOR, aunque sólo le
        // sirva a los proyectos. La razón es que tiene que apagarse SIEMPRE: la codeunit que lo
        // guarda es SingleInstance y vive lo que dura la sesión, así que si se prendiera adentro y
        // esa fila fallara, quedaría prendido para todo lo que el usuario haga después —incluida la
        // edición a mano de un proyecto, donde el diálogo sí tiene que aparecer—. Acá, entre el Run
        // y su resultado, el apagado no depende de cómo haya salido la fila.
        SinDialogo.Activar();
        Aplicada := Aplicador.Run();
        SinDialogo.Desactivar();

        // Sin relanzar: una fila que falla queda anotada con su error y el lote sigue, en vez de
        // abortar y perder todo lo aplicado hasta ese punto.
        if Aplicada then begin
            MarcarResultado(RecRef, "Estado Sinc NAV"::Procesado, Aplicador.GetAviso(), false);
            exit(true);
        end;

        MarcarResultado(RecRef, "Estado Sinc NAV"::Error, GetLastErrorText(), true);
        exit(false);
    end;

    /// <summary>
    /// Deja la fila esperando otra corrida. Devuelve false cuando ya no quedan intentos y la fila
    /// pasó a Error.
    /// </summary>
    local procedure Diferir(var RecRef: RecordRef; Motivo: Text): Boolean
    var
        HRSetup: Record "Human Resources Setup";
        FldIntentos: FieldRef;
        Intentos: Integer;
        MaxIntentos: Integer;
    begin
        FldIntentos := RecRef.Field(92);
        Intentos := FldIntentos.Value();

        MaxIntentos := 5;
        if HRSetup.Get() then
            if HRSetup."Máx. Intentos Sinc." > 0 then
                MaxIntentos := HRSetup."Máx. Intentos Sinc.";

        if Intentos + 1 >= MaxIntentos then begin
            MarcarResultado(RecRef, "Estado Sinc NAV"::Error, StrSubstNo(TxtVencidoIntentos, MaxIntentos, Motivo), true);
            exit(false);
        end;

        MarcarResultado(RecRef, "Estado Sinc NAV"::Pendiente, Motivo, true);
        exit(true);
    end;

    local procedure MarcarResultado(var RecRef: RecordRef; EstadoNuevo: Enum "Estado Sinc NAV"; Observacion: Text; SumaIntento: Boolean)
    var
        FldEstado: FieldRef;
        FldObservacion: FieldRef;
        FldIntentos: FieldRef;
        FldProcesado: FieldRef;
        Intentos: Integer;
    begin
        // RELEER ANTES DE ESCRIBIR, y no es una precaución de más.
        //
        // Entre que la fila se leyó y se anota el resultado pasan un Commit y un Codeunit.Run que
        // puede fallar y revertir. Si la copia en memoria queda con una versión anterior a la de la
        // base, el Modify no escribe: falla con "otro usuario modificó el registro".
        //
        // Y eso es mucho peor que perder una anotación. Lo que MarcarResultado escribe cuando el Run
        // falló es el MOTIVO del fallo; si ese Modify revienta, el error se propaga hacia arriba y se
        // lleva puesta la corrida entera — el Job Queue queda en Error, las 4476 filas buenas no se
        // aplican, y en ningún lado queda escrito qué fila tenía el problema ni cuál era. Una fila
        // mala pasa a ser un lote muerto sin diagnóstico.
        //
        // Si la fila ya no está, no hay nada que anotar y tampoco hay por qué romper.
        if not RecRef.Find('=') then
            exit;

        FldEstado := RecRef.Field(90);
        FldObservacion := RecRef.Field(91);
        FldIntentos := RecRef.Field(92);
        FldProcesado := RecRef.Field(95);

        FldEstado.Value := EstadoNuevo.AsInteger();
        FldObservacion.Value := CopyStr(Observacion, 1, 250);
        if SumaIntento then begin
            Intentos := FldIntentos.Value();
            FldIntentos.Value := Intentos + 1;
        end;
        FldProcesado.Value := CurrentDateTime();
        RecRef.Modify(true);

        // Cada fila se confirma sola. En un lote largo es lo que evita que un error a mitad de
        // camino se lleve puestas las que ya estaban bien aplicadas.
        Commit();
    end;

    local procedure RegistrarEnControl(Entidad: Enum "Entidad Sinc NAV"; Aplicadas: Integer; EnEspera: Integer; ConError: Integer)
    var
        Ctrl: Record "Ctrl Sinc NAV";
    begin
        if not Ctrl.Get(Entidad) then
            exit;
        if (Aplicadas = 0) and (EnEspera = 0) and (ConError = 0) then
            Ctrl.RegistrarProceso(0, TxtNadaPendiente)
        else
            Ctrl.RegistrarProceso(Aplicadas, StrSubstNo(TxtResumen, Aplicadas, EnEspera, ConError));
    end;
}
