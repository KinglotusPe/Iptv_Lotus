import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.tv, size: 60, color: Colors.amber),
              const SizedBox(height: 10),
              const Text("LotusPlay", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
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
              
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Xtream Form
                    _buildXtreamForm(),
                    // M3U Form
                    _buildM3uForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXtreamForm() {
    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }
  
  Widget _buildM3uForm() {
    return SingleChildScrollView(
      child: Column(
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
             onPressed: () {}, // TODO: Show Free Lists Dialog
             child: const Text("Obtener Listas Gratis", style: TextStyle(color: Colors.amber)),
          )
        ],
      ),
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
     // Basic helper for now
     setState(() => _isLoading = true);
     final url = _urlController.text.trim();
     final name = _nameController.text.trim();
     
     if (url.isEmpty) {
        setState(() => _isLoading = false);
        return;
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
