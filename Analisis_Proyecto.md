# Análisis de Arquitectura y Código del Proyecto

A continuación te presento un análisis detallado del estado actual del proyecto, respetando tu petición de **no realizar cambios**, sino de valorar y diagnosticar cómo está construido, su rendimiento, la separación de conceptos y la consistencia del idioma.

---

## 1. Arquitectura y Separación de Conceptos (Screens, Widgets, Models, State)

El proyecto sigue una estructura moderna basada en **capas**, lo cual es un estándar excelente en Flutter:
*   **Models (`lib/models/`)**: Utilizas `freezed` y `json_serializable`. Es la mejor opción para asegurar la inmutabilidad y evitar errores de tipado. 
*   **Screens (`lib/screens/`)**: Las pantallas principales (listados, vistas de detalle, etc.) están bien delimitadas.
*   **Widgets (`lib/widgets/`)**: Excelente trabajo extrayendo componentes reutilizables como `CabeceraForm`, `CabeceraView` y `FilaPedido`. Esto evita que las pantallas se conviertan en archivos interminables de código de interfaz.
*   **State (`lib/state/` y Providers)**: Usas `Cubit` (Bloc) para lógicas de formularios complejos (`PedidoFormCubit`) y `Provider` para estados globales. Es un enfoque mixto muy pragmático y eficiente.

### ⚠️ Área de Mejora: El "Objeto Dios" (`api_service.dart`)
Actualmente, el archivo `api_service.dart` tiene **cerca de 1.800 líneas**. Se encarga de:
1. Peticiones de Pedidos (listado, creación, actualización).
2. Peticiones de Presupuestos.
3. Obtención de todos los Maestros (Clientes, Artículos, Direcciones, Zonas).
4. Gestión de usuarios y autenticación base.
5. Ejecución de procesos de Velneo.

**Recomendación:** Romper este archivo en servicios más pequeños y especializados, como por ejemplo:
*   `pedidos_service.dart`
*   `maestros_service.dart` (para formas de pago, series, almacenes).
*   `clientes_service.dart` (para direcciones, datos por defecto).
Esto facilitará muchísimo la lectura y el mantenimiento futuro.

---

## 2. Nomenclatura e Idioma (Definiciones en Español)

En líneas generales, el proyecto **cumple de manera estricta** con mantener el dominio del negocio en español (`Pedido`, `LineaPedido`, `OpcionMaestra`, `CabeceraForm`, etc.).

*   **Mapeo de Velneo:** Has hecho un trabajo brillante aislando el "idioma" de Velneo (abreviaturas crípticas como `dir_env`, `fch`, `clt`, `fpg`) en la capa de red y parseo (`models.dart`). El resto de la app consume las propiedades legibles en español como `direccionEnvio`, `fecha`, `clienteId` y `formaPago`.
*   **Incongruencias menores:** En `OrderRepository`, algunas variables internas están en inglés (como `cachedOrders`, `_allOrders`, `filterOrders`, `currentUser`). Siguiendo tu regla de que todo esté en español, esto debería renombrarse a `pedidosCacheados`, `_todosLosPedidos`, `filtrarPedidos`, `usuarioActual`. De la misma manera ocurre en test locales y clases subyacentes.

---

## 3. Optimización y Rendimiento

El proyecto está diseñado pensando en no saturar el servidor de Velneo, lo cual es vital en apps móviles empresariales:
*   **Caché Local (`MasterCacheService` y `OrderRepository`)**: Evita solicitar repetidamente catálogos estáticos (series, formas de pago).
*   **Búsquedas (Debounce)**: Los selectores de clientes y artículos esperan inteligentemente a que el usuario deje de teclear (350-400 ms) antes de disparar la búsqueda a la API. Esto ahorra muchísimo rendimiento y ancho de banda.
*   **Listas Perezosas (`ListView.builder`)**: Usas renderizado eficiente en el listado de pedidos.

### ⚠️ Áreas de Mejora en Rendimiento:
1.  **Llamadas N+1 al guardar líneas:** Al guardar un pedido, se hace una petición POST por cada línea y, además, se dispara un proceso GET individual por línea (`ACT_VTA_PED_LIN_G_APP.pro`). Si un pedido tiene 30 líneas, la app hace muchísimas peticiones concurrentes a Velneo, lo que puede causar bloqueos (Timeouts) o colas en el servidor si hay mala cobertura. Lo ideal a futuro sería enviar todas las líneas en un solo JSON masivo (Bulk) y que un proceso de Velneo haga el bucle internamente para procesarlas todas juntas.

---

## 4. Modelos de Datos (`models.dart`)

Los modelos son sólidos. Las funciones top-level que normalizan JSON (`_intValue`, `_doubleValue`, `_textValue`, `_normalizePedidoJson`) hacen que el modelo tolere errores típicos de la API de Velneo (como enviar `""` en un campo numérico o referencias complejas tipo Objeto en vez de String).

**Incongruencia detectada:**
El modelo `models.dart` está empezando a llenarse de lógicas de "parseo de bajo nivel" (más de 400 líneas). Estaría mejor refactorizarlo moviendo todas las funciones `_intValue`, `_doubleValue`, `_textValue` a un archivo en `lib/core/json_parsers.dart` para dejar a los modelos como meros portadores de datos e información pura de negocio.

---

## Resumen Final
La base tecnológica del proyecto es **muy robusta y madura** (con una base bien probada mediante tests, manejo de estados predictivo mediante Provider/Cubit, Debouncers, Cache Local). 

El foco ahora mismo no debería estar en cambiar la tecnología, sino en la **organización estructural del proyecto** (separar responsabilidades en `api_service` y los parseadores) y en unificar al 100% el idioma (español) para las variables de repositorios.
