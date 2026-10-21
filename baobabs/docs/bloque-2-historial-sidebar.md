# Bloque 2 — Historial + sidebar segmentado (Marcadores | Historial)

**Fecha:** 2026-10-20
**Estado:** brief pendiente de entrega a Jules
**Rama objetivo:** `master` (base `d81d4c9`)
**Bloque anterior:** `baobabs/docs/bloque-1.5-aspecto-visual.md`

---

## Contexto

El Bloque 1 (barra de favoritos) y el 1.5 (aspecto visual) están cerrados,
mergeados y verificados en runtime. El rediseño reciente (`d81d4c9`) dejó un
**sidebar lateral de 250 px** que hoy contiene **sólo** la lista de marcadores, y
que arranca oculto tras un `ToggleButton` del HeaderBar.

Este bloque **fusiona dos cosas** que el usuario decidió hacer juntas:

1. **El Bloque 2 original**: historial funcional (`record_visit`) — que hasta
   ahora era sólo un modelo sin uso.
2. **El sidebar segmentado**: que el sidebar pueda mostrar **Marcadores** o
   **Historial** según una fila de botones segmentados.

La fusión tiene sentido porque **el modelo de historial ya existe** y el sidebar
ya está montado: la mitad del trabajo está escrita.

---

## Estado del código (verificado, no asumido)

### Lo que ya existe y se reutiliza tal cual

| Fichero | Qué aporta |
|---|---|
| `src/history/model.vala` | `History.Store` con `entries` (`Gee.HashMap<string, Entry>`), `record_visit(url, title)`, señal `changed`. `History.Entry` tiene `url`, `title`, `visit_count`, `last_visited_unix`, `last_visited_cocoa`, `redirect_urls`. |
| `src/ui/favorites_bar.vala` | `FavoritesBar : Gtk.Box`, señal `open_url(string url)`, construye el árbol de marcadores. **Ya funciona y no hay que reescribirlo.** |
| `src/ui/window.vala` | Sidebar con `ScrolledWindow` (250 px), `ToggleButton` + `bind_property` a `visible`, `Separator`, `main_box` HORIZONTAL. |
| `src/core/epoch.vala` | `EpochUtils.unix_to_cocoa` (ya usado por `record_visit`). |
| `src/core/config.vala` | `history_path` (`History.plist` en el perfil). |

### Punto de conexión del motor

`src/engine/engine.vala` expone la señal **`load_finished`** (contrato
`BrowserEngine`). Es el punto donde conectar `record_visit`. **No hay que tocar
el motor**: sólo conectar la señal desde `window.vala`.

---

## Verificaciones previas (runtime, no inspección)

Se compiló y **se ejecutó** un programa Vala aislado (GTK 4.24.1) para confirmar
que las piezas de UI existen y funcionan:

| Verificación | Resultado |
|---|---|
| `Gtk.Stack` en el vapi | ✅ `class Stack : Gtk.Widget` |
| `Gtk.StackSwitcher` en el vapi | ✅ `class StackSwitcher : Gtk.Widget` |
| `Gtk.SearchEntry` en el vapi | ✅ `class SearchEntry : Gtk.Widget` |
| `stack.add_titled(pagina, nombre, etiqueta)` | ✅ compila y ejecuta |
| `switcher.stack = stack` | ✅ el switcher controla el stack |
| `stack.set_visible_child_name("historial")` | ✅ devuelve `"historial"` |
| `stack.get_pages().get_n_items()` | ✅ devuelve `2` |

**Hallazgo que evita un error de compilación:** `stack.get_pages()` devuelve un
**`Gtk.SelectionModel`**, no una lista. Hay que usar **`.get_n_items()`**, **no
`.length()`** — `.length()` **no compila** (probado: `The name 'length' does not
exist in the context of 'Gtk.SelectionModel'`).

**`Gtk.StackSwitcher` es la versión GTK de los "Segmented Buttons" de Material 3:**
misma función (elegir una vista entre varias) y mismo aspecto (fila de botones
segmentados). No hace falta inventar nada.

---

## Fidelidad: cómo agrupa Safari 5.1 el historial

**No se inventa.** La evidencia está en `safari/HABITAT.md` §2.1, de
`Defaults.plist` (defaults de fábrica de Safari 5.1):

```
HistoryDaysMenuItemsLimit 7      ← el menú de historial lista 7 DÍAS
RecentHistoryMenuItemsLimit 18   ← 18 entradas recientes
HistoryAgeInDaysLimit 31         ← el historial se conserva 31 días
```

Esto **confirma que Safari agrupa el historial por días**, con un límite de 7
días visibles en el menú. La agrupación correcta es **por fecha natural**, con
encabezados del tipo `Hoy`, `Ayer`, y luego la fecha.

**Esquema de `History.plist`** (`safari/HABITAT.md` §1.3, confirmado en
`Safari.dll`):

```
{
  WebHistoryFileVersion : 1,
  WebHistoryDates : {
      "<URL>" : {
          title          : "Título de la página",
          lastVisitedDate: 814053320.7,   ← epoch Cocoa (segundos desde 2001-01-01)
          visitCount     : 3,
          redirectURLs   : [ "<URL anterior>", … ]
      }, …
  }
}
```

Claves confirmadas en binario: `lastVisitedDate`, `visitCount`, `redirectURLs`,
`WebHistoryDates`. El modelo `History.Entry` **ya refleja estos campos**.

**Nota importante:** Safari **ordena por `lastVisitedDate` descendente** (lo más
reciente primero), y agrupa por día natural. En Habitat hay que hacer lo mismo
usando `last_visited_unix`.

---

## Alcance del commit

### 1. `src/ui/history_view.vala` (nuevo) — widget del historial

Widget hermano de `FavoritesBar`, con la **misma señal pública** para que
`window.vala` los trate igual:

```vala
public class HistoryView : Gtk.Box {
    public signal void open_url(string url);
    // ...
}
```

**Requisitos del widget:**

- Recibe el `History.Store` y lee `entries` (un `HashMap`, **no ordenado**).
- **Ordena por `last_visited_unix` descendente** antes de agrupar.
- **Agrupa por día natural** (comparando fechas en hora local, no UTC):
  - `Hoy`
  - `Ayer`
  - Fechas anteriores con formato legible (p. ej. `lunes, 13 de octubre`).
- Cada grupo es un encabezado + una lista de entradas.
- Cada entrada muestra el **título** de la página (con `ellipsize`), y **navega
  al hacer clic** emitiendo `open_url(url)`.
- Se **reconstruye al recibir `store.changed`** (para que el historial se
  actualice en vivo mientras se navega).
- Si no hay entradas: mostrar un estado vacío honesto (p. ej. "Sin historial").
- `vexpand = true`, con `ScrolledWindow` propio **si hace falta** (el sidebar ya
  tiene uno; **no duplicar** sin necesidad — ver nota abajo).

### 2. `src/ui/window.vala` — el Stack y el switcher

Reemplazar el contenido del sidebar por **stack + switcher**:

```
sidebar (ScrolledWindow, 250 px)  ← ya existe, se conserva
└── Box VERTICAL
    ├── StackSwitcher          → "Marcadores" | "Historial"
    └── Stack
        ├── página "favoritos" → FavoritesBar   ← se reutiliza tal cual
        └── página "historial" → HistoryView     ← nuevo
```

**Detalles importantes:**

- `stack.add_titled(favorites_bar, "favoritos", "Marcadores")`
- `stack.add_titled(history_view, "historial", "Historial")`
- `switcher.stack = stack`
- **Ambá páginas** conectan `open_url` → `engine.load_uri(url)`.
- El `FavoritesBar` **no se modifica**: ya es un widget con su señal propia.

**Cuidado con el `ScrolledWindow`:** hoy el sidebar envuelve directamente a
`FavoritesBar`. Al meter un `Stack`, hay que decidir **dónde** va el scroll:
- Opción simple: el `ScrolledWindow` envuelve el `Stack` completo (el switcher
  se va con el scroll).
- Opción mejor: el `ScrolledWindow` va **dentro de cada página**, para que el
  switcher quede fijo arriba y sólo scrollee el contenido.
- **Elegir la que compile limpio** y se vea coherente; documentar la elección.

### 3. `src/ui/window.vala` — conectar `record_visit` (el núcleo del Bloque 2)

Aquí es donde el historial **deja de ser estructura y pasa a ser funcionalidad**:

**Los nombres están verificados** (leídos del contrato y de la implementación,
no adivinados):

- `src/engine/engine.vala` declara `public abstract string url { get; set; }` y
  `public abstract string title { get; set; }` → son **`engine.url`** y
  **`engine.title`**.
- La señal es `load_finished(bool success, string? error)`.
- En `src/engine/webview2.vala`, los callbacks de URL y título hacen
  `_url = new_url` (línea 71) y `_title = new_title` (línea 76) **antes** de que
  se emita `load_finished` (línea 91). Por lo tanto, leer `engine.url` y
  `engine.title` **dentro del callback de `load_finished` es correcto**: ya
  contienen los valores de la página que acaba de cargar.

```vala
private History.Store history_store;   // nuevo campo

// en construct:
history_store = new History.Store();

engine.load_finished.connect((success, error) => {
    if (!success) return;
    if (engine.url != null && engine.url.length > 0) {
        history_store.record_visit(engine.url, engine.title);
    }
});
```

> **Nota:** la firma del callback lleva **dos** parámetros (`success`, `error`);
> hay que declararlos ambos aunque `error` no se use.

### 4. `data/style.css` — añadir reglas mínimas

- `StackSwitcher` / `stackswitcher`: que los botones segmentados se vean
  coherentes con la paleta clara ya definida.
- Encabezados de fecha del historial (clase propia, p. ej.
  `.history-date-header`): texto pequeño, gris, no seleccionable.
- Entradas del historial (`.history-item`): mismo tratamiento que
  `.favorites-item` (planas, sin marco, con `:hover`).

**No reescribir el CSS existente**: sólo añadir lo nuevo.

---

## Restricciones duras

- **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
  `core/plist.vala`, `bookmarks/*`, `history/model.vala`.
  - Se **usan** `History.Store` y `record_visit`; **no se modifican**.
- **No** implementar persistencia: el historial vive **en memoria** en este
  bloque. Escribir `History.plist` es el **Bloque 3**.
- **No** añadir funcionalidad nueva fuera de esto: nada de pestañas, Top Sites,
  Reader, descargas ni menú de aplicación.
- **No** añadir dependencias (GTK4 y `gee` ya están).
- **No** cambiar `SizeTrackingArea` ni romper `web_area`
  (`hexpand`/`vexpand = true`).
- **No** tocar la estructura `main_box` HORIZONTAL
  (`sidebar` | `separator` | `web_area`): se conserva.
- `FavoritesBar` **se reutiliza sin reescribir**: si hay que ajustarlo, el cambio
  debe ser mínimo y justificado.

---

## Verificación requerida

- `meson compile` verde y `meson test` **2/2** en Windows.
- **La app arranca** y el sidebar se abre con el `ToggleButton` (sin cambios).
- **El switcher cambia de vista**: pulsar "Historial" muestra el historial;
  "Marcadores" vuelve a la lista de marcadores.
- **El historial se llena de verdad**: navegar a 2-3 sitios con los botones de
  marcadores y comprobar que aparecen en la pestaña Historial.
- **La agrupación por fecha es correcta**: las entradas de hoy aparecen bajo
  "Hoy"; si hay de días anteriores, bajo su fecha. **Orden descendente por
  fecha** (lo más reciente primero).
- **Los clics navegan**: clicar una entrada del historial carga esa URL.
- **Bounds coherentes**: `right−left` = ancho de `web_area`;
  `bottom−top` = alto de `web_area`.
- Sin `CRITICAL`/`WARNING` nuevos, y **sin errores de parseo de CSS** en el log.

**Números de referencia (rama actual `d81d4c9`, sidebar oculto):**

| Estado | Rect |
|---|---|
| Ventana | `left=14 top=81 right=1114 bottom=764` |
| Maximizado | `left=0 top=67 right=1920 bottom=1080` |

> **Ojo:** estos números son **con el sidebar oculto**. Si el sidebar se abre, el
> ancho de `web_area` **bajará** (~250 px menos) y `right` cambiará. Eso es
> **esperado y correcto**, no una regresión. Lo que debe cumplirse siempre es la
> **coherencia** (`right−left` = ancho real del área web).

---

## Fuera de alcance (siguientes bloques)

| Bloque | Contenido |
|---|---|
| 3 | Persistencia bplist propia (writer binario a mano; `History.plist` incluido) |
| 4 | Marcadores editables (estrella) |
| 5 | Top Sites (widget propio + `topsites://` en `decide-policy`) |
| 6 | Reader (reutilizar `Reader.html` + escribir el JS) |

---

## Preguntas abiertas (respondidas por el usuario)

| Pregunta | Decisión |
|---|---|
| ¿Fusionar historial + sidebar segmentado en un bloque? | **Sí**, fusionado |
| ¿Cambiar el comportamiento del sidebar (abrirse solo, etc.)? | **No**: sigue con el `ToggleButton`, sin cambios |
| ¿Conectar `record_visit`? | **Sí**, es parte del Bloque 2 |
| ¿Cómo agrupar el historial? | **Por fecha natural**, estilo Safari: Hoy, Ayer, etc. |

---

## Referencias

- `safari/HABITAT.md` §1.3 — esquema de `History.plist` (confirmado en `Safari.dll`).
- `safari/HABITAT.md` §2.1 — `Defaults.plist`: `HistoryDaysMenuItemsLimit 7`,
  `RecentHistoryMenuItemsLimit 18`, `HistoryAgeInDaysLimit 31`,
  `SidebarSplitViewDividerPosition 300`.
- `safari/History.plist` — perfil real (1 entrada: `google.com`).
- `baobabs/docs/bloque-1-barra-favoritos.md` — Bloque 1.
- `baobabs/docs/bloque-1.5-aspecto-visual.md` — Bloque 1.5.

---

## Anexo — Mensaje paste-ready para Jules

> **Contexto:** los Bloques 1 (barra de favoritos) y 1.5 (aspecto visual) están
> cerrados y mergeados. El rediseño reciente dejó un **sidebar lateral de 250 px**
> que hoy sólo muestra marcadores, oculto tras un `ToggleButton`.
>
> Este bloque **fusiona dos cosas**, por decisión del usuario:
> 1. El **historial funcional** (el Bloque 2 original).
> 2. El sidebar **segmentado**: que muestre **Marcadores** o **Historial**.
>
> La fusión tiene sentido porque el modelo de historial **ya existe**
> (`src/history/model.vala`: `History.Store` con `record_visit()` y señal
> `changed`) y el sidebar ya está montado.
>
> **Verificaciones que ya hice yo (ejecutadas, no supuestas):**
> - `Gtk.Stack`, `Gtk.StackSwitcher` y `Gtk.SearchEntry` existen en GTK 4.24.1 y
>   funcionan. **`StackSwitcher` es la versión GTK de los "Segmented Buttons"**:
>   no hay que inventar nada.
> - **Ojo con un error de compilación:** `stack.get_pages()` devuelve un
>   `Gtk.SelectionModel`. Se usa **`.get_n_items()`**, **no** `.length()`
>   (`.length()` no compila).
>
> **Fidelidad — cómo agrupa Safari 5.1 el historial.** No se inventa. En
> `safari/HABITAT.md` §2.1, los defaults de fábrica de Safari 5.1 incluyen:
> `HistoryDaysMenuItemsLimit 7` (el menú lista **7 días**),
> `RecentHistoryMenuItemsLimit 18` (18 entradas recientes) y
> `HistoryAgeInDaysLimit 31` (se conserva 31 días). Es decir: **Safari agrupa el
> historial por días**. Usar encabezados `Hoy`, `Ayer`, y fecha legible, con
> **orden descendente** por `lastVisitedDate`.
>
> **Alcance — sólo esto:**
>
> 1. **`src/ui/history_view.vala` (nuevo)** — `HistoryView : Gtk.Box` con señal
>    pública `open_url(string url)` (hermano de `FavoritesBar`, misma interfaz):
>    - Recibe el `History.Store`; lee `entries` (es un `HashMap`, **no ordenado**).
>    - **Ordena por `last_visited_unix` descendente** y **agrupa por día natural**
>      en hora local: `Hoy`, `Ayer`, luego la fecha.
>    - Cada entrada: **título** (con `ellipsize`), clic → `open_url(url)`.
>    - Se **reconstruye al recibir `store.changed`**.
>    - Sin entradas → estado vacío honesto ("Sin historial").
>
> 2. **`src/ui/window.vala`** — meter `Stack` + `StackSwitcher` en el sidebar:
>    ```vala
>    var stack = new Stack();
>    stack.add_titled(favorites_bar, "favoritos", "Marcadores");
>    stack.add_titled(history_view, "historial", "Historial");
>    var switcher = new StackSwitcher();
>    switcher.stack = stack;
>    ```
>    - **`FavoritesBar` se reutiliza tal cual** (ya tiene su señal `open_url`).
>    - Ambos widgets conectan `open_url` → `engine.load_uri(url)`.
>    - Decidir dónde va el scroll: mejor **dentro de cada página** (switcher fijo
>      arriba, sólo scrollea el contenido). Elegir lo que compile limpio.
>
> 3. **`src/ui/window.vala` — conectar el historial (el núcleo del bloque):**
>    Nombres **verificados** (leídos del contrato y de la implementación):
>    `engine.vala` declara `url` y `title` como propiedades abstractas, y
>    `webview2.vala` hace `_url = new_url` / `_title = new_title` **antes** de
>    emitir `load_finished`. Así que leer `engine.url` y `engine.title` dentro
>    del callback es correcto.
>    ```vala
>    private History.Store history_store;
>    // en construct:
>    history_store = new History.Store();
>    engine.load_finished.connect((success, error) => {
>        if (!success) return;
>        if (engine.url != null && engine.url.length > 0) {
>            history_store.record_visit(engine.url, engine.title);
>        }
>    });
>    ```
>    La firma del callback lleva **dos** parámetros (`success`, `error`); hay que
>    declararlos ambos aunque `error` no se use.
>
> 4. **`data/style.css`** — sólo **añadir** (no reescribir):
>    - `stackswitcher`: botones segmentados coherentes con la paleta clara.
>    - `.history-date-header`: pequeño, gris, no seleccionable.
>    - `.history-item`: mismo tratamiento que `.favorites-item`
>      (plano, sin marco, con `:hover`).
>
> **Restricciones duras:**
> - **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
>   `core/plist.vala`, `bookmarks/*`, `history/model.vala`. (`History.Store` se
>   **usa**, no se modifica.)
> - **No** persistencia: el historial vive **en memoria** (escribir
>   `History.plist` = Bloque 3).
> - **No** funcionalidad nueva fuera de esto (pestañas, Top Sites, Reader,
>   descargas, menú).
> - **No** deps nuevas. **No** cambiar `SizeTrackingArea` ni la estructura
>   `main_box` (`sidebar | separator | web_area`).
> - `FavoritesBar` **sin reescribir**: si hay que ajustarlo, mínimo y justificado.
> - **No** cambiar el comportamiento del sidebar: sigue con el `ToggleButton`.
>
> **Verificación requerida:**
> - `meson compile` verde y `meson test` **2/2**.
> - El sidebar se abre con el `ToggleButton` y **el switcher cambia de vista**.
> - **El historial se llena de verdad**: navegar a 2-3 sitios y verlos aparecer
>   en la pestaña Historial.
> - **Agrupación y orden correctos**: hoy bajo "Hoy"; descendente por fecha.
> - **Los clics navegan** a la URL de la entrada.
> - **Bounds coherentes**: `right−left` = ancho de `web_area`;
>   `bottom−top` = alto de `web_area`. Con el sidebar abierto, `web_area` pierde
>   ~250 px de ancho: **eso es esperado**, no una regresión; lo que debe cumplirse
>   es la coherencia.
> - Sin `CRITICAL`/`WARNING` nuevos ni errores de parseo de CSS.
>
> **Números de referencia (sidebar oculto, rama actual):** ventana
> `left=14 top=81 right=1114 bottom=764`; maximizado
> `left=0 top=67 right=1920 bottom=1080`.
