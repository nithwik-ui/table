import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/sraap/sraap_session_manager.dart';

class SraapTestScreen extends StatefulWidget {
  const SraapTestScreen({super.key});

  @override
  State<SraapTestScreen> createState() => _SraapTestScreenState();
}

class _SraapTestScreenState extends State<SraapTestScreen> {
  final _enrollmentCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  bool _isLoading = false;
  bool _isConnected = false;

  // Discovery State
  String? _lastRequestType;
  String? _finalUrl;
  int? _statusCode;
  bool? _isRedirected;
  String? _responseHtml;
  String? _analysisResults;

  @override
  void initState() {
    super.initState();
    _fetchCaptcha();
  }

  Future<void> _fetchCaptcha() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await SraapSessionManager.instance.fetchCaptcha();
      if (bytes != null && mounted) {
        setState(() => _captchaBytes = bytes);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _responseHtml = null;
      _analysisResults = null;
    });
    try {
      final res = await SraapSessionManager.instance.login(
        enrollment: _enrollmentCtrl.text,
        password: _passwordCtrl.text,
        captcha: _captchaCtrl.text,
      );

      if (res.statusCode == 302 || res.statusCode == 301 || res.body.toLowerCase().contains('logout') || res.bodyBytes.length > 10000) {
        setState(() => _isConnected = true);
      } else {
        setState(() {
          _isConnected = false;
          _responseHtml = 'Login Failed!\nHTTP ${res.statusCode}\nRedirected: ${res.isRedirect}\nBody length: ${res.bodyBytes.length}\nSnippet: ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}\nCookie Header sent: ${SraapSessionManager.instance.cookieHeader}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData(String type, String path) async {
    setState(() {
      _isLoading = true;
      _lastRequestType = type;
      _finalUrl = 'https://sraap.in$path'; // Masking session ids just in case
      _statusCode = null;
      _isRedirected = null;
      _responseHtml = null;
      _analysisResults = null;
    });

    try {
      final res = await SraapSessionManager.instance.get(path);
      
      // Remove sensitive headers/urls from display
      final cleanUrl = res.request?.url.path ?? path;
      final isRedir = res.statusCode == 302 || res.statusCode == 301 || res.isRedirect;

      String body = res.body;
      // Snipping logic to bypass 15KB nav header
      final splitKeyword = '<strong style="color:#FFFF33">Welc';
      if (body.contains(splitKeyword)) {
        final parts = body.split(splitKeyword);
        body = parts.last;
      }

      setState(() {
        _statusCode = res.statusCode;
        _isRedirected = isRedir;
        _finalUrl = cleanUrl;
        _responseHtml = body;
        _analysisResults = _analyzeHtml(type, body);
      });
    } catch (e) {
      setState(() => _responseHtml = 'ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _analyzeHtml(String type, String html) {
    final lower = html.toLowerCase();
    final buffer = StringBuffer('Detected elements:\n\n$type:\n');
    
    if (type == 'Attendance') {
      buffer.writeln(lower.contains('overall') || lower.contains('total attendance') ? '✓ Overall attendance found' : '✗ Overall attendance NOT found');
      buffer.writeln(lower.contains('%') || lower.contains('percentage') ? '✓ Subject attendance found' : '✗ Subject attendance NOT found');
      buffer.writeln(lower.contains('present') ? '✓ Present count found' : '✗ Present count NOT found');
      buffer.writeln(lower.contains('absent') ? '✓ Absent count found' : '✗ Absent count NOT found');
    } else if (type == 'CGPA') {
      buffer.writeln(lower.contains('cgpa') || lower.contains('sgpa') ? '✓ CGPA found' : '✗ CGPA NOT found');
    } else if (type == 'Mentor') {
      buffer.writeln(lower.contains('mentor') || lower.contains('faculty') ? '✓ Mentor name found' : '✗ Mentor name NOT found');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SRAAP Academic Discovery')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'SRAAP Session Connected' : 'Not Connected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  if (!_isConnected) ...[
                    TextField(controller: _enrollmentCtrl, decoration: const InputDecoration(labelText: 'Enrollment')),
                    TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                    if (_captchaBytes != null) Image.memory(_captchaBytes!, height: 60),
                    TextButton(onPressed: _fetchCaptcha, child: const Text('Refresh Captcha')),
                    TextField(controller: _captchaCtrl, decoration: const InputDecoration(labelText: 'Captcha')),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _login, child: const Text('Login')),
                  ] else ...[
                    // Buttons
                    const Text('DASHBOARD DATA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ElevatedButton(
                      onPressed: () => _fetchData('Dashboard', '/student/dash_board.php'),
                      child: const Text('Fetch Dashboard (Contains All Data)'),
                    ),
                    const SizedBox(height: 16),
                    const Text('COURSE ATTENDANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ElevatedButton(
                      onPressed: () => _fetchData('Attendance', '/student/attendance_monthwise.php?fdoa=2020-01-01&tdoa=2028-12-31&submit=Submit'),
                      child: const Text('Fetch Course Attendance'),
                    ),
                  ],

                  const Divider(height: 32),

                  // Diagnostics Output
                  if (_lastRequestType != null) ...[
                    const Text('Discovery Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('REQUEST: $_lastRequestType'),
                    Text('FINAL URL: $_finalUrl'),
                    Text('HTTP STATUS: ${_statusCode ?? 'Unknown'}'),
                    const Text('CONTENT TYPE: text/html'),
                    Text('REDIRECTS: ${_isRedirected == true ? 'yes' : 'no'}'),
                    const Text('AUTHENTICATED: yes'),
                    const SizedBox(height: 16),
                  ],

                  if (_analysisResults != null) ...[
                    Container(
                      color: Colors.blue.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(12),
                      child: Text(_analysisResults!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_responseHtml != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Raw Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _responseHtml!));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 300,
                      color: Colors.grey[200],
                      padding: const EdgeInsets.all(8),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _responseHtml!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
