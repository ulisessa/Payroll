namespace UAS.Payroll;

// El catálogo de columnas de Meta4: una fila por cada columna de M4T_ACUMULADO_RL..RL5. Son ~1.818.
//
// Existe para que el detalle guarde un entero en vez del nombre de la columna. Sobre ~117 millones de
// filas, guardar 'TOT_REMUN_27617' en texto en lugar de un Integer cuesta del orden de 2 GB.
//
// "Descripción" nace vacía y se llena a mano, sólo para las columnas que a alguien le importen. NO es
// un mapeo a conceptos de BC y no debe convertirse en uno: si mañana hace falta que BC calcule con
// algún dato de acá, el camino es cargarlo como línea en "Línea Liquidación" con su código de
// concepto, no enseñarle al motor a leer este archivo.
table 110055 "Columna Hist. Meta4"
{
    Caption = 'Columnas de la Historia Meta4';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Integer)
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; "Tabla Origen"; Code[30])
        {
            Caption = 'Tabla Origen';
            DataClassification = CustomerContent;
            // M4T_ACUMULADO_RL, RL2, RL3, RL4 o RL5. Se conserva porque el nombre de columna NO es
            // único entre las cinco tablas, y porque saber de dónde salió cada valor es justamente
            // lo que hace que esto sea un archivo y no una reinterpretación.
        }
        field(3; "Nombre Columna"; Code[50])
        {
            Caption = 'Nombre de Columna';
            DataClassification = CustomerContent;
        }
        field(4; "Tipo Dato"; Option)
        {
            Caption = 'Tipo de Dato';
            OptionMembers = Decimal,Texto,Fecha;
            OptionCaption = 'Decimal,Texto,Fecha';
            DataClassification = CustomerContent;
            // Dice cuál de los tres campos de valor del detalle está cargado. Es el catálogo el que
            // declara el tipo, no cada fila: 1.818 declaraciones en vez de 117 millones.
        }
        field(5; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(6; "Filas con Valor"; Integer)
        {
            Caption = 'Filas con Valor';
            DataClassification = CustomerContent;
            // Cuántas filas del detalle tienen esta columna cargada. Se calcula una vez al migrar.
            // Sirve para lo único que uno quiere saber al abrir este catálogo: cuáles de las 1.818
            // columnas se usaron de verdad y cuáles son residuo de versiones viejas de Meta4.
        }
        field(7; "Cód. Concepto BC"; Code[20])
        {
            Caption = 'Concepto BC';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
            ValidateTableRelation = false;
            // A qué concepto de BC corresponde esta columna. Sale de M4SYS_CONCEPTOS, que liga
            // ID_CONCEPTO con NOMBRE_CORTO — y los códigos de concepto de BC son esos ID_CONCEPTO.
            //
            // ES UNA AYUDA PARA COMPARAR, NO UNA AUTORIDAD, y la diferencia importa. La equivalencia
            // por nombre es PARCIAL: el NOMBRE_CORTO es el nombre interno del concepto, que no
            // siempre coincide con el de la columna física. El caso que lo demuestra es 1003 Sueldo,
            // cuyo NOMBRE_CORTO es SAL_BASE mientras que en las tablas anchas la columna se llama
            // SUELDO — y es el concepto más grande de todos. Reconstruir importes desde este mapeo
            // dio 25% bajo; por eso las bases de Ganancias NO salieron de acá sino de diferenciar
            // los acumuladores propios de Meta4.
            //
            // Sirve para lo que sirve: mirar un mes y ver qué concepto explica una diferencia. Que
            // una columna quede sin concepto no es un error, es que no hay equivalencia conocida.
        }
        field(9; "Mapeo Verificado"; Boolean)
        {
            Caption = 'Mapeo verificado';
            DataClassification = CustomerContent;
            // La equivalencia con el concepto de BC fue comprobada, no deducida del nombre.
            //
            // EXISTE PORQUE LA CLASIFICACIÓN NO ALCANZA COMO ÚNICO CRITERIO. La comparación de
            // importes exige que la columna sea DV, RT o SS, para que no se cuelen días, años ni
            // precios unitarios. Pero hay equivalencias correctas cuya columna Meta4 está
            // clasificada AX o sin clasificar: el SAC devengado (BSAC_MES_RG3976 → 4750) y sus
            // aportes son AX o vacío, y se verificaron ARITMÉTICAMENTE — el incremento mensual de
            // IG_TOT_C_IM_ST es exactamente TOT_REMUN_27617 + BSAC_MES_RG3976, al centavo.
            //
            // Marcada, la columna entra en la comparación aunque su clasificación no sea de importe.
            // Sin marcar, tiene que pasar el filtro de clasificación igual que cualquier otra.
            //
            // NO MARCAR UN MAPEO AUTOMÁTICO SIN COMPROBARLO. De los 205 que salieron por nombre, al
            // menos cinco son colisiones reales: el número de concepto coincide y el concepto es
            // otro. 1054 es "Ds vacac deveng mes act" en Meta4 y "Antigüedad mensuales" en BC.
        }
        field(8; "Clasificación Meta4"; Code[10])
        {
            Caption = 'Clasificación Meta4';
            DataClassification = CustomerContent;
            // ID_CLASIFICACION de M4SYS_CONCEPTOS: qué CLASE de cosa es esta columna.
            //
            //   DV  devengos             (SUELDO_NAVEG, PROD_NTA_CAE)   ← IMPORTES
            //   RT  retenciones al empleado (IMPUESTO, C_SINDICAL_VAC)  ← IMPORTES
            //   SS  seguridad social     (OBRA_SOCIAL, LEY_19032_VAC)   ← IMPORTES
            //   D   DÍAS Y UNIDADES      (DIAS_MAREA, UN_VACACIONES)
            //   P   precios unitarios    (PR_*, P_*)
            //   U   horas y cantidades   (HS_*, U_*)
            //   CT  contribuciones patronales (PAT_ART)
            //   C   créditos y anticipos (ANT_DESC_EMB)
            //   AX  auxiliares; O y RS procesos internos (PRE_UPD_*, CTROL_*)
            //
            // OJO CON "D": SON DÍAS, NO DESCUENTOS. La inicial engaña y cuesta caro: incluirlas en
            // una comparación de importes pone "27" al lado de "2.493.907,25" en la misma columna,
            // como si faltaran 27 pesos. Se detecta mirando los totales — DIAS_ALTA suma 9.958 para
            // 330 empleados, que son 30 días cada uno, no pesos. Los descuentos al empleado son RT.
            //
            // ES LO QUE HACE USABLE LA COMPARACIÓN. De las 1.646 columnas con datos, sólo 420 son
            // DV, RT o SS; el resto son días, cantidades, precios unitarios, contribuciones
            // patronales y maquinaria interna. Sin este campo el drilldown mostraba 1.199 filas de
            // ruido y el concepto que de verdad explicaba la diferencia quedaba enterrado.
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(PorNombre; "Tabla Origen", "Nombre Columna") { Unique = true; }
        key(PorUso; "Filas con Valor") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Nombre Columna", "Tabla Origen", Descripción) { }
    }
}
