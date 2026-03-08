unit ULogica;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, LclIntf, FileUtil, Controls, LCLType, ShellCtrls;

{ --- DEFINICIÓN DE FUNCIONES DE LÓGICA --- }

function BorrarElemento(const Ruta: string): Boolean;
function RenombrarElemento(const ViejaRuta: string; out NuevaRuta: string): Boolean;
function EsDirectorio(const Ruta: string): Boolean;
procedure RefrescarVistas(AListView: TShellListView; ATreeView: TShellTreeView);

implementation

function BorrarElemento(const Ruta: string): Boolean;
begin
  Result := False;
  if QuestionDlg('Borrar', '¿Eliminar ' + ExtractFileName(Ruta) + '?',
     mtConfirmation, [mrYes, mrNo], 0) = mrYes then
  begin
    if DirectoryExists(Ruta) then
    begin
      // Borra carpeta aunque tenga contenido
      Result := DeleteDirectory(Ruta, True);
    end
    else
    begin
      Result := DeleteFile(Ruta);
    end;
  end;
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
    AListView.Root := '';
    Application.ProcessMessages;
    AListView.Root := RutaActual;
  end;
  
  if Assigned(ATreeView) then
    ATreeView.Refresh;
end;

end.
