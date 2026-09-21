namespace UAS.Payroll;

// Dónde está NAV y a qué empresa de BC le corresponde. Es lo único que hay que cargar para que la
// sincronización sepa de dónde traer; el resto del circuito no lleva ningún nombre escrito a mano.
//
// Lo que NO se configura acá: el usuario y la contraseña con que SQL entra a NAV. Eso se define una
// sola vez en el servidor, con sp_addlinkedsrvlogin, y a propósito no se ve desde la interfaz. Acá
// va el nombre del linked server, que es la etiqueta con la que SQL lo conoce.
page 110037 "Config Sinc NAV"
{
    ApplicationArea = All;
    Caption = 'Configuración Sincronización NAV';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Config Sinc NAV";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Empresas)
            {
                field(Activo; Rec.Activo)
                {
                    ApplicationArea = All;
                    ToolTip = 'Destildarlo saca a esta empresa de la corrida sin borrar la configuración ni tocar el job de SQL Agent, que recorre solamente las activas.';
                }
                field("Empresa BC"; Rec."Empresa BC")
                {
                    ApplicationArea = All;
                    ToolTip = 'Empresa de BC a la que llegan los datos. Tiene que ser el nombre exacto: es el prefijo con el que BC nombra sus tablas en SQL y con el que la sincronización las encuentra.';
                }
                field(Transporte; Rec.Transporte)
                {
                    ApplicationArea = All;
                    ToolTip = 'Cómo se traen las filas hasta el staging. Los dos transportes llenan las mismas tablas y lo que aplica sobre los proyectos y las descargas es el mismo, así que se puede cambiar y volver atrás sin migrar nada.';
                }
                field("Empresa NAV"; Rec."Empresa NAV")
                {
                    ApplicationArea = All;
                    Visible = EsSQL;
                    ToolTip = 'Empresa dentro de la base de NAV. Puede no llamarse igual que en BC: es el prefijo de las tablas del origen, el "Grupo Arbumasa" de "Grupo Arbumasa$Job".';
                }
                field("Linked Server"; Rec."Linked Server")
                {
                    ApplicationArea = All;
                    Visible = EsSQL;
                    ToolTip = 'Nombre del linked server tal como se creó en el servidor de SQL de BC, que no es necesariamente el host de NAV. El usuario y la contraseña con que se conecta no se configuran acá, sino una sola vez en el servidor.';
                }
                field("Base NAV"; Rec."Base NAV")
                {
                    ApplicationArea = All;
                    Visible = EsSQL;
                    ToolTip = 'Base de datos de NAV 2013R2 en el servidor remoto.';
                }
            }
            group(WebServices)
            {
                Caption = 'Web services';
                Visible = EsWS;
                // La URL apunta a una instancia DISTINTA de la de producción. No es una preferencia:
                // la de producción responde NTLM y el HttpClient de AL no lo habla, así que hace
                // falta un service tier aparte sobre la misma base, en NavUserPassword.

                field("URL Base NAV"; Rec."URL Base NAV")
                {
                    ApplicationArea = All;
                    ToolTip = 'Hasta ODataV4 inclusive, sin la empresa y sin barra final. Tiene que ser la instancia de web services en NavUserPassword, no la de producción: ésa pide NTLM y AL no lo habla.';
                }
                field("Empresa OData"; Rec."Empresa OData")
                {
                    ApplicationArea = All;
                    ToolTip = 'El nombre lindo de la empresa, con puntos y espacios, tal como se lee: "Arbumasa S.A.". La codificación para la URL la hace la sincronización.';
                }
                field("Usuario WS"; Rec."Usuario WS")
                {
                    ApplicationArea = All;
                    ToolTip = 'Usuario de NAV para la integración. Conviene uno dedicado y de sólo lectura, no el de una persona: si esa persona se va o le cambian el perfil, la sincronización se cae y nadie relaciona una cosa con la otra.';
                }
                field("Clave WS Cargada"; Rec."Clave WS Cargada")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si la clave de acceso a web services ya está guardada. La clave en sí no se muestra ni se puede leer desde acá: vive en Isolated Storage, fuera del alcance de una exportación de datos o de un paquete de configuración.';
                }
            }
            group(EntidadesOData)
            {
                Caption = 'Entity sets del origen';
                Visible = EsWS;
                // Los nombres los eligió quien publicó los web services en NAV; no hay convención que
                // los haga predecibles, así que se configuran igual que los nombres de tabla del
                // transporte por SQL.

                field("Entidad Proyectos"; Rec."Entidad Proyectos")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de proyectos. El valor normal es ListaProyectos.';
                }
                field("Entidad Descargas"; Rec."Entidad Descargas")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de descargas. Una sola entidad alimenta las dos tablas de staging: la Query de NAV devuelve cabecera y línea juntas en una fila plana.';
                }
                field("Entidad Change Log"; Rec."Entidad Change Log")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set del registro de cambios de NAV. Es el reloj de todo el transporte por web services: OData no expone el rowversion, así que sin esto no hay forma de saber qué cambió. A cambio, detecta las bajas, que el transporte por SQL no puede ver.';
                }
                field("Entidad Empleados"; Rec."Entidad Empleados")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de empleados. Tiene que estar publicado sobre la FICHA del empleado, no sobre la lista: la lista no muestra fecha de ingreso, domicilio ni número de seguridad social, y OData expone sólo lo que la página muestra. Vacío significa que los empleados no se traen por web services.';
                }
                field("Entidad Valores Dim"; Rec."Entidad Valores Dim")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de valores de dimensión. Pesa más de lo que parece: sin valores de dimensión, una marea nueva hace fallar su propio proyecto al aplicarse.';
                }
                field("Entidad Informe Cap Cab"; Rec."Entidad Informe Cap Cab")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de la cabecera del informe del capitán. Consolida la marea entera: sirve para el total, no para cortar a una fecha.';
                }
                field("Entidad Informe Cap Lin"; Rec."Entidad Informe Cap Lin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de las líneas del informe del capitán.';
                }
                field("Entidad Dia Abordo Cab"; Rec."Entidad Dia Abordo Cab")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de la cabecera del diario de abordo.';
                }
                field("Entidad Dia Abordo Lin"; Rec."Entidad Dia Abordo Lin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entity set de las líneas del diario de abordo. Es la única fuente con producción día por día, y de ahí sale poder liquidarle a un tripulante que cortó la marea. Vacío significa que no se trae, y lo único posible sería prorratear el total de la marea por días a bordo.';
                }
            }
            group(TablasNAV)
            {
                Caption = 'N.º de tabla en NAV (registro de cambios)';
                Visible = EsWS;
                // El Change Log identifica qué cambió por NÚMERO de tabla del origen, no por nombre.
                // Son los números de NAV, no los de BC.

                field("Tabla NAV Proyecto"; Rec."Tabla NAV Proyecto") { ApplicationArea = All; ToolTip = 'Tabla Job en NAV. El valor normal es 167.'; }
                field("Tabla NAV Empleado"; Rec."Tabla NAV Empleado") { ApplicationArea = All; ToolTip = 'Tabla Employee en NAV. El valor normal es 5200.'; }
                field("Tabla NAV Valor Dim"; Rec."Tabla NAV Valor Dim") { ApplicationArea = All; ToolTip = 'Tabla Dimension Value en NAV. El valor normal es 349.'; }
                field("Tabla NAV Descarga Cab"; Rec."Tabla NAV Descarga Cab") { ApplicationArea = All; ToolTip = 'Tabla Cab. descarga de la personalización. El valor normal es 50561.'; }
                field("Tabla NAV Descarga Lin"; Rec."Tabla NAV Descarga Lin") { ApplicationArea = All; ToolTip = 'Tabla Lín. descarga de la personalización. El valor normal es 50562. Se mira además de la cabecera: una línea puede cambiar sin que cambie su cabecera.'; }
                field("Tabla NAV Informe Cap Cab"; Rec."Tabla NAV Informe Cap Cab") { ApplicationArea = All; ToolTip = 'Tabla Cab. informe del capitán. El valor normal es 50559.'; }
                field("Tabla NAV Informe Cap Lin"; Rec."Tabla NAV Informe Cap Lin") { ApplicationArea = All; ToolTip = 'Tabla Lín. informe del capitán. El valor normal es 50560.'; }
                field("Tabla NAV Dia Abordo Cab"; Rec."Tabla NAV Dia Abordo Cab") { ApplicationArea = All; ToolTip = 'Tabla Cab. diario de abordo. El valor normal es 50501.'; }
                field("Tabla NAV Dia Abordo Lin"; Rec."Tabla NAV Dia Abordo Lin") { ApplicationArea = All; ToolTip = 'Tabla Lín. diario de abordo. El valor normal es 50502. Como en descargas, se mira además de la cabecera: una línea puede cambiar sin que cambie su cabecera.'; }
            }
            group(TablasOrigen)
            {
                Caption = 'Tablas del origen';
                Visible = EsSQL;
                // Se cargan solas con los nombres esperados y casi nunca se tocan. Están a la vista
                // porque NAV transforma los nombres al crear las tablas —el punto y el apóstrofo se
                // vuelven guión bajo— y el día que uno no coincida, esto se corrige acá en vez de
                // tener que editar el script y volver a crear el procedimiento.

                field("Tabla Empleado"; Rec."Tabla Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la tabla de empleados en NAV, sin el prefijo de empresa. El valor normal es Employee.';
                }
                field("Tabla Proyecto"; Rec."Tabla Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la tabla de proyectos en NAV, sin el prefijo de empresa. El valor normal es Job.';
                }
                field("Tabla Descarga Cab"; Rec."Tabla Descarga Cab")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la tabla de cabeceras de descarga en NAV. El valor normal es "Cab_ descarga": el punto de "Cab. descarga" se convierte en guión bajo al crear la tabla en SQL.';
                }
                field("Tabla Descarga Lin"; Rec."Tabla Descarga Lin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la tabla de líneas de descarga en NAV. El valor normal es "Lín_ descarga".';
                }
                field("Tabla Valor Dimension"; Rec."Tabla Valor Dimension")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tabla de valores de dimensión en NAV. De ahí salen los buques y las mareas que BC todavía no conoce.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CompletarPorDefecto)
            {
                ApplicationArea = All;
                Caption = 'Completar valores por defecto';
                Image = Default;
                ToolTip = 'Rellena con los valores esperados los campos que estén en blanco. No pisa nada de lo que ya esté cargado.';

                trigger OnAction()
                begin
                    // Los valores por defecto sólo corren al INSERTAR la fila. Una configuración
                    // creada antes de que existiera el transporte por web services tiene esos campos
                    // en blanco, y el síntoma no dice qué pasó: "no hay entity set configurado".
                    // Esta acción es la forma de ponerse al día sin tener que borrar y recrear.
                    Rec.PonerNombresPorDefecto();
                    Rec.Modify(true);
                    CurrPage.Update(false);
                    Message(MsgCompletado);
                end;
            }
            action(CargarClaveWS)
            {
                ApplicationArea = All;
                Caption = 'Cargar clave de web services';
                Image = EncryptionKeys;
                Enabled = EsWS;
                ToolTip = 'Guarda la clave de acceso a web services del usuario de NAV. Se guarda en Isolated Storage, así que no se puede volver a leer desde acá: para cambiarla se carga de nuevo.';

                trigger OnAction()
                var
                    Cliente: Codeunit "Cliente NAV WS";
                    PagClave: Page "Clave Web Service NAV";
                    Clave: Text;
                begin
                    if PagClave.RunModal() <> Action::OK then
                        exit;

                    Clave := PagClave.GetClave();
                    if Clave = '' then begin
                        // Vacío es una orden válida: borra la clave guardada. Se avisa, porque
                        // aceptar el diálogo sin escribir nada suele ser un descuido y no una baja.
                        if not Confirm(ConfirmBorrarClave, false) then
                            exit;
                    end;

                    Cliente.GuardarClave(Rec."Empresa BC", Clave);
                    Clear(Clave);

                    // GuardarClave escribe sobre SU propia instancia del registro, no sobre la de la
                    // página. Sin releer, "Clave cargada" sigue mostrando lo de antes: la clave está
                    // guardada y la pantalla dice que no, que es la peor combinación posible para
                    // diagnosticar un 401.
                    if Rec.Find() then;
                    CurrPage.Update(false);
                    Message(MsgClaveGuardada);
                end;
            }
            action(ProbarConexionWS)
            {
                ApplicationArea = All;
                Caption = 'Probar conexión';
                Image = Link;
                Enabled = EsWS;
                ToolTip = 'Pide una fila de proyectos a NAV. Si esto anda, andan la URL, el certificado, la autenticación y los permisos del usuario.';

                trigger OnAction()
                var
                    Cliente: Codeunit "Cliente NAV WS";
                    Detalle: Text;
                begin
                    if not Cliente.SetEmpresa(Rec."Empresa BC") then begin
                        Message(Cliente.GetUltimoError());
                        exit;
                    end;

                    if Cliente.ProbarConexion(Detalle) then
                        Message(Detalle)
                    else
                        Message(MsgPruebaFallo, Detalle);
                end;
            }
        }
        area(Navigation)
        {
            action(VerControl)
            {
                ApplicationArea = All;
                Caption = 'Estado de la sincronización';
                Image = Status;
                RunObject = page "Control Sinc. NAV";
                ToolTip = 'Cuándo trajo el job de SQL, cuándo aplicó BC y qué quedó pendiente o en error.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(CompletarPorDefecto_Promoted; CompletarPorDefecto) { }
                actionref(ProbarConexionWS_Promoted; ProbarConexionWS) { }
                actionref(VerControl_Promoted; VerControl) { }
            }
        }
    }

    var
        EsSQL: Boolean;
        EsWS: Boolean;
        MsgClaveGuardada: Label 'Clave guardada. Probá la conexión para confirmar que NAV la acepta.';
        MsgPruebaFallo: Label 'No conecta.\\%1', Comment = '%1 = detalle del error';
        MsgCompletado: Label 'Listo. Los campos que estaban en blanco quedaron con los valores esperados; revisá que sean los de esta instalación.';
        ConfirmBorrarClave: Label 'No escribiste ninguna clave. ¿Querés borrar la que está guardada?';

    trigger OnAfterGetRecord()
    begin
        ActualizarVisibilidad();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        ActualizarVisibilidad();
    end;

    local procedure ActualizarVisibilidad()
    begin
        EsSQL := Rec.Transporte = Rec.Transporte::"SQL (linked server)";
        EsWS := Rec.Transporte = Rec.Transporte::"Web Services";
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // Los nombres de tabla del origen aparecen ya cargados al empezar la fila, en vez de en
        // blanco: son los mismos en toda instalación normal y verlos puestos evita la duda de si
        // hay que completarlos.
        Rec.PonerNombresPorDefecto();
    end;
}
