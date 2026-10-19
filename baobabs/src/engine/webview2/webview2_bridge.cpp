#include "webview2_bridge.h"

#include <windows.h>
#include <wrl.h>
#ifdef __MINGW32__
#include "wrl_callback_shim.h"
#endif
#include <WebView2.h>
#include <string>
#include <locale>
#include <codecvt>
#include <cstdio>

using namespace Microsoft::WRL;

// Utilidad para convertir de UTF-8 a std::wstring (UTF-16)
static std::wstring utf8_to_wstring(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

// Utilidad para convertir de UTF-16 a std::string (UTF-8)
static std::string wstring_to_utf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

struct WebView2Bridge {
    ComPtr<ICoreWebView2Controller> webviewController;
    ComPtr<ICoreWebView2> webview;
    HWND hwnd;
    int offset_y;

    WebView2URLChangedCallback url_cb;
    void* url_user_data;
    WebView2TitleChangedCallback title_cb;
    void* title_user_data;
    WebView2InitReadyCallback ready_cb;
    void* ready_user_data;
    WebView2NavStartingCallback nav_starting_cb;
    void* nav_starting_user_data;
    WebView2NavCompletedCallback nav_completed_cb;
    void* nav_completed_user_data;
    WebView2HistoryChangedCallback history_changed_cb;
    void* history_changed_user_data;

    bool com_initialized;

    EventRegistrationToken sourceChangedToken = {};
    EventRegistrationToken titleChangedToken = {};
    EventRegistrationToken navStartingToken = {};
    EventRegistrationToken navCompletedToken = {};
    EventRegistrationToken historyChangedToken = {};
    EventRegistrationToken newWindowRequestedToken = {};

    WebView2Bridge()
        : hwnd(nullptr),
          offset_y(0),
          url_cb(nullptr),
          url_user_data(nullptr),
          title_cb(nullptr),
          title_user_data(nullptr),
          ready_cb(nullptr),
          ready_user_data(nullptr),
          nav_starting_cb(nullptr),
          nav_starting_user_data(nullptr),
          nav_completed_cb(nullptr),
          nav_completed_user_data(nullptr),
          history_changed_cb(nullptr),
          history_changed_user_data(nullptr),
          com_initialized(false) {}

    void UpdateBounds(int logical_w, int logical_h) {
        if (webviewController && hwnd) {
            RECT clientRect;
            GetClientRect(hwnd, &clientRect);

            int phys_width = clientRect.right - clientRect.left;
            int phys_height = clientRect.bottom - clientRect.top;

            int phys_offset_y = offset_y;
            if (logical_h > 0 && phys_height > 0) {
                double scale = static_cast<double>(phys_height) / static_cast<double>(logical_h);
                phys_offset_y = static_cast<int>(offset_y * scale);
            }

            RECT bounds;
            bounds.left = 0;
            bounds.top = phys_offset_y;
            bounds.right = phys_width;
            bounds.bottom = phys_height;
            webviewController->put_Bounds(bounds);
        }
    }

    void NotifyHistory() {
        if (history_changed_cb && webview) {
            BOOL canBack = FALSE;
            BOOL canForward = FALSE;
            webview->get_CanGoBack(&canBack);
            webview->get_CanGoForward(&canForward);
            history_changed_cb(canBack ? 1 : 0, canForward ? 1 : 0, history_changed_user_data);
        }
    }
};

extern "C" {

WebView2Bridge* webview2_bridge_new(void) {
    return new WebView2Bridge();
}

void webview2_bridge_initialize(WebView2Bridge* bridge,
                                void* hwnd_ptr,
                                int offset_y,
                                const char* user_data_dir,
                                WebView2InitReadyCallback ready_cb,
                                void* user_data) {
    if (!bridge) {
        fprintf(stderr, "[WebView2 Bridge] ERROR: initialize called with NULL bridge!\n");
        fflush(stderr);
        return;
    }
    bridge->hwnd = static_cast<HWND>(hwnd_ptr);
    bridge->offset_y = offset_y;
    bridge->ready_cb = ready_cb;
    bridge->ready_user_data = user_data;

    fprintf(stderr, "[WebView2 Bridge] initialize called with HWND=%p, offset_y=%d, profile=%s\n",
            bridge->hwnd, offset_y, user_data_dir ? user_data_dir : "(default)");
    fflush(stderr);

    // Inicializar COM en el hilo de interfaz (STA)
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    fprintf(stderr, "[WebView2 Bridge] CoInitializeEx result: 0x%08lX\n", (unsigned long)hr);
    fflush(stderr);
    if (SUCCEEDED(hr)) {
        bridge->com_initialized = true;
    }

    std::wstring wUserDataFolder;
    if (user_data_dir && user_data_dir[0] != '\0') {
        wUserDataFolder = utf8_to_wstring(user_data_dir);
    }
    LPCWSTR pUserDataFolder = wUserDataFolder.empty() ? nullptr : wUserDataFolder.c_str();

    // 1. Crear el entorno CoreWebView2
    HRESULT hrEnvCall = CreateCoreWebView2EnvironmentWithOptions(nullptr, pUserDataFolder, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [bridge](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                fprintf(stderr, "[WebView2 Bridge] Environment callback: result=0x%08lX, env=%p\n", (unsigned long)result, env);
                fflush(stderr);
                if (FAILED(result) || !env) {
                    fprintf(stderr, "[WebView2 Bridge] ERROR: Failed to create Environment! HRESULT: 0x%08lX\n", (unsigned long)result);
                    fflush(stderr);
                    return E_FAIL;
                }

                // 2. Crear el controlador CoreWebView2
                HRESULT hrCtrlCall = env->CreateCoreWebView2Controller(bridge->hwnd,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [bridge](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                            fprintf(stderr, "[WebView2 Bridge] Controller callback: result=0x%08lX, controller=%p\n", (unsigned long)result, controller);
                            fflush(stderr);
                            if (FAILED(result) || !controller) {
                                fprintf(stderr, "[WebView2 Bridge] ERROR: Failed to create Controller! HRESULT: 0x%08lX\n", (unsigned long)result);
                                fflush(stderr);
                                return E_FAIL;
                            }

                            bridge->webviewController = controller;
                            controller->get_CoreWebView2(&bridge->webview);

                            // Ajustes de configuración del motor
                            ComPtr<ICoreWebView2Settings> settings;
                            if (SUCCEEDED(bridge->webview->get_Settings(&settings)) && settings) {
                                settings->put_IsScriptEnabled(TRUE);
                                settings->put_AreDefaultScriptDialogsEnabled(TRUE);
                                settings->put_IsWebMessageEnabled(TRUE);
                            }

                            // Evento: Cambio de URL fuente
                            bridge->webview->add_SourceChanged(
                                Callback<ICoreWebView2SourceChangedEventHandler>(
                                    [bridge](ICoreWebView2* sender, ICoreWebView2SourceChangedEventArgs* args) -> HRESULT {
                                        if (bridge->url_cb) {
                                            LPWSTR uri = nullptr;
                                            sender->get_Source(&uri);
                                            if (uri) {
                                                std::string utf8_uri = wstring_to_utf8(uri);
                                                bridge->url_cb(utf8_uri.c_str(), bridge->url_user_data);
                                                CoTaskMemFree(uri);
                                            }
                                        }
                                        bridge->NotifyHistory();
                                        return S_OK;
                                    }).Get(), &bridge->sourceChangedToken);

                            // Evento: Cambio de título del documento
                            bridge->webview->add_DocumentTitleChanged(
                                Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
                                    [bridge](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                                        if (bridge->title_cb) {
                                            LPWSTR title = nullptr;
                                            sender->get_DocumentTitle(&title);
                                            if (title) {
                                                std::string utf8_title = wstring_to_utf8(title);
                                                bridge->title_cb(utf8_title.c_str(), bridge->title_user_data);
                                                CoTaskMemFree(title);
                                            }
                                        }
                                        return S_OK;
                                    }).Get(), &bridge->titleChangedToken);

                            // Evento: Inicio de navegación
                            bridge->webview->add_NavigationStarting(
                                Callback<ICoreWebView2NavigationStartingEventHandler>(
                                    [bridge](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                        if (bridge->nav_starting_cb) {
                                            LPWSTR uri = nullptr;
                                            args->get_Uri(&uri);
                                            if (uri) {
                                                std::string utf8_uri = wstring_to_utf8(uri);
                                                bridge->nav_starting_cb(utf8_uri.c_str(), bridge->nav_starting_user_data);
                                                CoTaskMemFree(uri);
                                            }
                                        }
                                        bridge->NotifyHistory();
                                        return S_OK;
                                    }).Get(), &bridge->navStartingToken);

                            // Evento: Fin de navegación
                            bridge->webview->add_NavigationCompleted(
                                Callback<ICoreWebView2NavigationCompletedEventHandler>(
                                    [bridge](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                                        if (bridge->nav_completed_cb) {
                                            BOOL isSuccess = FALSE;
                                            args->get_IsSuccess(&isSuccess);
                                            const char* err_str = isSuccess ? nullptr : "Navigation failed";
                                            bridge->nav_completed_cb(isSuccess ? 1 : 0, err_str, bridge->nav_completed_user_data);
                                        }
                                        bridge->NotifyHistory();
                                        return S_OK;
                                    }).Get(), &bridge->navCompletedToken);

                            // Evento: Cambio en historial (Back/Forward)
                            bridge->webview->add_HistoryChanged(
                                Callback<ICoreWebView2HistoryChangedEventHandler>(
                                    [bridge](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                                        bridge->NotifyHistory();
                                        return S_OK;
                                    }).Get(), &bridge->historyChangedToken);

                            // Evento: Enlaces que solicitan ventana nueva (target="_blank")
                            bridge->webview->add_NewWindowRequested(
                                Callback<ICoreWebView2NewWindowRequestedEventHandler>(
                                    [bridge](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
                                        LPWSTR uri = nullptr;
                                        args->get_Uri(&uri);
                                        if (uri) {
                                            sender->Navigate(uri);
                                            CoTaskMemFree(uri);
                                        }
                                        args->put_Handled(TRUE);
                                        return S_OK;
                                    }).Get(), &bridge->newWindowRequestedToken);

                            // Bounds iniciales adaptados al tamaño de la ventana
                            bridge->UpdateBounds(0, 0);

                            // Visibilidad
                            controller->put_IsVisible(TRUE);

                            fprintf(stderr, "[WebView2 Bridge] Initialization SUCCESSFUL! Controller is visible.\n");
                            fflush(stderr);

                            if (bridge->ready_cb) {
                                bridge->ready_cb(bridge->ready_user_data);
                            }

                            return S_OK;
                        }).Get());

                if (FAILED(hrCtrlCall)) {
                    fprintf(stderr, "[WebView2 Bridge] CreateCoreWebView2Controller call returned: 0x%08lX\n", (unsigned long)hrCtrlCall);
                    fflush(stderr);
                }
                return S_OK;
            }).Get());

    if (FAILED(hrEnvCall)) {
        fprintf(stderr, "[WebView2 Bridge] CreateCoreWebView2EnvironmentWithOptions call returned: 0x%08lX\n", (unsigned long)hrEnvCall);
        fflush(stderr);
    }
}

void webview2_bridge_free(WebView2Bridge* bridge) {
    if (bridge) {
        if (bridge->webview) {
            bridge->webview->remove_SourceChanged(bridge->sourceChangedToken);
            bridge->webview->remove_DocumentTitleChanged(bridge->titleChangedToken);
            bridge->webview->remove_NavigationStarting(bridge->navStartingToken);
            bridge->webview->remove_NavigationCompleted(bridge->navCompletedToken);
            bridge->webview->remove_HistoryChanged(bridge->historyChangedToken);
            bridge->webview->remove_NewWindowRequested(bridge->newWindowRequestedToken);
            bridge->webview = nullptr;
        }
        if (bridge->webviewController) {
            bridge->webviewController->Close();
            bridge->webviewController = nullptr;
        }
        if (bridge->com_initialized) {
            CoUninitialize();
        }
        delete bridge;
    }
}

void webview2_bridge_set_url_changed_callback(WebView2Bridge* bridge, WebView2URLChangedCallback cb, void* user_data) {
    if (bridge) {
        bridge->url_cb = cb;
        bridge->url_user_data = user_data;
    }
}

void webview2_bridge_set_title_changed_callback(WebView2Bridge* bridge, WebView2TitleChangedCallback cb, void* user_data) {
    if (bridge) {
        bridge->title_cb = cb;
        bridge->title_user_data = user_data;
    }
}

void webview2_bridge_set_nav_starting_callback(WebView2Bridge* bridge, WebView2NavStartingCallback cb, void* user_data) {
    if (bridge) {
        bridge->nav_starting_cb = cb;
        bridge->nav_starting_user_data = user_data;
    }
}

void webview2_bridge_set_nav_completed_callback(WebView2Bridge* bridge, WebView2NavCompletedCallback cb, void* user_data) {
    if (bridge) {
        bridge->nav_completed_cb = cb;
        bridge->nav_completed_user_data = user_data;
    }
}

void webview2_bridge_set_history_changed_callback(WebView2Bridge* bridge, WebView2HistoryChangedCallback cb, void* user_data) {
    if (bridge) {
        bridge->history_changed_cb = cb;
        bridge->history_changed_user_data = user_data;
    }
}

void webview2_bridge_set_callbacks(WebView2Bridge* bridge,
                                   WebView2URLChangedCallback url_cb,
                                   void* url_user_data,
                                   WebView2TitleChangedCallback title_cb,
                                   void* title_user_data) {
    if (bridge) {
        bridge->url_cb = url_cb;
        bridge->url_user_data = url_user_data;
        bridge->title_cb = title_cb;
        bridge->title_user_data = title_user_data;
    }
}

void webview2_bridge_navigate(WebView2Bridge* bridge, const char* url) {
    fprintf(stderr, "[WebView2 Bridge] navigate requested: %s\n", url ? url : "(null)");
    fflush(stderr);
    if (bridge && bridge->webview && url) {
        std::wstring wurl = utf8_to_wstring(url);
        HRESULT hr = bridge->webview->Navigate(wurl.c_str());
        fprintf(stderr, "[WebView2 Bridge] webview->Navigate returned: 0x%08lX\n", (unsigned long)hr);
        fflush(stderr);
    }
}

void webview2_bridge_reload(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        bridge->webview->Reload();
    }
}

void webview2_bridge_stop(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        bridge->webview->Stop();
    }
}

void webview2_bridge_go_back(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        bridge->webview->GoBack();
    }
}

void webview2_bridge_go_forward(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        bridge->webview->GoForward();
    }
}

int webview2_bridge_can_go_back(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        BOOL canBack = FALSE;
        bridge->webview->get_CanGoBack(&canBack);
        return canBack ? 1 : 0;
    }
    return 0;
}

int webview2_bridge_can_go_forward(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        BOOL canFwd = FALSE;
        bridge->webview->get_CanGoForward(&canFwd);
        return canFwd ? 1 : 0;
    }
    return 0;
}

void webview2_bridge_execute_script(WebView2Bridge* bridge, const char* js) {
    if (bridge && bridge->webview && js) {
        std::wstring wjs = utf8_to_wstring(js);
        bridge->webview->ExecuteScript(wjs.c_str(), nullptr);
    }
}

void webview2_bridge_set_zoom(WebView2Bridge* bridge, double zoom) {
    if (bridge && bridge->webviewController) {
        bridge->webviewController->put_ZoomFactor(zoom);
    }
}

double webview2_bridge_get_zoom(WebView2Bridge* bridge) {
    if (bridge && bridge->webviewController) {
        double zoom = 1.0;
        if (SUCCEEDED(bridge->webviewController->get_ZoomFactor(&zoom))) {
            return zoom;
        }
    }
    return 1.0;
}

void webview2_bridge_focus(WebView2Bridge* bridge) {
    if (bridge && bridge->webviewController) {
        bridge->webviewController->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
    }
}

void webview2_bridge_resize(WebView2Bridge* bridge, int width, int height) {
    if (bridge) {
        bridge->UpdateBounds(width, height);
    }
}

void webview2_bridge_set_offset_y(WebView2Bridge* bridge, int offset_y) {
    if (bridge) {
        bridge->offset_y = offset_y;
    }
}

} // extern "C"
