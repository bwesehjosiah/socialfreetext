package com.socialfreetext.app

import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ProgressBar
import org.json.JSONObject
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var swipeRefresh: SwipeRefreshLayout
    private lateinit var loadingLine: ProgressBar
    private val handler = Handler(Looper.getMainLooper())
    private var clickTask: Runnable? = null
    private var pendingWebPermissionRequest: PermissionRequest? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        createNotificationChannels()

        loadingLine = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(-1, dp(3))
        }

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            addJavascriptInterface(PageBridge(), "SFTApp")
            webViewClient = object : WebViewClient() {
                override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                    super.onPageStarted(view, url, favicon)
                    if (url.startsWith(APP_URL)) showLoading(8)
                }
                override fun onPageFinished(view: WebView, url: String) {
                    super.onPageFinished(view, url)
                    if (url.startsWith(APP_URL)) {
                        swipeRefresh.isRefreshing = false
                        hideLoading()
                        installClickHook()
                        dispatchPendingNotificationReply()
                    }
                }
            }
            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, progress: Int) {
                    if (progress < 100) showLoading(progress.coerceAtLeast(5))
                    else if (clickTask == null) hideLoading()
                }
                override fun onPermissionRequest(request: PermissionRequest) {
                    runOnUiThread {
                        if (request.origin.host != "socialfreetext.vercel.app" || request.origin.scheme != "https") {
                            request.deny()
                            return@runOnUiThread
                        }
                        val permissions = mutableListOf<String>()
                        for (resource in request.resources) {
                            when (resource) {
                                PermissionRequest.RESOURCE_AUDIO_CAPTURE -> permissions.add(Manifest.permission.RECORD_AUDIO)
                                PermissionRequest.RESOURCE_VIDEO_CAPTURE -> permissions.add(Manifest.permission.CAMERA)
                                else -> { request.deny(); return@runOnUiThread }
                            }
                        }
                        val missing = permissions.distinct().filter {
                            ContextCompat.checkSelfPermission(this@MainActivity, it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isEmpty()) request.grant(request.resources)
                        else if (pendingWebPermissionRequest == null) {
                            pendingWebPermissionRequest = request
                            ActivityCompat.requestPermissions(this@MainActivity, missing.toTypedArray(), 302)
                        } else request.deny()
                    }
                }
                override fun onPermissionRequestCanceled(request: PermissionRequest) {
                    if (pendingWebPermissionRequest === request) pendingWebPermissionRequest = null
                }
            }
        }

        swipeRefresh = SwipeRefreshLayout(this).apply {
            setColorSchemeResources(android.R.color.holo_blue_bright, android.R.color.holo_blue_dark)
            setOnRefreshListener {
                showLoading(10)
                webView.reload()
            }
            addView(webView, ViewGroup.LayoutParams(-1, -1))
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(loadingLine)
            addView(swipeRefresh, LinearLayout.LayoutParams(-1, 0, 1f))
        }
        setContentView(root)
        webView.loadUrl(targetUrl(intent?.getStringExtra("target")))
        captureNotificationReply(intent)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun showLoading(progress: Int) {
        runOnUiThread {
            clickTask?.let { handler.removeCallbacks(it) }
            clickTask = null
            loadingLine.visibility = View.VISIBLE
            loadingLine.progress = progress.coerceIn(5, 95)
        }
    }

    private fun hideLoading() {
        runOnUiThread {
            clickTask?.let { handler.removeCallbacks(it) }
            clickTask = null
            loadingLine.progress = 100
            handler.postDelayed({ loadingLine.visibility = View.GONE; loadingLine.progress = 0 }, 180)
        }
    }

    private fun showClickLoading() {
        runOnUiThread {
            showLoading(35)
            val task = Runnable {
                loadingLine.progress = 100
                handler.postDelayed({ loadingLine.visibility = View.GONE; loadingLine.progress = 0 }, 160)
                clickTask = null
            }
            clickTask = task
            handler.postDelayed(task, 750)
        }
    }

    private fun installClickHook() {
        val js = "(function(){if(window.__sftClickHook)return;window.__sftClickHook=true;document.addEventListener('click',function(){if(window.SFTApp)window.SFTApp.onClick();},true);})();"
        webView.evaluateJavascript(js, null)
    }

    inner class PageBridge {
        @JavascriptInterface fun onClick() { showClickLoading() }
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 302) {
            val request = pendingWebPermissionRequest
            pendingWebPermissionRequest = null
            if (request != null) {
                val allGranted = permissions.isNotEmpty() && grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                if (allGranted) request.grant(request.resources) else request.deny()
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNotificationReply(intent)
        if (::webView.isInitialized) {
            if (webView.url?.startsWith(APP_URL) == true) dispatchPendingNotificationReply()
            else webView.loadUrl(targetUrl(intent.getStringExtra("target")))
        }
    }

    private var pendingNotificationReply: Pair<String, String>? = null
    private fun captureNotificationReply(source: android.content.Intent?) {
        val senderId = source?.getStringExtra("sender_id") ?: return
        val replyText = source.getStringExtra("notification_reply_text") ?: return
        if (replyText.isBlank()) return
        pendingNotificationReply = senderId to replyText
        source.removeExtra("notification_reply_text")
    }

    private fun dispatchPendingNotificationReply() {
        val pending = pendingNotificationReply ?: return
        val payload = JSONObject().put("type", "reply").put("senderId", pending.first).put("text", pending.second).toString()
        val script = "window.receiveSFTNativeAction && window.receiveSFTNativeAction(" + JSONObject.quote(payload) + ")"
        webView.evaluateJavascript(script) { result -> if (result == "true") pendingNotificationReply = null }
    }

    private fun targetUrl(target: String?): String = when (target) {
        "call" -> "$APP_URL/?open=calls"
        "reply" -> "$APP_URL/?open=chats&reply=1"
        else -> APP_URL
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 301)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(SFTMessagingService.callChannel())
            manager.createNotificationChannel(SFTMessagingService.messageChannel())
        }
    }

    override fun onDestroy() {
        clickTask?.let { handler.removeCallbacks(it) }
        if (::webView.isInitialized) webView.removeJavascriptInterface("SFTApp")
        super.onDestroy()
    }

    companion object { const val APP_URL = "https://socialfreetext.vercel.app" }
}
