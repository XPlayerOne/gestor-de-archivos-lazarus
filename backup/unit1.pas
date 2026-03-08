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
    MenuItemActualizar: TMenuItem;
    PopupMenu1: TPopupMenu;
    ShellListView1: TShellListView;
    ShellTreeView1: TShellTreeView;
    StatusBar1: TStatusBar;
    TimerRefresco: TTimer;
    ToolBar1: TToolBar;
    procedure FormCreate(Sender: TObject);
    procedure EditRutaKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItemActualizarClick(Sender: TObject);
    procedure ShellListView1Click(Sender: TObject);
    procedure ShellListView1DblClick(Sender: TObject);
    procedure ShellTreeView1Click(Sender: TObject);
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
  ShellListView1.ViewStyle := vsReport;
  ShellListView1.Refresh;
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
var
  RutaActual: string;
begin
  RutaActual := ShellListView1.Root;
  ShellListView1.Root := '';
  ShellListView1.Root := RutaActual;
  ShellTreeView1.Refresh;
  ActualizarEstado;
end;

procedure TForm1.ShellTreeView1Click(Sender: TObject);
begin
  ShellListView1.Root := ShellTreeView1.Path;
  ActualizarEstado;
end;

procedure TForm1.ShellListView1DblClick(Sender: TObject);
var
  RutaSeleccionada: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    RutaSeleccionada := ShellListView1.GetPathFromItem(ShellListView1.Selected);

    if EsDirectorio(RutaSeleccionada) then
      CambiarRuta(RutaSeleccionada)
    else
      OpenDocument(RutaSeleccionada);
  end;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
var
  Ruta: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    Ruta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if BorrarElemento(Ruta) then
    begin
      MenuItemActualizarClick(Sender);
    end;
  end;
end;

procedure TForm1.MenuItem1Click(Sender: TObject);
var ViejaRuta, NuevaRuta: string;
begin
  if Assigned(ShellListView1.Selected) then
  begin
    ViejaRuta := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    if RenombrarElemento(ViejaRuta, NuevaRuta) then
    begin
      MenuItemActualizarClick(Sender);
    end;
  end;
end;

procedure TForm1.ShellListView1Click(Sender: TObject);
begin
  if Assigned(ShellListView1.Selected) and Assigned(StatusBar1) then
    StatusBar1.SimpleText := 'Seleccionado: ' + ShellListView1.Selected.Caption;
end;

end.
