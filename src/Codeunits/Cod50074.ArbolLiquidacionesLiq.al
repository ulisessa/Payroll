namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Arma el buffer del árbol de liquidaciones y acumula los subtotales por nodo.
/// </summary>
codeunit 50074 "Árbol Liquidaciones Liq."
{
    Access = Public;

    var
        FSinProyecto: Boolean;
        Sep: Label '|', Locked = true;
        TxtSinProyecto: Label '(sin proyecto)';
        TxtSinTipo: Label '(sin tipo de liquidación)';
        TxtPeriodo: Label 'Período %1';
        TxtSinMes: Label '(sin mes)';
        TxtSinFecha: Label '(sin fecha)';
        TxtTipo: Label 'Tipo %1';

    /// <summary>
    /// Vuelca en Buffer el árbol de las liquidaciones que pasen el filtro de Origen.
    /// </summary>
    /// <summary>
    /// Elige la presentación del árbol. Hay que llamarlo ANTES de Construir.
    /// </summary>
    /// <remarks>
    /// Con proyecto (por defecto) el árbol es Mes → Fecha → Tipo → Proyecto → Liquidación, que es
    /// como se venía usando y sirve para revisar una marea contra otra.
    ///
    /// Sin proyecto queda Mes → Fecha → Tipo → Liquidación: la secuencia de trabajo del mes, leída de
    /// arriba hacia abajo en el Orden en que hay que liquidar. El nivel de proyecto ahí estorba —parte
    /// cada tipo en tantos nodos como mareas haya— y lo que se quiere ver es el conjunto.
    /// </remarks>
    procedure AgruparPorProyecto(Agrupar: Boolean)
    begin
        // Se guarda invertido para que el valor por defecto de un Boolean —false— signifique el árbol
        // de siempre. Un llamador que no elija presentación tiene que seguir viendo lo que veía.
        FSinProyecto := not Agrupar;
    end;

    procedure Construir(var Buffer: Record "Árbol Liquidaciones Buffer" temporary; var Origen: Record "Liquidación")
    var
        Periodo: Record "Período Liquidación";
        TipoLiq: Record "Tipo Liquidación";
        Job: Record Job;
        ClavePer: Code[100];
        ClaveFecha: Code[100];
        ClaveTipo: Code[100];
        ClaveProy: Code[100];
        DescProy: Text[150];
    begin
        Buffer.Reset();
        Buffer.DeleteAll();

        // Sin SetCurrentKey: el orden de lectura NO importa. Los nodos se crean por demanda con un
        // Get sobre su clave, y la jerarquía la da la clave primaria del buffer, no el recorrido.
        // Pedir un orden acá habría obligado a agregarle un índice a Liquidación —que ya tiene
        // cuatro— para una vista de consulta.
        if not Origen.FindSet() then
            exit;

        repeat
            if not Periodo.Get(Origen."Cód. Período") then
                Clear(Periodo);

            // La raíz agrupa por MES, no por código de período: en un mismo mes pueden convivir varios
            // —el mensual y el del aguinaldo— y verlos como dos ramas separadas parte en dos el mes
            // que uno está tratando de cerrar. El tipo de liquidación ya los distingue un nivel más
            // abajo, así que arriba estorba.
            //
            // El tramo se arma con la fecha INVERTIDA y no con el código: "MENS122025" ordena después
            // de "MENS012026" alfabéticamente, así que ordenar por código mezcla los años. Invertida,
            // además, deja el mes más reciente arriba.
            ClavePer := ClaveDescendente(PrimerDiaDelMes(Periodo));

            // Dentro del mes manda la FECHA, y recién debajo el tipo: un mismo tipo se corre varias
            // veces en el mes —una por marea que cierra— y agrupando primero por tipo esas corridas
            // quedan mezcladas en un solo nodo, sin forma de ver qué se liquidó cada día. Va
            // ascendente para que el mes se lea de arriba hacia abajo en el orden en que pasó.
            ClaveFecha := ClavePer + Sep + ClaveAscendente(Origen."Fecha Liquidación");

            // Los tipos van por su ORDEN y no por el código. Alfabéticamente, AGUINALDO queda antes
            // que REGULAR y CIERRE_MAREA antes que DEVENGADOS, que es al revés de como se liquidan.
            // Y el orden importa de verdad: el tope SIPA, los francos FIFO y los acumuladores del
            // mes dependen de cuál se calculó primero, así que el árbol tiene que mostrar la
            // secuencia real de trabajo y no un alfabético que invita a hacerlo mal.
            if not TipoLiq.Get(Origen."Cód. Tipo Liq.") then
                Clear(TipoLiq);
            ClaveTipo := ClaveFecha + Sep + Format(TipoLiq.Orden, 4, '<Integer,4><Filler Character,0>') + '_' + Origen."Cód. Tipo Liq.";
            // Sin agrupar por proyecto, las hojas cuelgan del tipo y el nivel intermedio no se crea.
            ClaveProy := ClaveTipo;
            if not FSinProyecto then
                ClaveProy := ClaveTipo + Sep + Origen."No. Proyecto";

            if not Buffer.Get(ClavePer) then
                CrearNodo(Buffer, ClavePer, 0, CopyStr(DescripcionMes(Periodo), 1, 150));
            AgregarPeriodoAlNodo(Buffer, ClavePer, Origen."Cód. Período");

            if not Buffer.Get(ClaveFecha) then begin
                CrearNodo(Buffer, ClaveFecha, 1, CopyStr(DescripcionFecha(Origen."Fecha Liquidación"), 1, 150));
                Buffer."Fecha Liquidación" := Origen."Fecha Liquidación";
                Buffer.Modify();
            end;
            AgregarPeriodoAlNodo(Buffer, ClaveFecha, Origen."Cód. Período");

            if not Buffer.Get(ClaveTipo) then begin
                // El orden va en la etiqueta: sin él, el nodo se ve igual que antes y no hay forma de
                // saber si la secuencia que muestra el árbol es la correcta o una casualidad.
                CrearNodo(Buffer, ClaveTipo, 2,
                    CopyStr(Format(TipoLiq.Orden) + '. ' + DescripcionTipo(Origen."Cód. Tipo Liq.", TipoLiq), 1, 150));
                Buffer."Fecha Liquidación" := Origen."Fecha Liquidación";
                Buffer."Cód. Tipo Liq." := Origen."Cód. Tipo Liq.";
                Buffer.Modify();
            end;
            AgregarPeriodoAlNodo(Buffer, ClaveTipo, Origen."Cód. Período");

            if (not FSinProyecto) and (not Buffer.Get(ClaveProy)) then begin
                DescProy := TxtSinProyecto;
                if Origen."No. Proyecto" <> '' then
                    if Job.Get(Origen."No. Proyecto") then
                        DescProy := CopyStr(Origen."No. Proyecto" + '  ' + Job.Description, 1, 150)
                    else
                        DescProy := Origen."No. Proyecto";
                CrearNodo(Buffer, ClaveProy, 3, DescProy);
                Buffer."Fecha Liquidación" := Origen."Fecha Liquidación";
                Buffer."Cód. Tipo Liq." := Origen."Cód. Tipo Liq.";
                Buffer."No. Proyecto" := Origen."No. Proyecto";
                Buffer.Modify();
            end;
            if not FSinProyecto then
                AgregarPeriodoAlNodo(Buffer, ClaveProy, Origen."Cód. Período");

            // Todas las hojas de un nodo comparten fecha —la fecha ya es un nivel—, así que acá
            // alcanza con el número para que el orden sea estable.
            CrearHoja(Buffer, ClaveProy + Sep + Origen."No.", Origen, NivelHoja());
            // El aporte de la hoja sube a sus ancestros. Se hace acá y no en una pasada posterior
            // porque las claves de los ancestros ya están armadas en este punto.
            Acumular(Buffer, ClavePer, Origen);
            Acumular(Buffer, ClaveFecha, Origen);
            Acumular(Buffer, ClaveTipo, Origen);
            // Sin nivel de proyecto, ClaveProy ES ClaveTipo: acumular de nuevo contaría dos veces.
            if not FSinProyecto then
                Acumular(Buffer, ClaveProy, Origen);
        until Origen.Next() = 0;

        Buffer.Reset();
        if Buffer.FindFirst() then;
    end;

    /// <summary>
    /// Ocho dígitos que ordenan la fecha de más reciente a más antigua.
    /// </summary>
    /// <remarks>
    /// El buffer se ordena por su clave, que es texto. Para que una fecha ordene al revés se guarda
    /// su complemento contra 99991231: así el 2026 queda antes que el 2025 sin necesidad de un
    /// campo de orden aparte ni de invertir la clave entera.
    ///
    /// Una fecha vacía da 99991231, o sea el final de la lista: lo que no tiene fecha va último.
    /// </remarks>
    local procedure ClaveDescendente(Fecha: Date): Text
    var
        Complemento: Integer;
    begin
        if Fecha = 0D then
            exit('99991231');
        Complemento := 99991231 - (Date2DMY(Fecha, 3) * 10000 + Date2DMY(Fecha, 2) * 100 + Date2DMY(Fecha, 1));
        exit(Format(Complemento, 8, '<Integer,8><Filler Character,0>'));
    end;

    /// <remarks>
    /// La contracara: aaaammdd, del más antiguo al más reciente. Es la que usa el nivel de fecha,
    /// donde lo que se quiere leer es la cronología del mes y no la novedad. La fecha vacía da
    /// 00000000 y queda arriba: lo que no tiene fecha salta a la vista en vez de esconderse al final.
    /// </remarks>
    local procedure ClaveAscendente(Fecha: Date): Text
    begin
        if Fecha = 0D then
            exit('00000000');
        exit(Format(Date2DMY(Fecha, 3) * 10000 + Date2DMY(Fecha, 2) * 100 + Date2DMY(Fecha, 1), 8, '<Integer,8><Filler Character,0>'));
    end;

    local procedure DescripcionFecha(Fecha: Date): Text
    begin
        if Fecha = 0D then
            exit(TxtSinFecha);
        // Con el día de la semana adelante: en un mes lleno de fechas todas parecidas, "Vie" es lo
        // que hace saltar a la vista la corrida que quedó en un día raro.
        exit(Format(Fecha, 0, '<Weekday Text,3> <Day,2>/<Month,2>/<Year4>'));
    end;

    /// <remarks>
    /// El mes sale de Año/Mes del período y no de su Fecha Desde: un período que arranque el 26 del
    /// mes anterior pertenece igual al mes que declara. Si no los tiene cargados, se cae a la fecha.
    /// </remarks>
    // Delegado a la tabla: la misma regla la necesita el acumulado mensual por concepto del contexto
    // de cálculo, y dos copias harían que el árbol y el cálculo discrepen sobre a qué mes pertenece
    // un período — una discrepancia que se vería como un importe, no como un error.
    local procedure PrimerDiaDelMes(Periodo: Record "Período Liquidación"): Date
    begin
        exit(Periodo.PrimerDiaDelMes());
    end;

    local procedure DescripcionMes(Periodo: Record "Período Liquidación"): Text
    var
        Primero: Date;
    begin
        Primero := PrimerDiaDelMes(Periodo);
        if Primero = 0D then
            exit(TxtSinMes);
        exit(Format(Primero, 0, '<Month Text> <Year4>'));
    end;

    /// <summary>
    /// Suma un código de período al filtro del nodo, sin repetirlo.
    /// </summary>
    /// <remarks>
    /// Es lo que le permite a un nodo de mes abarcar varios códigos. Se compara delimitado por "|"
    /// para no dar por presente a "MENS072026" cuando lo que está es "MENS072026B".
    /// </remarks>
    local procedure AgregarPeriodoAlNodo(var Buffer: Record "Árbol Liquidaciones Buffer" temporary; Clave: Code[100]; CodPeriodo: Code[10])
    begin
        if CodPeriodo = '' then
            exit;
        if not Buffer.Get(Clave) then
            exit;
        if StrPos(Sep + Buffer."Filtro Período" + Sep, Sep + CodPeriodo + Sep) > 0 then
            exit;
        if Buffer."Filtro Período" = '' then
            Buffer."Filtro Período" := CodPeriodo
        else begin
            // Sin CopyStr: un código cortado por la mitad daría un filtro que parece válido y alcanza
            // otras liquidaciones. Antes que eso, se deja el filtro como está —más angosto, pero
            // exacto—. Con 250 caracteres hacen falta más de veinte períodos en un mes para llegar acá.
            if StrLen(Buffer."Filtro Período") + StrLen(Sep) + StrLen(CodPeriodo) > MaxStrLen(Buffer."Filtro Período") then
                exit;
            Buffer."Filtro Período" += Sep + CodPeriodo;
        end;
        Buffer.Modify();
    end;

    local procedure CrearNodo(var Buffer: Record "Árbol Liquidaciones Buffer" temporary; Clave: Code[100]; NivelNodo: Integer; Desc: Text[150])
    begin
        Buffer.Init();
        Buffer."Clave Orden" := Clave;
        Buffer.Nivel := NivelNodo;
        Buffer.Descripción := Desc;
        Buffer.Insert();
    end;

    // Sin el nivel de proyecto la hoja sube un escalón; si no, la indentación deja un hueco donde
    // no hay nada.
    local procedure NivelHoja(): Integer
    begin
        if FSinProyecto then
            exit(3);
        exit(4);
    end;

    local procedure CrearHoja(var Buffer: Record "Árbol Liquidaciones Buffer" temporary; Clave: Code[100]; var Liq: Record "Liquidación"; Nivel: Integer)
    begin
        Buffer.Init();
        Buffer."Clave Orden" := Clave;
        Buffer.Nivel := Nivel;
        Buffer.Descripción := CopyStr(Liq."No." + '  ' + Liq."Nombre Empleado", 1, 150);
        Buffer."No. Liquidación" := Liq."No.";
        Buffer."Cód. Período" := Liq."Cód. Período";
        Buffer."Fecha Liquidación" := Liq."Fecha Liquidación";
        Buffer."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
        Buffer."No. Proyecto" := Liq."No. Proyecto";
        Buffer."No. Empleado" := Liq."No. Empleado";
        Buffer."Nombre Empleado" := Liq."Nombre Empleado";
        Buffer.Estado := Liq.Estado;
        Buffer."Total Haberes" := Liq."Total Haberes";
        Buffer."Total Descuentos" := Liq."Total Descuentos";
        Buffer."Neto a Pagar" := Liq."Neto a Pagar";
        Buffer.Insert();
    end;

    local procedure Acumular(var Buffer: Record "Árbol Liquidaciones Buffer" temporary; Clave: Code[100]; var Liq: Record "Liquidación")
    begin
        if not Buffer.Get(Clave) then
            exit;
        Buffer.Cantidad += 1;
        Buffer."Total Haberes" += Liq."Total Haberes";
        Buffer."Total Descuentos" += Liq."Total Descuentos";
        Buffer."Neto a Pagar" += Liq."Neto a Pagar";
        Buffer.Modify();
    end;

    local procedure DescripcionTipo(Codigo: Code[20]; TipoLiq: Record "Tipo Liquidación"): Text
    begin
        // Sin código no queda nada que sustituir y el 'Tipo %1' se veía como un "Tipo " colgado, que
        // se lee como si el nodo se llamara así en vez de como una liquidación a la que le falta el
        // tipo. Mismo criterio que el nivel de proyecto con (sin proyecto).
        if Codigo = '' then
            exit(TxtSinTipo);
        // Los tipos suelen describirse con su propio código —REGULAR / "Regular"— y ahí el
        // "código  descripción" del resto de los niveles se lee como una repetición: "REGULAR
        // Regular". Cuando los dos dicen lo mismo va uno solo, el código, que es lo que después se
        // ve en los filtros y en la Lista.
        if UpperCase(TipoLiq.Descripción) = UpperCase(Codigo) then
            exit(Codigo);
        if TipoLiq.Descripción <> '' then
            exit(Codigo + '  ' + TipoLiq.Descripción);
        exit(StrSubstNo(TxtTipo, Codigo));
    end;
}
