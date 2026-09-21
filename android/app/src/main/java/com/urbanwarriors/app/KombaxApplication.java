package com.urbanwarriors.app;

import android.app.Application;
import com.stripe.stripeterminal.TerminalApplicationDelegate;

public class KombaxApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        TerminalApplicationDelegate.onCreate(this);
    }
}
