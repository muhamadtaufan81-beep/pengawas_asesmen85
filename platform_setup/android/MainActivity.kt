package id.sch.sman85jkt.pengawas

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Blokir screenshot, perekaman layar, dan pratinjau di daftar aplikasi terbaru,
        // agar alamat/isi halaman tidak bisa dipotret oleh pengawas.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
