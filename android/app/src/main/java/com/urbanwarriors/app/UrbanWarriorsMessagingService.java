package com.urbanwarriors.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public class UrbanWarriorsMessagingService extends FirebaseMessagingService {
    private static final String CHANNEL_ID = "urban_warriors_alerts";
    private static final String LOG_TAG = "UrbanWarriorsPush";

    @Override
    public void onNewToken(String token) {
        super.onNewToken(token);
        if (token == null || token.trim().isEmpty()) {
            Log.w(LOG_TAG, "Firebase entregó un token vacío; se ignora.");
            return;
        }
        getSharedPreferences("uw_push", MODE_PRIVATE).edit().putString("fcm_token", token.trim()).apply();
        Log.i(LOG_TAG, "Token FCM renovado y almacenado para la siguiente sincronización.");
    }

    @Override
    public void onMessageReceived(RemoteMessage message) {
        super.onMessageReceived(message);
        String title = "Urban Warriors";
        String body = "Tienes una nueva notificación.";
        if (message.getNotification() != null) {
            if (message.getNotification().getTitle() != null) title = message.getNotification().getTitle();
            if (message.getNotification().getBody() != null) body = message.getNotification().getBody();
        }
        if (message.getData().get("title") != null) title = message.getData().get("title");
        if (message.getData().get("body") != null) body = message.getData().get("body");
        String route = message.getData().getOrDefault("route", "notifications");
        Intent intent = new Intent(this, MainActivity.class);
        intent.putExtra("route", route);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, route.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Alertas Urban Warriors", NotificationManager.IMPORTANCE_HIGH);
            manager.createNotificationChannel(channel);
        }
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent);
        try { manager.notify((int)(System.currentTimeMillis() % Integer.MAX_VALUE), builder.build()); }
        catch (SecurityException error) { Log.w(LOG_TAG, "Notificación FCM recibida pero bloqueada por Android.", error); }
    }
}
