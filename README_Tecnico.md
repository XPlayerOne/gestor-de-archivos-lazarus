# 🛠 Especificaciones Técnicas de Ingeniería - Gestor de Archivos Lazarus

Este documento detalla la arquitectura de software, los patrones de diseño y las implementaciones de bajo nivel del Gestor de Archivos desarrollado en Object Pascal (Free Pascal).

## 1. Arquitectura del Sistema (Layered Pattern)

El proyecto se divide en dos capas principales para garantizar la mantenibilidad y la portabilidad:

### A. Capa de Presentación (`Unit1.pas`)
Controla el ciclo de vida de la ventana principal y la respuesta a estímulos del usuario.
*   **Gestión de Estado**: Implementa un motor de navegación que sincroniza tres componentes de forma atómica: `TShellTreeView`, `TShellListView` y la barra de ruta `TEdit`.
*   **Encapsulamiento de Datos**: Utiliza ámbitos privados para proteger el estado del historial (`ListaAtras`, `ListaAdelante`) y banderas de control de flujo (`NavegandoHistorial`).

### B. Capa de Servicios/Lógica (`ULogica.pas`)
Unidad desacoplada de la interfaz que provee servicios de manipulación de E/S (Entrada/Salida).
*   **Persistence Mock**: Utiliza un portapapeles virtual mediante un `TStringList` global gestionado por bloques `initialization` y `finalization`, emulando un búfer de archivos persistente durante el tiempo de ejecución.

## 2. Flujos de Datos Críticos

### Sistema de Historial (Navegación LIFO)
La navegación utiliza dos pilas de datos para permitir el retroceso y avance:
1.  Al llamar a `CambiarRuta`, si no es una navegación de historial, la ruta actual se empuja (`Add`) a `ListaAtras`.
2.  `ListaAdelante` se limpia (`Clear`) para romper la rama de avance tras una nueva navegación manual.
3.  Al presionar "Atrás", se hace un *Pop* de `ListaAtras` y se empuja el estado actual a `ListaAdelante`.

### Motor de Copia Recursiva
La función `CopiarDirectorio` implementa una travesía de árbol de directorios mediante recursión:
*   Usa `FindFirst` / `FindNext` con la máscara `faAnyFile`.
*   Filtra explícitamente los directorios especiales `.` y `..` para evitar bucles infinitos.
*   Utiliza `ForceDirectories` para garantizar la integridad de la estructura de destino antes de iniciar el streaming de bits de archivos individuales vía `CopyFile`.

## 3. Soluciones Técnicas Avanzadas

### Acceso a Miembros Protegidos (Hack de Visibilidad)
Debido a que `TShellTreeView` protege las propiedades de Drag & Drop por diseño en la LCL, se utiliza una **Clase Cracker**:
```pascal
type TTreeCracker = class(TShellTreeView);
// Uso: TTreeCracker(ShellTreeView1).OnDragDrop := @ShellTreeView1DragDrop;
```
Este patrón permite el acceso a la tabla de métodos virtuales (VMT) de la clase padre sin necesidad de heredar y registrar un nuevo componente, manteniendo el binario ligero.

### Optimización del Refresco de UI
Para eliminar el parpadeo visual (*flickering*) durante la recarga de directorios con miles de archivos:
1.  Se invoca `AListView.Items.BeginUpdate`.
2.  Se resetea la propiedad `Root`.
3.  Se reasigna la ruta original.
4.  Se invoca `AListView.Items.EndUpdate`, forzando un único repintado de la lista en el hilo principal de la GUI.

### Abstracción Multiplataforma (OS Bridge)
El software detecta el kernel en tiempo de compilación para ajustar su comportamiento:
*   **En UNIX (Linux/macOS)**: 
    *   Mapea el root a `/`.
    *   Inyecta sugerencias de `chmod`/`chown` en las excepciones de borrado.
    *   Utiliza `GetUserDir` para localizar el punto de montaje del `HOME`.
*   **En Windows**: 
    *   Permite que el sistema Shell maneje las letras de unidad lógicas automáticamente mediante strings vacíos en `Root`.

## 4. Gestión de Errores y Excepciones
*   **Borrado Atómico**: El sistema de eliminación recorre los elementos en orden inverso (`downto`) para evitar desbordamientos de índice al modificar la lista mientras se itera.
*   **Reporte de Fallos**: Implementa un contador de errores en operaciones por lotes. Si una operación de borrado de 10 elementos falla en 2, el usuario recibe un resumen preciso en lugar de una falla silenciosa.

---
*Documentación generada para el entorno de desarrollo Lazarus 4.6.0 (FPC 3.2.2).*