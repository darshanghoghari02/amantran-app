package com.olive.amantran

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import android.content.Intent
import java.io.File
import android.content.Context
import android.accounts.AccountManager
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.olive.amantran/apk_share"
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep link clicks
        val action = intent.action
        val data = intent.data
        
        if (action == Intent.ACTION_VIEW && data != null) {
            // Pass the deep link to Flutter
            val flutterEngine = flutterEngine ?: return
            val messenger = flutterEngine.dartExecutor.binaryMessenger
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "handleDeepLink") {
                    result.success(data.toString())
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkPath") {
                try {
                    val apkPath = applicationContext.packageCodePath
                    result.success(apkPath)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "APK path not available.", e.message)
                }
            } else if (call.method == "openSmsApp") {
                try {
                    val context = applicationContext
                    val defaultSmsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(context)
                    val packageName = if (defaultSmsPackage != null && defaultSmsPackage.isNotEmpty()) {
                        defaultSmsPackage
                    } else {
                        "com.google.android.apps.messaging"
                    }
                    
                    val deepLinkUrl = "https://nimantran.app/invitation"
                    val message = "Check out my Wedding Invitation! $deepLinkUrl"
                    
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        setPackage(packageName)
                        data = Uri.parse("smsto:")
                        putExtra("sms_body", message)
                    }
                    this@MainActivity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    e.printStackTrace()
                    result.error("OPEN_SMS_FAILED", e.message, null)
                }
            } else if (call.method == "shareFileToPackage") {
                val filePath = call.argument<String>("filePath")
                val requestedPackageName = call.argument<String>("packageName")
                val userEmail = call.argument<String>("userEmail")
                if (filePath == null || requestedPackageName == null) {
                    result.error("INVALID_ARGUMENTS", "filePath or packageName is null", null)
                    return@setMethodCallHandler
                }
                
                val context = applicationContext
                var targetPackageName = requestedPackageName
                
                // Override with default SMS package name if the user selected messages sharing
                if (requestedPackageName == "com.google.android.apps.messaging") {
                    val defaultSmsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(context)
                    if (defaultSmsPackage != null && defaultSmsPackage.isNotEmpty()) {
                        targetPackageName = defaultSmsPackage
                    }
                }
                
                try {
                    val file = File(filePath)
                    val authority = "${context.packageName}.flutter.share_provider"
                    val uri = FileProvider.getUriForFile(this@MainActivity, authority, file)
                    
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        setPackage(targetPackageName)
                    }
                    
                    // For Gmail, try to find and suggest the correct Google account
                    if (targetPackageName == "com.google.android.gm" && userEmail != null && userEmail.isNotEmpty()) {
                        try {
                            val accountManager = AccountManager.get(context)
                            val accounts = accountManager.getAccountsByType("com.google")
                            
                            // Try to find the matching Google account
                            for (account in accounts) {
                                if (account.name.equals(userEmail, ignoreCase = true)) {
                                    // Found matching account, use it to hint Gmail
                                    intent.putExtra("android.intent.extra.ACCOUNT", account)
                                    intent.putExtra("account", account.name)
                                    break
                                }
                            }
                        } catch (e: Exception) {
                            // AccountManager might fail due to permissions, continue anyway
                            e.printStackTrace()
                        }
                    }
                    
                    this@MainActivity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    e.printStackTrace()
                    if (requestedPackageName == "com.whatsapp") {
                        try {
                            val file = File(filePath)
                            val authority = "${context.packageName}.flutter.share_provider"
                            val uri = FileProvider.getUriForFile(this@MainActivity, authority, file)
                            
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                setPackage("com.whatsapp.w4b")
                            }
                            this@MainActivity.startActivity(intent)
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e2: Exception) {
                            e2.printStackTrace()
                            result.error("SHARE_FAILED", e2.message, null)
                            return@setMethodCallHandler
                        }
                    } else if (requestedPackageName == "com.google.android.apps.messaging") {
                        val SMS_FALLBACKS = arrayOf(
                            "com.google.android.apps.messaging",
                            "com.samsung.android.messaging",
                            "com.android.mms",
                            "com.xiaomi.discover"
                        )
                        for (pkg in SMS_FALLBACKS) {
                            if (pkg == targetPackageName) continue
                            try {
                                val file = File(filePath)
                                val authority = "${context.packageName}.flutter.share_provider"
                                val uri = FileProvider.getUriForFile(this@MainActivity, authority, file)
                                
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "application/pdf"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    setPackage(pkg)
                                }
                                this@MainActivity.startActivity(intent)
                                result.success(true)
                                return@setMethodCallHandler
                            } catch (eInner: Exception) {
                                eInner.printStackTrace()
                            }
                        }
                    }
                    result.error("SHARE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
