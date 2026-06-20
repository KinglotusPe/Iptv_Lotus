import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _xtreamFormKey = GlobalKey<FormState>();
  final _m3uFormKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  
  final _xtreamUrlController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();

  bool _isLoading = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentIndex) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _xtreamUrlController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    
    Widget logoColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.play_circle_filled, size: 70, color: Color(0xFFFFB703)),
        const SizedBox(height: 10),
        Text(
          "LotusPlay",
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFB703),
            letterSpacing: 1.2,
          ),
        ),
        Text(
          "IPTV Premium Player",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    Widget formCard = Card(
      elevation: 8,
      color: const Color(0xFF151F32).withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF233554), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFFB703),
              labelColor: const Color(0xFFFFB703),
              unselectedLabelColor: Colors.white38,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: "Xtream Codes"),
                Tab(text: "Lista M3U"),
              ],
            ),
            const SizedBox(height: 16),
            keyboardOpen || !isLandscape
                ? AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _currentIndex == 0 ? _buildXtreamForm() : _buildM3uForm(),
                  )
                : Flexible(
                    child: SingleChildScrollView(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _currentIndex == 0 ? _buildXtreamForm() : _buildM3uForm(),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );

    Widget content;
    if (isLandscape) {
      if (keyboardOpen) {
        content = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: formCard,
          ),
        );
      } else {
        content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: logoColumn,
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 6,
                child: formCard,
              ),
            ],
          ),
        );
      }
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              logoColumn,
              const SizedBox(height: 20),
              formCard,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090D16), // Deep Space Black/Blue
              Color(0xFF0F172A), // Slate Dark
              Color(0xFF1E1E2F), // Muted Purple-Black
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildXtreamForm() {
    return Form(
      key: _xtreamFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Nombre de la Cuenta (Opcional)",
              prefixIcon: Icon(Icons.label, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _xtreamUrlController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: "URL del Servidor",
              hintText: "http://ejemplo.com:8080",
              prefixIcon: Icon(Icons.link, color: Colors.white54),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "La URL es obligatoria";
              }
              final val = value.trim();
              if (!val.startsWith('http://') && !val.startsWith('https://')) {
                return "Debe iniciar con http:// o https://";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _xtreamUserController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Usuario",
              prefixIcon: Icon(Icons.person, color: Colors.white54),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? "El usuario es obligatorio" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _xtreamPassController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Contraseña",
              prefixIcon: Icon(Icons.lock, color: Colors.white54),
            ),
            obscureText: true,
            validator: (value) => (value == null || value.trim().isEmpty) ? "La contraseña es obligatoria" : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginXtream,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Text("INICIAR SESIÓN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildM3uForm() {
    return Form(
      key: _m3uFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Nombre de la Lista (Opcional)",
              prefixIcon: Icon(Icons.label, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: "URL de la Lista M3U",
              hintText: "http://servidor.com/lista.m3u",
              prefixIcon: Icon(Icons.link, color: Colors.white54),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "La URL M3U es obligatoria";
              }
              final val = value.trim();
              if (!val.startsWith('http://') && !val.startsWith('https://')) {
                return "Debe iniciar con http:// o https://";
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginM3u,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Text("CARGAR LISTA", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.telegram, color: Color(0xFFFFB703)),
            onPressed: () async {
              final Uri url = Uri.parse("https://t.me/LotusIptvFREE");
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No se pudo abrir el canal de Telegram")),
                  );
                }
              }
            },
            label: Text("Obtener Listas Gratis", style: GoogleFonts.inter(color: const Color(0xFFFFB703), fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  Future<void> _loginXtream() async {
    if (!_xtreamFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final url = _xtreamUrlController.text.trim();
    final user = _xtreamUserController.text.trim();
    final pass = _xtreamPassController.text.trim();
    final name = _nameController.text.trim();

    final isValid = await ApiService.validateXtream(url, user, pass);
    if (isValid) {
      final account = Account(
        name: name.isEmpty ? user : name,
        url: url,
        username: user,
        password: pass,
        type: 'xtream',
      );
      await StorageService.saveAccount(account);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Credenciales o servidor inválido. Verifica tus datos."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loginM3u() async {
    if (!_m3uFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    
    // Intento de auto-detectar si es una URL de Xtream Codes metida como M3U
    try {
      final uri = Uri.parse(url);
      final user = uri.queryParameters['username'];
      final pass = uri.queryParameters['password'];
      
      if (user != null && pass != null) {
        String baseUrl = "${uri.scheme}://${uri.host}";
        if (uri.hasPort) {
          baseUrl += ":${uri.port}";
        }

        final isValid = await ApiService.validateXtream(baseUrl, user, pass);
        if (isValid) {
          final account = Account(
            name: name.isEmpty ? user : name,
            url: baseUrl,
            username: user,
            password: pass,
            type: 'xtream',
          );
          await StorageService.saveAccount(account);
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
          setState(() => _isLoading = false);
          return;
        }
      }
    } catch (e) {
      print("Smart M3U parse failed: $e");
    }
    
    final account = Account(
      name: name.isEmpty ? "Lista M3U" : name,
      url: url,
      type: 'm3u',
    );
    await StorageService.saveAccount(account);
    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    setState(() => _isLoading = false);
  }
}
