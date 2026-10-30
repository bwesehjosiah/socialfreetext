package com.socialfreetext.app

import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private var pendingWebPermissionRequest: PermissionRequest? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        createNotificationChannels()
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    super.onPageFinished(view, url)
                    if (url.startsWith(APP_URL)) dispatchPendingNotificationReply()
                }
            }
            webChromeClient = object : WebChromeClient() {
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
                                else -> {
                                    request.deny()
                                    return@runOnUiThread
                                }
                            }
                        }
                        val missing = permissions.distinct().filter {
                            ContextCompat.checkSelfPermission(this@MainActivity, it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isEmpty()) {
                            request.grant(request.resources)
                        } else if (pendingWebPermissionRequest == null) {
                            pendingWebPermissionRequest = request
                            ActivityCompat.requestPermissions(this@MainActivity, missing.toTypedArray(), 302)
                        } else {
                            request.deny()
                        }
                    }
                }

                override fun onPermissionRequestCanceled(request: PermissionRequest) {
                    if (pendingWebPermissionRequest === request) pendingWebPermissionRequest = null
                }
            }
        }
        setContentView(webView)
        webView.loadUrl(targetUrl(intent?.getStringExtra("target")))
        captureNotificationReply(intent)
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
        val payload = JSONObject().put("type", "reply")
            .put("senderId", pending.first).put("text", pending.second).toString()
        val script = "window.receiveSFTNativeAction && window.receiveSFTNativeAction(" + JSONObject.quote(payload) + ")"
        webView.evaluateJavascript(script, null)
        pendingNotificationReply = null
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

    companion object { const val APP_URL = "https://socialfreetext.vercel.app" }
}
