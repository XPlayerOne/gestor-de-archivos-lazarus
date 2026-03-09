unit ULogica;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, LclIntf, FileUtil, Controls, LCLType, ShellCtrls;

{ --- DEFINICIÓN DE FUNCIONES DE LÓGICA --- }

var
  RutaPortapapeles: string; // Almacena la ruta del archivo a copiar

procedure AbrirElemento(const Ruta: string);
function IniciarCopia(const Ruta: string): Boolean;
function EjecutarPegado(const DestinoBase: string): Boolean;
function CrearCarpeta(const RutaBase: string; out NuevaRuta: string): Boolean;
function BorrarElemento(const Ruta: string): Boolean;
function RenombrarElemento(const ViejaRuta: string; out NuevaRuta: string): Boolean;
function EsDirectorio(const Ruta: string): Boolean;
procedure RefrescarVistas(AListView: TShellListView; ATreeView: TShellTreeView);

implementation

procedure AbrirElemento(const Ruta: string);
begin
  if Ruta = '' then Exit;

  if DirectoryExists(Ruta) then
  begin
    // Si es una carpeta, simplemente le pedimos al Form que navegue hacia ella
    // (Esto se gestionará mejor desde el evento del Form)
  end
  else if FileExists(Ruta) then
  begin
    // OpenDocument está en la unidad LclIntf
    if not OpenDocument(Ruta) then
      ShowMessage('No se encontró una aplicación asociada para abrir este archivo.');
  end;
end;

function IniciarCopia(const Ruta: string): Boolean;
begin
  Result := False;
  if FileExists(Ruta) or DirectoryExists(Ruta) then
  begin
    RutaPortapapeles := Ruta;
    Result := True;
  end;
end;

function EjecutarPegado(const DestinoBase: string): Boolean;
var
  NombreElemento: string;
  RutaFinal: string;
begin
  Result := False;
  if RutaPortapapeles = '' then Exit;

  NombreElemento := ExtractFileName(RutaPortapapeles);
  RutaFinal := IncludeTrailingPathDelimiter(DestinoBase) + NombreElemento;

  if DirectoryExists(RutaPortapapeles) then
    // CopyDirTree copia carpetas de forma recursiva
    Result := CopyDirTree(RutaPortapapeles, RutaFinal, [cffOverwriteFile, cffCreateDestDirectory])
  else
    // CopyFile copia archivos individuales
    Result := CopyFile(RutaPortapapeles, RutaFinal, [cffOverwriteFile]);

  if not Result then
    ShowMessage('No se pudo completar la operación de pegado.');
end;

function CrearCarpeta(const RutaBase: string; out NuevaRuta: string): Boolean;
var
  NombreNuevo: string;
begin
  Result := False;
  NombreNuevo := 'Nueva Carpeta';
  if InputQuery('Crear Carpeta', 'Nombre de la nueva carpeta:', NombreNuevo) then
  begin
    // IncludeTrailingPathDelimiter asegura que la ruta tenga un "\" o "/" al final
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
    AListView.Root := '';
    Application.ProcessMessages;
    AListView.Root := RutaActual;
  end;
  
  if Assigned(ATreeView) then
    ATreeView.Refresh;
end;

end.
