# Baobabs (Habitat) — Plan de desarrollo

**Proyecto:** navegador inspirado en Safari 5.1.7 (Windows), de motor intercambiable.
**Fuentes:** `safari/INFORME.md` (ingeniería inversa con REA/Ghidra) y `safari/HABITAT.md` (diseño de datos y UI).
**Fecha del plan:** 2026-10-19

---

## 1. Contexto

La ingeniería inversa de Safari 5.1.7 para Windows extrajo:

- Cadena de arranque (`Safari.exe` lanzador → `Safari.dll` navegador).
- Modelo de datos en **plists binarios** (`Bookmarks`, `History`, `TopSites`, `ReadingList`, `LastSession`) con UUIDs y epoch Cocoa (2001-01-01).
- UI: `Reader.html` (HTML/CSS puro; el JS de `ReaderJS.*` **no existe en ningún binario** — hay que escribirlo), TopSites nativo con esquema `topsites://`, 42 paneles HTML.
- `Search.dll`: índice propio con API `SW*` → se sustituye por SQLite FTS5.
- `PubSubDLL.dll`: RSS/Atom con esquema SQLite completo (ya documentado en HABITAT.md §4).

**Baobabs** reutiliza todo ese conocimiento en un navegador nuevo:

| Decisión | Valor |
|---|---|
| Lenguaje | Vala + GObject |
| UI | GTK 4 + **Granite 7** (elementary) |
| Build | Meson + Ninja |
| Motor (Linux) | WebKitGTK (`webkitgtk-6.0`) |
| Motor (Windows) | WebView2 (fase 4) |
| Plataforma de desarrollo inicial | Linux (elementary OS 8) |

---

## 2. Decisiones tomadas

1. **Linux/WebKitGTK primero.** El backend WebView2 queda como stub hasta la Fase 4; se implementa primero `WebKitGtkEngine` sobre GTK4.
2. **La UI de Windows se decide en la Fase 4.** GTK4 no puede embeber HWNDs nativos (necesarios para WebView2), así que cuando se llegue ahí se elegirá entre UI Win32 nativa, GTK4 en Windows con embedding adaptado, o aplazar. La interfaz `BrowserEngine` aísla esa decisión.
3. **Alcance de la v1: navegador mínimo navegable.** Fase 1 completa (cargar URLs, pestañas, historial básico, marcadores legibles). TopSites, Reader, preferencias, búsqueda y RSS quedan para fases posteriores.
4. **Usar Granite 7** (librería de widgets GTK4 de elementary) para el pulido de UI: `Toast`, `HeaderLabel`, `AccelLabel`, `MessageDialog`, `ValidatedEntry`, clases `STYLE_CLASS_*`. Evitamos libadwaita (elementary no lo usa). En meson se detecta con `required: false` para no romper builds mínimos; en Windows (Fase 4) la UI se decide aparte y Granite no aplica.

---

## 3. Estado actual del código (`baobabs/`)

| Componente | Estado |
|---|---|
| Interfaz `BrowserEngine` (src/engine/engine.vala) | ✅ existe, **le falta transporte de widget** |
| Stub `WebView2Engine` | ✅ compila, sin funcionalidad |
| Backend `WebKitGtkEngine` | ❌ **no existe** |
| Parser plist + epoch Cocoa | ✅ ~270 líneas con tests y fixtures |
| Loader de marcadores/historial | ⚠️ lectura parcial, sin escritura |
| Ventana (`ui/window.vala`) | ❌ solo una etiqueta de texto |
| Barra de dirección / pestañas | ❌ no existen |
| Writer de plist | ❌ solo parsea |
| WebKitGTK en meson | ⚠️ detectado como opcional (debe ser requerido en Linux) |

---

## 4. Fase 1 — v1 mínima navegable (objetivo inmediato)

### 4.1 Completar la abstracción del motor

- `src/engine/engine.vala`: añadir
  ```vala
  public abstract Gtk.Widget get_widget();
  ```
  Hoy no existe forma de insertar el motor en la ventana. Se anota como punto
  de decisión de la Fase 4: si Windows termina en Win32 nativo, la interfaz se
  divide en núcleo neutral + transporte por toolkit.
- **Meson:** en Linux, `webkitgtk-6.0` pasa a **requerido**. El fallback actual
  a `webkit2gtk-4.1` debe eliminarse: esa librería es GTK3 y no se puede embeber
  en una ventana GTK4.

### 4.2 Backend `WebKitGtkEngine` (nuevo: `src/engine/webkitgtk.vala`)

- `WebKitWebView` embebido como widget de la pestaña.
- Señales de la interfaz conectadas a las de WebKit:
  - `load-changed` → `load_started` / `load_finished`
  - `estimated-load-progress` → `progress_changed`
  - `notify::title` → `title_changed`
  - `notify::uri` → `url_changed`
  - `can-go-back` / `can-go-forward` → flags `can_go_back` / `can_go_forward`
- `decide-policy`: interceptar `topsites://` (reservado para la Fase 2) y
  rechazar esquemas no soportados.
- `load_uri` normaliza la entrada de la barra de dirección (URL vs búsqueda),
  al estilo Safari.
- `set_user_agent` vía `WebKit.Settings.user_agent`.
- `execute_script` vía `run_javascript` / `evaluate_javascript`.
- El stub `WebView2Engine` sigue compilándose sin cambios (selección
  condicional en meson).

### 4.3 Ventana y pestañas

- `src/ui/window.vala` (reescritura) + nuevos `src/ui/toolbar.vala`,
  `src/ui/tabs.vala`:
  - HeaderBar con: botones atrás/adelante/recargar, barra de dirección,
    botón de pestaña nueva.
  - Modelo de pestañas: **una instancia de motor por pestaña**, cierre de
    pestaña, cambio con Ctrl+Tab.
  - Shortcuts: Ctrl+T (nueva), Ctrl+W (cerrar), Ctrl+L (barra de dirección),
    Ctrl+R (recargar), Alt+←/→ (navegar).
- **Granite** (si está disponible): `ToastOverlay` + `Toast` para avisos de
    error de carga, `AccelLabel` en menús, clases `Granite.STYLE_CLASS_*` en la
    barra de herramientas. Si `granite-7` no se encuentra, la UI degrada a GTK
    puro (meson con `required: false`).
- Página de error real cuando `load_finished(false, …)`.

### 4.4 Capa de datos mínima

- `src/core/plist.vala`: añadir **escritor** (hoy solo parsea), con roundtrip
  `bplist00` cubierto por tests.
- `src/history/`: registrar visitas en `load_finished` → `History.plist` con
  `lastVisitedDate` (epoch Cocoa) y `visitCount` (HABITAT.md §1.3).
- Marcadores: **solo lectura** en v1 (menú/barra desde `Bookmarks.plist`, el
  loader ya existe).
- Directorio de perfil propio (`~/.local/share/baobabs/`). **Nunca** se toca un
  perfil real de Safari.

### 4.5 Build y tests

- Meson: `webkitgtk-6.0` requerido en Linux, `WebView2Engine` excluido en Linux.
- Tests (`meson test`): roundtrip de escritor plist, epoch Cocoa, loader de
  marcadores e historial con los fixtures de `tests/fixtures/`.

**Fuera de v1:** TopSites nativo, Reader + `ReaderJS` propio, preferencias
GSettings, búsqueda FTS5, RSS/PubSub, WebView2/Windows.

---

## 5. Fases posteriores

### Fase 2 — Capa de datos compatible con Safari

- Escritura completa de plists + señales GObject con el vocabulario original
  (`WebBookmarksWereReloadedNotification`, `WebBookmarkDidChangeNotification`,
  … ver HABITAT.md §1.6).
- TopSites: modelo de `TopSites.plist` + vista nativa (cuadrícula GTK) +
  interceptación de `topsites://`.
- ReadingList (datos + vista `ReadingList.html`).
- Búsqueda con **SQLite FTS5** tras una API con la forma de `Search.dll`
  (`openReader/openWriter`, `begin/endAddDocument`, `addData`, `search`).

### Fase 3 — Fidelidad Safari 5.1

- Barra de marcadores, sidebar, menús al estilo 5.1.7.
- Preferencias: 87 claves de `Defaults.plist` en GSettings (omitir el prefijo
  `…ContentPageGroupIdentifier.WebKit2…`); ventana de ajustes con widgets
  Granite (`Settings`, `ValidatedEntry` en la barra de dirección).
- **Reader:** reutilizar `baobabs/data/Reader.html` + **escribir el JS** de
  `ReaderJS.loaded`, `articleScrolled`, `hudMouseOver/Out`,
  `setHUDAcceptsPointerEvents`, `makeTextSmaller/Larger`, `mailArticle`,
  `printArticle`, `deactivateAfterAnimation`, `didLoseFocus` (no existe fuente
  en los binarios).
- Selector de agente de usuario desde `UserAgents.plist` (estructura original,
  UA modernos).

### Fase 4 — Windows / WebView2

- Shim C++ (`WebView2.h` + `CreateCoreWebView2EnvironmentWithOptions`, carga
  dinámica de `WebView2Loader.dll`) que exponga una **API C plana** → VAPI para
  Vala; implementa `WebView2Engine` de verdad.
- **Decisión pendiente:** UI de Windows (Win32 nativo / GTK4 con embedding /
  otra) — condiciona el transporte de `BrowserEngine`.
- Meson: selección de backend por `host_machine.system()`.

### Fase 5 — RSS/PubSub y empaquetado

- Esquema SQLite de `PubSubDLL.dll` **literal** (HABITAT.md §4.3), parseo con
  `xmlTextReader` (libxml2) + fallback libtidy, refresh 30 min / expiración
  14 d / adjuntos 8 MB.
- Empaquetado (flatpak/deb) y licencia.

---

## 6. Entorno de build (elementary OS 8 / Ubuntu 24.04)

Comprobado en la máquina de desarrollo:

| Componente | Estado |
|---|---|
| `webkitgtk-6.0` | ✅ instalado (pkg-config lo encuentra) |
| `gtk4` 4.14.5 | ✅ instalado |
| `valac` 0.56.17 · `meson` 1.9.1 · `ninja` · `gcc` | ✅ instalados |
| `sqlite3` 3.45.1 | ✅ instalado |
| `libgee-0.8` | ❌ **falta** |
| `libgranite-7` | ❌ falta (opcional, para pulido de UI) |
| `libxml-2.0` | ❌ falta (necesario en la Fase 5) |

Instalar lo que falta:

```bash
sudo apt install libgee-0.8-dev libxml2-dev libgranite-7-dev
```

Compilar y probar:

```bash
cd baobabs
meson setup build
meson compile -C build
meson test -C build
./build/src/baobabs
```

> **WebKitGTK no requiere instalación adicional** en elementary OS 8: el paquete
> `libwebkitgtk-6.0-dev` ya está presente. En elementary 7 (Ubuntu 22.04) esa
> librería **no existe en los repositorios** (solo `webkit2gtk`, GTK3), lo que
> obligaría a subir de sistema o cambiar de toolkit.
