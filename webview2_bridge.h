#ifndef WEBVIEW2_BRIDGE_H
#define WEBVIEW2_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Estructura opaca para representar el puente
typedef struct WebView2Bridge WebView2Bridge;

// Callbacks que Vala implementará
typedef void (*WebView2URLChangedCallback)(const char* url, void* user_data);
typedef void (*WebView2TitleChangedCallback)(const char* title, void* user_data);
typedef void (*WebView2InitReadyCallback)(void* user_data);

// Crea una nueva instancia del puente.
// hwnd: El HWND de la ventana GTK4, convertido a puntero genérico (o intptr_t).
WebView2Bridge* webview2_bridge_new();

// Inicializa el WebView2 asíncronamente en el HWND dado.
// hwnd: HWND (void*) del widget Gtk.
// offset_y: Espacio reservado arriba (para la barra de GTK).
// ready_cb: Callback que se ejecuta cuando el WebView2 está listo.
// user_data: Puntero de contexto.
void webview2_bridge_initialize(WebView2Bridge* bridge, void* hwnd, int offset_y, WebView2InitReadyCallback ready_cb, void* user_data);

// Destruye el puente y libera los recursos.
void webview2_bridge_free(WebView2Bridge* bridge);

// Establece los callbacks de eventos.
// Vala generará 5 argumentos: bridge, url_cb, url_user_data, title_cb, title_user_data
void webview2_bridge_set_callbacks(WebView2Bridge* bridge,
                                   WebView2URLChangedCallback url_cb,
                                   void* url_user_data,
                                   WebView2TitleChangedCallback title_cb,
                                   void* title_user_data);

// Navegación
void webview2_bridge_navigate(WebView2Bridge* bridge, const char* url);
void webview2_bridge_reload(WebView2Bridge* bridge);
void webview2_bridge_go_back(WebView2Bridge* bridge);
void webview2_bridge_go_forward(WebView2Bridge* bridge);

// Redimensionar el WebView2 (por ejemplo, cuando la ventana GTK cambia de tamaño).
// ancho y alto son las dimensiones totales, el puente internamente aplicará el offset_y a la posición Y y restará de alto si es necesario.
void webview2_bridge_resize(WebView2Bridge* bridge, int width, int height);

#ifdef __cplusplus
}
#endif

#endif // WEBVIEW2_BRIDGE_H
