# Documentación del Sistema: Gestor de Archivos (Lazarus)

## 1. Descripción General
Este documento contiene el código fuente y la estructura completa del Gestor de Archivos desarrollado en Lazarus. El sistema es una aplicación de escritorio multiplataforma (probada en Windows y Linux) que permite navegar por el sistema de archivos, copiar, cortar, pegar, eliminar, enviar a la papelera, crear carpetas y renombrar archivos. 

La arquitectura se divide principalmente en tres componentes:
*   **project1.lpr:** El punto de entrada principal de la aplicación.
*   **Unit1.pas / Unit1.lfm:** La interfaz de usuario (vista) y sus controladores de eventos.
*   **ULogica.pas:** El módulo que centraliza la lógica de negocio (operaciones sobre archivos).

---

## 2. Código Fuente

### 2.1. Archivo de Proyecto (`project1.lpr`)
Este archivo inicializa la aplicación y crea el formulario principal.

```pascal
program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
```

### 2.2. Lógica del Negocio (`ULogica.pas`)
Esta unidad aísla la funcionalidad del sistema de archivos. Gestiona el portapapeles, operaciones recursivas de carpetas, operaciones multiplataforma para la papelera y el sistema operativo.

```pascal
unit ULogica;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, LclIntf, FileUtil, Controls, LCLType, ShellCtrls, Process;

{ --- DEFINICIÓN DE FUNCIONES DE LÓGICA --- }

var
  RutasPortapapeles: TStringList; // Almacena múltiples rutas para copiar/pegar
  EsOperacionCorte: Boolean;      // Indica si la acción actual es Cortar o Copiar

procedure AbrirElemento(const Ruta: string);
procedure IniciarCopia(ListaRutas: TStrings);
procedure IniciarCorte(ListaRutas: TStrings);
function EnviarALaPapelera(const Ruta: string): Boolean;
function EjecutarPegado(const DestinoBase: string): Boolean;
function CrearCarpeta(const RutaBase: string; out NuevaRuta: string): Boolean;
function BorrarElemento(const Ruta: string): Boolean;
function BorrarElementoSilencioso(const Ruta: string): Boolean;
function RenombrarElemento(const ViejaRuta: string; out NuevaRuta: string): Boolean;
function EsDirectorio(const Ruta: string): Boolean;
procedure RefrescarVistas(AListView: TShellListView; ATreeView: TShellTreeView);
function CopiarDirectorio(RutaOrigen, RutaDestino: string): Boolean;

implementation

{$IFDEF MSWINDOWS}
uses
  ShellAPI;
{$ENDIF}

function EnviarALaPapelera(const Ruta: string): Boolean;
{$IFDEF MSWINDOWS}
var
  FileOp: TSHFILEOPSTRUCTW;
  RutaWindows: UnicodeString;
begin
  RutaWindows := UTF8Decode(Ruta) + #0#0;
  FillChar(FileOp, SizeOf(FileOp), 0);
  FileOp.Wnd := 0;
  FileOp.wFunc := FO_DELETE;
  FileOp.pFrom := PWideChar(RutaWindows);
  FileOp.fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION;
  Result := (SHFileOperationW(@FileOp) = 0);
end;
{$ELSE}
var
  Salida: string; // Variable para capturar la salida del comando
begin
  // Intentamos usar 'gio trash'
  Result := RunCommand('gio', ['trash', Ruta], Salida);

  if not Result then
    // Alternativa si no existe gio
    Result := RunCommand('trash-put', [Ruta], Salida);
end;
{$ENDIF}

procedure AbrirElemento(const Ruta: string);
begin
  if Ruta = '' then Exit;

  if DirectoryExists(Ruta) then
  begin
    // Si es una carpeta, la navegación se gestiona en el Form
  end
  else if FileExists(Ruta) then
  begin
    if not OpenDocument(Ruta) then
    begin
      {$IFDEF UNIX}
      ShowMessage('Error: No se pudo abrir el archivo. Verifica que "xdg-open" u otra herramienta por defecto esté instalada.');
      {$ELSE}
      ShowMessage('No se encontró una aplicación asociada para abrir este archivo.');
      {$ENDIF}
    end;
  end;
end;

procedure IniciarCopia(ListaRutas: TStrings);
begin
  RutasPortapapeles.Assign(ListaRutas);
  EsOperacionCorte := False;
end;

procedure IniciarCorte(ListaRutas: TStrings);
begin
  RutasPortapapeles.Assign(ListaRutas);
  EsOperacionCorte := True;
end;

function CopiarDirectorio(RutaOrigen, RutaDestino: string): Boolean;
var
  Info: TSearchRec;
begin
  Result := True;
  RutaOrigen := IncludeTrailingPathDelimiter(RutaOrigen);
  RutaDestino := IncludeTrailingPathDelimiter(RutaDestino);

  // Intentar crear el directorio de destino
  if not DirectoryExists(RutaDestino) then
    if not ForceDirectories(RutaDestino) then Exit(False);

  if FindFirst(RutaOrigen + '*', faAnyFile, Info) = 0 then
  begin
    try
      repeat
        if (Info.Name <> '.') and (Info.Name <> '..') then
        begin
          if (Info.Attr and faDirectory) = faDirectory then
            Result := CopiarDirectorio(RutaOrigen + Info.Name, RutaDestino + Info.Name)
          else
            Result := CopyFile(RutaOrigen + Info.Name, RutaDestino + Info.Name, [cffOverwriteFile, cffPreserveTime]);
        end;
      until (FindNext(Info) <> 0) or (not Result);
    finally
      FindClose(Info);
    end;
  end;
end;

function EjecutarPegado(const DestinoBase: string): Boolean;
var
  Ruta, NombreDestino: string;
  i: Integer;
  ExitoMover: Boolean;
begin
  Result := False;
  if (not Assigned(RutasPortapapeles)) or (RutasPortapapeles.Count = 0) then Exit;
  Result := True;

  for i := 0 to RutasPortapapeles.Count - 1 do
  begin
    Ruta := RutasPortapapeles[i];
    NombreDestino := IncludeTrailingPathDelimiter(DestinoBase) + ExtractFileName(Ruta);

    if SameFileName(Ruta, NombreDestino) then
      Continue;

    if EsOperacionCorte then
    begin
      ExitoMover := RenameFile(Ruta, NombreDestino);

      if not ExitoMover then
      begin
        if DirectoryExists(Ruta) then
          ExitoMover := CopiarDirectorio(Ruta, NombreDestino)
        else
          ExitoMover := CopyFile(Ruta, NombreDestino, [cffOverwriteFile, cffPreserveTime]);

        if ExitoMover then BorrarElementoSilencioso(Ruta);
      end;
      Result := Result and ExitoMover;
    end
    else
    begin
      if DirectoryExists(Ruta) then
        Result := Result and CopiarDirectorio(Ruta, NombreDestino)
      else
        Result := Result and CopyFile(Ruta, NombreDestino, [cffOverwriteFile, cffPreserveTime]);
    end;
  end;

  if EsOperacionCorte and Result then
    RutasPortapapeles.Clear;

  if not Result then ShowMessage('Hubo un problema al pegar uno o más elementos. Verifica los permisos.');
end;

function CrearCarpeta(const RutaBase: string; out NuevaRuta: string): Boolean;
var
  NombreNuevo: string;
begin
  Result := False;
  NombreNuevo := 'Nueva Carpeta';
  if InputQuery('Crear Carpeta', 'Nombre de la nueva carpeta:', NombreNuevo) then
  begin
    NuevaRuta := IncludeTrailingPathDelimiter(RutaBase) + NombreNuevo;
    Result := CreateDir(NuevaRuta);
    if not Result then
      ShowMessage('Error al crear la carpeta. Verifica los permisos o si ya existe.');
  end;
end;

function BorrarElemento(const Ruta: string): Boolean;
begin
  Result := False;
  if QuestionDlg('Borrar', '¿Eliminar ' + ExtractFileName(Ruta) + '?',
     mtConfirmation, [mrYes, mrNo], 0) = mrYes then
  begin
    Result := BorrarElementoSilencioso(Ruta);
  end;
end;

function BorrarElementoSilencioso(const Ruta: string): Boolean;
begin
  if DirectoryExists(Ruta) then
    Result := DeleteDirectory(Ruta, False)
  else
    Result := DeleteFile(Ruta);
end;

function RenombrarElemento(const ViejaRuta: string; out NuevaRuta: string): Boolean;
var
  NuevoNombre: string;
begin
  Result := False;
  NuevoNombre := ExtractFileName(ViejaRuta);
  if InputQuery('Renombrar', 'Nuevo nombre:', NuevoNombre) then
  begin
    NuevaRuta := ExtractFilePath(ViejaRuta) + NuevoNombre;
    Result := RenameFile(ViejaRuta, NuevaRuta);

    if not Result then
      ShowMessage('Error: No se pudo renombrar el archivo. Puede que esté en uso o falten permisos.');
  end;
end;

function EsDirectorio(const Ruta: string): Boolean;
begin
  Result := DirectoryExists(Ruta);
end;

procedure RefrescarVistas(AListView: TShellListView; ATreeView: TShellTreeView);
var
  RutaActual: string;
begin
  if Assigned(AListView) then
  begin
    RutaActual := AListView.Root;
    AListView.Items.BeginUpdate;
    try
      AListView.Root := '';
      AListView.Root := RutaActual;
    finally
      AListView.Items.EndUpdate;
    end;
  end;

  if Assigned(ATreeView) then
    ATreeView.Refresh;
end;

initialization
  RutasPortapapeles := TStringList.Create;

finalization
  RutasPortapapeles.Free;

end.
```

### 2.3. Código del Formulario (`Unit1.pas`)
Contiene los manejadores de eventos, el historial de navegación (atrás/adelante) y el enlace con la lógica de `ULogica.pas`.

```pascal
unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ShellCtrls,
  Menus, LclIntf, ComCtrls, StdCtrls, ExtCtrls, LCLType, FileUtil, ULogica;

type
  { TForm1 }
  TForm1 = class(TForm)
    btnAdelante: TToolButton;
    btnAtras: TToolButton;
    btnHome: TToolButton;
    btnRefrescar: TToolButton;
    btnPapelera: TToolButton;
    btnSeparador1: TToolButton;
    btnSeparador2: TToolButton;
    btnSubir: TToolButton;
    EditRuta: TEdit;
    MenuItemBorrar: TMenuItem;
    MenuItemRenombrar: TMenuItem;
    MenuItemEliminar: TMenuItem;
    MenuItemCrearCarpeta: TMenuItem;
    MenuItemCopiar: TMenuItem;
    MenuItemPegar: TMenuItem;
    MenuItemAbrir: TMenuItem;
    MenuItemCortar: TMenuItem;
    MenuItemActualizar: TMenuItem;
    PopupMenu1: TPopupMenu;
    ShellListView1: TShellListView;
    ShellTreeView1: TShellTreeView;
    StatusBar1: TStatusBar;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    procedure FormCreate(Sender: TObject);
    procedure EditRutaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuItemBorrarClick(Sender: TObject);
    procedure MenuItemRenombrarClick(Sender: TObject);
    procedure MenuItemEliminarClick(Sender: TObject);
    procedure MenuItemCrearCarpetaClick(Sender: TObject);
    procedure MenuItemCopiarClick(Sender: TObject);
    procedure MenuItemPegarClick(Sender: TObject);
    procedure MenuItemAbrirClick(Sender: TObject);
    procedure MenuItemCortarClick(Sender: TObject);
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
    procedure btnPapeleraClick(Sender: TObject);
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
  function BuscarIcono(const Nombre: string; EsCarpeta: Boolean): string;
  var
    Temas: array[0..5] of string;
    Categorias: array[0..1] of string;
    i, j: Integer;
    RutaBase: string;
  begin
    Result := '';
    Temas[0] := 'Mint-Y'; Temas[1] := 'Adwaita'; Temas[2] := 'hicolor';
    Temas[3] := 'Papirus'; Temas[4] := 'gnome'; Temas[5] := 'breeze';
    
    if EsCarpeta then
    begin
      Categorias[0] := 'places'; Categorias[1] := 'apps';
    end
    else
    begin
      Categorias[0] := 'mimetypes'; Categorias[1] := 'mimetypes';
    end;

    for i := 0 to High(Temas) do
      for j := 0 to High(Categorias) do
      begin
        RutaBase := '/usr/share/icons/' + Temas[i] + '/16x16/' + Categorias[j] + '/' + Nombre + '.png';
        if FileExists(RutaBase) then Exit(RutaBase);
      end;
  end;
var
  Ruta: string;
  Pic: TPicture;
begin
  IconosSistema := TImageList.Create(Self);
  IconosSistema.Width := 16;
  IconosSistema.Height := 16;

  Pic := TPicture.Create;
  try
    Ruta := BuscarIcono('folder', True);
    if (Ruta <> '') and FileExists(Ruta) then
    begin
      Pic.LoadFromFile(Ruta);
      IconosSistema.Add(Pic.Bitmap, nil);
    end;
    
    Ruta := BuscarIcono('text-x-generic', False);
    if (Ruta <> '') and FileExists(Ruta) then
    begin
      Pic.LoadFromFile(Ruta);
      IconosSistema.Add(Pic.Bitmap, nil);
    end;
  finally
    Pic.Free;
  end;

  ShellListView1.SmallImages := IconosSistema;
  ShellTreeView1.Images := IconosSistema;
end;
{$ENDIF}

type
  TTreeCracker = class(TShellTreeView);

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ListaAtras := TStringList.Create;
  ListaAdelante := TStringList.Create;
  NavegandoHistorial := False;

  TTreeCracker(ShellTreeView1).OnDragDrop := @ShellTreeView1DragDrop;
  TTreeCracker(ShellTreeView1).OnDragOver := @ShellTreeView1DragOver;

  {$IFDEF UNIX}
  ConfigurarIconosLinux;
  ShellTreeView1.Root := '/';
  ShellListView1.Root := GetUserDir;
  ShellListView1.ViewStyle := vsReport;
  ShellTreeView1.Color := clDefault;
  ShellTreeView1.BackgroundColor := clDefault;
  {$ELSE}
  ShellTreeView1.Root := '';
  ShellListView1.ViewStyle := vsIcon;
  {$ENDIF}

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
      ListaAdelante.Clear;
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

procedure TForm1.MenuItemBorrarClick(Sender: TObject);
var
  i: Integer;
  Ruta: string;
  Exito: Boolean;
begin
  if ShellListView1.SelCount = 0 then Exit;

  Exito := True;
  for i := ShellListView1.Items.Count - 1 downto 0 do
  begin
    if ShellListView1.Items[i].Selected then
    begin
      Ruta := ShellListView1.GetPathFromItem(ShellListView1.Items[i]);
      if not EnviarALaPapelera(Ruta) then
        Exito := False;
    end;
  end;

  if Exito then
  begin
    MenuItemActualizarClick(Sender);
    StatusBar1.SimpleText := 'Elementos enviados a la papelera.';
  end
  else
    ShowMessage('Algunos elementos no pudieron enviarse a la papelera.');
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

procedure TForm1.btnPapeleraClick(Sender: TObject);
begin
  {$IFDEF UNIX}
  CambiarRuta(IncludeTrailingPathDelimiter(GetUserDir) + '.local/share/Trash/files');
  {$ELSE}
  OpenDocument('shell:RecycleBinFolder');
  {$ENDIF}
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
  MenuItemAbrirClick(Sender);
end;

procedure TForm1.ShellListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    MenuItemAbrirClick(Sender);
  end;
end;

procedure TForm1.MenuItemEliminarClick(Sender: TObject);
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
      Mensaje := Mensaje + ' Verifica permisos.';
      {$ENDIF}
      ShowMessage(Mensaje);
    end;

    if Exito then MenuItemActualizarClick(Sender);
  end;
end;

procedure TForm1.MenuItemCrearCarpetaClick(Sender: TObject);
var
  NuevaRuta: string;
begin
  if CrearCarpeta(ShellListView1.Root, NuevaRuta) then
  begin
    RefrescarVistas(ShellListView1, ShellTreeView1);
    ActualizarEstado;
  end;
end;

procedure TForm1.MenuItemCopiarClick(Sender: TObject);
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
    finally
      RutasSeleccionadas.Free;
    end;
  end;
end;

procedure TForm1.MenuItemPegarClick(Sender: TObject);
begin
  if EjecutarPegado(ShellListView1.Root) then
  begin
    RefrescarVistas(ShellListView1, ShellTreeView1);
    ActualizarEstado;
  end;
end;

procedure TForm1.MenuItemAbrirClick(Sender: TObject);
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

procedure TForm1.MenuItemCortarClick(Sender: TObject);
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
     IniciarCorte(RutasSeleccionadas);
    finally
      RutasSeleccionadas.Free;
    end;
  end;
end;

procedure TForm1.MenuItemRenombrarClick(Sender: TObject);
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
    ShowMessage('Selecciona solo un elemento.');
end;

procedure TForm1.ShellListView1Click(Sender: TObject);
begin
  if Assigned(ShellListView1.Selected) and Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Seleccionado: ' + ShellListView1.Selected.Caption;
end;

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

          RutasPortapapeles.Clear;
          RefrescarVistas(ShellListView1, ShellTreeView1);
        finally
          ListaArrastrada.Free;
        end;
      end;
    end;
  end;
end;

end.
```

### 2.4. Interfaz Gráfica (`Unit1.lfm`)
Este archivo contiene la definición del formulario principal, los botones y barras de herramientas.

```pascal
object Form1: TForm1
  Left = 401
  Height = 422
  Top = 152
  Width = 879
  Caption = 'Gestor de Archivos'
  ClientHeight = 422
  ClientWidth = 879
  LCLVersion = '4.6.0.0'
  OnCreate = FormCreate
  object ShellTreeView1: TShellTreeView
    Left = 0
    Height = 346
    Top = 58
    Width = 216
    Align = alLeft
    AutoExpand = True
    BackgroundColor = clInactiveCaption
    Color = clInactiveCaption
    PopupMenu = PopupMenu1
    ShowLines = False
    TabOrder = 0
    Options = [tvoAutoExpand, tvoAutoItemHeight, tvoHideSelection, tvoKeepCollapsedNodes, tvoReadOnly, tvoShowButtons, tvoShowRoot, tvoToolTips, tvoThemedDraw]
    ObjectTypes = [otFolders, otHidden]
    ShellListView = ShellListView1
    OnChange = ShellTreeView1Change
  end
  object ShellListView1: TShellListView
    Left = 216
    Height = 346
    Top = 58
    Width = 663
    Align = alClient
    Color = clDefault
    DragMode = dmAutomatic
    ParentShowHint = False
    PopupMenu = PopupMenu1
    ShowHint = True
    SmallImagesWidth = 16
    TabOrder = 1
    ViewStyle = vsIcon
    ObjectTypes = [otFolders, otNonFolders, otHidden]
    ShellTreeView = ShellTreeView1
    OnClick = ShellListView1Click
    OnDblClick = ShellListView1DblClick
  end
  object ToolBar1: TToolBar
    Left = 0
    Height = 30
    Top = 0
    Width = 879
    ButtonHeight = 28
    ButtonWidth = 80
    Caption = 'ToolBar1'
    EdgeBorders = [ebBottom]
    List = True
    ShowCaptions = True
    TabOrder = 2
    object btnAtras: TToolButton
      Left = 1
      Top = 0
      Caption = '◀ Atrás'
      OnClick = btnAtrasClick
    end
    object btnAdelante: TToolButton
      Left = 81
      Top = 0
      Caption = 'Adelante ▶'
      OnClick = btnAdelanteClick
    end
    object btnSeparador1: TToolButton
      Left = 161
      Height = 28
      Top = 0
      Caption = 'btnSeparador1'
      Style = tbsSeparator
    end
    object btnSubir: TToolButton
      Left = 169
      Top = 0
      Caption = '▲ Subir'
      OnClick = ToolButton1Click
    end
    object btnSeparador2: TToolButton
      Left = 249
      Height = 28
      Top = 0
      Caption = 'btnSeparador2'
      Style = tbsSeparator
    end
    object btnHome: TToolButton
      Left = 257
      Top = 0
      Caption = '🏠 Inicio'
      OnClick = btnHomeClick
    end
    object btnRefrescar: TToolButton
      Left = 337
      Top = 0
      Caption = '🔄 Refrescar'
      OnClick = MenuItemActualizarClick
    end
    object btnPapelera: TToolButton
      Left = 417
      Top = 0
      Caption = '🗑 Papelera'
      OnClick = btnPapeleraClick
    end
  end
  object EditRuta: TEdit
    Left = 0
    Height = 28
    Top = 30
    Width = 879
    Align = alTop
    TabOrder = 3
    OnKeyDown = EditRutaKeyDown
  end
  object StatusBar1: TStatusBar
    Left = 0
    Height = 18
    Top = 404
    Width = 879
    Panels = <>
  end
  object PopupMenu1: TPopupMenu
    Left = 342
    Top = 223
    object MenuItemAbrir: TMenuItem
      Caption = 'Abrir'
      OnClick = MenuItemAbrirClick
    end
    object MenuItemActualizar: TMenuItem
      Caption = 'Actualizar'
      OnClick = MenuItemActualizarClick
    end
    object MenuItemRenombrar: TMenuItem
      Caption = 'Renombrar'
      OnClick = MenuItemRenombrarClick
    end
    object MenuItemCopiar: TMenuItem
      Caption = 'Copiar'
      OnClick = MenuItemCopiarClick
    end
    object MenuItemCortar: TMenuItem
      Caption = 'Cortar'
      OnClick = MenuItemCortarClick
    end
    object MenuItemPegar: TMenuItem
      Caption = 'Pegar'
      OnClick = MenuItemPegarClick
    end
    object MenuItemEliminar: TMenuItem
      Caption = 'Eliminar'
      OnClick = MenuItemEliminarClick
    end
    object MenuItemBorrar: TMenuItem
      Caption = 'Borrar'
      OnClick = MenuItemBorrarClick
    end
    object MenuItemCrearCarpeta: TMenuItem
      Caption = 'Crear Carpeta'
      OnClick = MenuItemCrearCarpetaClick
    end
  end
end
```
