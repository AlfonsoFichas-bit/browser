# Bloque 1.5 — Aspecto visual (chrome estilo Safari 5.1)

**Fecha:** 2026-10-20
**Estado:** brief entregado a Jules, pendiente de implementación
**Rama objetivo:** `master` (base `a8b98f9`)

---

## Contexto

El Bloque 1 (barra de favoritos) está cerrado y verificado en runtime: la barra
se ve, navega, y los bounds siguen coherentes. Ahora toca **el aspecto visual**,
antes de seguir con funcionalidad (Bloque 2: historial).

**Estado actual:** la UI usa los widgets GTK4 por defecto, sin CSS propio. Se ve
como una app GNOME genérica, no como Safari 5.1.

### Nota de fidelidad (importante para no perseguir un imposible)

Safari 5.1 en Windows **no** dibujaba su chrome con CSS: usaba controles
**nativos de Windows** vía `SafariTheme.dll` (que **no está analizado** en
`safari/`). Por lo tanto **no existe un CSS de Safari que copiar** para la UI
del navegador — el aspecto es **criterio de diseño** inspirado en Safari 5.1.

Los únicos colores auténticos que tenemos documentados están en
`safari/Reader.html` (aplican al **Reader**, Bloque 6, no a este bloque):

| Uso | Valor real (Reader.html) |
|---|---|
| Enlaces | `rgb(32, 0, 127)` (azul violáceo clásico de Apple) |
| Tipografía de artículo | `Palatino, Georgia, Times, "Times New Roman", serif` |
| UI del Reader | overlay `rgba(0,0,0,0.8)`, contenedor 862 px centrado |

### Decisiones ya tomadas por el usuario

- **Alcance:** barra de favoritos + HeaderBar (no todo el chrome, no sistema de temas completo).
- **Paleta:** clara estilo Safari (gris claro metálico + blanco + acento azul).

---

## Verificaciones previas (runtime, no inspección)

| Verificación | Resultado |
|---|---|
| `Gtk.CssProvider.load_from_resource` en este entorno | ✅ Probado en un proyecto Meson aislado: carga OK y el CSS queda embebido |
| `gnome.compile_resources` disponible | ✅ El módulo `gnome` existe (`meson 1.12.1`) y `glib-compile-resources` está presente |
| `CssProvider` API en el vapi | ✅ `load_from_resource`, `load_from_string`, `load_from_path`, `load_from_file` |
| CSS por `install_data` en Windows | ❌ **No sirve**: corremos desde `builddir` sin instalar → el CSS no se encontraría |

**Conclusión clave:** el CSS debe ir **embebido en el binario** con
`gnome.compile_resources` + `load_from_resource`. Cargarlo desde fichero
instalado no funciona en Windows, que es donde verificamos.

---

## Alcance del commit

### 1. `baobabs/data/style.css` (nuevo)

CSS de GTK4 con **paleta clara estilo Safari**. Sin colores hardcodeados
dispersos: definir todo aquí, en un único lugar.

Contenido esperado (orientativo, el detalle es criterio del implementador):

- **Fondo general del chrome**: gris claro (`#e8e8e8` / `#ececec`).
- **Clase propia para la barra de favoritos** (p. ej. `.favorites-bar`): fondo
  gris, borde inferior sutil, altura fija coherente, sin separación excesiva.
- **Botones de la barra** (`.favorites-bar button`): **planos** (sin marco ni
  fondo), texto oscuro, esquinas suaves, y **resalte al pasar el mouse**
  (`:hover`) con gris más marcado. Sin sombra.
- **Botón de carpeta** (`.favorites-bar menubutton`): mismo tratamiento, para
  que hojas y carpetas se vean consistentes.
- **HeaderBar**: fondo gris claro, sin sombra fuerte.
- **Campo de URL** (`entry`): fondo blanco, borde sutil, esquinas redondeadas.
- **Acento**: azul Apple (`rgb(32, 0, 127)` o un azul más legible) para foco y
  `:checked`.

**Reglas de estilo (obligatorias):**
- Usar **clases CSS propias** en los widgets (vía `add_css_class`), **no**
  selectores sobre widgets de GTK internos no documentados.
- No usar `!important`.
- No romper el modo oscuro del sistema de forma catastrófica (aunque se
  prioriza el claro, ver nota de alcance).

### 2. `baobabs/data/style.gresource.xml` (nuevo)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gresources>
  <gresource prefix="/org/baobabs/browser">
    <file>style.css</file>
  </gresource>
</gresources>
```

### 3. `baobabs/data/meson.build`

Añadir la compilación del recurso y exponerlo a `src/`. Forma esperada:
`gnome.compile_resources(...)` en `data/`, y que `src/meson.build` enlace el
resultado al ejecutable y a la librería.

> **Nota de implementación:** `gnome.compile_resources` debe estar **accesible**
> desde donde se declare el ejecutable. Si resulta más simple, declararlo en
> `src/meson.build` con `source_dir` apuntando a `../data`. Elegir la forma que
> compile sin retorcer la estructura.

### 4. `baobabs/src/app.vala` o `baobabs/src/ui/window.vala` — cargar el CSS

Cargar el provider **una sola vez** al arrancar:

```vala
var provider = new Gtk.CssProvider();
provider.load_from_resource("/org/baobabs/browser/style.css");
Gtk.StyleContext.add_provider_for_display(
    Gdk.Display.get_default(),
    provider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
);
```

**Ojo:** `Gdk.Display.get_default()` puede ser `null` si se llama antes de que
GTK inicialice. Cargar el CSS **después** de que haya display (en `activate()`
de `app.vala` es lo natural).

### 5. Clases CSS en los widgets

- **`favorites_bar.vala`**: añadir `add_css_class("favorites-bar")` a la barra,
  y una clase a los botones si hace falta (p. ej. `add_css_class("favorites-item")`).
- **`window.vala`**: `add_css_class` al `HeaderBar` y al `url_entry` si el CSS
  los necesita para poder seleccionarlos sin depender de internals.

---

## Restricciones duras

- **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
  `core/plist.vala`, `bookmarks/*`, `history/model.vala`.
- **No cambiar la estructura** de widgets: `[FavoritesBar, web_area]` sigue
  igual; `web_area` conserva `hexpand`/`vexpand = true`; `SizeTrackingArea`
  no se toca.
- **No** implementar funcionalidad nueva: nada de historial, persistencia,
  marcadores editables, top sites, reader, pestañas, menú.
- **No añadir dependencias** nuevas en `meson.build` (GTK4 ya está; `gnome` es
  un módulo de Meson, no una dependencia).
- **No instalar** el CSS con `install_data`: va embebido.

---

## Verificación requerida

- `meson compile` verde y `meson test` **2/2** en Windows.
- La app arranca y **el CSS se aplica** (la barra y el HeaderBar se ven con la
  paleta clara, no con el estilo GNOME por defecto).
- La barra de favoritos sigue funcionando: los 3 botones navegan.
- **Bounds coherentes** (el CSS no debe alterar el layout de forma que rompa el
  cálculo): verificar `right−left` = ancho de `web_area` y `bottom−top` = alto
  de `web_area`. Si el alto de la barra cambia con el CSS, el `top` cambiará en
  consecuencia — **eso es esperado**, no una regresión.
- Sin `CRITICAL`/`WARNING` nuevos.
- Sin errores de parseo de CSS (GTK emite warning si el CSS tiene errores de
  sintaxis: revisar el log).

**Números de referencia (con barra, ya verificados):**

| Estado | Rect |
|---|---|
| Ventana | `left=14 top=95 right=1114 bottom=764` |
| Maximizado | `left=0 top=81 right=1920 bottom=1080` |

---

## Nota de alcance sobre modo oscuro

La paleta elegida es **clara**. Si el sistema está en modo oscuro, forzar claro
puede verse incoherente. **No** se pide resolver esto ahora: se prioriza el
aspecto claro tipo Safari. Si el implementador quiere, puede añadir en el CSS un
bloque para `@media (prefers-color-scheme: dark)` que simplemente herede el
tema, pero **no es obligatorio** y no debe complicar el commit.

---

## Fuera de alcance (siguientes bloques)

| Bloque | Contenido |
|---|---|
| 2 | Historial: `engine.load_finished` → `History.Store.record_visit()` + menú |
| 3 | Persistencia bplist propia (writer binario a mano; no existe `libplist`) |
| 4 | Marcadores editables (estrella) |
| 5 | Top Sites (widget propio + `topsites://` en `decide-policy`) |
| 6 | Reader (reutilizar `Reader.html` + escribir el JS; paleta real `rgb(32,0,127)`) |

---

## Referencias

- `safari/Reader.html` — CSS auténtico de Apple (aplica al Reader, no a este bloque).
- `safari/HABITAT.md` §2.1 — claves de UI de `Defaults.plist` (`ShowFavoritesBar`,
  `ShowStatusBar`, `SidebarSplitViewDividerPosition 300`).
- `safari/INFORME.md` — `SafariTheme.dll` sólo mencionado, **no analizado**.
- `baobabs/docs/bloque-1-barra-favoritos.md` — bloque anterior.

---

## Anexo — Mensaje paste-ready para Jules

> **Contexto:** el Bloque 1 (barra de favoritos) está cerrado. Ahora toca el
> **aspecto visual**, antes de seguir con funcionalidad. Estado actual: la UI usa
> los widgets GTK4 por defecto, sin CSS propio; se ve como una app GNOME
> genérica, no como Safari 5.1.
>
> **Nota de fidelidad:** Safari 5.1 en Windows no dibujaba su chrome con CSS
> (usaba controles nativos vía `SafariTheme.dll`, **no analizado**), así que **no
> hay CSS de Safari que copiar** — es criterio de diseño. Los únicos colores
> auténticos documentados están en `Reader.html` y aplican al Reader (Bloque 6).
>
> **Decisiones ya tomadas:** alcance = barra de favoritos + HeaderBar; paleta =
> clara estilo Safari (gris claro + blanco + acento azul).
>
> **Alcance — sólo esto:**
>
> 1. **`baobabs/data/style.css` (nuevo)** — CSS de GTK4, paleta clara estilo
>    Safari, todo en un solo lugar:
>    - Fondo del chrome: gris claro (`#e8e8e8`/`#ececec`).
>    - `.favorites-bar`: fondo gris, borde inferior sutil, altura coherente.
>    - `.favorites-bar button` y `.favorites-bar menubutton`: **planos** (sin
>      marco ni fondo), texto oscuro, esquinas suaves, **resalte `:hover`**.
>    - `HeaderBar`: fondo gris claro, sin sombra fuerte.
>    - `entry` (campo de URL): fondo blanco, borde sutil, esquinas redondeadas.
>    - Acento azul Apple (`rgb(32, 0, 127)` o uno más legible) para foco/`:checked`.
>    - Usar **clases CSS propias** (`add_css_class`), **no** selectores sobre
>      internals de GTK. Sin `!important`.
>
> 2. **`baobabs/data/style.gresource.xml` (nuevo)**:
>    ```xml
>    <?xml version="1.0" encoding="UTF-8"?>
>    <gresources>
>      <gresource prefix="/org/baobabs/browser">
>        <file>style.css</file>
>      </gresource>
>    </gresources>
>    ```
>
> 3. **`baobabs/data/meson.build`** — compilar el recurso con
>    `gnome.compile_resources` y enlazarlo al ejecutable/librería. Si es más
>    simple, declararlo en `src/meson.build` con `source_dir` a `../data`.
>    Elegir la forma que compile limpio.
>
> 4. **Cargar el CSS una vez al arrancar** (en `activate()` de `app.vala`, para
>    que el display ya exista):
>    ```vala
>    var provider = new Gtk.CssProvider();
>    provider.load_from_resource("/org/baobabs/browser/style.css");
>    Gtk.StyleContext.add_provider_for_display(
>        Gdk.Display.get_default(),
>        provider,
>        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
>    );
>    ```
>    **Ojo:** `Gdk.Display.get_default()` puede ser `null` antes de que GTK
>    inicialice.
>
> 5. **Clases CSS en los widgets** — `add_css_class("favorites-bar")` en
>    `favorites_bar.vala`; clases al `HeaderBar`/`url_entry` si hacen falta para
>    seleccionarlos sin depender de internals.
>
> **Restricciones duras:**
> - **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
>   `core/plist.vala`, `bookmarks/*`, `history/model.vala`.
> - **No cambiar la estructura** de widgets (`[FavoritesBar, web_area]` igual;
>   `web_area` conserva `hexpand`/`vexpand`; `SizeTrackingArea` intacto).
> - **No** implementar funcionalidad nueva (historial, persistencia, marcadores,
>   top sites, reader, pestañas, menú).
> - **No añadir dependencias** (GTK4 ya está; `gnome` es módulo de Meson, no dep).
> - **No instalar** el CSS con `install_data`: va **embebido** (verificado:
>   `load_from_resource` funciona; cargarlo desde fichero instalado **no**
>   funciona en Windows).
>
> **Verificación requerida:**
> - `meson compile` verde y `meson test` **2/2** en Windows.
> - El CSS **se aplica**: barra y HeaderBar con paleta clara, no estilo GNOME.
> - La barra sigue funcionando (los 3 botones navegan).
> - **Bounds coherentes**: `right−left` = ancho de `web_area`;
>   `bottom−top` = alto de `web_area`. Si el alto de la barra cambia con el CSS,
>   el `top` cambia en consecuencia (**esperado**, no regresión).
> - Sin `CRITICAL`/`WARNING` nuevos, y **sin errores de parseo de CSS** en el log.
>
> **Referencia de los números actuales (con barra):** ventana
> `left=14 top=95 right=1114 bottom=764`; maximizado
> `left=0 top=81 right=1920 bottom=1080`.
