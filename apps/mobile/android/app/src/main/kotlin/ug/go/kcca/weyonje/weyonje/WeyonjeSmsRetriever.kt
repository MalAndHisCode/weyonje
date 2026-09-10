package ug.go.kcca.weyonje.weyonje

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** A flow-scoped, permission-protected receiver, never an inbox reader. */
class WeyonjeSmsRetriever(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "weyonje/sms_retriever")
    private var receiver: BroadcastReceiver? = null
    private var generation = 0
    private val messagePattern = Regex("^<#> Weyonje code: ([0-9]{6})\\nExpires in [0-9]+s\\. Do not share\\.\\nRef: ([0-9a-f-]{36})\\n[A-Za-z0-9+/]{11}$")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    stop()
                    generation = call.argument<Int>("generation") ?: 0
                    val active = generation
                    val listener = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            if (active != generation || intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                            val status = intent.extras?.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                            if (status.statusCode == CommonStatusCodes.SUCCESS) {
                                val body = intent.extras?.getString(SmsRetriever.EXTRA_SMS_MESSAGE) ?: return
                                val match = messagePattern.matchEntire(body) ?: return
                                channel.invokeMethod("candidate", mapOf(
                                    "generation" to active,
                                    "code" to match.groupValues[1],
                                    "challengeId" to match.groupValues[2]
                                ))
                                // A delayed superseded message must not prevent
                                // retrieval of the current challenge's message.
                                SmsRetriever.getClient(context).startSmsRetriever()
                                    .addOnFailureListener { if (active == generation) stopReceiver() }
                                return
                            }
                            stopReceiver()
                        }
                    }
                    receiver = listener
                    try {
                        ContextCompat.registerReceiver(context, listener, IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION), SmsRetriever.SEND_PERMISSION, null, ContextCompat.RECEIVER_EXPORTED)
                        SmsRetriever.getClient(context).startSmsRetriever()
                            .addOnSuccessListener { result.success(null) }
                            .addOnFailureListener {
                                if (active == generation) stopReceiver()
                                result.error("unavailable", "SMS retrieval unavailable", null)
                            }
                    } catch (_: Exception) {
                        stopReceiver()
                        result.error("unavailable", "SMS retrieval unavailable", null)
                    }
                }
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun stopReceiver() {
        receiver?.let { try { context.unregisterReceiver(it) } catch (_: IllegalArgumentException) {} }
        receiver = null
    }
    private fun stop() { generation++; stopReceiver() }
    fun dispose() { stop(); channel.setMethodCallHandler(null) }
}
