package com.gildedmoth.velvetmaze;

import android.app.Activity;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity implements SensorEventListener {

    private static final int PICK_IMAGES = 41;
    private WebView web;
    private SensorManager sensors;
    private Sensor accel;
    private ValueCallback<Uri[]> pendingChooser;
    // low-pass filtered gravity vector; start as "flat on table"
    private float lx = 0f, ly = 0f, lz = 9.81f;
    private boolean hasReading;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setTextZoom(100);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        web.setBackgroundColor(0xFF120810);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                return true;   // the game never navigates; block everything
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb,
                                             FileChooserParams params) {
                if (pendingChooser != null) pendingChooser.onReceiveValue(null);
                pendingChooser = cb;
                Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                i.setType("image/*");
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                try {
                    startActivityForResult(Intent.createChooser(i, "Choose images"), PICK_IMAGES);
                } catch (Exception e) {
                    pendingChooser.onReceiveValue(null);
                    pendingChooser = null;
                    return false;
                }
                return true;
            }
        });

        setContentView(web);
        // A fake https base gives the page a secure context, so IndexedDB and
        // localStorage persist under a stable origin with zero network involved.
        web.loadDataWithBaseURL("https://velvetmaze.local/", readAsset("index.html"),
                "text/html", "utf-8", null);

        sensors = (SensorManager) getSystemService(SENSOR_SERVICE);
        accel = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
    }

    private String readAsset(String name) {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader r = new BufferedReader(new InputStreamReader(
                getAssets().open(name), StandardCharsets.UTF_8))) {
            String line;
            while ((line = r.readLine()) != null) sb.append(line).append('\n');
        } catch (Exception e) {
            return "<body style=\"background:#120810;color:#efe3d0\">Failed to load game.</body>";
        }
        return sb.toString();
    }

    @Override
    public void onSensorChanged(SensorEvent e) {
        final float a = hasReading ? 0.22f : 1f;
        hasReading = true;
        lx += a * (e.values[0] - lx);
        ly += a * (e.values[1] - ly);
        lz += a * (e.values[2] - lz);
        double g = Math.max(1e-3, Math.sqrt(lx * lx + ly * ly + lz * lz));
        // Android sensor axes: left side down => +x, bottom edge down => +y.
        // Map to deviceorientation semantics: right side down => +gamma,
        // top edge up => +beta — matches what the game's tilt code expects.
        double beta = Math.toDegrees(Math.asin(clamp(ly / g)));
        double gamma = -Math.toDegrees(Math.asin(clamp(lx / g)));
        web.evaluateJavascript(
                "window.__nativeTilt&&__nativeTilt(" + beta + "," + gamma + ")", null);
    }

    private static double clamp(double v) { return Math.max(-1.0, Math.min(1.0, v)); }

    @Override public void onAccuracyChanged(Sensor s, int a) { }

    @Override
    protected void onResume() {
        super.onResume();
        hideBars();
        if (accel != null) sensors.registerListener(this, accel, SensorManager.SENSOR_DELAY_GAME);
    }

    @Override
    protected void onPause() {
        super.onPause();
        sensors.unregisterListener(this);
    }

    private void hideBars() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
              | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
              | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    }

    @Override
    public void onWindowFocusChanged(boolean f) {
        super.onWindowFocusChanged(f);
        if (f) hideBars();
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != PICK_IMAGES || pendingChooser == null) return;
        Uri[] out = null;
        if (res == RESULT_OK && data != null) {
            if (data.getClipData() != null) {
                int n = data.getClipData().getItemCount();
                out = new Uri[n];
                for (int i = 0; i < n; i++) out[i] = data.getClipData().getItemAt(i).getUri();
            } else if (data.getData() != null) {
                out = new Uri[] { data.getData() };
            }
        }
        pendingChooser.onReceiveValue(out);
        pendingChooser = null;
    }
}
