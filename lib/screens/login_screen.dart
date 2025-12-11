import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  
  final _xtreamUrlController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();

  bool _isLoading = false;
  int _currentIndex = 0; // Para controlar la vista sin TabBarView 'expanded'

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
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF0D1B2A), // Opcional: Asegurar fondo oscuro si es necesario
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500), // Evita que se estire demasiado en tablets/PC
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.tv, size: 60, color: Colors.amber),
                  const SizedBox(height: 10),
                  const Text("LotusPlay", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
                  const Text("@Kinglotusp", style: TextStyle(fontSize: 14, color: Colors.white54)),
                  const SizedBox(height: 30),
                  
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.amber,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: "Xtream Codes"),
                      Tab(text: "M3U Playlist"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Mostramos el formulario directamente para permitir scroll completo de la página
                  // Esto arregla el problema del teclado ocultando input en horizontal
                  _currentIndex == 0 ? _buildXtreamForm() : _buildM3uForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildXtreamForm() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: "Nombre de la Cuenta", prefixIcon: Icon(Icons.label)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _xtreamUrlController,
          decoration: const InputDecoration(labelText: "URL del Servidor (http://...)", prefixIcon: Icon(Icons.link)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _xtreamUserController,
          decoration: const InputDecoration(labelText: "Usuario", prefixIcon: Icon(Icons.person)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _xtreamPassController,
          decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)),
          obscureText: true,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginXtream,
            child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("INICIAR SESIÓN"),
          ),
        )
      ],
    );
  }
  
  Widget _buildM3uForm() {
    return Column(
      children: [
        TextField(
           controller: _nameController, // Reuse name controller
           decoration: const InputDecoration(labelText: "Nombre de la Lista", prefixIcon: Icon(Icons.label)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(labelText: "URL M3U", prefixIcon: Icon(Icons.link)),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginM3u,
            child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("CARGAR LISTA"),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
           onPressed: () async {
             final Uri url = Uri.parse("https://t.me/LotusIptvFREE");
             if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir Telegram")));
             }
           },
           child: const Text("Obtener Listas Gratis", style: TextStyle(color: Colors.amber)),
        )
      ],
    );
  }

  Future<void> _loginXtream() async {
    setState(() => _isLoading = true);
    final url = _xtreamUrlController.text.trim();
    final user = _xtreamUserController.text.trim();
    final pass = _xtreamPassController.text.trim();
    final name = _nameController.text.trim();

    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos")));
      setState(() => _isLoading = false);
      return;
    }

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credenciales Inválidas")));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loginM3u() async {
     setState(() => _isLoading = true);
     final url = _urlController.text.trim();
     final name = _nameController.text.trim();
     
     if (url.isEmpty) {
        setState(() => _isLoading = false);
        return;
     }

     // Attempt to parse as Xtream Codes URL
     try {
       final uri = Uri.parse(url);
       final user = uri.queryParameters['username'];
       final pass = uri.queryParameters['password'];
       
       if (user != null && pass != null) {
          String baseUrl = "${uri.scheme}://${uri.host}";
          if (uri.hasPort) {
            baseUrl += ":${uri.port}";
          }

          // Validate as Xtream
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
