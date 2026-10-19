#include "webview2_bridge.h"

#include <windows.h>
#include <wrl.h>
#include <WebView2.h>
#include <string>
#include <locale>
#include <codecvt>

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
    bool com_initialized;

    EventRegistrationToken sourceChangedToken = {};
    EventRegistrationToken titleChangedToken = {};

    WebView2Bridge() : hwnd(nullptr), offset_y(0), url_cb(nullptr), url_user_data(nullptr), title_cb(nullptr), title_user_data(nullptr), ready_cb(nullptr), ready_user_data(nullptr), com_initialized(false) {}

    void UpdateBounds(int width, int height) {
        if (webviewController) {
            RECT bounds;
            bounds.left = 0;
            bounds.top = offset_y;
            bounds.right = width;
            bounds.bottom = height;
            webviewController->put_Bounds(bounds);
        }
    }
};

extern "C" {

WebView2Bridge* webview2_bridge_new() {
    return new WebView2Bridge();
}

void webview2_bridge_initialize(WebView2Bridge* bridge, void* hwnd_ptr, int offset_y, WebView2InitReadyCallback ready_cb, void* user_data) {
    if (!bridge) return;
    bridge->hwnd = static_cast<HWND>(hwnd_ptr);
    bridge->offset_y = offset_y;
    bridge->ready_cb = ready_cb;
    bridge->ready_user_data = user_data;

    // Inicializar COM en el hilo principal
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr)) {
        bridge->com_initialized = true;
    }

    // 1. Create Environment
    CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [bridge](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                if (FAILED(result) || !env) return E_FAIL;

                // 2. Create Controller
                env->CreateCoreWebView2Controller(bridge->hwnd,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [bridge](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                            if (FAILED(result) || !controller) return E_FAIL;

                            bridge->webviewController = controller;
                            controller->get_CoreWebView2(&bridge->webview);

                            // Registrar eventos
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
                                        return S_OK;
                                    }).Get(), &bridge->sourceChangedToken);

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

                            // Obtener tamaño actual para los bounds iniciales (opcional)
                            RECT clientRect;
                            GetClientRect(bridge->hwnd, &clientRect);
                            bridge->UpdateBounds(clientRect.right, clientRect.bottom);

                            if (bridge->ready_cb) {
                                bridge->ready_cb(bridge->ready_user_data);
                            }

                            return S_OK;
                        }).Get());
                return S_OK;
            }).Get());
}

void webview2_bridge_free(WebView2Bridge* bridge) {
    if (bridge) {
        if (bridge->webview) {
            bridge->webview->remove_SourceChanged(bridge->sourceChangedToken);
            bridge->webview->remove_DocumentTitleChanged(bridge->titleChangedToken);
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
    if (bridge && bridge->webview) {
        std::wstring wurl = utf8_to_wstring(url);
        bridge->webview->Navigate(wurl.c_str());
    }
}

void webview2_bridge_reload(WebView2Bridge* bridge) {
    if (bridge && bridge->webview) {
        bridge->webview->Reload();
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

void webview2_bridge_resize(WebView2Bridge* bridge, int width, int height) {
    if (bridge) {
        bridge->UpdateBounds(width, height);
    }
}

} // extern "C"
