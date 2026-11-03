package id.modulehub.app

import android.content.Context
import java.io.File

/** Menyalin skrip mesin dari assets ke penyimpanan privat aplikasi (dibaca oleh root). */
object Engine {
    const val CONF = "/data/adb/modulehub_game_boost.conf"

    fun dir(ctx: Context): File = File(ctx.filesDir, "engine")

    /** Selalu disalin ulang agar skrip ikut ter-update bersama aplikasi (ukurannya kecil). */
    fun install(ctx: Context) {
        val d = dir(ctx)
        d.mkdirs()
        val names = ctx.assets.list("engine") ?: return
        for (name in names) {
            val out = File(d, name)
            ctx.assets.open("engine/$name").use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            }
            out.setReadable(true, false)
            out.setExecutable(true, false)
        }
    }

    /**
     * Hanya perintah yang dipakai WebUI sendiri yang boleh dijalankan sebagai root:
     * skrip mesin di folder aplikasi, dan membaca file konfigurasi.
     * Karakter pengalihan/penyambung perintah ditolak.
     */
    fun allowed(cmd: String, dir: String): Boolean {
        if (cmd.isEmpty() || cmd.length > 4000) return false
        if (cmd == "cat $CONF 2>/dev/null") return true
        if (cmd.any { it == ';' || it == '|' || it == '&' || it == '`' || it == '<' || it == '>' || it == '\n' || it == '\r' }) return false
        if (cmd.contains("$(")) return false
        return cmd.startsWith("sh $dir/")
    }
}
