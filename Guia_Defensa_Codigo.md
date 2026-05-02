# Guía Práctica de las Funciones del Gestor de Archivos

Esta guía explica de forma clara y directa **qué hace cada parte del código en relación a lo que el usuario ve y hace en el programa**. Si el profesor pregunta "¿Para qué sirve esta función?", aquí está la respuesta enfocada en el funcionamiento del sistema.

---

## 1. Navegación (Moverse por las carpetas)
Estas funciones se encargan de que el usuario pueda entrar, salir y viajar entre sus carpetas.

*   **`CambiarRuta` (Unit1.pas)**
    *   **¿Qué hace?** Es el motor visual. Cuando el usuario hace doble clic en una carpeta o escribe una dirección, esta función actualiza la pantalla (la lista de la derecha y el árbol de la izquierda) para mostrar los archivos que están dentro de ese nuevo lugar.
*   **`btnAtrasClick` y `btnAdelanteClick` (Unit1.pas)**
    *   **¿Qué hacen?** Igual que en un navegador de internet. Leen el "historial" de las carpetas que el usuario ha visitado y lo regresan a la pantalla anterior o lo avanzan a la siguiente.
*   **`ToolButton1Click` / Subir Nivel (Unit1.pas)**
    *   **¿Qué hace?** Toma la carpeta actual en la que está el usuario, averigua cuál es su "carpeta padre" (la que la contiene) y viaja hacia ella. Por ejemplo, si está en `C:\Fotos\Viaje`, lo sube a `C:\Fotos`.

---

## 2. Organización Básica (Crear, Renombrar y Abrir)
Estas funciones permiten al usuario estructurar y consultar su información.

*   **`CrearCarpeta` (ULogica.pas)**
    *   **¿Qué hace?** Abre una ventanita preguntando "¿Nombre de la nueva carpeta?". Cuando el usuario escribe el nombre y acepta, crea físicamente esa carpeta en el disco duro.
*   **`RenombrarElemento` (ULogica.pas)**
    *   **¿Qué hace?** Le pide al usuario un nuevo nombre para un archivo o carpeta que haya seleccionado y actualiza ese nombre en el sistema operativo.
*   **`AbrirElemento` (ULogica.pas)**
    *   **¿Qué hace?** Si el usuario hace doble clic en un archivo (como un `.txt` o un `.jpg`), esta función le dice al sistema operativo (Windows o Linux) que abra ese archivo usando el programa predeterminado que el usuario tenga instalado (como el Bloc de notas o el visor de fotos).

---

## 3. Mover y Duplicar (El Portapapeles)
Estas funciones controlan la acción de llevar cosas de un lado a otro.

*   **`IniciarCopia` e `IniciarCorte` (ULogica.pas)**
    *   **¿Qué hacen?** Cuando el usuario le da a "Copiar" o "Cortar", estas funciones toman nota mentalmente de cuáles son los archivos que se seleccionaron, para saber qué hacer cuando el usuario presione "Pegar".
*   **`EjecutarPegado` (ULogica.pas)**
    *   **¿Qué hace?** Toma los archivos que se habían guardado en la nota mental (portapapeles) y los deposita en la carpeta donde el usuario esté en ese momento. Si la acción era "Copiar", los duplica. Si era "Cortar", los mueve de lugar original al nuevo.
*   **`CopiarDirectorio` (ULogica.pas)**
    *   **¿Qué hace?** Es un ayudante de `EjecutarPegado`. Si el usuario decide copiar una carpeta entera, esta función entra a esa carpeta, copia todos los archivos que hay adentro, si hay subcarpetas también entra a ellas, y duplica todo exactamente igual en el nuevo destino.

---

## 4. Eliminación y Papelera (Seguridad de Datos)
Estas funciones se encargan de deshacerse de los archivos, de forma segura o definitiva.

*   **`EnviarALaPapelera` (ULogica.pas)**
    *   **¿Qué hace?** Cuando el usuario hace clic en el botón de la papelera en la barra, o usa la opción "Borrar", esta función toma el archivo y, en lugar de destruirlo, lo envía a la Papelera de Reciclaje de Windows o Linux. Así el usuario puede recuperarlo después si se arrepiente.
*   **`btnPapeleraClick` (Unit1.pas)**
    *   **¿Qué hace?** Es el botón grande en la barra de herramientas. Al pulsarlo, le abre al usuario la ventana de la Papelera de su computadora para que pueda revisar qué cosas ha borrado.
*   **`BorrarElemento` y `BorrarElementoSilencioso` (ULogica.pas)**
    *   **¿Qué hacen?** Es la eliminación permanente. `BorrarElemento` primero le pregunta al usuario: "¿Estás seguro?". Si dice que sí, llama a la versión "Silenciosa", que elimina el archivo o carpeta directamente del disco duro, sin pasar por la papelera (para siempre).

---

## 5. Experiencia Avanzada: Arrastrar y Soltar (Drag & Drop)
Estas funciones hacen que la aplicación se sienta como un programa moderno.

*   **`ShellTreeView1DragDrop` (Unit1.pas)**
    *   **¿Qué hace?** Es la función que se dispara cuando el usuario agarra un archivo de la lista de la derecha con su ratón y lo "suelta" encima de una de las carpetas del árbol de la izquierda.
    *   Lo que hace internamente es automatizar dos pasos en uno: automáticamente hace un "Copiar" del archivo seleccionado y luego ejecuta un "Pegar" en la carpeta donde el usuario soltó el botón del ratón.
