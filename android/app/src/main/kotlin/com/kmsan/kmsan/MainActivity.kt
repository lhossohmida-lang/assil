package com.kmsan.kmsan

import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScanner
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * جسر إلى ماسح غوغل الرسمي (Google Code Scanner).
 *
 * لماذا هو لا mobile_scanner على أندرويد:
 *  - لا يطلب صلاحية الكاميرا إطلاقاً (المسح يجري داخل عملية خدمات غوغل).
 *  - واجهة جاهزة بزوايا ملوّنة وتركيز تلقائي وتقريب تلقائي — أدقّ بكثير
 *    من واجهة نكتبها بأنفسنا، وأسرع في القراءة من مسافة.
 * يبقى mobile_scanner احتياطاً على ويندوز وعند فشل خدمات غوغل.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "kmsan/code_scanner"

    /** حارس ضدّ ردّ مزدوج على نفس نداء MethodChannel (يرمي استثناءً في Flutter). */
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> startScan(result)
                    "prefetch" -> {
                        prefetchModule()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** تنزيل وحدة المسح مسبقاً حتى لا ينتظر البائع عند أول استعمال. */
    private fun prefetchModule() {
        try {
            val scanner: GmsBarcodeScanner = GmsBarcodeScanning.getClient(this)
            val request = ModuleInstallRequest.newBuilder()
                .addApi(scanner)
                .build()
            ModuleInstall.getClient(this).installModules(request)
        } catch (_: Throwable) {
            // لا شيء: التنزيل سيحدث عند أول مسح.
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "عملية مسح جارية بالفعل", null)
            return
        }
        pending = result

        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(
                Barcode.FORMAT_CODE_128,
                Barcode.FORMAT_CODE_39,
                Barcode.FORMAT_CODE_93,
                Barcode.FORMAT_EAN_13,
                Barcode.FORMAT_EAN_8,
                Barcode.FORMAT_UPC_A,
                Barcode.FORMAT_UPC_E,
                Barcode.FORMAT_ITF,
                Barcode.FORMAT_QR_CODE,
            )
            .enableAutoZoom()
            .build()

        try {
            GmsBarcodeScanning.getClient(this, options)
                .startScan()
                .addOnSuccessListener { barcode ->
                    reply { it.success(barcode.rawValue) }
                }
                .addOnCanceledListener {
                    // إلغاء المستخدم ليس خطأً — null يعني «لم يُقرأ شيء».
                    reply { it.success(null) }
                }
                .addOnFailureListener { e ->
                    reply { it.error("SCAN_FAILED", e.message, null) }
                }
        } catch (e: Throwable) {
            reply { it.error("SCAN_UNAVAILABLE", e.message, null) }
        }
    }

    private inline fun reply(block: (MethodChannel.Result) -> Unit) {
        val r = pending ?: return
        pending = null
        block(r)
    }
}
