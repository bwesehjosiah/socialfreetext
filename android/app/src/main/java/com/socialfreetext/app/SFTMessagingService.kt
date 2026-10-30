package com.socialfreetext.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SFTMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // MainActivity obtains the current token and registers it through the authenticated WebView session.
        getSharedPreferences("sft_push", Context.MODE_PRIVATE).edit().putString("fcm_token", token).apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val kind = data["kind"] ?: data["type"] ?: "message"
        val isCall = kind == "call"
        val title = message.notification?.title ?: data["title"] ?: if (isCall) "Incoming call" else "New message"
        val body = message.notification?.body ?: data["body"] ?: "Open SocialfreeText to view."
        showNotification(title, body, isCall, data["sender_id"], data["call_id"])
    }

    private fun showNotification(title: String, body: String, isCall: Boolean, senderId: String?, callId: String?) {
        val manager = getSystemService(NotificationManager::class.java)
        val target = if (isCall) "call" else "reply"
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("target", target)
            putExtra("sender_id", senderId)
            putExtra("call_id", callId)
        }
        val openPending = PendingIntent.getActivity(this, if (isCall) 501 else 502, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val builder = NotificationCompat.Builder(this, if (isCall) CALL_CHANNEL else MESSAGE_CHANNEL)
            .setSmallIcon(android.R.drawable.sym_action_call.takeIf { isCall } ?: android.R.drawable.sym_action_email)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openPending)
            .setAutoCancel(!isCall)
            .setPriority(if (isCall) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_HIGH)
            .setCategory(if (isCall) NotificationCompat.CATEGORY_CALL else NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(false)

        if (isCall) {
            val answer = actionIntent("answer", senderId, callId, 511)
            val reject = actionIntent("reject", senderId, callId, 512)
            builder.addAction(android.R.drawable.sym_action_call, "Answer", answer)
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", reject)
            builder.setOngoing(true)
            builder.setFullScreenIntent(openPending, true)
        } else {
            val replyIntent = actionIntent("reply", senderId, null, 513)
            val remoteInput = androidx.core.app.RemoteInput.Builder(ReplyReceiver.KEY_TEXT)
                .setLabel("Write a reply…").build()
            val replyAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_send, "Reply", replyIntent
            ).addRemoteInput(remoteInput).setAllowGeneratedReplies(true).build()
            builder.addAction(replyAction)
        }
        manager.notify(if (isCall) CALL_NOTIFICATION_ID else (System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }

    private fun actionIntent(action: String, senderId: String?, callId: String?, requestCode: Int): PendingIntent {
        val intent = Intent(this, CallActionReceiver::class.java).apply {
            this.action = action
            putExtra("action", action)
            putExtra("sender_id", senderId)
            putExtra("call_id", callId)
        }
        return PendingIntent.getBroadcast(this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
    }

    companion object {
        const val CALL_CHANNEL = "sft_calls_v2"
        const val MESSAGE_CHANNEL = "sft_messages_v2"
        const val CALL_NOTIFICATION_ID = 7501

        fun callChannel(): NotificationChannel {
            val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            return NotificationChannel(CALL_CHANNEL, "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Incoming SocialfreeText calls"
                setSound(sound, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 900, 400, 900, 400, 1200)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(false)
            }
        }

        fun messageChannel(): NotificationChannel {
            return NotificationChannel(MESSAGE_CHANNEL, "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "New SocialfreeText messages"
                enableVibration(true)
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }
        }
    }
}
