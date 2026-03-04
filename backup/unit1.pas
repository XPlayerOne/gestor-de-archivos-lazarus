unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ShellCtrls,
  Menus, LclIntf, ComCtrls, StdCtrls, ExtCtrls, LCLType, FileUtil;

type
  { TForm1 }
  TForm1 = class(TForm)
    EditRuta: TEdit;
    ImageList1: TImageList;
    MenuItem1: TMenuItem; // Renombrar
    MenuItem2: TMenuItem; // Borrar
    MenuItem3: TMenuItem; // Abrir
    PopupMenu1: TPopupMenu;
    ShellListView1: TShellListView;
    ShellTreeView1: TShellTreeView;
    StatusBar1: TStatusBar;
    ToolBar1: TToolBar;
    btnAtras: TToolButton;
    btnAdelante: TToolButton;
    procedure btnAdelanteClick(Sender: TObject);
    procedure btnAtrasClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure EditRutaKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure ShellListView1Change(Sender: TObject; Item: TListItem; Change: TItemChange);
    procedure ShellListView1Click(Sender: TObject);
    procedure ShellListView1DblClick(Sender: TObject);
    procedure ShellTreeView1Click(Sender: TObject);
    procedure ShellTreeView1GetImageIndex(Sender: TObject; Node: TTreeNode);
  private
    ListaAtras: TStringList;
    ListaAdelante: TStringList;
    procedure ActualizarEstado;
    procedure Navegar(const NuevaRuta: string; AddToHistory: Boolean);
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ListaAtras := TStringList.Create;
  ListaAdelante := TStringList.Create;

  ShellTreeView1.Root := '';
  ShellListView1.ViewStyle := vsReport;
  ActualizarEstado;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Liberamos la memoria de las listas al cerrar el programa
  ListaAtras.Free;
  ListaAdelante.Free;
end;

procedure TForm1.Navegar(const NuevaRuta: string; AddToHistory: Boolean);
begin
  if (NuevaRuta = '') or (not DirectoryExists(NuevaRuta)) then Exit;

  if AddToHistory then
  begin
    // Solo guardamos en el historial si la ruta es distinta a la actual
    if ShellListView1.Root <> NuevaRuta then
    begin
      ListaAtras.Add(ShellListView1.Root);
      ListaAdelante.Clear; // Nueva navegación limpia el "adelante"
    end;
  end;

  ShellListView1.Root := NuevaRuta;
  ShellTreeView1.Path := NuevaRuta;
  EditRuta.Text := NuevaRuta;
  ActualizarEstado;
end;

procedure TForm1.btnAtrasClick(Sender: TObject);
var
  RutaAnterior: string;
begin
  if ListaAtras.Count > 0 then
  begin
    RutaAnterior := ListaAtras[ListaAtras.Count - 1];
    ListaAtras.Delete(ListaAtras.Count - 1);

    // Antes de ir atrás, guardamos la actual en adelante
    ListaAdelante.Add(ShellListView1.Root);

    Navegar(RutaAnterior, False);
  end;
end;

procedure TForm1.btnAdelanteClick(Sender: TObject);
var
  RutaSiguiente: string;
begin
  if ListaAdelante.Count > 0 then
  begin
    RutaSiguiente := ListaAdelante[ListaAdelante.Count - 1];
    ListaAdelante.Delete(ListaAdelante.Count - 1);

    // Antes de ir adelante, guardamos la actual en atrás
    ListaAtras.Add(ShellListView1.Root);

    Navegar(RutaSiguiente, False);
  end;
end;

procedure TForm1.EditRutaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if DirectoryExists(EditRuta.Text) then
      Navegar(EditRuta.Text, True)
    else
      ShowMessage('La ruta no existe.');
  end;
end;

procedure TForm1.ActualizarEstado;
begin
  if Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Elementos: ' + IntToStr(ShellListView1.Items.Count);

  // Habilitar o deshabilitar botones según el historial
  btnAtras.Enabled := ListaAtras.Count > 0;
  btnAdelante.Enabled := ListaAdelante.Count > 0;
end;

procedure TForm1.ShellTreeView1Click(Sender: TObject);
begin
  // Cuando clicamos en el árbol, navegamos y actualizamos historial
  if DirectoryExists(ShellTreeView1.Path) then
    Navegar(ShellTreeView1.Path, True);
end;

procedure TForm1.ShellTreeView1GetImageIndex(Sender: TObject; Node: TTreeNode);
begin
  if DirectoryExists(ShellTreeView1.GetPathFromNode(Node)) then
    Node.ImageIndex := 0
  else
    Node.ImageIndex := 1;
  Node.SelectedIndex := Node.ImageIndex;
end;

procedure TForm1.ShellListView1DblClick(Sender: TObject);
var
  RutaSel: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    RutaSel := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if DirectoryExists(RutaSel) then
      Navegar(RutaSel, True)
    else
      OpenDocument(RutaSel);
  end;
end;

procedure TForm1.MenuItem3Click(Sender: TObject);
begin
  // Reutilizamos el código del doble click para el menú "Abrir"
  ShellListView1DblClick(Sender);
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
var Ruta: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    Ruta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if QuestionDlg('Borrar', '¿Eliminar ' + ExtractFileName(Ruta) + '?', mtConfirmation, [mrYes, mrNo], 0) = mrYes then
    begin
      if DirectoryExists(Ruta) then
      begin
        if DeleteDirectory(Ruta, True) then ShellListView1.Refresh;
      end
      else
      begin
        if DeleteFile(Ruta) then ShellListView1.Refresh;
      end;
    end;
  end;
end;

procedure TForm1.MenuItem1Click(Sender: TObject);
var ViejaRuta, NuevaRuta, NuevoNombre: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    ViejaRuta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    NuevoNombre := ExtractFileName(ViejaRuta);
    if InputQuery('Renombrar', 'Nuevo nombre:', NuevoNombre) then
    begin
      NuevaRuta := ExtractFilePath(ViejaRuta) + NuevoNombre;
      if RenameFile(ViejaRuta, NuevaRuta) then ShellListView1.Refresh;
    end;
  end;
end;

procedure TForm1.ShellListView1Click(Sender: TObject);
begin
  if Assigned(ShellListView1.Selected) and Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Seleccionado: ' + ShellListView1.Selected.Caption;
end;

procedure TForm1.ShellListView1Change(Sender: TObject; Item: TListItem; Change: TItemChange);
begin
  // Opcional: Actualizar estado al cambiar selección
end;

end.
