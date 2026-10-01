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
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.nfc.NfcAdapter;
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
import androidx.core.content.FileProvider;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;
import org.json.JSONObject;

// historical-release-marker: KOMBAXRevision/r81-tap-to-pay KOMBAXApp/2.0.0-rc.13/20134
public class MainActivity extends Activity {
    private static final int FILE_PICKER_REQUEST = 401;
    private static final int NOTIFICATION_PERMISSION_REQUEST = 402;
    private static final int TERMINAL_LOCATION_PERMISSION_REQUEST = 403;
    private static final int PDF_SAVE_REQUEST = 404;
    private static final String NOTIFICATION_CHANNEL_ID = "urban_warriors_alerts";
    private static final String LOG_TAG = "UrbanWarriorsPush";
    // Origen HTTPS virtual para que los ES modules del frontend 2.0 funcionen en WebView.
    private static final String APP_HOST = "appassets.androidplatform.net";
    private static final String APP_ORIGIN = "https://" + APP_HOST;
    private WebView webView;
    private ValueCallback<Uri[]> fileCallback;
    private String pendingPdfAssetPath;
    private int safeAreaTopPx;
    private int safeAreaBottomPx;
    private boolean firebaseReady;
    private KombaxTerminalManager terminalManager;

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView.setWebContentsDebuggingEnabled(false);
        createNotificationChannel();
        configureEdgeToEdge();
        webView = new WebView(this);
        terminalManager = new KombaxTerminalManager(this, this::emitTerminalEvent);
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
        // QA Android: los assets viven dentro del APK; en debug evitamos que una caché WebView
        // de una instalación anterior oculte una revisión recién instalada. Release conserva
        // el comportamiento normal para no penalizar rendimiento.
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
            webView.clearCache(true);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) settings.setSafeBrowsingEnabled(true);
        settings.setSupportMultipleWindows(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setUserAgentString(settings.getUserAgentString() + " KOMBAXRevision/r117-netlify-android-ready KOMBAXApp/2.0.0-rc.13/20170");
        // historical QA marker preserved: KOMBAXApp/2.0.0-rc.13/20101

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
                if (APP_HOST.equalsIgnoreCase(uri.getHost())) return false;
                openExternalUri(uri);
                return true;
            }

            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                Uri uri;
                try { uri = Uri.parse(url); }
                catch (Exception ignored) { return true; }
                if (APP_HOST.equalsIgnoreCase(uri.getHost())) return false;
                openExternalUri(uri);
                return true;
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

        webView.loadUrl(APP_ORIGIN + "/index.html" + entrySuffix(getIntent()));
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
        // WindowInsets entrega píxeles físicos, mientras que la WebView interpreta
        // los valores CSS en píxeles independientes de densidad. Inyectar el valor
        // físico sin convertirlo triplicaba aproximadamente los márgenes en móviles
        // xxhdpi/xxxhdpi. Convertimos una sola vez antes de exponerlos al frontend.
        final float density = Math.max(1f, getResources().getDisplayMetrics().density);
        final int top = Math.max(0, Math.round(safeAreaTopPx / density));
        final int bottom = Math.max(0, Math.round(safeAreaBottomPx / density));
        webView.post(() -> webView.evaluateJavascript(
            "document.documentElement.style.setProperty('--uw-native-safe-top','" + top + "px');"
                + "document.documentElement.style.setProperty('--uw-native-safe-bottom','" + bottom + "px');"
                + "window.dispatchEvent(new CustomEvent('uw-safe-area-changed',{detail:{top:" + top + ",bottom:" + bottom + "}}));",
            null
        ));
    }

    private void openExternalUri(Uri uri) {
        if (uri == null) return;
        String scheme = String.valueOf(uri.getScheme()).toLowerCase();
        if (!("https".equals(scheme) || "mailto".equals(scheme) || "tel".equals(scheme))) {
            Log.w(LOG_TAG, "Navegación externa bloqueada por esquema no permitido: " + scheme);
            return;
        }
        try {
            Intent external = new Intent(Intent.ACTION_VIEW, uri);
            external.addCategory(Intent.CATEGORY_BROWSABLE);
            startActivity(external);
        } catch (Exception error) {
            Log.w(LOG_TAG, "No se pudo abrir el enlace externo fuera de KOMBAX.", error);
            Toast.makeText(this, "No se pudo abrir el enlace externo", Toast.LENGTH_SHORT).show();
        }
    }

    private static boolean trustedKombaxHost(String host) {
        if (host == null) return false;
        return "kombax.es".equalsIgnoreCase(host) || "www.kombax.es".equalsIgnoreCase(host);
    }

    private static void appendEntryParam(StringBuilder query, Uri source, String name, String pattern, int maxLength) {
        String value = source.getQueryParameter(name);
        if (value == null || value.isEmpty() || value.length() > maxLength || !value.matches(pattern)) return;
        query.append(query.length() == 0 ? "?" : "&")
            .append(Uri.encode(name)).append("=").append(Uri.encode(value));
    }

    private static String entrySuffix(Intent intent) {
        if (intent == null) return "";
        StringBuilder query = new StringBuilder();
        String route = intent.getStringExtra("route");
        Uri data = intent.getData();
        if (Intent.ACTION_VIEW.equals(intent.getAction()) && data != null && trustedKombaxHost(data.getHost())) {
            appendEntryParam(query, data, "club", "[A-Za-z0-9-]{1,80}", 80);
            appendEntryParam(query, data, "access_type", "[A-Za-z0-9_-]{1,32}", 32);
            appendEntryParam(query, data, "invite_type", "[A-Za-z0-9_-]{1,32}", 32);
            appendEntryParam(query, data, "access_code", "[A-Za-z0-9_-]{1,48}", 48);
            appendEntryParam(query, data, "invite", "[A-Za-z0-9_-]{1,48}", 48);
            appendEntryParam(query, data, "team_role", "[A-Za-z0-9_-]{1,32}", 32);
            // KOMBAX Eventos públicos: conservar únicamente parámetros conocidos y validados.
            appendEntryParam(query, data, "event", "[A-Za-z0-9][A-Za-z0-9-]{0,119}", 120);
            appendEntryParam(query, data, "fight", "[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[1-5][A-Fa-f0-9]{3}-[89AaBb][A-Fa-f0-9]{3}-[A-Fa-f0-9]{12}", 36);
            String queryRoute = data.getQueryParameter("route");
            if (queryRoute != null) route = queryRoute;
            if ((route == null || route.isEmpty()) && data.getFragment() != null) route = data.getFragment();
        }
        if (route != null && route.matches("[A-Za-z0-9_-]{1,64}")) query.append("#").append(route);
        return query.toString();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (webView == null) return;
        if (Intent.ACTION_VIEW.equals(intent.getAction()) && intent.getData() != null) {
            if (!trustedKombaxHost(intent.getData().getHost())) { openExternalUri(intent.getData()); return; }
            webView.loadUrl(APP_ORIGIN + "/index.html" + entrySuffix(intent));
            return;
        }
        String suffix = entrySuffix(intent);
        int hashIndex = suffix.indexOf('#');
        if (hashIndex >= 0) {
            String route = suffix.substring(hashIndex + 1);
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
            NotificationChannel channel = new NotificationChannel(NOTIFICATION_CHANNEL_ID, "Alertas KOMBAX", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Avisos privados de KOMBAX y de tu club");
            channel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
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

    private void emitTerminalEvent(String eventName, JSONObject detail) {
        if (webView == null) return;
        String js = "window.dispatchEvent(new CustomEvent(" + JSONObject.quote(eventName) + ", {detail:" + detail.toString() + "}));";
        webView.post(() -> webView.evaluateJavascript(js, null));
    }

    private String tapToPayDeviceStatus() {
        try {
            JSONObject out = new JSONObject();
            boolean osSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU;
            NfcAdapter nfc = NfcAdapter.getDefaultAdapter(this);
            boolean nfcPresent = nfc != null;
            boolean nfcEnabled = nfcPresent && nfc.isEnabled();
            boolean locationGranted = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
            boolean keystore = getPackageManager().hasSystemFeature(PackageManager.FEATURE_HARDWARE_KEYSTORE, 100);
            boolean debug = (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
            boolean developerOptions = Settings.Global.getInt(getContentResolver(), Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0;
            out.put("platform", "android");
            out.put("os_supported", osSupported);
            out.put("nfc_present", nfcPresent);
            out.put("nfc_enabled", nfcEnabled);
            out.put("hardware_keystore", keystore);
            out.put("permission_granted", locationGranted);
            out.put("secure_environment", !debug && !developerOptions);
            out.put("supported", osSupported && nfcPresent && nfcEnabled && keystore && locationGranted && !debug && !developerOptions);
            return out.toString();
        } catch (Exception error) {
            Log.w(LOG_TAG, "No se pudo evaluar Tap to Pay.", error);
            return "{\"platform\":\"android\",\"supported\":false}";
        }
    }

    private void requestTapToPayPermissions() {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            try {
                JSONObject detail = new JSONObject(tapToPayDeviceStatus());
                emitTerminalEvent("kombax-terminal-device-status", detail);
            } catch (Exception ignored) { }
            return;
        }
        requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION}, TERMINAL_LOCATION_PERMISSION_REQUEST);
    }

    private String bundledGuideAssetPath(String relativePath) {
        if (relativePath == null) return null;
        String clean = relativePath.trim().replace('\\', '/');
        while (clean.startsWith("/")) clean = clean.substring(1);
        if (!clean.startsWith("assets/guides/") || !clean.toLowerCase().endsWith(".pdf") || clean.contains("..")) return null;
        return "www/" + clean;
    }

    private String bundledGuideFileName(String assetPath) {
        if (assetPath == null) return "KOMBAX_Guia.pdf";
        int slash = assetPath.lastIndexOf('/');
        String name = slash >= 0 ? assetPath.substring(slash + 1) : assetPath;
        name = name.replaceAll("[^A-Za-z0-9._-]", "_");
        return name.toLowerCase().endsWith(".pdf") ? name : name + ".pdf";
    }

    private void copyBundledGuide(String assetPath, OutputStream output) throws Exception {
        try (InputStream input = getAssets().open(assetPath); OutputStream out = output) {
            byte[] buffer = new byte[16384];
            int read;
            while ((read = input.read(buffer)) >= 0) out.write(buffer, 0, read);
            out.flush();
        }
    }

    private void openBundledPdfAsset(String relativePath) {
        String assetPath = bundledGuideAssetPath(relativePath);
        if (assetPath == null) { Toast.makeText(this, "Guía PDF no válida", Toast.LENGTH_SHORT).show(); return; }
        try {
            File dir = new File(getCacheDir(), "shared-pdf");
            if (!dir.exists() && !dir.mkdirs()) throw new IllegalStateException("No se pudo preparar la caché PDF");
            File pdf = new File(dir, bundledGuideFileName(assetPath));
            copyBundledGuide(assetPath, new FileOutputStream(pdf, false));
            Uri uri = FileProvider.getUriForFile(this, getPackageName() + ".fileprovider", pdf);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(uri, "application/pdf");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try { startActivity(intent); }
            catch (Exception noViewer) { Toast.makeText(this, "No hay un visor PDF disponible. Usa Descargar PDF.", Toast.LENGTH_LONG).show(); }
        } catch (Exception error) {
            Log.e(LOG_TAG, "No se pudo abrir la guía PDF", error);
            Toast.makeText(this, "No se pudo abrir la guía PDF", Toast.LENGTH_SHORT).show();
        }
    }

    private void saveBundledPdfAsset(String relativePath) {
        String assetPath = bundledGuideAssetPath(relativePath);
        if (assetPath == null) { Toast.makeText(this, "Guía PDF no válida", Toast.LENGTH_SHORT).show(); return; }
        try {
            pendingPdfAssetPath = assetPath;
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/pdf");
            intent.putExtra(Intent.EXTRA_TITLE, bundledGuideFileName(assetPath));
            startActivityForResult(intent, PDF_SAVE_REQUEST);
        } catch (Exception error) {
            pendingPdfAssetPath = null;
            Log.e(LOG_TAG, "No se pudo abrir el selector de guardado PDF", error);
            Toast.makeText(this, "No se pudo preparar la descarga PDF", Toast.LENGTH_SHORT).show();
        }
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
        @JavascriptInterface public String getTapToPayDeviceStatus() { return tapToPayDeviceStatus(); }
        @JavascriptInterface public void requestTapToPayPermissions() { runOnUiThread(MainActivity.this::requestTapToPayPermissions); }
        @JavascriptInterface public void startTapToPay(String payloadJson) { runOnUiThread(() -> terminalManager.start(payloadJson)); }
        @JavascriptInterface public void provideTapToPayConnectionToken(String token) { terminalManager.provideConnectionToken(token); }
        @JavascriptInterface public void openBundledPdf(String relativePath) { runOnUiThread(() -> openBundledPdfAsset(relativePath)); }
        @JavascriptInterface public void saveBundledPdf(String relativePath) { runOnUiThread(() -> saveBundledPdfAsset(relativePath)); }
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            Log.i(LOG_TAG, granted ? "Permiso de notificaciones concedido." : "Permiso de notificaciones no concedido.");
            if (granted) refreshPushTokenSafely();
            notifyPermissionState();
        } else if (requestCode == TERMINAL_LOCATION_PERMISSION_REQUEST) {
            try { emitTerminalEvent("kombax-terminal-device-status", new JSONObject(tapToPayDeviceStatus())); }
            catch (Exception error) { Log.w(LOG_TAG, "No se pudo notificar el permiso de Tap to Pay.", error); }
        }
    }
    @Override protected void onResume() {
        super.onResume();
        if (notificationPermissionState().equals("granted")) refreshPushTokenSafely();
        notifyPermissionState();
    }
    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PDF_SAVE_REQUEST) {
            String assetPath = pendingPdfAssetPath;
            pendingPdfAssetPath = null;
            if (resultCode == RESULT_OK && data != null && data.getData() != null && assetPath != null) {
                try {
                    OutputStream output = getContentResolver().openOutputStream(data.getData());
                    if (output == null) throw new IllegalStateException("No se pudo abrir el destino PDF");
                    copyBundledGuide(assetPath, output);
                    Toast.makeText(this, "PDF guardado", Toast.LENGTH_SHORT).show();
                } catch (Exception error) {
                    Log.e(LOG_TAG, "No se pudo guardar la guía PDF", error);
                    Toast.makeText(this, "No se pudo guardar el PDF", Toast.LENGTH_SHORT).show();
                }
            }
            return;
        }
        if (requestCode != FILE_PICKER_REQUEST || fileCallback == null) return;
        Uri[] result = null; if (resultCode == RESULT_OK && data != null && data.getData() != null) result = new Uri[]{data.getData()};
        fileCallback.onReceiveValue(result); fileCallback = null;
    }
    @Override public void onBackPressed() { if (webView != null && webView.canGoBack()) webView.goBack(); else super.onBackPressed(); }
    @Override protected void onDestroy() { if (webView != null) { webView.loadUrl("about:blank"); webView.destroy(); } super.onDestroy(); }
}
