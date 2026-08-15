package com.urbanwarriors.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.graphics.Insets;
import android.util.Log;
import android.view.View;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends Activity {
    private static final int FILE_PICKER_REQUEST = 401;
    private static final int NOTIFICATION_PERMISSION_REQUEST = 402;
    private static final String NOTIFICATION_CHANNEL_ID = "urban_warriors_alerts";
    private static final String LOG_TAG = "UrbanWarriorsPush";
    // Origen HTTPS virtual para que los ES modules del frontend 2.0 funcionen en WebView.
    private static final String APP_HOST = "appassets.androidplatform.net";
    private static final String APP_ORIGIN = "https://" + APP_HOST;
    private WebView webView;
    private ValueCallback<Uri[]> fileCallback;
    private int safeAreaTopPx;
    private int safeAreaBottomPx;
    private boolean firebaseReady;

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();
        configureEdgeToEdge();
        webView = new WebView(this);
        setContentView(webView);
        observeSafeAreas();
        firebaseReady = initializeFirebaseSafely();

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setUserAgentString(settings.getUserAgentString() + " UrbanWarriorsApp/2.0.0-rc.13");

        webView.addJavascriptInterface(new NativeBridge(), "UrbanWarriorsNative");
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                applySafeAreasToFrontend();
            }

            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (!APP_HOST.equals(uri.getHost())) return super.shouldInterceptRequest(view, request);
                String path = uri.getPath();
                if (path == null || path.equals("/")) path = "/index.html";
                path = path.replaceFirst("^/", "");
                if (path.contains("..")) return new WebResourceResponse("text/plain", "UTF-8", null);
                try {
                    InputStream input = getAssets().open("www/" + path);
                    Map<String,String> headers = new HashMap<>();
                    headers.put("Cache-Control", "no-store");
                    return new WebResourceResponse(mimeType(path), "UTF-8", 200, "OK", headers, input);
                } catch (Exception exception) {
                    return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", new HashMap<>(), null);
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (APP_HOST.equals(uri.getHost())) return false;
                String scheme = uri.getScheme();
                if ("https".equals(scheme) || "http".equals(scheme)) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); return true; }
                catch (Exception ignored) { return false; }
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                Intent intent;
                try { intent = params.createIntent(); }
                catch (Exception exception) {
                    intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("*/*");
                }
                try { startActivityForResult(intent, FILE_PICKER_REQUEST); }
                catch (Exception exception) {
                    fileCallback = null;
                    Toast.makeText(MainActivity.this, "No se pudo abrir el selector de archivos", Toast.LENGTH_SHORT).show();
                }
                return true;
            }
        });

        webView.loadUrl(APP_ORIGIN + "/index.html" + routeFragment(getIntent()));
    }

    private boolean initializeFirebaseSafely() {
        try {
            FirebaseApp app = FirebaseApp.getApps(this).isEmpty() ? FirebaseApp.initializeApp(this) : FirebaseApp.getInstance();
            if (app == null) {
                Log.w(LOG_TAG, "Firebase no está configurado; la app continuará sin push.");
                return false;
            }
            Log.i(LOG_TAG, "Firebase inicializado correctamente.");
            return true;
        } catch (Throwable error) {
            Log.e(LOG_TAG, "Firebase no pudo inicializarse; la app continuará funcionando.", error);
            return false;
        }
    }

    private void refreshPushTokenSafely() {
        if (!firebaseReady) {
            firebaseReady = initializeFirebaseSafely();
            if (!firebaseReady) return;
        }
        try {
            Log.i(LOG_TAG, "Solicitando token FCM de forma asíncrona.");
            FirebaseMessaging.getInstance().getToken().addOnCompleteListener(task -> {
                if (!task.isSuccessful() || task.getResult() == null || task.getResult().trim().isEmpty()) {
                    Log.w(LOG_TAG, "No se pudo obtener el token FCM.", task.getException());
                    return;
                }
                String token = task.getResult().trim();
                getSharedPreferences("uw_push", MODE_PRIVATE).edit().putString("fcm_token", token).apply();
                Log.i(LOG_TAG, "Token FCM obtenido y preparado para sincronización.");
                dispatchPushToken(token);
            });
        } catch (Throwable error) {
            Log.e(LOG_TAG, "Error al solicitar token FCM; no se interrumpe la app.", error);
        }
    }

    private void dispatchPushToken(String token) {
        if (webView == null || token == null || token.trim().isEmpty()) return;
        runOnUiThread(() -> webView.evaluateJavascript(
            "window.dispatchEvent(new CustomEvent('uw-native-push-token',{detail:" + org.json.JSONObject.quote(token) + "}));",
            null
        ));
    }

    private void configureEdgeToEdge() {
        getWindow().setStatusBarColor(android.graphics.Color.TRANSPARENT);
        getWindow().setNavigationBarColor(android.graphics.Color.TRANSPARENT);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        );
    }

    private void observeSafeAreas() {
        getWindow().getDecorView().setOnApplyWindowInsetsListener((view, insets) -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                safeAreaTopPx = bars.top;
                safeAreaBottomPx = bars.bottom;
            } else {
                safeAreaTopPx = Math.max(insets.getStableInsetTop(), insets.getSystemWindowInsetTop());
                safeAreaBottomPx = insets.getStableInsetBottom();
            }
            applySafeAreasToFrontend();
            return insets;
        });
        getWindow().getDecorView().requestApplyInsets();
    }

    private void applySafeAreasToFrontend() {
        if (webView == null) return;
        final int top = Math.max(0, safeAreaTopPx);
        final int bottom = Math.max(0, safeAreaBottomPx);
        webView.post(() -> webView.evaluateJavascript(
            "document.documentElement.style.setProperty('--uw-native-safe-top','" + top + "px');"
                + "document.documentElement.style.setProperty('--uw-native-safe-bottom','" + bottom + "px');"
                + "window.dispatchEvent(new CustomEvent('uw-safe-area-changed',{detail:{top:" + top + ",bottom:" + bottom + "}}));",
            null
        ));
    }

    private static String routeFragment(Intent intent) {
        if (intent == null) return "";
        String route = intent.getStringExtra("route");
        if (route == null || !route.matches("[A-Za-z0-9_-]{1,64}")) return "";
        return "#" + route;
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        String fragment = routeFragment(intent);
        if (webView != null && !fragment.isEmpty()) {
            String route = fragment.substring(1);
            webView.evaluateJavascript("window.location.hash=" + org.json.JSONObject.quote("#" + route) + ";", null);
        }
    }

    private static String mimeType(String path) {
        String p = path.toLowerCase();
        if (p.endsWith(".html")) return "text/html";
        if (p.endsWith(".js")) return "text/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".json") || p.endsWith(".webmanifest")) return "application/json";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
        if (p.endsWith(".webp")) return "image/webp";
        if (p.endsWith(".pdf")) return "application/pdf";
        if (p.endsWith(".svg")) return "image/svg+xml";
        return "application/octet-stream";
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(NOTIFICATION_CHANNEL_ID, "Alertas Urban Warriors", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Mensualidades, clases, pagos y avisos del club");
            getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            getSharedPreferences("uw_push", MODE_PRIVATE).edit().putBoolean("notification_permission_requested", true).apply();
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, NOTIFICATION_PERMISSION_REQUEST);
        } else {
            refreshPushTokenSafely();
            notifyPermissionState();
        }
    }

    private String notificationPermissionState() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "granted";
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return "granted";
        boolean requested = getSharedPreferences("uw_push", MODE_PRIVATE).getBoolean("notification_permission_requested", false);
        if (!requested) return "prompt";
        return shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) ? "rationale" : "settings";
    }

    private void notifyPermissionState() {
        if (webView == null) return;
        String state = notificationPermissionState();
        runOnUiThread(() -> webView.evaluateJavascript(
            "window.dispatchEvent(new CustomEvent('uw-native-notification-state',{detail:" + org.json.JSONObject.quote(state) + "}));",
            null
        ));
    }

    private void openNotificationSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName());
            startActivity(intent);
        } catch (Exception error) {
            Log.w(LOG_TAG, "No se pudo abrir ajustes de notificaciones; se abre la ficha de la app.", error);
            Intent fallback = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getPackageName()));
            startActivity(fallback);
        }
    }

    private void showLocalNotification(String title, String body) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            Log.i(LOG_TAG, "Notificación local omitida: permiso Android no concedido.");
            return;
        }
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? new Notification.Builder(this, NOTIFICATION_CHANNEL_ID) : new Notification.Builder(this);
        builder.setSmallIcon(R.mipmap.ic_launcher).setContentTitle(title).setContentText(body).setAutoCancel(true);
        try { manager.notify((int) (System.currentTimeMillis() % Integer.MAX_VALUE), builder.build()); }
        catch (SecurityException error) { Log.w(LOG_TAG, "Android bloqueó la notificación local.", error); }
    }

    public class NativeBridge {
        @JavascriptInterface
        public String requestNotifications() {
            runOnUiThread(MainActivity.this::requestNotificationPermission);
            return getSharedPreferences("uw_push", MODE_PRIVATE).getString("fcm_token", "");
        }
        @JavascriptInterface public String getPushToken() { return getSharedPreferences("uw_push", MODE_PRIVATE).getString("fcm_token", ""); }
        @JavascriptInterface public String getNotificationPermissionState() { return notificationPermissionState(); }
        @JavascriptInterface public boolean isFirebaseReady() { return firebaseReady; }
        @JavascriptInterface public void openNotificationSettings() { runOnUiThread(MainActivity.this::openNotificationSettings); }
        @JavascriptInterface public void showNotification(String title, String body) { runOnUiThread(() -> showLocalNotification(title, body)); }
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            Log.i(LOG_TAG, granted ? "Permiso de notificaciones concedido." : "Permiso de notificaciones no concedido.");
            if (granted) refreshPushTokenSafely();
            notifyPermissionState();
        }
    }
    @Override protected void onResume() {
        super.onResume();
        if (notificationPermissionState().equals("granted")) refreshPushTokenSafely();
        notifyPermissionState();
    }
    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != FILE_PICKER_REQUEST || fileCallback == null) return;
        Uri[] result = null; if (resultCode == RESULT_OK && data != null && data.getData() != null) result = new Uri[]{data.getData()};
        fileCallback.onReceiveValue(result); fileCallback = null;
    }
    @Override public void onBackPressed() { if (webView != null && webView.canGoBack()) webView.goBack(); else super.onBackPressed(); }
    @Override protected void onDestroy() { if (webView != null) { webView.loadUrl("about:blank"); webView.destroy(); } super.onDestroy(); }
}
