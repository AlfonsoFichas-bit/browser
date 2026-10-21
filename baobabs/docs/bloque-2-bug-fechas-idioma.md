# Bloque 2 — Encabezados de fecha en español (reporte de bug a Jules)

**Fecha:** 2026-10-20
**Estado:** reporte a entregar a Jules, pendiente de ajuste en la misma rama
**Rama:** `feature-history-and-sidebar-segmentation-1298054787794286302` (commit `8828af3`)
**Brief original:** `baobabs/docs/bloque-2-historial-sidebar.md`
**Respuestas previas:** `baobabs/docs/bloque-2-respuesta-a-jules.md`

---

## Contexto

El commit `8828af3` está **impecable** salvo **un bug**, detectado por el usuario
al ver la app en su máquina (que tiene más de un idioma configurado: `es-BO` y
`es-ES`).

El usuario reportó: **"veo la ventana en diferentes idiomas"**.

La causa está en **una sola línea**: `history_view.vala:79`.

```vala
group_title = visited.format("%A, %d de %B");
```

**El problema:** el `de` está hardcodeado en español, pero `%A` (día) y `%B`
(mes) los resuelve el **locale del sistema**. Si el sistema no está en español,
la cadena sale **mezclada**.

---

## Reproducción (runtime, verificada)

Se compiló y ejecutó un programa aislado, forzando el locale del proceso por
variable de entorno (`LANG`), que es lo que sí afecta a GLib en este entorno:

| Fecha | Con locale español | Con locale inglés |
|---|---|---|
| 2026-10-13 | `Martes, 13 de octubre` | **`Tuesday, 13 de October`** ❌ |
| 2026-01-04 | `Domingo, 04 de enero` | **`Sunday, 04 de January`** ❌ |
| 2026-09-01 | `Martes, 01 de septiembre` | **`Tuesday, 01 de September`** ❌ |

Día de la semana en inglés + conector en español + mes en inglés. **Un híbrido.**

**Agravante:** `Hoy` y `Ayer` están hardcodeados en español en el código (no
pasan por `format`). Así que en un sistema no hispanohablante se vería, en la
misma lista:

```
Hoy
Tuesday, 13 de October
Ayer
```

**Nota:** esto **no es un fallo de la implementación**. El brief pedía
literalmente `"%A, %d de %B"` — Jules lo implementó al pie de la letra. El error
fue de la **especificación**.

---

## Solución (opción A): formato español determinista, sin depender del locale

**Objetivo:** los encabezados de fecha deben salir **siempre en español**,
independientemente del idioma del sistema.

**Verificado en runtime** (con locale inglés forzado, la tabla sigue en español):

| Fecha | Resultado |
|---|---|
| 2026-10-13 | `Martes, 13 de octubre` ✅ |
| 2026-01-04 | `Domingo, 4 de enero` ✅ |
| 2026-09-01 | `Martes, 1 de septiembre` ✅ |
| 2026-12-31 | `Jueves, 31 de diciembre` ✅ |

**Ventaja adicional:** el `%d` del locale inglés produce `04`, `01` (con cero a
la izquierda). Con la tabla se obtiene `4`, `1`, más natural.

### Mapeo del día de la semana — verificado

`GLib.DateTime.get_day_of_week()` devuelve **1 = lunes … 7 = domingo**.
El índice correcto en el arreglo es **`wd % 7`**:

```
wd=1 -> idx=1 -> Lunes      ✅
wd=7 -> idx=0 -> Domingo    ✅
```

Probado para los 7 días de la semana. La fórmula `% 7` es correcta.

---

## Alcance del ajuste

**Sólo `src/ui/history_view.vala`.** Nada más. No hay que tocar CSS, meson,
motor ni ningún otro fichero.

### Cambios

1. Añadir dos arreglos constantes (días y meses) en español.
2. Sustituir la línea 79 (`visited.format("%A, %d de %B")`) por una llamada a un
   helper propio.
3. El helper recibe el `GLib.DateTime` y devuelve `"<Día>, <d> de <mes>"`, con
   la primera letra en mayúscula (que de hecho ya sale así porque los nombres de
   la tabla van capitalizados).

### Nota sobre la capitalización existente

El código actual capitaliza la primera letra **después** de `format`. Con la
tabla, **sobra**: los nombres ya van capitalizados en la tabla. Eliminar ese
bloque (es código muerto). Verificado: capitalizar `%A` que ya devuelve
`Martes` no cambia nada.

---

## Restricciones (recordatorio)

- **No tocar** nada fuera de `src/ui/history_view.vala`.
- **No** tocar `engine.vala`, `webview2.vala`, `webkit.vala`, `factory.vala`,
  `core/plist.vala`, `bookmarks/*`, `history/model.vala`.
- **No** tocar la estructura `main_box` ni el sidebar.
- **No** cambiar `Hoy` / `Ayer` (ya están en español y son correctos).
- **No** introducir gettext/i18n (fuera de alcance del proyecto por ahora).
- **No** tocar CSS.

---

## Verificación requerida

- `meson compile` verde y `meson test` **2/2**.
- **El bug está resuelto**: con el sistema en un idioma no español, los
  encabezados de fecha **siguen saliendo en español** (`Martes, 13 de octubre`),
  **no** `Tuesday, 13 de October`.
- `Hoy` y `Ayer` siguen funcionando.
- La agrupación sigue por fecha de calendario (no romper lo que ya funciona).
- Sin `CRITICAL`/`WARNING` nuevos.

---

## Referencias

- `baobabs/docs/bloque-2-historial-sidebar.md` — brief de este bloque.
- `baobabs/docs/bloque-2-respuesta-a-jules.md` — respuestas previas.
- `safari/HABITAT.md` §1.3 y §2.1 — esquema de historial.

---

## Anexo — Mensaje paste-ready para Jules

> **Tu commit está excelente** salvo **un bug**, detectado por el usuario al ver
> la app en su máquina (que tiene varios idiomas configurados). El reporte fue:
> "veo la ventana en diferentes idiomas".
>
> **La causa es una sola línea** — `history_view.vala:79`:
> ```vala
> group_title = visited.format("%A, %d de %B");
> ```
> El **`de` está hardcodeado en español**, pero **`%A` (día) y `%B` (mes) los
> traduce el locale del sistema**. Si el sistema no está en español, sale
> **mezclado**. Verificado en runtime:
>
> | Con locale español | Con locale inglés |
> |---|---|
> | `Martes, 13 de octubre` | **`Tuesday, 13 de October`** ❌ |
> | `Domingo, 04 de enero` | **`Sunday, 04 de January`** ❌ |
>
> **No es culpa tuya**: el brief pedía literalmente `"%A, %d de %B"`. El error
> fue de la especificación. Ahora hay que corregirlo.
>
> **Agravante:** `Hoy` y `Ayer` están hardcodeados en español, así que en un
> sistema en inglés se vería, en la misma lista:
> ```
> Hoy
> Tuesday, 13 de October
> Ayer
> ```
>
> **Ajuste pedido (opción A): formato español determinista, sin depender del
> locale.** Sólo hay que tocar **`src/ui/history_view.vala`**, nada más.
>
> 1. Añade dos arreglos constantes, en español:
>    ```vala
>    private const string[] DIAS = {
>        "Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"
>    };
>    private const string[] MESES = {
>        "enero","febrero","marzo","abril","mayo","junio",
>        "julio","agosto","septiembre","octubre","noviembre","diciembre"
>    };
>    ```
>
> 2. Sustituye la línea 79 por un helper propio:
>    ```vala
>    private string fecha_en_espanol(GLib.DateTime d) {
>        int y, m, dd;
>        d.get_ymd(out y, out m, out dd);
>        int wd = d.get_day_of_week();   // 1 = lunes ... 7 = domingo
>        return "%s, %d de %s".printf(DIAS[wd % 7], dd, MESES[m - 1]);
>    }
>    ```
>    Y en el bucle: `group_title = fecha_en_espanol(visited);`
>
> 3. **Elimina el bloque de capitalización** que hay después (el que hace
>    `substring(0,1).up()`): con la tabla **sobra**, porque los nombres ya van
>    capitalizados. Es código muerto.
>
> **Detalles verificados por mí (no los asumas):**
> - `get_day_of_week()` devuelve **1 = lunes … 7 = domingo**; el índice correcto
>   es **`wd % 7`**. Probado para los 7 días: `wd=1 → Lunes`, `wd=7 → Domingo`.
> - Este helper da siempre español, **incluso con locale inglés**: verificado
>   `Martes, 13 de octubre`, `Domingo, 4 de enero`, `Jueves, 31 de diciembre`.
> - Ventaja extra: el `%d` del locale inglés produce `04`/`01` (con cero a la
>   izquierda); con la tabla sale `4`/`1`, más natural.
>
> **Restricciones:** **no toques nada fuera de `src/ui/history_view.vala`**; no
> cambies `Hoy`/`Ayer` (ya están bien); no introduzcas gettext/i18n; no toques
> CSS, motor, `main_box` ni el sidebar.
>
> **Verificación:** `meson compile` verde y `meson test` **2/2**; los encabezados
> de fecha siguen en español aunque el sistema esté en otro idioma; `Hoy`/`Ayer`
> siguen bien; la agrupación por fecha de calendario no se rompe; sin
> `CRITICAL`/`WARNING` nuevos.
