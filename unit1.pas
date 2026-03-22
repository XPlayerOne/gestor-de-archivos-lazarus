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
    ImageList1: TImageList;
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
    procedure ShellTreeView1Click(Sender: TObject);
    procedure ShellTreeView1DragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ShellTreeView1DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ToolButton1Click(Sender: TObject);
  private
    procedure ActualizarEstado;
    procedure CambiarRuta(const NuevaRuta: string);
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ShellTreeView1.Root := '';
  ShellListView1.ViewStyle := vsIcon;

  // Habilitamos selección múltiple y arrastrar/soltar por código
  ShellListView1.MultiSelect := True;
  ShellListView1.DragMode := dmAutomatic;

  RefrescarVistas(ShellListView1, ShellTreeView1);
  ActualizarEstado;
end;

procedure TForm1.CambiarRuta(const NuevaRuta: string);
begin
  if EsDirectorio(NuevaRuta) then
  begin
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

procedure TForm1.ShellTreeView1Click(Sender: TObject);
begin
  ShellListView1.Root := ShellTreeView1.Path;
  ActualizarEstado;
end;

procedure TForm1.ToolButton1Click(Sender: TObject);
var
  RutaActual, RutaPadre: string;
begin
  RutaActual := ShellListView1.Root;
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
begin
  if ShellListView1.SelCount = 0 then Exit;

  if MessageDlg('Eliminar', '¿Estás seguro de eliminar los ' + IntToStr(ShellListView1.SelCount) + ' elementos seleccionados?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Exito := False;
    // Iterar hacia atrás al eliminar elementos de una lista
    for i := ShellListView1.Items.Count - 1 downto 0 do
    begin
      if ShellListView1.Items[i].Selected then
      begin
        if BorrarElementoSilencioso(ShellListView1.GetPathFromItem(ShellListView1.Items[i])) then
          Exito := True;
      end;
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
