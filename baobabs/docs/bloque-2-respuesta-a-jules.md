  # Bloque 2 — Historial + sidebar segmentado: respuestas a Jules
  
  **Fecha:** 2026-10-20
  **Estado:** respuesta a entregar a Jules, pendiente de implementación
  **Base:** `master` = `6504143`
  **Brief original:** `baobabs/docs/bloque-2-historial-sidebar.md`
  
  ---
  
  ## Contexto
  
  Jules revisó el brief y devolvió su comprensión del trabajo más **cuatro
  preguntas**. Su comprensión es correcta en todo. Las cuatro preguntas se
  responden abajo, y **dos de ellas esconden un error que él cometería igual**.
  
  Las dos trampas:
  
  1. **Pregunta 3 (ScrolledWindow):** ya existe **un** `ScrolledWindow` en el
     sidebar envolviendo `FavoritesBar`. Su plan (envolver `FavoritesBar` en
     *otro*) crea **dos scrolls apilados** en la misma página.
  2. **Pregunta 1 (zona horaria):** "usar hora local" es correcto, pero
     **no basta**: agrupar por diferencia de horas da mal "Ayer". Verificado: una
     visita de **hace 30 horas** calcula como **"Hoy"**. Hay que comparar **fechas
     de calendario**, no restar `86400`.
  
  ---
  
  ## Verificaciones previas (runtime, ejecutado — no inspeccionado)
  
  Programa Vala aislado con GTK 4.24.1 y GLib, compilado y ejecutado.
  
  ### 1. Doble `ScrolledWindow` anidado
  
  ```
  outer->child es ScrolledWindow, inner->child es Box
  hay 2 ScrolledWindow apilados: SI (doble scroll)
  ```
  
  **Envolver un `ScrolledWindow` dentro de otro compila** — no da error, sólo
  **doble barra de scroll y comportamiento confuso**. Es exactamente el tipo de
  fallo que pasa los tests y se descubre al usar la app.
  
  ### 2. Agrupación por diferencia de horas (el error sutil)
  
  ```
  hoy (local): 2026-10-20
  medianoche local: 2026-10-20T00:00:00-0400
  hace 30h -> diff_days respecto a medianoche de hoy = 0  (0=hoy, 1=ayer)
  ```
  
  Una entrada de **hace 30 horas** cae en **"Hoy"** según el cálculo trivial
  (`(ahora - entrada) / 86400`). Es incorrecto: a las 23:00 de ayer, 30 horas
  antes es hoy a las 05:00 — pero a las 02:00 de hoy, 30 horas antes es
  **anteayer**. **La única forma correcta es comparar fechas de calendario.**
  
  ### 3. Formato de fecha en español
  
  ```
  formato '%A, %d de %B'  -> Martes, 13 de octubre
  formato '%A %d/%m/%Y'   -> Martes 13/10/2026
  ```
  
  **Sale en español directamente.** No hace falta tabla de traducción manual.
  (Advertencia: depende del locale; si el sistema está en inglés saldría en inglés.
  En la máquina de verificación sale español.)
  
  ### 4. Errores de compilación reales que aparecieron (para evitarlos)
  
  | Se intentó | Resultado |
  |---|---|
  | `get_ymd(out var y, out var m, out var d)` | ❌ **no compila**: no se puede declarar variable dentro del `out`. Declarar antes: `int ty, tm, td;` y luego `dt.get_ymd(out ty, out tm, out td);` |
  | `dt.get_day()` | ❌ **no existe**. El método es **`get_day_of_month()`** |
  | `print("... %ld", int64)` | ❌ no convierte `int64` a `long`. Usar `%s` con `.to_string()` |
  
  ---
  
  ## Respuestas
  
  ### 1. Zona horaria — **sí, hora local — pero con la corrección crítica**
  
  Correcto: usar `GLib.DateTime` en **hora local**. **Pero "local" no es el punto
  principal**: el punto es que hay que **comparar fechas de calendario**, no restar
  segundos.
  
  **Incorrecto (da mal "Ayer"):**
  ```vala
  int64 diff_days = (now.to_unix() - entry.last_visited_unix) / 86400;
  ```
  
  **Correcto: comparar el día de calendario en hora local:**
  ```vala
  var now = new GLib.DateTime.now_local();
  var visited = new GLib.DateTime.from_unix_local(entry.last_visited_unix);
  
  // Fecha (año, mes, día) de cada uno, en local
  int ny, nm, nd, vy, vm, vd;
  now.get_ymd(out ny, out nm, out nd);
  visited.get_ymd(out vy, out vm, out vd);
  
  // "Hoy": misma fecha Y/M/D
  bool is_today = (ny == vy && nm == vm && nd == vd);
  
  // "Ayer": la fecha del visitado + 1 dia == fecha de hoy
  var yesterday = now.add_days(-1);
  int yy, ym, yd;
  yesterday.get_ymd(out yy, out ym, out yd);
  bool is_yesterday = (yy == vy && ym == vm && yd == vd);
  ```
  
  **Por qué importa:** agrupar por `last_visited_unix` con divisiones de 86400
  mete visitas de ayer en "Hoy" (y viceversa), sobre todo cerca de medianoche. Se
  verificó con "hace 30 horas" → dio **"Hoy"**, que es incorrecto según la hora.
  
  ### 2. Formato de fecha — **sí, `%A, %d de %B` es correcto y sale en español**
  
  Verificado: produce **`Martes, 13 de octubre`**. No hace falta tabla manual.
  Aceptable tal cual. Si se quiere evitar la dependencia del locale, se puede
  usar un arreglo de meses/días en español — pero **no es obligatorio** y añade
  código. Preferible el formato directo.
  
  ### 3. `ScrolledWindow` — **NO envolver `FavoritesBar` en otro `ScrolledWindow`**
  
  **Ojo aquí: ya hay un `ScrolledWindow` en el sidebar.** Hoy `window.vala` hace:
  
  ```vala
  var sidebar_scrolled = new ScrolledWindow();
  sidebar_scrolled.set_child(favorites_bar);      // ← ya envuelve FavoritesBar
  sidebar_scrolled.width_request = 250;
  sidebar_scrolled.add_css_class("sidebar-container");
  ```
  
  Si además se envuelve `FavoritesBar` en **otro** `ScrolledWindow` antes de
  metido en el `Stack`, quedan **dos scrolls apilados** (verificado: compila, pero
  es doble scroll).
  
  **Lo correcto:**
  
  ```
  sidebar_scrolled (ScrolledWindow, 250px, "sidebar-container")   ← SE CONSERVA, es el único scroll
  └── Box VERTICAL
      ├── switcher (StackSwitcher)      ← queda FIJO arriba (no scrollea)
      └── stack (Stack)
          ├── "favoritos" → FavoritesBar   ← SIN ScrolledWindow propio
          └── "historial" → HistoryView    ← SIN ScrolledWindow propio
  ```
  
  - Se **conserva** el `sidebar_scrolled` que ya existe (con su `width_request` y
    su clase CSS).
  - Dentro va un `Box` vertical: **switcher arriba, stack debajo**.
  - **Ni `FavoritesBar` ni `HistoryView` llevan `ScrolledWindow` propio.**
  - El switcher queda fijo porque está **fuera** del scroll (el scroll es el
    contenedor padre, y scrollea el `Box` completo). Si se quiere que el switcher
    **no** scrollee con el contenido, entonces sí hace falta el scroll interno —
    pero **entonces hay que quitar el externo**, nunca los dos.
  
  **Decisión:** la opción simple (switcher arriba, un solo scroll) es la que
  compila limpio y cumple lo pedido. **Un solo `ScrolledWindow`.**
  
  ### 4. Estado vacío — **sí, `Gtk.Label` centrado con "Sin historial" es correcto**
  
  Perfecto. `Gtk.Label` centrado con "Sin historial" cuando `entries` está vacío.
  Sugerencia menor (no obligatoria): usar una clase CSS (p. ej.
  `.history-empty`) para que el texto salga gris y discreto, coherente con el tema
  claro.
  
  ---
  
  ## Restricciones (recordatorio)
  
  - **No tocar** `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
    `core/plist.vala`, `bookmarks/*`, `history/model.vala` (`History.Store` se
    **usa**, no se modifica).
  - **No** persistencia: historial **en memoria** (Bloque 3).
  - **No** funcionalidad nueva fuera de esto.
  - **No** deps nuevas. **No** tocar `SizeTrackingArea` ni la estructura
    `main_box` (`sidebar | separator | web_area`).
  - **No** cambiar el comportamiento del sidebar (sigue con el `ToggleButton`).
  - `FavoritesBar` **sin reescribir**.
  
  ---
  
  ## Verificación requerida
  
  - `meson compile` verde y `meson test` **2/2**.
  - El sidebar se abre con el `ToggleButton`; el switcher **cambia de vista**.
  - **El historial se llena de verdad**: navegar a 2-3 sitios y verlos aparecer.
  - **Agrupación correcta**: visitas de hoy bajo "Hoy"; **sin falsos "Hoy"** para
    visitas de ayer (probar cerca de medianoche si se puede).
  - **Sin doble barra de scroll** en el sidebar.
  - Bounds coherentes: `right−left` = ancho de `web_area`.
  - Sin `CRITICAL`/`WARNING` nuevos ni errores de parseo de CSS.
  
  ---
  
  ## Referencias
  
  - `baobabs/docs/bloque-2-historial-sidebar.md` — brief de este bloque.
  - `safari/HABITAT.md` §1.3 y §2.1 — esquema de historial y límites de Safari.
  
  ---
  
  ## Anexo — Mensaje paste-ready para Jules
  
  > Tus cuatro puntos de comprensión son correctos. Las respuestas, con **dos
  > correcciones importantes** (preguntas 1 y 3): verifiqué ambas en runtime y las
  > dos esconden un fallo que compila y pasa los tests.
  >
  > **1. Zona horaria — sí, hora local; pero el punto crítico es OTRO.**
  >
  > Usar `GLib.DateTime` en hora local es correcto. **Pero no agrupes por
  > diferencia de segundos.** Verifiqué que una entrada de **hace 30 horas**
  > calcula como **"Hoy"** con `(now.to_unix() - last_visited_unix) / 86400`, y eso
  > es incorrecto.
  >
  > Compara **fechas de calendario**:
  > ```vala
  > var now = new GLib.DateTime.now_local();
  > var visited = new GLib.DateTime.from_unix_local(entry.last_visited_unix);
  >
  > int ny, nm, nd, vy, vm, vd;
  > now.get_ymd(out ny, out nm, out nd);
  > visited.get_ymd(out vy, out vm, out vd);
  > bool is_today = (ny == vy && nm == vm && nd == vd);
  >
  > var yesterday = now.add_days(-1);
  > int yy, ym, yd;
  > yesterday.get_ymd(out yy, out ym, out yd);
  > bool is_yesterday = (yy == vy && ym == vm && yd == vd);
  > ```
  >
  > **Ojo con tres errores de compilación que ya probé:**
  > - `get_ymd(out var y, ...)` **no compila** — declara las variables **antes**.
  > - `get_day()` **no existe** — es **`get_day_of_month()`**.
  > - `print("%ld", int64)` falla — usa `%s` con `.to_string()`.
  >
  > **2. Formato `%A, %d de %B` — sí, correcto.** Verificado: produce
  > **`Martes, 13 de octubre`** directamente en español. No hace falta traducir a
  > mano.
  >
  > **3. ScrolledWindow — NO (corrección importante).** Ya existe **un**
  > `ScrolledWindow` en el sidebar envolviendo `FavoritesBar`
  > (`sidebar_scrolled`, 250 px, clase `sidebar-container`). Si envuelves
  > `FavoritesBar` en **otro**, quedan **dos scrolls apilados** (verificado:
  > compila, pero es doble scroll).
  >
  > Estructura correcta — **un solo scroll**:
  > ```
  > sidebar_scrolled (se CONSERVA, es el único)
  > └── Box VERTICAL
  >     ├── StackSwitcher      ← fijo arriba
  >     └── Stack
  >         ├── "favoritos" → FavoritesBar   (SIN ScrolledWindow propio)
  >         └── "historial" → HistoryView    (SIN ScrolledWindow propio)
  > ```
  > **Ni `FavoritesBar` ni `HistoryView` llevan `ScrolledWindow` propio.** Nunca
  > los dos a la vez.
  >
  > **4. Estado vacío — sí, correcto.** `Gtk.Label` centrado con "Sin historial".
  > Opcional: darle una clase CSS (p. ej. `.history-empty`) para que salga gris y
  > discreto.
  >
  > **Recordá:** no tocar `engine.vala`/`webview2.vala`/`webkit.vala`/
  > `factory.vala`/`core/plist.vala`/`bookmarks/*`/`history/model.vala`; no
  > persistencia (memoria); no deps nuevas; no tocar `SizeTrackingArea` ni la
  > estructura `main_box`; no cambiar el comportamiento del sidebar;
  > `FavoritesBar` sin reescribir.
  >
  > **Verificación crítica:** que el historial se llene **de verdad** y que las
  > visitas de ayer **no** aparezcan bajo "Hoy". Y que **no haya doble barra de
  > scroll**.
