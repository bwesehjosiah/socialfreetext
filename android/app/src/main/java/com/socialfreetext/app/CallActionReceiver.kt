package com.socialfreetext.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action") ?: intent.action ?: return
        val target = if (action == "reply") "reply" else "call"
        // Answer/decline must be connected to authenticated WebRTC call signaling before
        // these actions can accept/reject a live call. Do not pretend the call was answered.
        if (action == "answer" || action == "reject") {
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("target", target)
                putExtra("pending_call_action", action)
                putExtra("sender_id", intent.getStringExtra("sender_id"))
                putExtra("call_id", intent.getStringExtra("call_id"))
            }
            context.startActivity(launch)
            if (action == "reject") NotificationManagerCompat.from(context).cancel(SFTMessagingService.CALL_NOTIFICATION_ID)
            return
        }
        if (action == "reply") {
            val replyText = RemoteInput.getResultsFromIntent(intent)
                ?.getCharSequence(ReplyReceiver.KEY_TEXT)?.toString()?.trim().orEmpty()
            if (replyText.isBlank()) return
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("target", "reply")
                putExtra("sender_id", intent.getStringExtra("sender_id"))
                putExtra("notification_reply_text", replyText)
            }
            context.startActivity(launch)
        }
    }
}
