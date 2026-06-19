package com.seeknirvana.vyana

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.solana.mobilewalletadapter.clientlib.scenario.LocalAssociationIntentCreator
import com.solana.mobilewalletadapter.clientlib.scenario.LocalAssociationScenario
import com.solana.mobilewalletadapter.clientlib.scenario.Scenario
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Base64
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Native MWA bridge for Solana phones (Seeker, Saga).
 * Supports Seed Vault, Phantom, Solflare, and any other local MWA wallet.
 */
class SolanaMobileWalletHandler(private val activity: Activity) {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(
                        LocalAssociationIntentCreator.isWalletEndpointAvailable(
                            activity.packageManager,
                        ),
                    )
                }

                "listWallets" -> {
                    result.success(queryMwaWallets())
                }

                "authorize" -> {
                    val walletPackage = call.argument<String>("walletPackage")
                    val identityUri = call.argument<String>("identityUri")
                    val iconUri = call.argument<String>("iconUri")
                    val identityName = call.argument<String>("identityName")
                    val cluster = call.argument<String>("cluster")
                    authorize(
                        walletPackage,
                        identityUri,
                        iconUri,
                        identityName,
                        cluster,
                        result,
                    )
                }

                "deauthorize" -> {
                    val authToken = call.argument<String>("authToken")
                    val walletPackage = call.argument<String>("walletPackage")
                    if (authToken.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "authToken is required", null)
                        return@setMethodCallHandler
                    }
                    deauthorize(authToken, walletPackage, result)
                }

                "signAndSendTransactions" -> {
                    val authToken = call.argument<String>("authToken")
                    val walletPackage = call.argument<String>("walletPackage")
                    val transactions = call.argument<List<String>>("transactions")
                    val identityUri = call.argument<String>("identityUri")
                    val iconUri = call.argument<String>("iconUri")
                    val identityName = call.argument<String>("identityName")
                    val cluster = call.argument<String>("cluster")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: DEFAULT_WALLET_OP_TIMEOUT_MS
                    if (authToken.isNullOrBlank() || transactions.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "authToken and transactions are required", null)
                        return@setMethodCallHandler
                    }
                    signAndSendTransactions(
                        authToken,
                        walletPackage,
                        transactions,
                        identityUri,
                        iconUri,
                        identityName,
                        cluster,
                        timeoutMs.toLong(),
                        result,
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun authorize(
        walletPackage: String?,
        identityUri: String?,
        iconUri: String?,
        identityName: String?,
        cluster: String?,
        result: MethodChannel.Result,
    ) {
        Thread {
            var scenario: LocalAssociationScenario? = null
            try {
                scenario = LocalAssociationScenario(Scenario.DEFAULT_CLIENT_TIMEOUT_MS)
                val associationIntent = buildAssociationIntent(scenario, walletPackage)

                launchWalletActivity(associationIntent)
                Thread.sleep(WALLET_SERVER_READY_MS)

                Log.d(TAG, "MWA connect port=${scenario.port} wallet=$walletPackage")
                val client = scenario.start().get()
                val authResult = client.authorize(
                    identityUri?.let(Uri::parse),
                    toRelativeIconUri(iconUri, identityUri)?.let(Uri::parse),
                    identityName,
                    cluster,
                ).get()

                mainHandler.post {
                    result.success(
                        mapOf(
                            "authToken" to authResult.authToken,
                            "publicKey" to authResult.publicKey,
                            "accountLabel" to authResult.accountLabel,
                            "walletUriBase" to authResult.walletUriBase?.toString(),
                            "walletPackage" to walletPackage,
                        ),
                    )
                }
            } catch (error: Throwable) {
                Log.e(TAG, "MWA authorize failed", error)
                mainHandler.post {
                    result.error(
                        "MWA_AUTHORIZE_FAILED",
                        error.message ?: "Wallet authorization failed",
                        error.javaClass.simpleName,
                    )
                }
            } finally {
                scenario?.close()
            }
        }.start()
    }

    private fun deauthorize(
        authToken: String,
        walletPackage: String?,
        result: MethodChannel.Result,
    ) {
        Thread {
            var scenario: LocalAssociationScenario? = null
            try {
                scenario = LocalAssociationScenario(Scenario.DEFAULT_CLIENT_TIMEOUT_MS)
                val associationIntent = buildAssociationIntent(scenario, walletPackage)

                launchWalletActivity(associationIntent)
                Thread.sleep(WALLET_SERVER_READY_MS)

                val client = scenario.start().get()
                client.deauthorize(authToken).get()

                mainHandler.post {
                    result.success(null)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "MWA deauthorize failed", error)
                mainHandler.post {
                    result.error(
                        "MWA_DEAUTHORIZE_FAILED",
                        error.message ?: "Wallet deauthorization failed",
                        error.javaClass.simpleName,
                    )
                }
            } finally {
                scenario?.close()
            }
        }.start()
    }

    private fun buildAssociationIntent(
        scenario: LocalAssociationScenario,
        walletPackage: String?,
    ): Intent {
        return LocalAssociationIntentCreator.createAssociationIntent(
            null,
            scenario.port,
            scenario.session,
        ).apply {
            walletPackage?.let { setPackage(it) }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
    }

    private fun queryMwaWallets(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("solana-wallet:/v1/associate/local"))
        intent.addCategory(Intent.CATEGORY_BROWSABLE)

        val pm = activity.packageManager
        val activities = pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)

        return activities
            .mapNotNull { resolveInfo ->
                val pkg = resolveInfo.activityInfo?.packageName ?: return@mapNotNull null
                mapOf(
                    "package" to pkg,
                    "label" to (KNOWN_WALLET_LABELS[pkg]
                        ?: resolveInfo.loadLabel(pm).toString()),
                )
            }
            .distinctBy { it["package"] }
            .sortedWith(
                compareBy<Map<String, String>> {
                    when (it["package"]) {
                        SEED_VAULT_PACKAGE -> 0
                        PHANTOM_PACKAGE -> 1
                        SOLFLARE_PACKAGE -> 2
                        else -> 3
                    }
                }.thenBy { it["label"] },
            )
    }

    private fun toRelativeIconUri(iconUri: String?, identityUri: String?): String? {
        if (iconUri.isNullOrBlank()) return null
        val parsed = Uri.parse(iconUri)
        if (!parsed.isAbsolute) return iconUri
        val scheme = parsed.scheme?.lowercase()
        if (scheme == "data") return DEFAULT_ICON_FILENAME
        val identityPath = identityUri?.let { Uri.parse(it).path?.trimEnd('/') }.orEmpty()
        val iconPath = parsed.path.orEmpty().trimStart('/')
        if (identityPath.isNotEmpty() && iconPath.startsWith("$identityPath/")) {
            return iconPath.removePrefix("$identityPath/")
        }
        return iconPath.substringAfterLast('/').ifBlank { DEFAULT_ICON_FILENAME }
    }

    private fun signAndSendTransactions(
        authToken: String,
        walletPackage: String?,
        transactionsBase64: List<String>,
        identityUri: String?,
        iconUri: String?,
        identityName: String?,
        cluster: String?,
        timeoutMs: Long,
        result: MethodChannel.Result,
    ) {
        Thread {
            var scenario: LocalAssociationScenario? = null
            try {
                scenario = LocalAssociationScenario(Scenario.DEFAULT_CLIENT_TIMEOUT_MS)
                val associationIntent = buildAssociationIntent(scenario, walletPackage)

                launchWalletActivity(associationIntent)
                Thread.sleep(WALLET_SERVER_READY_MS)

                Log.d(TAG, "MWA signAndSend port=${scenario.port} wallet=$walletPackage")
                val client = scenario.start().get(timeoutMs, TimeUnit.MILLISECONDS)

                val identity = identityUri?.let(Uri::parse)
                val icon = toRelativeIconUri(iconUri, identityUri)?.let(Uri::parse)
                val authResult = authorizeForSigning(
                    client = client,
                    identityUri = identity,
                    iconUri = icon,
                    identityName = identityName,
                    cluster = cluster,
                    authToken = authToken,
                    timeoutMs = timeoutMs,
                )

                val transactions = transactionsBase64
                    .map { Base64.decode(it, Base64.DEFAULT) }
                    .toTypedArray()

                val response = client
                    .signAndSendTransactions(transactions, null)
                    .get(timeoutMs, TimeUnit.MILLISECONDS)

                if (response.signatures.isEmpty()) {
                    mainHandler.post {
                        result.error(
                            "MWA_EMPTY_SIGNATURE",
                            "Wallet did not complete the payment.",
                            null,
                        )
                    }
                    return@Thread
                }

                val signatures = response.signatures.map {
                    Base64.encodeToString(it, Base64.NO_WRAP)
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "signatures" to signatures,
                            "walletPackage" to walletPackage,
                            "publicKey" to authResult.publicKey,
                            "authToken" to authResult.authToken,
                            "authRefreshed" to authResult.refreshed,
                        ),
                    )
                }
            } catch (error: TimeoutException) {
                Log.e(TAG, "MWA signAndSend timed out", error)
                mainHandler.post {
                    result.error(
                        "MWA_TIMEOUT",
                        "Wallet did not respond in time. Open your wallet and try again.",
                        null,
                    )
                }
            } catch (error: Throwable) {
                Log.e(TAG, "MWA signAndSend failed", error)
                val message = error.message ?: "Payment failed in wallet"
                val code = when {
                    message.contains("cancel", ignoreCase = true) ||
                        message.contains("declin", ignoreCase = true) ->
                        "MWA_CANCELLED"
                    message.contains("authorization", ignoreCase = true) ->
                        "MWA_AUTH_FAILED"
                    else -> "MWA_SIGN_SEND_FAILED"
                }
                mainHandler.post {
                    result.error(code, message, error.javaClass.simpleName)
                }
            } finally {
                scenario?.close()
            }
        }.start()
    }

    private data class SigningAuthResult(
        val authToken: String,
        val publicKey: ByteArray,
        val refreshed: Boolean,
    )

    private fun authorizeForSigning(
        client: com.solana.mobilewalletadapter.clientlib.protocol.MobileWalletAdapterClient,
        identityUri: Uri?,
        iconUri: Uri?,
        identityName: String?,
        cluster: String?,
        authToken: String,
        timeoutMs: Long,
    ): SigningAuthResult {
        try {
            val reauth = client.reauthorize(
                identityUri,
                iconUri,
                identityName,
                authToken,
            ).get(timeoutMs, TimeUnit.MILLISECONDS)
            return SigningAuthResult(
                authToken = reauth.authToken,
                publicKey = reauth.publicKey,
                refreshed = false,
            )
        } catch (reauthError: Throwable) {
            Log.w(TAG, "MWA reauthorize failed, retrying with authorize", reauthError)
            val auth = client.authorize(
                identityUri,
                iconUri,
                identityName,
                cluster,
            ).get(timeoutMs, TimeUnit.MILLISECONDS)
            return SigningAuthResult(
                authToken = auth.authToken,
                publicKey = auth.publicKey,
                refreshed = true,
            )
        }
    }

    private fun launchWalletActivity(intent: Intent) {
        val latch = CountDownLatch(1)
        mainHandler.post {
            try {
                activity.startActivity(intent)
            } finally {
                latch.countDown()
            }
        }
        latch.await(LAUNCH_TIMEOUT_MS, TimeUnit.MILLISECONDS)
    }

    companion object {
        private const val TAG = "VyanaMWA"
        private const val CHANNEL = "vyana/solana_mobile_wallet"
        private const val DEFAULT_ICON_FILENAME = "logo.png"
        private const val SEED_VAULT_PACKAGE = "com.solanamobile.wallet"
        private const val PHANTOM_PACKAGE = "app.phantom"
        private const val SOLFLARE_PACKAGE = "com.solflare.mobile"
        private val KNOWN_WALLET_LABELS = mapOf(
            SEED_VAULT_PACKAGE to "Seed Vault",
            PHANTOM_PACKAGE to "Phantom",
            SOLFLARE_PACKAGE to "Solflare",
        )
        private const val WALLET_SERVER_READY_MS = 750L
        private const val LAUNCH_TIMEOUT_MS = 3000L
        private const val DEFAULT_WALLET_OP_TIMEOUT_MS = 20_000
    }
}