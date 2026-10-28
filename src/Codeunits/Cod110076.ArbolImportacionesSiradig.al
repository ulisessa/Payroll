namespace UAS.Payroll;

/// <summary>
/// Arma el buffer del árbol de importaciones SIRADIG —mes de presentación, estado, importación— y
/// acumula los contadores por nodo.
/// </summary>
/// <remarks>
/// EL NIVEL SUPERIOR ES EL MES EN QUE SE PRESENTÓ, no el período de la declaración. El "Período" de
/// SIRADIG es el año fiscal (2026) y todas las presentaciones de un año caen en el mismo: agrupar por
/// él deja un solo nodo con todo adentro. El mes de presentación sí reparte el trabajo —las de enero,
/// las de febrero— y es el corte con el que se carga y se procesa cada tanda.
/// </remarks>
codeunit 110076 "Árbol Importaciones SIRADIG"
{
    Access = Public;

    var
        Sep: Label '|', Locked = true;
        TxtSinFecha: Label '(sin fecha de presentación)';
        TxtHoja: Label '%1 · presentación %2 · %3', Locked = true;

    procedure Construir(var Buffer: Record "Árbol SIRADIG Buffer" temporary; var Origen: Record "Importación SIRADIG")
    var
        ClavePer: Code[100];
        ClaveEst: Code[100];
        ClaveHoja: Code[100];
        Desde: Date;
        Hasta: Date;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();

        // Sin orden de lectura: los nodos se crean por demanda y la jerarquía la da la clave del buffer.
        if not Origen.FindSet() then
            exit;

        repeat
            LimitesDelMes(Origen."Fecha Presentación", Desde, Hasta);
            ClavePer := ClaveMes(Origen."Fecha Presentación");
            ClaveEst := ClavePer + Sep + OrdenEstado(Origen.Estado);
            ClaveHoja := ClaveEst + Sep + Format(Origen."No.", 10, '<Integer,10><Filler Character,0>');

            Nodo(Buffer, ClavePer, 0, DescripcionMes(Origen."Fecha Presentación"), Origen."Período", -1, Desde, Hasta);
            Nodo(Buffer, ClaveEst, 1, Format(Origen.Estado), Origen."Período", Origen.Estado.AsInteger(), Desde, Hasta);
            Hoja(Buffer, ClaveHoja, Origen);

            Acumular(Buffer, ClavePer, Origen.Estado);
            Acumular(Buffer, ClaveEst, Origen.Estado);
        until Origen.Next() = 0;
    end;

    /// <summary>Las importaciones que abarca un nodo: una sola en la hoja, o las del mes de presentación / el estado de ese mes.</summary>
    procedure AlcanceDeNodo(Nodo: Record "Árbol SIRADIG Buffer"; var Imp: Record "Importación SIRADIG")
    begin
        Imp.Reset();
        if Nodo."No. Importación" <> 0 then begin
            Imp.SetRange("No.", Nodo."No. Importación");
            exit;
        end;

        // Por fecha de presentación. Un nodo sin fecha (las importaciones que no la traen) filtra el
        // blanco: con las dos fechas en cero, SetRange(campo, 0D, 0D) deja justo las que no tienen.
        Imp.SetRange("Fecha Presentación", Nodo."Fecha Desde", Nodo."Fecha Hasta");
        if Nodo."Estado Alcance" >= 0 then
            Imp.SetRange(Estado, "Estado Importación SIRADIG".FromInteger(Nodo."Estado Alcance"));
    end;

    local procedure Nodo(var Buffer: Record "Árbol SIRADIG Buffer" temporary; Clave: Code[100]; Nivel: Integer; Descripcion: Text; Periodo: Integer; EstadoAlcance: Integer; Desde: Date; Hasta: Date)
    begin
        if Buffer.Get(Clave) then
            exit;
        Buffer.Init();
        Buffer."Clave Orden" := Clave;
        Buffer.Nivel := Nivel;
        Buffer.Descripción := CopyStr(Descripcion, 1, MaxStrLen(Buffer.Descripción));
        Buffer."Período" := Periodo;
        Buffer."Estado Alcance" := EstadoAlcance;
        Buffer."Fecha Desde" := Desde;
        Buffer."Fecha Hasta" := Hasta;
        Buffer.Insert();
    end;

    local procedure Hoja(var Buffer: Record "Árbol SIRADIG Buffer" temporary; Clave: Code[100]; Origen: Record "Importación SIRADIG")
    begin
        Buffer.Init();
        Buffer."Clave Orden" := Clave;
        Buffer.Nivel := 2;
        Buffer.Descripción := CopyStr(StrSubstNo(TxtHoja, Origen."CUIL Empleado", Origen."Nro. Presentación", Format(Origen."Fecha Presentación")), 1, MaxStrLen(Buffer.Descripción));
        Buffer."No. Importación" := Origen."No.";
        Buffer."Período" := Origen."Período";
        Buffer."Estado Alcance" := Origen.Estado.AsInteger();
        Buffer.Cantidad := 1;
        Buffer."CUIL Empleado" := Origen."CUIL Empleado";
        Buffer."No. Empleado" := Origen."No. Empleado";
        Buffer."Nro. Presentación" := Origen."Nro. Presentación";
        Buffer."Fecha Presentación" := Origen."Fecha Presentación";
        Buffer."Deducciones Importadas" := Origen."Deducciones Importadas";
        Buffer."Cargas Familia Importadas" := Origen."Cargas Familia Importadas";
        Buffer.Estado := Origen.Estado;
        Buffer."Mensajes Error" := Origen."Mensajes Error";
        Buffer.Insert();
    end;

    local procedure Acumular(var Buffer: Record "Árbol SIRADIG Buffer" temporary; Clave: Code[100]; Estado: Enum "Estado Importación SIRADIG")
    begin
        if not Buffer.Get(Clave) then
            exit;
        Buffer.Cantidad += 1;
        case Estado of
            Estado::"Pendiente Procesar":
                Buffer.Pendientes += 1;
            Estado::"Error en Procesamiento":
                Buffer."Con Errores" += 1;
            else
                Buffer.Procesadas += 1;
        end;
        Buffer.Modify();
    end;

    // El mes más reciente arriba: la clave es el complemento a 999999 de aaaamm. Sin fecha de
    // presentación va al final, con la clave más alta.
    local procedure ClaveMes(Fecha: Date): Code[100]
    begin
        if Fecha = 0D then
            exit('999999');
        exit(Format(999999 - (Date2DMY(Fecha, 3) * 100 + Date2DMY(Fecha, 2)), 6, '<Integer,6><Filler Character,0>'));
    end;

    local procedure LimitesDelMes(Fecha: Date; var Desde: Date; var Hasta: Date)
    begin
        if Fecha = 0D then begin
            Desde := 0D;
            Hasta := 0D;
            exit;
        end;
        Desde := DMY2Date(1, Date2DMY(Fecha, 2), Date2DMY(Fecha, 3));
        Hasta := CalcDate('<CM>', Desde);
    end;

    local procedure DescripcionMes(Fecha: Date): Text
    begin
        if Fecha = 0D then
            exit(TxtSinFecha);
        exit(Format(Fecha, 0, '<Month Text> <Year4>'));
    end;
    // Lo que hay que hacer primero, arriba: pendientes, después errores, advertencias y lo ya procesado.
    local procedure OrdenEstado(Estado: Enum "Estado Importación SIRADIG"): Text
    begin
        case Estado of
            Estado::"Pendiente Procesar":
                exit('1');
            Estado::"Error en Procesamiento":
                exit('2');
            Estado::"Procesado con Advertencias":
                exit('3');
            else
                exit('4');
        end;
    end;
}
