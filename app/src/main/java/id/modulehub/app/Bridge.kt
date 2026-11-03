package id.modulehub.app

import android.content.Context
import android.webkit.JavascriptInterface
import android.webkit.WebView
import com.topjohnwu.superuser.Shell
import org.json.JSONObject

/** Jembatan JS bernama "ksu" (bentuknya sama dengan WebUI KernelSU) sehingga halaman WebUI jalan tanpa diubah. */
class Bridge(ctx: Context, private val web: WebView) {
    private val engine: String = Engine.dir(ctx).absolutePath
    private val cbName = Regex("[A-Za-z0-9_]+")

    @JavascriptInterface
    fun moduleDir(): String = engine

    @JavascriptInterface
    fun exec(cmd: String, options: String, callback: String) {
        if (!cbName.matches(callback)) return
        if (!Engine.allowed(cmd, engine)) {
            reply(callback, 126, "", "perintah ditolak")
            return
        }
        Shell.cmd(cmd).submit { r ->
            reply(callback, r.code, r.out.joinToString("\n"), r.err.joinToString("\n"))
        }
    }

    private fun reply(cb: String, code: Int, out: String, err: String) {
        val js = "window['$cb'] && window['$cb']($code, ${JSONObject.quote(out)}, ${JSONObject.quote(err)})"
        web.post { web.evaluateJavascript(js, null) }
    }
}
