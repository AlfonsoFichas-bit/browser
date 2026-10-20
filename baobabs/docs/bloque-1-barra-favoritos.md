# Bloque 1 — Barra de Favoritos

**Fecha:** 2026-10-20
**Estado:** brief entregado a Jules, pendiente de implementación
**Rama objetivo:** `master` (base `cbf4378`)

---

## Contexto

Habitat ya tiene, verificado en Windows:

- `core/plist.vala` — parser bplist completo (dict/array/string UTF-16/fecha Cocoa/UID).
- `core/epoch.vala` — conversión epoch Cocoa ⇄ unix.
- `bookmarks/model.vala`, `bookmarks/loader.vala`, `bookmarks/store.vala` — modelo, reconstrucción del árbol `WebBookmark*` y señales.
- `history/model.vala` — modelo de historial.

**Pero nada de eso está conectado a la app.** `window.vala` hoy sólo muestra:
`HeaderBar` + `Entry` de URL + `web_area`. No hay barra de favoritos, ni menú,
ni historial visible, ni persistencia.

`History.Store` **nunca se llama**; `Bookmarks.Store` se usa sólo en tests.

**El trabajo no es parsear plists — eso ya está. El trabajo es conectar los datos
a la UI.**

---

## Verificaciones previas (runtime, no inspección)

| Verificación | Resultado |
|---|---|
| `core/plist.vala` sobre `Bookmarks.plist` real | ✅ Parsea; UTF-16 y acentos correctos |
| Estructura real del plist | Raíz `LIST` → `BookmarksBar` (5 hojas + carpetas `Noticias` 7 hojas, `Populares` 9 hojas) + `BookmarksMenu` + `Favoritos IE importados` |
| `bookmarks/loader.vala` | ✅ Ya reconstruye el árbol; no hace falta tocarlo |
| `Gtk.Popover` (`set_child`/`popup`/`popdown`) | ✅ Existe en el vapi |
| `Gtk.MenuButton` (`child`/`popover`) | ✅ Existe en el vapi |
| `libplist` en el sistema | ❌ No existe → el writer bplist hay que escribirlo a mano (Bloque 3) |
| `webkitgtk` en Windows | ❌ No disponible (el Bloque 1 no lo necesita) |

**Dato de fidelidad:** las carpetas especiales (`BookmarksBar`, `BookmarksMenu`)
**no llevan UUID especial** en el perfil real — llevan un GUID normal aleatorio.
Lo único que las identifica es el `title` literal. Ver `safari/HABITAT.md` §1.2.

---

## Alcance del commit

### 1. `baobabs/src/core/config.vala` — rutas del perfil

Añadir:

- `bookmarks_path` → `<data_dir>/Bookmarks.plist`
- `history_path` → `<data_dir>/History.plist`

Sólo las rutas. **No** implementar lectura/escritura de ficheros todavía.

### 2. `baobabs/src/bookmarks/defaults.vala` (nuevo)

Sembrar un árbol mínimo **en memoria**:

- Raíz `Node(NodeType.LIST)`.
- Hija `Node(NodeType.LIST)` con `title = "BookmarksBar"` (literal exacto) y `uuid` no vacío.
- Tres hojas dentro de la barra:
  - `DuckDuckGo` → `https://duckduckgo.com`
  - `Wikipedia` → `https://es.wikipedia.org`
  - `Hacker News` → `https://news.ycombinator.com`

**No** leer ni escribir ficheros.

### 3. `baobabs/src/ui/favorites_bar.vala` (nuevo)

`FavoritesBar : Gtk.Box` que recibe un `Bookmarks.Store` y construye la barra:

- Busca la carpeta hija cuyo `title` sea exactamente `"BookmarksBar"`; si no
  existe, usa la raíz.
- **Hoja (`LEAF`)** → `Gtk.Button` con la etiqueta = título. `clicked` emite
  `open_url(string url)`.
- **Carpeta (`LIST`/`PROXY`)** → `Gtk.MenuButton` con etiqueta = título y un
  `Gtk.Popover` cuyo hijo es un `Gtk.Box` vertical con un botón por hoja hija,
  **recursivo**. Cada botón emite `open_url`.
- Declara `public signal void open_url(string url);` y **no** conoce al motor.
- `vexpand = false` (para que `web_area` conserve el alto restante).

Título de respaldo para hojas sin `title`:

```vala
private string display_title_for(Node node) {
    if (node.title != null && node.title.length > 0)
        return node.title;
    if (node.url != null) {
        try {
            var host = GLib.Uri.parse(node.url, GLib.UriFlags.NONE).get_host();
            if (host != null && host.length > 0)
                return host;
        } catch (GLib.UriError e) {
            // fallback abajo
        }
    }
    return node.url ?? "(sin título)";
}
```

Nota: `GLib.Uri.parse()` **lanza `GLib.UriError`** y `get_host()` **puede devolver
null** (`about:`, `file://`, etc.). Alternativa sin throw: `GLib.Uri.try_parse()`.

### 4. `baobabs/src/ui/window.vala` — conectar la barra

- Crear `Bookmarks.Store`, poblarlo con `Bookmarks.Defaults.seed()`.
- Insertar la barra **dentro del `Box` vertical existente**, entre el `HeaderBar`
  y el `web_area`:

```
Gtk.Window
├── titlebar: HeaderBar
└── child:    Box(vertical)
             ├── FavoritesBar   ← nuevo
             └── web_area       ← SizeTrackingArea
```

- `web_area` conserva `hexpand`/`vexpand = true`.
- Conectar `favorites_bar.open_url` → `engine.load_uri(url)`.

### 5. `baobabs/src/meson.build`

Añadir `bookmarks/defaults.vala` y `ui/favorites_bar.vala` a `baobabs_core_sources`.

---

## Restricciones duras

- **No tocar:** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
  `core/plist.vala`, `bookmarks/model.vala`, `bookmarks/loader.vala`,
  `bookmarks/store.vala`, `history/model.vala`.
- **No implementar todavía:** persistencia a disco, importar perfil de Safari,
  marcadores editables, historial, top sites, reader, pestañas, menú hamburguesa.
- **No añadir dependencias nuevas** en `meson.build`.

---

## Verificación requerida

- `meson compile` verde y `meson test` **2/2** en Windows.
- La app arranca y **se ve la barra** con los 3 botones (DuckDuckGo, Wikipedia,
  Hacker News) arriba del área web.
- Al pulsar un botón, **navega** a esa URL.
- **Los bounds cambian a propósito:** el motor calcula con
  `web_area.compute_bounds(toplevel)` (geometría relativa real), así que al
  insertar la barra `origin.y` crece y el alto se reduce. **No es regresión.**
  Verificar la **coherencia** del rect, no el número viejo:
  - `right − left` = ancho de `web_area`
  - `bottom − top` = alto de `web_area`
- Persistencia al maximizar/restaurar.
- Sin `CRITICAL`/`WARNING` nuevos.
- Puede aparecer **un `UpdateBounds` extra** al arranque (el `web_area` cambia de
  tamaño al insertarse la barra). Benigno y esperado.

**Números de referencia previos (sin barra, ya verificados):**

| Estado | Rect |
|---|---|
| Ventana | `left=14 top=61 right=1114 bottom=764` |
| Maximizado | `left=0 top=47 right=1920 bottom=1080` |

---

## Notas de arquitectura

- `WebView2Engine.update_bounds()` usa `this.host.compute_bounds(toplevel, out rect)`;
  **no hay constantes que asuman posición absoluta.** Prueba de que ya absorbe
  widgets por encima: hoy reporta `top=61` en vez de `0` por el `HeaderBar`.
- Un `Gtk.Popover` suelto necesita `set_parent`; con `MenuButton` queda resuelto
  (el botón es el padre). Por eso hojas → `Button`, carpetas → `MenuButton`.
- `Gtk.MenuButton` anidado dentro del popover de otro funciona en GTK4, en
  profundidad arbitraria.

---

## Fuera de alcance (siguientes bloques)

| Bloque | Contenido |
|---|---|
| 2 | Historial: conectar `engine.load_finished` → `History.Store.record_visit()` + menú |
| 3 | Persistencia bplist propia (writer binario a mano; no existe `libplist`) |
| 4 | Marcadores editables (estrella) |
| 5 | Top Sites (widget propio + `topsites://` en `decide-policy`) |
| 6 | Reader (reutilizar `Reader.html` + escribir el JS que Apple compilaba de forma nativa) |

---

## Referencias

- `safari/HABITAT.md` — esquemas de plists, `ShowFavoritesBar`, equivalencias.
- `safari/Bookmarks.plist` — perfil real (`BookmarksBar`, `Noticias`, `Populares`).
- `baobabs/src/core/plist.vala`, `baobabs/src/bookmarks/*` — código existente.

---

## Anexo — Mensaje paste-ready para Jules

> **Contexto:** Habitat ya tiene el parser bplist (`core/plist.vala`), el
> modelo/loader/store de marcadores (`bookmarks/*`) y el modelo de historial —
> todo verificado. **Pero nada de eso está conectado a la app:** `window.vala`
> hoy sólo muestra HeaderBar + Entry de URL + `web_area`. No hay barra de favoritos.
>
> **Objetivo de este commit: Barra de Favoritos (como Safari 5.1, `ShowFavoritesBar`).**
>
> **Alcance — sólo esto, no más:**
>
> 1. **`baobabs/src/core/config.vala`** — añadir rutas del perfil de datos:
>    `bookmarks_path` → `<data_dir>/Bookmarks.plist` y
>    `history_path` → `<data_dir>/History.plist`. Sólo las rutas; **no**
>    implementar lectura/escritura todavía.
>
> 2. **`baobabs/src/bookmarks/defaults.vala` (nuevo)** — sembrar un árbol mínimo
>    **en memoria**: raíz `Node(NodeType.LIST)`, hija `Node(NodeType.LIST)` con
>    `title` = literal exacto `"BookmarksBar"` y `uuid` no vacío, y **3 hojas**:
>    `DuckDuckGo` → `https://duckduckgo.com`, `Wikipedia` → `https://es.wikipedia.org`,
>    `Hacker News` → `https://news.ycombinator.com`. **No** leer ni escribir ficheros.
>
> 3. **`baobabs/src/ui/favorites_bar.vala` (nuevo)** — `FavoritesBar : Gtk.Box`
>    que recibe un `Bookmarks.Store`:
>    - Busca la carpeta hija cuyo `title` sea exactamente `"BookmarksBar"`; si no
>      existe, usa la raíz.
>    - **Hoja (`LEAF`)** → `Gtk.Button` con etiqueta = título; `clicked` emite
>      `open_url(string url)`.
>    - **Carpeta (`LIST`/`PROXY`)** → `Gtk.MenuButton` con etiqueta = título y un
>      `Gtk.Popover` cuyo hijo es un `Gtk.Box` vertical con un botón por hoja
>      hija, **recursivo**. Cada botón emite `open_url`.
>    - Declara `public signal void open_url(string url);` y **no** conoce al motor.
>    - `vexpand = false`.
>
>    Título de respaldo (nótese el manejo de error):
>
>    ```vala
>    private string display_title_for(Node node) {
>        if (node.title != null && node.title.length > 0)
>            return node.title;
>        if (node.url != null) {
>            try {
>                var host = GLib.Uri.parse(node.url, GLib.UriFlags.NONE).get_host();
>                if (host != null && host.length > 0)
>                    return host;
>            } catch (GLib.UriError e) {
>                // fallback abajo
>            }
>        }
>        return node.url ?? "(sin título)";
>    }
>    ```
>
> 4. **`baobabs/src/ui/window.vala`** — conectar la barra:
>    - Crear `Bookmarks.Store`, poblarlo con `Bookmarks.Defaults.seed()`.
>    - Insertar la barra **dentro del `Box` vertical existente**, entre el
>      `HeaderBar` y el `web_area`:
>      ```
>      Box(vertical) → [ FavoritesBar, web_area ]
>      ```
>      El `HeaderBar` sigue como titlebar (`set_titlebar`); el `Box` es el hijo de
>      la ventana (`set_child`). `web_area` conserva `hexpand`/`vexpand = true`.
>    - Conectar `favorites_bar.open_url` → `engine.load_uri(url)`.
>
> 5. **`baobabs/src/meson.build`** — añadir `bookmarks/defaults.vala` y
>    `ui/favorites_bar.vala` a `baobabs_core_sources`.
>
> **Restricciones duras (no negociables):**
> - **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
>   `core/plist.vala`, `bookmarks/model.vala`, `bookmarks/loader.vala`,
>   `bookmarks/store.vala`, `history/model.vala`.
> - **No** implementar: guardar a disco, importar el perfil de Safari, marcadores
>   editables, historial, top sites, reader, pestañas, menú hamburguesa.
> - **No** añadir dependencias nuevas en `meson.build`.
>
> **Verificación requerida:**
> - `meson compile` verde y `meson test` **2/2** en Windows.
> - La app arranca y **se ve la barra** con los 3 botones arriba del área web.
> - Al pulsar un botón, **navega** a esa URL.
> - **Los bounds cambian a propósito** (el motor usa
>   `web_area.compute_bounds(toplevel)`, geometría relativa real): `origin.y` sube
>   y el alto baja. **No es regresión.** Verificar coherencia del rect
>   (`right−left` = ancho de `web_area`; `bottom−top` = alto de `web_area`), no el
>   número viejo.
> - Persistencia al maximizar/restaurar.
> - Sin `CRITICAL`/`WARNING` nuevos.
> - Puede aparecer **un `UpdateBounds` extra** al arranque. Benigno y esperado.
>
> **Nota de fidelidad:** en Safari 5.1 la barra se llama `ShowFavoritesBar` y vive
> en `Defaults.plist`. La estructura del árbol (`BookmarksBar` como carpeta especial
> dentro de la raíz, sin UUID especial) es la documentada en `safari/HABITAT.md` §1.2.
