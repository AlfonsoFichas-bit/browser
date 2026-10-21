# Decisión de alcance — Extensiones de navegador

**Fecha:** 2026-10-20
**Estado:** decisión tomada, documentada para no repetir la investigación
**Ámbito:** tanto Windows (WebView2) como Linux (WebKitGTK)

---

## Decisión

**Habitat no soportará extensiones de navegador.** No está en la hoja de ruta y no
se prevé implementarlo.

No es un olvido ni una deuda pendiente: es una **consecuencia directa de la
arquitectura elegida**.

---

## Motivo: no es un problema del motor

Es tentador pensar que "cambiando de motor" se arreglaría. **Es incorrecto.** El
motor (Blink, WebKit, Gecko) **no opina sobre extensiones**: es el renderizador
de HTML. La capa de extensiones vive **por encima**, en el navegador.

### Estado por plataforma

| | Windows | Linux |
|---|---|---|
| Motor | WebView2 | WebKitGTK |
| Extensiones | ❌ **no existen** en la API | ✅ **sí** (Web Extensions, Manifest V2/V3, desde 2.46) |
| Motivo | carencia de la API pública de WebView2 | modelo **distinto**, no unificado con WebView2 |

**El obstáculo es doble:**
- En Windows, la API **falta** (Microsoft no la expone en `ICoreWebView2`).
- En Linux, **existe** pero con otro modelo.

En ambos casos el resultado para Habitat es el mismo: **no hay una API común**
que se pueda usar sobre el motor intercambiable. Unificar eso rompería la
promesa central del proyecto (`factory.vala`: misma app, dos motores).

*(Nota: `meson.build` declara `webkitgtk-6.0 >= 2.42`; las extensiones llegaron
en 2.46, así que ni el mínimo declarado las garantiza.)*

---

## Evidencia: el motor no determina las extensiones

Cuatro casos que lo demuestran:

| Navegador | Motor | ¿Extensiones de Chrome? | Por qué |
|---|---|---|---|
| **Brave / Opera / Edge** | Blink | ✅ sí | Adoptan **Chromium entero** y lo modifican |
| **Waterfox** | Gecko | ✅ sí | Es Firefox modificado + capa de compatibilidad |
| **Electron** | Blink | ❌ no | Es "motor para embeber", no navegador completo |
| **Habitat** (WebView2) | Blink | ❌ no | Igual que Electron: sólo el motor |

**Electron es el caso decisivo:** usa Blink, el mismo motor que Chrome, y **no**
tiene extensiones de Chrome. Prueba que el motor es irrelevante para esto.

### La distinción de fondo

```
Chrome / Brave / Opera / Edge  ->  el navegador COMPLETO (modificado)
Electron / WebView2 / Habitat  ->  SÓLO el motor, para embeber
```

Los navegadores con extensiones las tienen porque **traen Chromium completo**
(motor + gestor de extensiones + permisos + almacén + sandbox + validación de
firmas + UI, ~15 años de trabajo). Habitat usa el motor **suelto, a propósito**.

---

## Qué costaría tener extensiones

No es "cambiar de motor". Sería **adoptar Chromium entero**:

| | Habitat (WebView2) | Fork de Chromium |
|---|---|---|
| Descarga | pocos MB | **~150–300 MB** |
| Actualizaciones | las de Windows | **responsabilidad propia** |
| Seguridad | parchea Microsoft | **parchear uno mismo**, cada ~4 semanas |
| Motor intercambiable | ✅ sí | ❌ no (casado con Chromium) |
| Linux nativo (GTK4/WebKitGTK) | ✅ sí | ❌ no |

**Eso contradice la razón de ser del proyecto:** navegador pequeño, dos motores,
Linux nativo. La parte cara no son las extensiones — es el Chromium completo con
su ciclo de seguridad perpetuo.

---

## Camino alternativo (si algún día se quisiera)

No haría falta cambiar de motor. Sería **escribir la capa propia** sobre la API
existente:

- `engine.execute_script` ya existe (inyección de JS).
- Recursos empaquetados en GResource.
- Resultado: **"extensiones de Habitat"**, no de Chrome.

Viable y verificable en Windows. Pero es **un proyecto propio**, no un cambio de
dependencia. **No está planificado.**

---

## Nota de fidelidad

Safari 5.1 (el objetivo del clon) **sí tenía extensiones**, pero con un modelo
**propietario**: paquetes `.safariextz`, validados por `Safari.dll`, ajenos a
Manifest V2/V3. Es decir: ni el original era estándar. Las extensiones no son
una regresión frente a Safari 5.1, sino una decisión de alcance consciente.

---

## Referencias

- `baobabs/src/engine/factory.vala` — selección de motor (`#if WINDOWS`).
- `baobabs/meson.build` — versiones mínimas de `webkitgtk` (2.42) y deps.
- `safari/HABITAT.md` — análisis de Safari 5.1.
