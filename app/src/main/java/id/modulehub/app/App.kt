package id.modulehub.app

import android.app.Application
import com.topjohnwu.superuser.Shell

class App : Application() {
    companion object {
        init {
            Shell.setDefaultBuilder(Shell.Builder.create().setTimeout(20))
        }
    }
}
