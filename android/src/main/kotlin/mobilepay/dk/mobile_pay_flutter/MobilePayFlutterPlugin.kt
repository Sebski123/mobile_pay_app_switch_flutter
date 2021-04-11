package mobilepay.dk.mobile_pay_flutter

import dk.mobilepay.sdk.Country
import dk.mobilepay.sdk.MobilePay
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import dk.mobilepay.sdk.model.Payment
import java.math.BigDecimal
import android.content.Intent
import io.flutter.plugin.common.PluginRegistry
import dk.mobilepay.sdk.model.FailureResult
import dk.mobilepay.sdk.model.SuccessResult
import dk.mobilepay.sdk.ResultCallback


class MobilePayFlutterPlugin {
    companion object : PluginRegistry.ActivityResultListener, MethodCallHandler {

        fun getCountry(countryCode: String): Country {
            when {
                countryCode == "fi" -> {
                    return Country.FINLAND
                }
                countryCode == "dk" -> {
                    return Country.DENMARK
                }
                else -> {
                    return Country.DENMARK
                }
            }
        }

        override fun onMethodCall(call: MethodCall, result: Result) {
            when {
                call.method == "initMobilePay" -> {
                    val merchantId = call.argument<String>("merchantId")
                    val country = call.argument<String>("country")
                    MobilePay.getInstance().init(merchantId!!, getCountry(country!!))
                    result.success(null)
                }
                call.method == "setRequestCode" -> {
                    val requestCode = call.argument<Int>("requestCode")

                    this.requestCode = requestCode!!
                    result.success(null)
                }
                call.method == "createPayment" -> {
                    val price = call.argument<Double>("productPrice")
                    val orderId = call.argument<String>("orderId")

                    val payment = Payment()
                    payment.productPrice = BigDecimal(price!!)
                    payment.orderId = orderId

                    val paymentIntent = MobilePay.getInstance().createPaymentIntent(payment)

                    registrar?.activity()?.startActivityForResult(paymentIntent, requestCode)
                    result.success(null)
                }
                call.method == "downloadMobilePay" -> {
                    val intent = MobilePay.getInstance().createDownloadMobilePayIntent(registrar?.context()?.applicationContext!!)
                    registrar?.activity()?.startActivity(intent)
                    result.success(null)
                }
                call.method == "isMobilePayInstalled" -> {
                    val appContext = registrar?.context()?.applicationContext!!
                    result.success(MobilePay.getInstance().isMobilePayInstalled(appContext))
                }
                else -> result.notImplemented()
            }
        }

        override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent): Boolean {
            if (requestCode == this.requestCode) {
                MobilePay.getInstance().handleResult(resultCode, data, object : ResultCallback {
                    override fun onSuccess(result: SuccessResult) {
                        val args = mapOf("requestCode" to requestCode,
                                "amountWithdrawnFromCard" to result.amountWithdrawnFromCard.toDouble(),
                                "orderId" to result.orderId,
                                "signature" to result.signature,
                                "transactionId" to result.transactionId)
                        channel?.invokeMethod("mobilePaySuccess", args)
                    }

                    override fun onFailure(result: FailureResult) {
                        val args = mapOf("requestCode" to requestCode,
                                "orderId" to result.orderId,
                                "errorCode" to result.errorCode,
                                "errorMessage" to result.errorMessage
                        )
                        channel?.invokeMethod("mobilePayFailure", args)
                    }

                    override fun onCancel(orderId: String) {
                        val args = mapOf("requestCode" to requestCode, "orderId" to orderId)
                        channel?.invokeMethod("mobilePayCancel", args)
                    }
                })
            }
            return true
        }

        var registrar: Registrar? = null
        var channel: MethodChannel? = null
        var requestCode: Int = 1337

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            channel = MethodChannel(registrar.messenger(), "mobile_pay_flutter")
            channel?.setMethodCallHandler(this)
            registrar.addActivityResultListener(this)
            this.registrar = registrar
        }
    }
}
