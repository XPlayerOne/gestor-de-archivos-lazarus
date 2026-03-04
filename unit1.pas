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
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    PopupMenu1: TPopupMenu;
    ShellListView1: TShellListView;
    ShellTreeView1: TShellTreeView;
    StatusBar1: TStatusBar;
    ToolBar1: TToolBar;
    procedure FormCreate(Sender: TObject);
    procedure EditRutaKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure ShellListView1Change(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure ShellListView1Click(Sender: TObject);
    procedure ShellListView1DblClick(Sender: TObject);
    procedure ShellTreeView1Click(Sender: TObject);
    procedure ShellTreeView1GetImageIndex(Sender: TObject; Node: TTreeNode);
  private
    procedure ActualizarEstado;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ShellTreeView1.Root := '';  // <- comillas vacías = mostrar todos los discos
  ShellListView1.ViewStyle := vsReport;
  ShellListView1.Refresh;
end;

procedure TForm1.EditRutaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then // Si el usuario presiona Enter
  begin
    if DirectoryExists(EditRuta.Text) then
    begin
      ShellListView1.Root := EditRuta.Text;
      ShellTreeView1.Path := EditRuta.Text;
    end
    else
      ShowMessage('La ruta no existe.');
  end;
end;

procedure TForm1.ActualizarEstado;
begin
  // Verificamos que los componentes existan antes de usarlos
  if Assigned(EditRuta) then
    EditRuta.Text := ShellTreeView1.Path;

  if Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Elementos: ' + IntToStr(ShellListView1.Items.Count);
end;

procedure TForm1.ShellTreeView1Click(Sender: TObject);
begin
  ActualizarEstado;
end;

procedure TForm1.ShellTreeView1GetImageIndex(Sender: TObject; Node: TTreeNode);
begin
  // Verificamos si el nodo actual es un directorio
  if DirectoryExists(ShellTreeView1.GetPathFromNode(Node)) then
    Node.ImageIndex := 0  // Índice de la carpeta en tu ImageList
  else
    Node.ImageIndex := 1; // Índice del documento en tu ImageList

  // Esto asegura que el icono se mantenga igual cuando se selecciona
  Node.SelectedIndex := Node.ImageIndex;
end;

procedure TForm1.ShellListView1DblClick(Sender: TObject);
var
  RutaSeleccionada: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    RutaSeleccionada := ShellListView1.GetPathFromItem(ShellListView1.Selected);

    if DirectoryExists(RutaSeleccionada) then
    begin
      // NAVEGACIÓN: Entrar a la carpeta
      ShellListView1.Root := RutaSeleccionada;
      ShellTreeView1.Path := RutaSeleccionada;
      if Assigned(EditRuta) then EditRuta.Text := RutaSeleccionada;
    end
    else
      OpenDocument(RutaSeleccionada); // ABRIR: Si es archivo
  end;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
var
  Ruta: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    Ruta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if QuestionDlg('Borrar', '¿Eliminar ' + ExtractFileName(Ruta) + '?',
       mtConfirmation, [mrYes, mrNo], 0) = mrYes then
    begin
      if DirectoryExists(Ruta) then
      begin
        // Borra carpeta aunque tenga contenido
        if not DeleteDirectory(Ruta, True) then
          ShowMessage('No se pudo eliminar la carpeta.')
        else
          ShellListView1.Refresh;
      end
      else
      begin
        if not DeleteFile(Ruta) then
          ShowMessage('No se pudo eliminar el archivo.')
        else
          ShellListView1.Refresh;
      end;
    end;
  end;
end;

procedure TForm1.ShellListView1Change(Sender: TObject; Item: TListItem;
  Change: TItemChange);
begin

end;

procedure TForm1.ShellListView1Click(Sender: TObject);
begin
  if Assigned(ShellListView1.Selected) and Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Seleccionado: ' + ShellListView1.Selected.Caption;
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

//procedure TForm1.MenuItem2Click(Sender: TObject);
//var Ruta: string;
//begin
  //if Assigned(ShellListView1.Selected) then
  //begin
    //Ruta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    //if QuestionDlg('Borrar', '¿Eliminar ' + ExtractFileName(Ruta) + '?', mtConfirmation, [mrYes, mrNo], 0) = mrYes then
    //begin
      //if DeleteFile(Ruta) or RemoveDir(Ruta) then ShellListView1.Refresh;
    //end;
  //end;
  //end;

end.
