package id.modulehub.app

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import com.topjohnwu.superuser.Shell

class MainActivity : Activity() {
    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        web = WebView(this)
        web.fitsSystemWindows = true
        setContentView(web)

        val s = web.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true
        s.allowContentAccess = false
        s.allowFileAccessFromFileURLs = false
        s.allowUniversalAccessFromFileURLs = false

        // Halaman hanya boleh dari aset aplikasi; semua navigasi lain diblokir.
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean = true
        }

        Engine.install(this)

        Shell.getShell { shell ->
            if (shell.isRoot) {
                web.addJavascriptInterface(Bridge(this, web), "ksu")
                web.loadUrl("file:///android_asset/webroot/index.html")
            } else {
                showNoRoot()
            }
        }
    }

    private fun showNoRoot() {
        val html = """
            <html><body style="font-family:sans-serif;padding:28px;background:#0e1013;color:#e8eaed">
            <h2>Akses root dibutuhkan</h2>
            <p>ModuleHub mengatur CPU, GPU, memori, dan layar, jadi butuh akses root.</p>
            <p>Beri izin root ke ModuleHub di Magisk, KernelSU, atau APatch, lalu buka aplikasi ini lagi.</p>
            </body></html>
        """.trimIndent()
        web.loadDataWithBaseURL(null, html, "text/html", "utf-8", null)
    }

    override fun onDestroy() {
        web.removeJavascriptInterface("ksu")
        super.onDestroy()
    }
}
