namespace UAS.Payroll;

using System.Environment;

/// <summary>
/// Las dos mitades de la sincronización en una sola corrida: traer del origen y aplicar sobre las
/// tablas reales. Es lo que va en la entrada de proyecto (Job Queue).
/// </summary>
/// <remarks>
/// UNA SOLA ENTRADA DE PROYECTO PARA LOS DOS TRANSPORTES. Con web services esta codeunit hace todo:
/// trae y aplica. Con SQL la traída la hace el job del Agent —que corre afuera de BC, desfasado dos
/// minutos— y acá sólo queda aplicar. Que el comportamiento dependa de la configuración y no de qué
/// entrada de proyecto se creó evita el error de cambiar el transporte y quedarse sin traída, o con
/// dos.
///
/// La traída va ANTES de aplicar, y en el orden de dependencia: los valores de dimensión antes que
/// los proyectos, porque un proyecto con una marea que BC no conoce falla al aplicarse. Si algo de
/// la traída falla, igual se aplica lo que ya está en staging: una caída de red no tiene por qué
/// dejar sin procesar lo que llegó en la corrida anterior.
/// </remarks>
codeunit 110042 "Traer y Procesar NAV"
{
    var
        TxtFalloTraida: Label 'Falló la traída de %1: %2', Comment = '%1 = entidad; %2 = motivo';
        TxtResumen: Label '%1 fila(s) traídas, %2 aplicadas.', Comment = '%1 %2 = cantidades';

    trigger OnRun()
    begin
        TraerYProcesar();
    end;

    procedure TraerYProcesar() Aplicadas: Integer
    var
        Sinc: Codeunit "Sinc NAV Liq.";
        Traidas: Integer;
    begin
        Traidas := TraerTodo();
        Aplicadas := Sinc.ProcesarTodo();

        if GuiAllowed() then
            Message(TxtResumen, Traidas, Aplicadas);
    end;

    /// <summary>
    /// Trae todas las entidades por web services, si la empresa está configurada así. Con transporte
    /// SQL devuelve cero sin hacer nada: la traída es del job del Agent.
    /// </summary>
    procedure TraerTodo() Traidas: Integer
    var
        Cfg: Record "Config Sinc NAV";
        Empresa: Text[30];
    begin
        Empresa := CopyStr(CompanyName(), 1, MaxStrLen(Empresa));
        if not Cfg.Get(Empresa) then
            exit(0);
        if not Cfg.Activo then
            exit(0);
        if Cfg.Transporte <> Cfg.Transporte::"Web Services" then
            exit(0);

        // El orden es el de dependencia, igual que al aplicar. "Descarga Linea" no está en la lista
        // a propósito: la trae la cabecera, de un solo pedido.
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Valor Dimension");
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::Empleado);
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::Proyecto);
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Descarga Cabecera");
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Informe Cap Cabecera");
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Informe Cap Linea");
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Dia Abordo Cabecera");
        Traidas += TraerUna(Empresa, "Entidad Sinc NAV"::"Dia Abordo Linea");
    end;

    /// <summary>
    /// Trae una entidad y deja el motivo anotado si falla, sin cortar las demás.
    /// </summary>
    /// <remarks>
    /// Una entidad que falla no frena a las otras: se anota en su fila de control y se sigue. Cortar
    /// todo porque un entity set no contestó dejaría sin actualizar cosas que no tienen nada que ver
    /// con la que falló.
    /// </remarks>
    local procedure TraerUna(Empresa: Text[30]; Entidad: Enum "Entidad Sinc NAV") Filas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Traedor: Codeunit "Traer NAV WS";
    begin
        Filas := Traedor.TraerEntidad(Empresa, Entidad);

        if Filas < 0 then begin
            if Ctrl.Get(Entidad) then begin
                Ctrl."Ultima Observacion" := CopyStr(StrSubstNo(TxtFalloTraida, Entidad, Traedor.GetUltimoError()),
                                                     1, MaxStrLen(Ctrl."Ultima Observacion"));
                Ctrl.Modify(true);
            end;
            exit(0);
        end;
    end;
}
