package id.modulehub.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.topjohnwu.superuser.Shell

/** Menyalakan kembali daemon Game Boost setelah boot (daemon sendiri tetap berjalan saat aplikasi ditutup). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Engine.install(context)
        val e = Engine.dir(context).absolutePath
        // resolusi yang tertinggal dari sesi sebelumnya selalu dikembalikan dulu
        Shell.cmd("sleep 25; [ -f /data/adb/modulehub_gb_wm ] && sh $e/display.sh reset; sh $e/tools.sh restart").submit()
    }
}
