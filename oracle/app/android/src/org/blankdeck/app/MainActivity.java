package org.blankdeck.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.webkit.JavascriptInterface;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.ValueCallback;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * THE BLANK DECK on Android: one screen that shows the one page carried inside the app.
 *
 * The game is the page (assets/index.html): its rooms, its engine and its touch screen are all in
 * that file. This class gives it a window, the two things a page cannot do for itself on a phone
 * (put text on the clipboard, hand text to another app), and the back key.
 *
 * The app declares no permissions. With no INTERNET permission the system gives it no network,
 * so the page could not send anything anywhere even if it tried. It does not try.
 */
public final class MainActivity extends Activity {
    private static final String PAGE = "file:///android_asset/index.html";
    private static final String BRIDGE = "AndroidBridge";
    private static final String CLIP_LABEL = "The Blank Deck: the prompt for your builder";
    private static final String SHARE_TITLE = "Send the prompt to";
    private static final String ASK_PAGE_ABOUT_BACK =
            "(function(){try{return window.blankDeckBack&&window.blankDeckBack()?1:0}catch(e){return 0}})()";

    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        web.setBackgroundColor(Color.rgb(7, 20, 15));           // the table, before the page has drawn
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);

        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);                     // the game is the page's own script
        settings.setDomStorageEnabled(true);                     // where a night is kept between turns
        settings.setAllowFileAccess(false);                      // the page is an asset; it reads no other file
        settings.setAllowContentAccess(false);
        settings.setSupportZoom(false);

        web.addJavascriptInterface(new Bridge(), BRIDGE);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return true;                                     // the page never leaves itself
            }

            @Override
            public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
                recreate();                                      // a night is kept on every turn: open the page again
                return true;
            }
        });

        setContentView(web, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        web.loadUrl(PAGE);
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.onResume();
    }

    @Override
    protected void onPause() {
        web.onPause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        ViewParent parent = web.getParent();
        if (parent instanceof ViewGroup) {
            ((ViewGroup) parent).removeView(web);
        }
        web.removeJavascriptInterface(BRIDGE);
        web.destroy();
        super.onDestroy();
    }

    /** The back key closes whatever the page has open; with nothing open, it puts the app away. */
    @Override
    public void onBackPressed() {
        web.evaluateJavascript(ASK_PAGE_ABOUT_BACK, new ValueCallback<String>() {
            @Override
            public void onReceiveValue(String handled) {
                if (!"1".equals(handled)) {
                    moveTaskToBack(true);
                }
            }
        });
    }

    /** What the page may ask of the phone. Both act only on a tap, and only on the text the page hands over. */
    private final class Bridge {
        @JavascriptInterface
        public boolean copy(String text) {
            try {
                ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                if (clipboard == null || text == null) {
                    return false;
                }
                clipboard.setPrimaryClip(ClipData.newPlainText(CLIP_LABEL, text));
                return true;
            } catch (RuntimeException failed) {
                return false;
            }
        }

        @JavascriptInterface
        public void share(final String text, final String subject) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    try {
                        Intent send = new Intent(Intent.ACTION_SEND);
                        send.setType("text/plain");
                        send.putExtra(Intent.EXTRA_SUBJECT, subject);
                        send.putExtra(Intent.EXTRA_TEXT, text);
                        startActivity(Intent.createChooser(send, SHARE_TITLE));
                    } catch (RuntimeException failed) {
                        // No app can take it. The copy button is still there.
                    }
                }
            });
        }
    }
}
