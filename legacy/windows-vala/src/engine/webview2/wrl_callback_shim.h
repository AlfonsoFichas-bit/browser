#pragma once
#ifdef __MINGW32__

// Shim MinGW: MSYS2 no publica wrl/event.h (Microsoft::WRL::Callback), pero
// el SDK WebView2 usa ese patrón Callback<Iface>(lambda) para handlers async.
// Este shim replica la firma exacta: devuelve ComPtr<TInterface> apuntando a
// un objeto COM que delega Invoke en la lambda.
#include <wrl.h>
#include <utility>

namespace Microsoft { namespace WRL {

template <typename TInterface, typename TInvokeSig, typename TLambda>
class CallbackShim;

template <typename TInterface, typename TLambda, typename... Args>
class CallbackShim<TInterface, HRESULT (STDMETHODCALLTYPE TInterface::*)(Args...), TLambda>
    : public TInterface {
public:
    explicit CallbackShim(TLambda&& fn) : fn_(std::move(fn)) {}
    virtual ~CallbackShim() = default;

    // El runtime de WebView2 solo invoca Invoke/Release sobre estos
    // manejadores (no hace QI), asi que aceptamos cualquier IID.
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (ppv == nullptr) return E_POINTER;
        *ppv = static_cast<TInterface*>(this);
        AddRef();
        return S_OK;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override {
        return (ULONG)InterlockedIncrement(&refcount_);
    }

    IFACEMETHODIMP_(ULONG) Release() override {
        ULONG r = (ULONG)InterlockedDecrement(&refcount_);
        if (r == 0) delete this;
        return r;
    }

    HRESULT STDMETHODCALLTYPE Invoke(Args... args) override { return fn_(args...); }

private:
    TLambda fn_;
    LONG refcount_ = 1;
};

template <typename TInterface, typename TLambda>
ComPtr<TInterface> Callback(TLambda&& fn) {
    using InvokeSig = decltype(&TInterface::Invoke);
    return ComPtr<TInterface>(
        new CallbackShim<TInterface, InvokeSig, TLambda>(std::forward<TLambda>(fn)));
}

}} // namespace Microsoft::WRL

#endif // __MINGW32__
