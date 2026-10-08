namespace UAS.Payroll;

codeunit 50055 "Gestión Tipo Liq."
{
    // Seeds the Tipo Liquidación master. Idempotent: safe to run on install and on upgrade.
    // The enum→code migration (EnumACodigo, Liq/Lin conversion) that used to live here was removed once
    // the old Enum "Tipos Liquidación" and its Liquidación/Línea fields were deleted — run this BEFORE
    // that deletion ships if any data hasn't been migrated yet, or it's lost.

    procedure Sembrar()
    begin
        Agregar('REGULAR', 'Regular', 10, false, true);
        Agregar('AGUINALDO', 'Aguinaldo', 20, false, false);
        Agregar('VACACIONES', 'Vacaciones', 30, false, false);
        Agregar('LIQ_FINAL', 'Liquidación Final', 40, false, false);
        Agregar('RELIQUIDACION', 'Reliquidación', 50, false, false);
        Agregar('DEVENGADOS', 'Devengados', 60, false, false);
        Agregar('CIERRE_MAREA', 'Cierre Marea', 70, true, false);
    end;

    /// <summary>
    /// Pasa las banderas viejas al Disparador y deja configurado cuándo corresponde cada tipo.
    /// </summary>
    /// <remarks>
    /// IDEMPOTENTE Y NO PISA LO CARGADO A MANO: el disparador sólo se completa si está en Ninguno, y
    /// las líneas de estado sólo se crean si el tipo no tiene ninguna. Alguien que ajustó la
    /// configuración no se la encuentra revertida en el próximo upgrade.
    ///
    /// POR QUÉ ESTOS VALORES. Vienen de cómo se liquida acá, no de una teoría:
    ///   · Cierre de marea y Devengados ya se resolvían con los filtros de proyecto y de personal;
    ///     sólo cambian de bandera a Disparador.
    ///   · Liquidación final corre todos los meses pero sólo para quien se fue: disparador Baja.
    ///   · Aguinaldo es semestral y no depende del empleado: va por el calendario.
    ///   · Regular es para el que tiene días que NO son de una marea — los de marea los paga su
    ///     Cierre — y por eso pide un estado cuyo proyecto no sea productivo.
    ///   · Vacaciones se paga si las toma este mes O si las va a tomar el que viene, que es el caso
    ///     del pago anticipado. Dos líneas del mismo tipo, no dos tipos.
    ///   · Saldo inicial, Hist. Remun. y Reliquidación NO entran en la corrida: los dos primeros son
    ///     de una sola vez, y la reliquidación no la dispara ningún hecho del empleado sino un cambio
    ///     POSTERIOR al cálculo. Se crean a mano.
    /// </remarks>
    procedure ConfigurarDisparadores()
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        // El disparador sale de las banderas que ya estaban, para no depender de que el código del
        // tipo se llame como acá: quien liquidaba al arribo sigue liquidando al arribo.
        if TipoLiq.FindSet(true) then
            repeat
                if TipoLiq.Disparador = TipoLiq.Disparador::Ninguno then begin
                    if TipoLiq."Liquida al Arribo" then
                        TipoLiq.Disparador := TipoLiq.Disparador::Arribo
                    else
                        if TipoLiq."Sólo Proyectos en Curso" then
                            TipoLiq.Disparador := TipoLiq.Disparador::MareaEnCurso;
                    TipoLiq.Modify();
                end;
            until TipoLiq.Next() = 0;

        Disparador('LIQ_FINAL', TipoLiq.Disparador::BajaEmpleado);
        EntraEnCorrida('CIERRE_MAREA', '');
        EntraEnCorrida('DEVENGADOS', '');
        EntraEnCorrida('REGULAR', '');
        EntraEnCorrida('VACACIONES', '');
        EntraEnCorrida('LIQ_FINAL', '');
        EntraEnCorrida('AGUINALDO', '6|12');

        // EL RECIBO DE VACACIONES ES SÓLO PARA EMBARCADOS. Al mensualizado no se le emite documento
        // aparte: cobra el haber de vacaciones y el descuento de días en su propio recibo mensual,
        // que es lo que hace Meta4. Emitiéndoselo, cobraba las dos cosas enteras —el 90016 en enero
        // de 2026 daba 50.381.512,84 contra los 24.208.252,13 de Meta4, más del doble— y el
        // descuento de días no lo corregía: la condición del 4743 es "HAY_LIQ_VACACIONES = 0", o sea
        // que se apaga justo cuando el documento existe.
        AplicarA('VACACIONES', "Aplica A Liq."::Tripulante);

        // Un estado del mes que no venga de una marea: los días de marea los paga el Cierre.
        ExigirEstado('REGULAR', '', "Ventana Estado Tipo Liq."::Periodo, 2, 'Días que no son de una marea');
        // LA REGLA VIEJA SE RETIRA ANTES DE SEMBRAR LA NUEVA, y no es una limpieza cosmética.
        //
        // Las líneas "Exige" se combinan con O. Si una instalación que ya corrió conserva la línea de
        // ventana MesSiguiente, la nueva no la reemplaza: se SUMA, y los empleados siguen entrando
        // por la vieja. Una instalación actualizada quedaría con una regla distinta de una nueva, que
        // es exactamente lo que este procedimiento existe para evitar.
        //
        // ExigirEstado converge por (tipo, estado, ventana), así que nunca podría tocar una línea de
        // otra ventana: retirarla hay que pedirlo.
        RetirarEstado('VACACIONES', 'AU9', "Ventana Estado Tipo Liq."::MesSiguiente);

        // EL RECIBO DE VACACIONES VA EN EL MES EN QUE LAS VACACIONES EMPIEZAN, y el último true es lo
        // que lo dice: el AU9 tiene que ARRANCAR dentro del período, no rozarlo.
        //
        // Las dos mitades de esa frase costaron una corrida cada una:
        //
        //   Sin "Empieza en la Ventana", la línea pedía solapamiento y entraba cualquiera que tuviera
        //   vacaciones tocando el mes —incluido el que las empezó en diciembre—.
        //
        //   Con ventana MesSiguiente, el recibo salía un mes ANTES de las vacaciones. Medido contra
        //   Meta4 en enero de 2026: de los 63 empleados cuyo AU9 empieza en febrero, 54 tienen su
        //   corrida aparte en FEBRERO y sólo 1 en enero. Y de los 82 cuyo AU9 empieza en enero, 64
        //   tienen corrida aparte ese mismo enero. El recibo acompaña al comienzo de las vacaciones.
        //
        // Que se pague por adelantado es cierto y es la regla del negocio —la fecha de pago precede
        // al inicio del descanso—, pero no se puede leer de la fecha de la liquidación: BC estampa
        // todas con el último día del período. Lo que sí se puede leer es en qué mes arrancan.
        //
        // Los 18 de los 82 que en Meta4 van DENTRO de la mensual son otra decisión, y la resuelve
        // HAY_LIQ_VACACIONES en la condición de los conceptos, no esta línea.
        ExigirEstado('VACACIONES', 'AU9', "Ventana Estado Tipo Liq."::Periodo, 0, 'Las vacaciones empiezan dentro del período', true);
    end;

    local procedure Disparador(Codigo: Code[20]; Valor: Enum "Disparador Tipo Liq.")
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if not TipoLiq.Get(Codigo) then exit;
        if TipoLiq.Disparador <> TipoLiq.Disparador::Ninguno then exit;
        TipoLiq.Disparador := Valor;
        TipoLiq.Modify();
    end;

    /// <summary>
    /// Deja el tipo restringido a una clase de empleado. CONVERGE: si está en otro valor lo cambia.
    /// </summary>
    /// <remarks>
    /// Va sin guarda de "si ya tiene algo no lo toco", a diferencia de Disparador y EntraEnCorrida,
    /// por la misma razón que RetirarEstado: una instalación ya corrida tiene el campo en "Todos"
    /// —el valor inicial del enum— y con una guarda permisiva nunca llegaría al valor bueno. Es
    /// configuración que el producto define, no una preferencia del usuario.
    /// </remarks>
    local procedure AplicarA(Codigo: Code[20]; Valor: Enum "Aplica A Liq.")
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if not TipoLiq.Get(Codigo) then exit;
        if TipoLiq."Aplica A" = Valor then exit;
        TipoLiq."Aplica A" := Valor;
        TipoLiq.Modify();
    end;

    local procedure EntraEnCorrida(Codigo: Code[20]; Meses: Text[30])
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if not TipoLiq.Get(Codigo) then exit;
        if TipoLiq."Entra en Corrida Completa" then exit;
        TipoLiq."Entra en Corrida Completa" := true;
        if TipoLiq.Meses = '' then
            TipoLiq.Meses := Meses;
        TipoLiq.Modify();
    end;

    local procedure ExigirEstado(CodTipo: Code[20]; CodEstado: Code[20]; Ventana: Enum "Ventana Estado Tipo Liq."; TipoProyecto: Integer; Desc: Text[100])
    begin
        ExigirEstado(CodTipo, CodEstado, Ventana, TipoProyecto, Desc, false);
    end;

    /// <summary>
    /// Retira una línea de estado que este sembrador ya no declara. Devuelve cuántas borró.
    /// </summary>
    /// <remarks>
    /// EXISTE PORQUE SEMBRAR NO ES CONVERGER. ExigirEstado empareja por (tipo, estado, ventana), así
    /// que una regla que cambió de ventana no se pisa: queda la vieja y se agrega la nueva. Y como
    /// las líneas "Exige" se combinan con O, la vieja sigue admitiendo empleados. El resultado es que
    /// una instalación actualizada se comporta distinto de una nueva, sin que nada falle.
    ///
    /// Se retira SÓLO lo que se nombra acá arriba, una regla por vez y a propósito. La alternativa
    /// —borrar todas las líneas del tipo y volver a sembrarlas— también dejaría los dos casos
    /// iguales, pero se llevaría puesta cualquier línea que alguien haya agregado a mano en la
    /// página, que es una configuración legítima y no una herencia a limpiar.
    /// </remarks>
    local procedure RetirarEstado(CodTipo: Code[20]; CodEstado: Code[20]; Ventana: Enum "Ventana Estado Tipo Liq.") Retiradas: Integer
    var
        Linea: Record "Estado Tipo Liq.";
    begin
        Linea.SetRange("Cód. Tipo Liq.", CodTipo);
        Linea.SetRange("Cód. Estado", CodEstado);
        Linea.SetRange(Ventana, Ventana);
        // Se cuenta ANTES: DeleteAll no devuelve cuántas borró.
        Retiradas := Linea.Count();
        if Retiradas > 0 then
            Linea.DeleteAll(true);
    end;

    /// <summary>
    /// Siembra una línea de estado exigido. Con Empieza = true la línea pide que el estado ARRANQUE
    /// dentro de la ventana, no que la roce.
    /// </summary>
    /// <remarks>
    /// CONVERGE, no sólo crea. Antes salía si ya existía una línea igual, y eso alcanzaba mientras
    /// los calificadores no cambiaran. Al agregar "Empieza en la Ventana" dejó de alcanzar: la línea
    /// de vacaciones ya existía sin la bandera, así que un seeder que sólo inserta la dejaría
    /// exactamente como estaba y el upgrade no arreglaría nada en las instalaciones que ya corrieron.
    /// </remarks>
    local procedure ExigirEstado(CodTipo: Code[20]; CodEstado: Code[20]; Ventana: Enum "Ventana Estado Tipo Liq."; TipoProyecto: Integer; Desc: Text[100]; Empieza: Boolean)
    var
        TipoLiq: Record "Tipo Liquidación";
        Linea: Record "Estado Tipo Liq.";
    begin
        if not TipoLiq.Get(CodTipo) then exit;
        // Si el tipo ya tiene una línea igual, no se duplica; si tiene otras, se respetan.
        Linea.SetRange("Cód. Tipo Liq.", CodTipo);
        Linea.SetRange("Cód. Estado", CodEstado);
        Linea.SetRange(Ventana, Ventana);
        if Linea.FindFirst() then begin
            if Linea."Empieza en la Ventana" <> Empieza then begin
                Linea."Empieza en la Ventana" := Empieza;
                Linea.Descripción := Desc;
                Linea.Modify(true);
            end;
            exit;
        end;

        Linea.Init();
        Linea."Cód. Tipo Liq." := CodTipo;
        Linea.Modo := Linea.Modo::Exige;
        Linea."Cód. Estado" := CodEstado;
        Linea.Ventana := Ventana;
        Linea."Tipo Proyecto" := TipoProyecto;
        Linea.Descripción := Desc;
        Linea."Empieza en la Ventana" := Empieza;
        Linea.Insert(true);
    end;

    local procedure Agregar(Codigo: Code[20]; Desc: Text[50]; Orden: Integer; LiquidaArribo: Boolean; IncluyeFrancos: Boolean)
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if TipoLiq.Get(Codigo) then
            exit;
        TipoLiq.Init();
        TipoLiq.Código := Codigo;
        TipoLiq.Descripción := Desc;
        TipoLiq.Orden := Orden;
        // SIEMBRA EL DISPARADOR Y NO LA BANDERA OBSOLETA. En una instalación nueva el Upgrade que
        // deriva el Disparador de las banderas viejas no corre —no hay nada viejo que migrar—, así
        // que sembrar sólo la bandera dejaba el tipo con Disparador = Ninguno y CodigoArribo(), que
        // ahora lee el Disparador, no lo encontraba.
        if LiquidaArribo then
            TipoLiq.Disparador := TipoLiq.Disparador::Arribo;
        TipoLiq."Incluye Francos Puerto" := IncluyeFrancos;
        TipoLiq.Activo := true;
        TipoLiq.Insert();
    end;

    // Keeps any stray old-format (enum caption) text in Concepto."Tipos Liq. Aplicables" migrated to
    // codes. Harmless/idempotent to rerun — codes never match the caption text being replaced.
    procedure MigrarDatos()
    var
        Concepto: Record "Concepto Liquidación";
        NuevoTexto: Text[250];
    begin
        if Concepto.FindSet(true) then
            repeat
                NuevoTexto := NombresACodigos(Concepto."Tipos Liq. Aplicables");
                if NuevoTexto <> Concepto."Tipos Liq. Aplicables" then begin
                    Concepto."Tipos Liq. Aplicables" := NuevoTexto;
                    Concepto.Modify();
                end;
            until Concepto.Next() = 0;
    end;

    // Replaces the old enum captions with the new codes in a pipe-delimited "Tipos Liq. Aplicables" string.
    // Case-sensitive replace makes it idempotent (already-migrated codes don't match the captions).
    local procedure NombresACodigos(Texto: Text[250]): Text[250]
    begin
        if Texto = '' then exit('');
        Texto := Texto.Replace('Cierre Marea', 'CIERRE_MAREA');
        Texto := Texto.Replace('Liquidación Final', 'LIQ_FINAL');
        Texto := Texto.Replace('Reliquidación', 'RELIQUIDACION');
        Texto := Texto.Replace('Aguinaldo', 'AGUINALDO');
        Texto := Texto.Replace('Vacaciones', 'VACACIONES');
        Texto := Texto.Replace('Devengados', 'DEVENGADOS');
        Texto := Texto.Replace('Regular', 'REGULAR');
        exit(Texto);
    end;
}
