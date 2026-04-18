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

    // SALVAGUARDA: Si intentas pegar en el mismo sitio exacto de donde cortaste, lo ignoramos para evitar fallos.
    if SameFileName(Ruta, NombreDestino) then
      Continue;

    if EsOperacionCorte then
    begin
      // Intenta mover directamente
      ExitoMover := RenameFile(Ruta, NombreDestino);

      // Si falla, copiamos y borramos el original
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

  // Si se movió correctamente, vaciamos el portapapeles
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
