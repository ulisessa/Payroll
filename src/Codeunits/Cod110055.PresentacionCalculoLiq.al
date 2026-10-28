namespace UAS.Payroll;

codeunit 110055 "Presentación Cálculo Liq."
{
    procedure Abrir(Linea: Record "Línea Liquidación")
    var
        Concepto: Record "Concepto Liquidación";
        Francos: Page "Lotes Franco Consumidos";
        Detalle: Page "Detalle Cálculo Línea";
    begin
        if Linea."Cód. Concepto" = '' then
            exit;
        if Concepto.Get(Linea."Cód. Concepto", Linea."Vigencia Concepto") then
            if Concepto."Rol Franco" = Concepto."Rol Franco"::Consumo then begin
                Francos.CargarDesde(Linea);
                Francos.RunModal();
                exit;
            end;
        Detalle.CargarDesdeLinea(Linea);
        Detalle.RunModal();
    end;

    procedure EsGanancias(Linea: Record "Línea Liquidación"): Boolean
    var
        Concepto: Record "Concepto Liquidación";
        Det: Record "Detalle Ganancias Liq.";
        Variables: Record "Detalle Variable Línea Liq.";
        FormulaNormalizada: Text;
        Separador: Char;
    begin
        if Linea."Cód. Concepto" = '' then
            exit(false);
        // Compatibilidad con liquidaciones anteriores al snapshot y sin etiqueta de recibo.
        // Identificar la escala fiscal concreta, no cualquier uso de TRAMO().
        FormulaNormalizada := Linea."Fórmula Aplicada".ToUpper().Replace(' ', '');
        for Separador := 9 to 13 do
            FormulaNormalizada := FormulaNormalizada.Replace(Format(Separador), '');
        if StrPos(FormulaNormalizada, 'TRAMO(''TAB_IMP_4CAT'',') > 0 then
            exit(true);
        Variables.SetRange("No. Liquidación", Linea."No. Liquidación");
        Variables.SetRange("No. Línea", Linea."No. Línea");
        // Los paréntesis son texto del nombre, no operadores de un filtro AL.
        // Recorrer únicamente los datos guardados de esta línea incluye también los sufijos #2, #3.
        if Variables.FindSet() then
            repeat
                if Variables."Nombre Variable".StartsWith('TRAMO(TAB_IMP_4CAT)') then
                    exit(true);
            until Variables.Next() = 0;
        // Preferir la evidencia guardada; la configuración se usa solo como respaldo.
        Det.SetRange("No. Liquidación", Linea."No. Liquidación");
        Det.SetRange(Tipo, Det.Tipo::Paso);
        Det.SetRange(Código, Linea."Cód. Concepto");
        if not Det.IsEmpty() then
            exit(true);
        if Concepto.Get(Linea."Cód. Concepto", Linea."Vigencia Concepto") then
            exit(Concepto."Etiqueta Det. Ganancias" <> '');
        exit(false);
    end;

    procedure CargarDatos(Linea: Record "Línea Liquidación"; var Datos: Record "Paso Cálculo Línea" temporary)
    var
        Det: Record "Detalle Variable Línea Liq." temporary;
        Guardadas: Codeunit "Variables Guardadas Liq.";
        Constructor: Codeunit "Detalle Cálculo Línea";
        Nombre: Text;
    begin
        Datos.Reset();
        Datos.DeleteAll();
        Guardadas.CargarDetalle(Linea."No. Liquidación", Linea."No. Línea", Det);
        if Det.FindSet() then
            repeat
                if not Det."Nombre Variable".StartsWith('TRAMO(') then begin
                    Nombre := Constructor.DescribirTermino(Det."Nombre Variable");
                    if Nombre = '' then
                        Nombre := Det."Nombre Variable";
                    Agregar(Datos, Nombre, Det.Valor, Det.Detalle);
                    if Det."Código Atributo" <> '' then
                        Datos.Detalle := CopyStr('Código utilizado: ' + Det."Código Atributo", 1, MaxStrLen(Datos.Detalle));
                    Datos.Término := Det."Nombre Variable";
                    Datos.Modify();
                end;
            until Det.Next() = 0;
    end;

    procedure CargarGanancias(Linea: Record "Línea Liquidación"; var Pasos: Record "Paso Cálculo Línea" temporary; var Datos: Record "Paso Cálculo Línea" temporary; var Base: Record "Paso Cálculo Línea" temporary; var Escala: Record "Paso Cálculo Línea" temporary; var Retencion: Record "Paso Cálculo Línea" temporary)
    var
        Det: Record "Detalle Variable Línea Liq.";
        Comprobable: Boolean;
        Descripcion: Text;
    begin
        Base.Reset();
        Base.DeleteAll();
        Escala.Reset();
        Escala.DeleteAll();
        Retencion.Reset();
        Retencion.DeleteAll();
        if Pasos.FindLast() then
            Comprobable := Pasos."Es Total";
        if Comprobable then begin
            if Pasos.FindSet() then
                repeat
                    Descripcion := Pasos.Descripción;
                    if Pasos."Es Total" then
                        Descripcion := 'Retención resultante de la cuenta'
                    else
                        if Pasos."Es Subtotal" then begin
                            if Pasos."Es Base Escala" then
                                Descripcion := 'Subtotal de la base'
                            else
                                Descripcion := 'Subtotal de ajustes';
                        end
                        else
                            if StrPos(Pasos.Término.ToUpper(), 'TRAMO(') > 0 then
                                Descripcion := 'Impuesto según la escala y ajustes de la expresión'
                            else
                                if Descripcion = '' then
                                    Descripcion := 'Operación intermedia';
                    if Pasos."Es Base Escala" then
                        CopiarPaso(Pasos, Base, Descripcion)
                    else
                        CopiarPaso(Pasos, Retencion, Descripcion);
                until Pasos.Next() = 0;
        end else begin
            // En históricos incompletos se muestran los insumos, sin inventar una secuencia.
            if Datos.FindSet() then
                repeat
                    CopiarPaso(Datos, Base, Datos.Descripción);
                until Datos.Next() = 0;
        end;
        Det.SetRange("No. Liquidación", Linea."No. Liquidación");
        Det.SetRange("No. Línea", Linea."No. Línea");
        if Det.FindSet() then
            repeat
                if Det."Nombre Variable".StartsWith('TRAMO(') then begin
                    if Det."Snapshot Tramo" then begin
                        Agregar(Base, 'Base imponible utilizada en la escala', Det."Base Tramo", 'Vigencia: ' + Format(Det."Vigencia Tramo"));
                        Base."Es Subtotal" := true;
                        Base.Modify();
                        Agregar(Escala, 'Base utilizada', Det."Base Tramo", 'Vigencia: ' + Format(Det."Vigencia Tramo"));
                        Agregar(Escala, 'Límite inferior del tramo', Det."Límite Tramo", '');
                        Agregar(Escala, 'Excedente sobre el límite inferior', Det."Base Tramo" - Det."Límite Tramo", 'Base utilizada menos límite inferior.');
                        Agregar(Escala, 'Porcentaje sobre el excedente', Det."Porcentaje Tramo", 'Porcentaje; se divide por 100 para calcular el importe.');
                        Agregar(Escala, 'Impuesto sobre el excedente', (Det."Base Tramo" - Det."Límite Tramo") * Det."Porcentaje Tramo" / 100, 'Excedente por porcentaje dividido por 100.');
                        Agregar(Escala, 'Importe fijo', Det."Fijo Tramo", '');
                    end;
                    Agregar(Escala, 'Impuesto determinado por la escala', Det.Valor, Det.Detalle);
                end;
            until Det.Next() = 0;
        if Escala.IsEmpty() then
            Agregar(Escala, 'Sin consulta de escala guardada', 0, 'Esta línea puede ser un paso previo del cálculo de Ganancias.');
        Agregar(Retencion, 'Importe guardado en la liquidación', Linea.Importe, '');
        Retencion."Es Total" := true;
        Retencion.Modify();
    end;

    local procedure CopiarPaso(var Origen: Record "Paso Cálculo Línea" temporary; var Destino: Record "Paso Cálculo Línea" temporary; Descripcion: Text)
    var
        Numero: Integer;
    begin
        if Destino.FindLast() then
            Numero := Destino."No. Paso";
        Destino := Origen;
        Destino."No. Paso" := Numero + 1;
        Destino.Descripción := CopyStr(Descripcion, 1, MaxStrLen(Destino.Descripción));
        Destino.Insert();
    end;

    local procedure Agregar(var Datos: Record "Paso Cálculo Línea" temporary; Descripcion: Text; Valor: Decimal; Detalle: Text)
    var
        Numero: Integer;
    begin
        if Datos.FindLast() then
            Numero := Datos."No. Paso";
        Datos.Init();
        Datos."No. Paso" := Numero + 1;
        Datos.Descripción := CopyStr(Descripcion, 1, MaxStrLen(Datos.Descripción));
        Datos.Valor := Valor;
        Datos.Detalle := CopyStr(Detalle, 1, MaxStrLen(Datos.Detalle));
        Datos.Insert();
    end;
}
