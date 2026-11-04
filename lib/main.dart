import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ============================================================
//  TUJUAN APLIKASI
//  Membuka halaman kepengawasan TANPA memperlihatkan alamat
//  (URL/domain) kepada pengawas. Tidak ada address bar, alamat
//  tidak ditulis polos di kode, tidak muncul di pesan error,
//  dan tidak bisa disalin / dibagikan dari aplikasi.
//  Pengawas BOLEH berpindah ke aplikasi lain.
// ============================================================

// Alamat disimpan dalam bentuk teredam (XOR + base64), bukan teks polos.
// Dibuat ulang dengan tool/generate_secret.py bila alamat berubah.
const List<int> _k = [
  136, 102, 192, 32, 189, 110, 247, 31, 112, 233, 123, 231,
  55, 162, 162, 214, 168, 171, 184, 43, 220, 112, 73, 121,
];
const String _eUrl =
    '4BK0UM5U2DARmh6UWsfM+8fF1EKyFXFM4gerQc8aljEdkFWOU43BtNzK3Ea1Hg==';
const String _eHost = '6RWlU9ALmTIfhxeOWcea48LK00quBChX5R/uSdk=';

String _dec(String s) {
  final b = base64.decode(s);
  return utf8.decode(
    List<int>.generate(b.length, (i) => b[i] ^ _k[i % _k.length]),
  );
}

const String kAppTitle = 'Pengawas Asesmen Online';

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

// ============================================================
//  MAIN
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isMobile) {
    await WakelockPlus.enable(); // layar tetap menyala saat mengawasi
  }
  runApp(const PengawasApp());
}

class PengawasApp extends StatelessWidget {
  const PengawasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B5FA5),
        useMaterial3: true,
      ),
      home: const PengawasPage(),
    );
  }
}

// ============================================================
//  HALAMAN PENGAWAS
// ============================================================
class PengawasPage extends StatefulWidget {
  const PengawasPage({super.key});

  @override
  State<PengawasPage> createState() => _PengawasPageState();
}

class _PengawasPageState extends State<PengawasPage>
    with WidgetsBindingObserver {
  late final String _url = _dec(_eUrl);
  late final String _host = _dec(_eHost);

  InAppWebViewController? _web;
  double _progress = 0;
  bool _hasError = false;
  bool _blockedNotice = false;
  bool _cover = false; // penutup saat aplikasi di app switcher (iOS/Android)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tutup tampilan saat aplikasi tidak aktif, agar halaman/alamat tidak
  // terlihat di pratinjau app switcher.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobile) return;
    final inactive = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (_cover != inactive) setState(() => _cover = inactive);
  }

  bool _isAllowed(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme == 'about' || uri.scheme == 'blob' || uri.scheme == 'data') {
      return true;
    }
    if (uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    return h == _host || h.endsWith('.$_host');
  }

  void _flashBlocked() {
    if (_blockedNotice) return;
    setState(() => _blockedNotice = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _blockedNotice = false);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _progress = 0;
    });
    await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
  }

  Future<void> _goBack() async {
    if (await _web?.canGoBack() ?? false) {
      await _web?.goBack();
    }
  }

  // Mencegah pemilihan/penyalinan teks dan penyeretan tautan di halaman.
  static final UserScript _noCopyScript = UserScript(
    source: '''
      (function(){
        var s = document.createElement('style');
        s.innerHTML = '*{-webkit-user-select:none!important;user-select:none!important;-webkit-touch-callout:none!important;} input,textarea{-webkit-user-select:text!important;user-select:text!important;}';
        document.documentElement.appendChild(s);
        ['copy','cut','dragstart','contextmenu'].forEach(function(e){
          document.addEventListener(e,function(ev){
            var t = ev.target && ev.target.tagName;
            if (t==='INPUT'||t==='TEXTAREA') return;
            ev.preventDefault();
          },true);
        });
      })();
    ''',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppTitle, style: TextStyle(fontSize: 16)),
        // Sengaja TIDAK ada address bar / judul halaman web.
        actions: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_url)),
              initialUserScripts: UnmodifiableListView([_noCopyScript]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                supportZoom: false,
                useShouldOverrideUrlLoading: true,
                disableContextMenu: true,
                disableLongPressContextMenuOnLinks: true,
                allowsLinkPreview: false, // iOS: tanpa pratinjau tautan
                isInspectable: false, // iOS/macOS: tanpa Web Inspector
                transparentBackground: false,
                cacheEnabled: true,
              ),
              shouldOverrideUrlLoading: (controller, action) async {
                if (_isAllowed(action.request.url)) {
                  return NavigationActionPolicy.ALLOW;
                }
                _flashBlocked();
                return NavigationActionPolicy.CANCEL;
              },
              onCreateWindow: (controller, action) async {
                final url = action.request.url;
                if (_isAllowed(url)) {
                  controller.loadUrl(urlRequest: URLRequest(url: url));
                } else {
                  _flashBlocked();
                }
                return false;
              },
              onWebViewCreated: (c) => _web = c,
              onLoadStart: (c, u) => setState(() => _hasError = false),
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
              onReceivedError: (c, req, err) {
                if (req.isForMainFrame ?? true) {
                  // Pesan error asli sengaja tidak ditampilkan (bisa memuat alamat).
                  setState(() => _hasError = true);
                }
              },
              onPermissionRequest: (c, req) async => PermissionResponse(
                resources: req.resources,
                action: PermissionResponseAction.GRANT,
              ),
            ),

            if (_progress < 1 && !_hasError)
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),

            if (_hasError) _ErrorView(onRetry: _reload),

            if (_blockedNotice)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _Banner(
                  text: 'Tautan ke luar sistem diblokir.',
                  color: Color(0xFFB3261E),
                ),
              ),

            if (_cover)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_outline, size: 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  KOMPONEN KECIL
// ============================================================
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Tidak dapat terhubung ke server asesmen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Periksa koneksi internet, lalu coba lagi.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
