package com.urbanwarriors.app;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.util.Log;

import androidx.annotation.NonNull;

import com.stripe.stripeterminal.Terminal;
import com.stripe.stripeterminal.external.callable.Callback;
import com.stripe.stripeterminal.external.callable.Cancelable;
import com.stripe.stripeterminal.external.callable.ConnectionTokenCallback;
import com.stripe.stripeterminal.external.callable.ConnectionTokenProvider;
import com.stripe.stripeterminal.external.callable.PaymentIntentCallback;
import com.stripe.stripeterminal.external.callable.ReaderCallback;
import com.stripe.stripeterminal.external.callable.TapToPayReaderListener;
import com.stripe.stripeterminal.external.callable.TerminalListener;
import com.stripe.stripeterminal.external.models.CollectPaymentIntentConfiguration;
import com.stripe.stripeterminal.external.models.ConfirmPaymentIntentConfiguration;
import com.stripe.stripeterminal.external.models.ConnectionConfiguration;
import com.stripe.stripeterminal.external.models.ConnectionStatus;
import com.stripe.stripeterminal.external.models.DisconnectReason;
import com.stripe.stripeterminal.external.models.DiscoveryConfiguration;
import com.stripe.stripeterminal.external.models.EasyConnectConfiguration;
import com.stripe.stripeterminal.external.models.PaymentIntent;
import com.stripe.stripeterminal.external.models.PaymentStatus;
import com.stripe.stripeterminal.external.models.Reader;
import com.stripe.stripeterminal.external.models.TapUseCase;
import com.stripe.stripeterminal.external.models.TerminalException;
import com.stripe.stripeterminal.log.LogLevel;

import org.json.JSONObject;

public final class KombaxTerminalManager implements TerminalListener, TapToPayReaderListener {
    public interface EventSink { void emit(String eventName, JSONObject detail); }

    private static final String TAG = "KombaxTerminal";
    private final Context appContext;
    private final EventSink sink;
    private volatile String connectionToken = "";
    private volatile ConnectionTokenCallback pendingTokenCallback;
    private String saleId = "";
    private String clientSecret = "";
    private String locationId = "";
    private String subjectType = "";
    private String subjectId = "";

    public KombaxTerminalManager(Context context, EventSink sink) {
        this.appContext = context.getApplicationContext();
        this.sink = sink;
    }

    private final ConnectionTokenProvider tokenProvider = this::requestConnectionToken;

    private void requestConnectionToken(ConnectionTokenCallback callback) {
        String token = connectionToken;
        connectionToken = "";
        if (token != null && token.startsWith("pst_")) {
            callback.onSuccess(token);
            return;
        }
        pendingTokenCallback = callback;
        try {
            JSONObject detail = new JSONObject();
            detail.put("request_id", java.util.UUID.randomUUID().toString());
            detail.put("subject_type", subjectType);
            detail.put("subject_id", subjectId);
            sink.emit("kombax-terminal-token-request", detail);
        } catch (Exception error) {
            Log.e(TAG, "Could not request a refreshed connection token", error);
        }
    }

    public synchronized void provideConnectionToken(String token) {
        ConnectionTokenCallback callback = pendingTokenCallback;
        pendingTokenCallback = null;
        if (callback != null && token != null && token.startsWith("pst_")) callback.onSuccess(token);
        else if (token != null && token.startsWith("pst_")) connectionToken = token;
    }

    public synchronized void start(String payloadJson) {
        try {
            JSONObject payload = new JSONObject(payloadJson);
            saleId = payload.optString("sale_id", "");
            clientSecret = payload.optString("client_secret", "");
            locationId = payload.optString("location_id", "");
            subjectType = payload.optString("subject_type", "");
            subjectId = payload.optString("subject_id", "");
            connectionToken = payload.optString("connection_token", "");
            if (saleId.isEmpty() || !clientSecret.startsWith("pi_") || !clientSecret.contains("_secret_") || !locationId.startsWith("tml_") || !connectionToken.startsWith("pst_")) {
                fail("INVALID_TERMINAL_PAYLOAD", "KOMBAX received an incomplete Tap to Pay payload.");
                return;
            }
            ensureInitialized();
            Terminal terminal = Terminal.getInstance();
            if (terminal.getConnectionStatus() == ConnectionStatus.CONNECTED) {
                terminal.disconnectReader(new Callback() {
                    @Override public void onSuccess() { connectAndProcess(); }
                    @Override public void onFailure(@NonNull TerminalException e) { fail("DISCONNECT_FAILED", e.getErrorMessage()); }
                });
            } else connectAndProcess();
        } catch (Exception error) {
            fail("TERMINAL_START_FAILED", error.getMessage());
        }
    }

    private void ensureInitialized() throws TerminalException {
        if (!Terminal.isInitialized()) Terminal.init(appContext, LogLevel.INFO, tokenProvider, this, null);
    }

    private void connectAndProcess() {
        try {
            boolean simulated = (appContext.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
            EasyConnectConfiguration config = new EasyConnectConfiguration.TapToPayEasyConnectConfiguration(
                new DiscoveryConfiguration.TapToPayDiscoveryConfiguration(simulated),
                new ConnectionConfiguration.TapToPayConnectionConfiguration(
                    new TapUseCase.Pay(locationId),
                    true,
                    this
                )
            );
            Terminal.getInstance().easyConnect(config, new ReaderCallback() {
                @Override public void onSuccess(@NonNull Reader reader) { retrieveAndProcess(); }
                @Override public void onFailure(@NonNull TerminalException e) { fail("TAP_TO_PAY_CONNECT_FAILED", e.getErrorMessage()); }
            });
        } catch (Exception error) {
            fail("TAP_TO_PAY_CONNECT_FAILED", error.getMessage());
        }
    }

    private void retrieveAndProcess() {
        Terminal.getInstance().retrievePaymentIntent(clientSecret, new PaymentIntentCallback() {
            @Override public void onSuccess(@NonNull PaymentIntent intent) {
                CollectPaymentIntentConfiguration collectConfig = new CollectPaymentIntentConfiguration.Builder().skipTipping(true).build();
                ConfirmPaymentIntentConfiguration confirmConfig = new ConfirmPaymentIntentConfiguration.Builder().build();
                Terminal.getInstance().processPaymentIntent(intent, collectConfig, confirmConfig, new PaymentIntentCallback() {
                    @Override public void onSuccess(@NonNull PaymentIntent paymentIntent) {
                        success(paymentIntent.getId());
                        Terminal.getInstance().disconnectReader(new Callback() {
                            @Override public void onSuccess() { }
                            @Override public void onFailure(@NonNull TerminalException e) { Log.w(TAG, "Reader disconnect after payment failed: " + e.getErrorMessage()); }
                        });
                    }
                    @Override public void onFailure(@NonNull TerminalException e) { fail("PAYMENT_PROCESS_FAILED", e.getErrorMessage()); }
                });
            }
            @Override public void onFailure(@NonNull TerminalException e) { fail("PAYMENT_RETRIEVE_FAILED", e.getErrorMessage()); }
        });
    }

    private void success(String paymentIntentId) {
        try {
            JSONObject detail = new JSONObject();
            detail.put("ok", true);
            detail.put("sale_id", saleId);
            detail.put("payment_intent_id", paymentIntentId == null ? "" : paymentIntentId);
            detail.put("platform", "android");
            sink.emit("kombax-tap-to-pay-result", detail);
        } catch (Exception error) { Log.e(TAG, "Could not emit success", error); }
    }

    private void fail(String code, String message) {
        try {
            JSONObject detail = new JSONObject();
            detail.put("ok", false);
            detail.put("sale_id", saleId);
            detail.put("error", code);
            detail.put("message", message == null ? code : message);
            detail.put("platform", "android");
            sink.emit("kombax-tap-to-pay-result", detail);
        } catch (Exception error) { Log.e(TAG, "Could not emit failure", error); }
    }

    @Override public void onConnectionStatusChange(@NonNull ConnectionStatus status) { Log.d(TAG, "Connection status: " + status); }
    @Override public void onPaymentStatusChange(@NonNull PaymentStatus status) { Log.d(TAG, "Payment status: " + status); }
    @Override public void onReaderReconnectStarted(@NonNull Reader reader, @NonNull Cancelable cancelReconnect, @NonNull DisconnectReason reason) { Log.i(TAG, "Tap to Pay reconnect started"); }
    @Override public void onReaderReconnectSucceeded(@NonNull Reader reader) { Log.i(TAG, "Tap to Pay reconnected"); }
    @Override public void onReaderReconnectFailed(@NonNull Reader reader) { Log.w(TAG, "Tap to Pay reconnect failed"); }
    @Override public void onDisconnect(@NonNull DisconnectReason reason) { Log.i(TAG, "Tap to Pay disconnected: " + reason); }
}
