unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ShellCtrls,
  Menus, LclIntf, ComCtrls, StdCtrls, ExtCtrls, LCLType, FileUtil, ULogica;

type
  { TForm1 }
  TForm1 = class(TForm)
    EditRuta: TEdit;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItemActualizar: TMenuItem;
    PopupMenu1: TPopupMenu;
    ShellListView1: TShellListView;
    ShellTreeView1: TShellTreeView;
    StatusBar1: TStatusBar;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    procedure FormCreate(Sender: TObject);
    procedure EditRutaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure MenuItem6Click(Sender: TObject);
    procedure MenuItemActualizarClick(Sender: TObject);
    procedure ShellListView1Click(Sender: TObject);
    procedure ShellListView1DblClick(Sender: TObject);
    procedure ShellListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ShellTreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure ShellTreeView1DragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ShellTreeView1DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ToolButton1Click(Sender: TObject);
    procedure btnAdelanteClick(Sender: TObject);
    procedure btnAtrasClick(Sender: TObject);
    procedure btnHomeClick(Sender: TObject);
  private
    ListaAtras: TStringList;
    ListaAdelante: TStringList;
    NavegandoHistorial: Boolean;
    {$IFDEF UNIX}
    IconosSistema: TImageList;
    procedure ConfigurarIconosLinux;
    {$ENDIF}
    procedure ActualizarEstado;
    procedure CambiarRuta(const NuevaRuta: string; AgregarAlHistorial: Boolean = True);
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{$IFDEF UNIX}
procedure TForm1.ConfigurarIconosLinux;
begin
  // Creamos la lista de iconos solo para Linux
  IconosSistema := TImageList.Create(Self);
  IconosSistema.Width := 16;
  IconosSistema.Height := 16;

  // Intentamos cargar iconos de carpetas y archivos desde rutas comunes de Linux
  // Si no existen en tu distro, el ImageList quedará vacío pero vinculado, 
  // lo que ayuda a que el ShellListView se dibuje correctamente.
  if FileExists('/usr/share/icons/hicolor/16x16/places/folder.png') then
    IconosSistema.AddPixelsFromFile('/usr/share/icons/hicolor/16x16/places/folder.png');
    
  if FileExists('/usr/share/icons/hicolor/16x16/mimetypes/text-x-generic.png') then
    IconosSistema.AddPixelsFromFile('/usr/share/icons/hicolor/16x16/mimetypes/text-x-generic.png');

  ShellListView1.SmallImages := IconosSistema;
  ShellTreeView1.Images := IconosSistema;
end;
{$ENDIF}

type
  // Truco para acceder a propiedades protegidas si no son publicas en esta version
  TTreeCracker = class(TShellTreeView);

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ListaAtras := TStringList.Create;
  ListaAdelante := TStringList.Create;
  NavegandoHistorial := False;

  // Asignamos los eventos de Drag & Drop por código para evitar errores en el LFM
  TTreeCracker(ShellTreeView1).OnDragDrop := @ShellTreeView1DragDrop;
  TTreeCracker(ShellTreeView1).OnDragOver := @ShellTreeView1DragOver;

  {$IFDEF UNIX}
  ConfigurarIconosLinux; // Solo se ejecuta en Linux
  ShellTreeView1.Root := '/';
  ShellListView1.Root := GetUserDir;
  // En Linux, vsReport es mucho más estable para ShellListView
  // y evita el problema de visualización "roto" en modo vsIcon
  ShellListView1.ViewStyle := vsReport;
  // Corregimos colores que pueden verse mal en ciertos temas de Linux
  ShellTreeView1.Color := clDefault;
  ShellTreeView1.BackgroundColor := clDefault;
  {$ELSE}
  ShellTreeView1.Root := '';
  ShellListView1.ViewStyle := vsIcon;
  {$ENDIF}

  // Habilitamos selección múltiple y arrastrar/soltar por código
  ShellListView1.MultiSelect := True;
  ShellListView1.DragMode := dmAutomatic;

  RefrescarVistas(ShellListView1, ShellTreeView1);
  ActualizarEstado;
end;

procedure TForm1.CambiarRuta(const NuevaRuta: string; AgregarAlHistorial: Boolean = True);
var
  RutaAnterior: string;
begin
  if EsDirectorio(NuevaRuta) then
  begin
    RutaAnterior := ShellListView1.Root;

    if AgregarAlHistorial and (RutaAnterior <> '') and (RutaAnterior <> NuevaRuta) then
    begin
      ListaAtras.Add(RutaAnterior);
      ListaAdelante.Clear; // Al navegar a una ruta nueva, se limpia el "adelante"
    end;

    ShellListView1.Root := NuevaRuta;
    ShellTreeView1.Path := NuevaRuta;
    ActualizarEstado;
  end;
end;

procedure TForm1.EditRutaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if EsDirectorio(EditRuta.Text) then
      CambiarRuta(EditRuta.Text)
    else
      ShowMessage('La ruta no existe.');
  end;
end;

procedure TForm1.ActualizarEstado;
begin
  if Assigned(EditRuta) then
    EditRuta.Text := ShellListView1.Root;

  if Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Elementos: ' + IntToStr(ShellListView1.Items.Count);
end;

procedure TForm1.MenuItemActualizarClick(Sender: TObject);
begin
  RefrescarVistas(ShellListView1, ShellTreeView1);
  ActualizarEstado;
end;

procedure TForm1.ShellTreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  // Al cambiar en el árbol, el ShellListView se actualiza automáticamente
  // por la propiedad ShellListView vinculada, pero forzamos el refresco
  // de los datos de la interfaz (Edit e Items.Count)
  ActualizarEstado;
end;

procedure TForm1.btnAtrasClick(Sender: TObject);
var
  Ruta: string;
begin
  if ListaAtras.Count > 0 then
  begin
    Ruta := ListaAtras[ListaAtras.Count - 1];
    ListaAtras.Delete(ListaAtras.Count - 1);
    ListaAdelante.Add(ShellListView1.Root);
    CambiarRuta(Ruta, False);
  end;
end;

procedure TForm1.btnAdelanteClick(Sender: TObject);
var
  Ruta: string;
begin
  if ListaAdelante.Count > 0 then
  begin
    Ruta := ListaAdelante[ListaAdelante.Count - 1];
    ListaAdelante.Delete(ListaAdelante.Count - 1);
    ListaAtras.Add(ShellListView1.Root);
    CambiarRuta(Ruta, False);
  end;
end;

procedure TForm1.btnHomeClick(Sender: TObject);
begin
  CambiarRuta(GetUserDir);
end;

procedure TForm1.ToolButton1Click(Sender: TObject);
var
  RutaActual, RutaPadre: string;
begin
  RutaActual := ShellListView1.Root;
  {$IFDEF UNIX}
  if RutaActual = '/' then Exit;
  {$ENDIF}
  RutaPadre := ExtractFileDir(ExcludeTrailingPathDelimiter(RutaActual));

  if (RutaPadre <> '') and (RutaPadre <> RutaActual) then
    CambiarRuta(RutaPadre);
end;

procedure TForm1.ShellListView1DblClick(Sender: TObject);
begin
  MenuItem6Click(Sender);
end;

procedure TForm1.ShellListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    MenuItem6Click(Sender);
  end;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
var
  i: Integer;
  Exito: Boolean;
  Fallos, Exitos: Integer;
  Mensaje: string;
begin
  if ShellListView1.SelCount = 0 then Exit;

  if ShellListView1.SelCount = 1 then
    Mensaje := '¿Estás seguro de eliminar el elemento seleccionado?'
  else
    Mensaje := '¿Estás seguro de eliminar los ' + IntToStr(ShellListView1.SelCount) + ' elementos seleccionados?';

  if MessageDlg('Eliminar', Mensaje, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Exito := False;
    Fallos := 0;
    Exitos := 0;
    // Iterar hacia atrás al eliminar elementos de una lista
    for i := ShellListView1.Items.Count - 1 downto 0 do
    begin
      if ShellListView1.Items[i].Selected then
      begin
        if BorrarElementoSilencioso(ShellListView1.GetPathFromItem(ShellListView1.Items[i])) then
        begin
          Exito := True;
          Inc(Exitos);
        end
        else
        begin
          Inc(Fallos);
        end;
      end;
    end;

    if Fallos > 0 then
    begin
      Mensaje := 'Falló la eliminación de ' + IntToStr(Fallos) + ' elemento(s).';
      {$IFDEF UNIX}
      Mensaje := Mensaje + ' Verifica que tengas permisos suficientes. Sugerencia: Revisa los permisos usando chmod o chown.';
      {$ENDIF}
      ShowMessage(Mensaje);
    end;

    if Exito then MenuItemActualizarClick(Sender);
  end;
end;

procedure TForm1.MenuItem3Click(Sender: TObject);
var
  NuevaRuta: string;
begin
  if CrearCarpeta(ShellListView1.Root, NuevaRuta) then
  begin
    RefrescarVistas(ShellListView1, ShellTreeView1);
    ActualizarEstado;
  end;
end;

procedure TForm1.MenuItem4Click(Sender: TObject);
var
  i: Integer;
  RutasSeleccionadas: TStringList;
begin
  if ShellListView1.SelCount > 0 then
  begin
    RutasSeleccionadas := TStringList.Create;
    try
      for i := 0 to ShellListView1.Items.Count - 1 do
      begin
        if ShellListView1.Items[i].Selected then
          RutasSeleccionadas.Add(ShellListView1.GetPathFromItem(ShellListView1.Items[i]));
      end;
      IniciarCopia(RutasSeleccionadas);
      if Assigned(StatusBar1) then
        StatusBar1.SimpleText := 'Copiados ' + IntToStr(RutasSeleccionadas.Count) + ' elementos.';
    finally
      RutasSeleccionadas.Free;
    end;
  end;
end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
  if EjecutarPegado(ShellListView1.Root) then
  begin
    RefrescarVistas(ShellListView1, ShellTreeView1);
    ActualizarEstado;
    if Assigned(StatusBar1) then
      StatusBar1.SimpleText := 'Pegado completado con éxito.';
  end;
end;

procedure TForm1.MenuItem6Click(Sender: TObject);
var
  RutaSeleccionada: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    RutaSeleccionada := ShellListView1.GetPathFromItem(ShellListView1.Selected);

    if EsDirectorio(RutaSeleccionada) then
      CambiarRuta(RutaSeleccionada)
    else
      AbrirElemento(RutaSeleccionada);
  end;
end;

procedure TForm1.MenuItem1Click(Sender: TObject);
var
  ViejaRuta, NuevaRuta: string;
begin
  if ShellListView1.SelCount = 1 then
  begin
    ViejaRuta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if RenombrarElemento(ViejaRuta, NuevaRuta) then
    begin
      MenuItemActualizarClick(Sender);
    end;
  end
  else if ShellListView1.SelCount > 1 then
    ShowMessage('Por favor, selecciona solo un elemento para renombrar.');
end;

procedure TForm1.ShellListView1Click(Sender: TObject);
begin
  if Assigned(ShellListView1.Selected) and Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Seleccionado: ' + ShellListView1.Selected.Caption;
end;

// Eventos para el Drag and Drop
procedure TForm1.ShellTreeView1DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Source is TShellListView);
end;

procedure TForm1.ShellTreeView1DragDrop(Sender, Source: TObject; X, Y: Integer);
var
  NodoDestino: TTreeNode;
  RutaDestino: string;
  i: Integer;
  ListaArrastrada: TStringList;
begin
  if Source is TShellListView then
  begin
    NodoDestino := ShellTreeView1.GetNodeAt(X, Y);
    if Assigned(NodoDestino) then
    begin
      RutaDestino := ShellTreeView1.GetPathFromNode(NodoDestino);

      if EsDirectorio(RutaDestino) then
      begin
        ListaArrastrada := TStringList.Create;
        try
          for i := 0 to ShellListView1.Items.Count - 1 do
          begin
            if ShellListView1.Items[i].Selected then
              ListaArrastrada.Add(ShellListView1.GetPathFromItem(ShellListView1.Items[i]));
          end;

          IniciarCopia(ListaArrastrada);
          EjecutarPegado(RutaDestino);

          // Limpiamos el portapapeles tras soltar
          RutasPortapapeles.Clear;

          RefrescarVistas(ShellListView1, ShellTreeView1);
          if Assigned(StatusBar1) then
            StatusBar1.SimpleText := 'Archivos copiados a ' + ExtractFileName(RutaDestino);
        finally
          ListaArrastrada.Free;
        end;
      end;
    end;
  end;
end;

end.
