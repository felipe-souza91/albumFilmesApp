import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Esse e-mail já está em uso. Tente fazer login ou use outro e-mail.';
      case 'invalid-email':
        return 'E-mail inválido. Verifique e tente novamente.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail está desativado no momento.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível criar sua conta agora. Tente novamente.';
    }
  }

  String _friendlyFirestoreError(FirebaseException e) {
    // O “The caller does not have permission…” costuma cair em permission-denied
    switch (e.code) {
      case 'permission-denied':
        return 'Não foi possível salvar seu perfil agora. Tente novamente.';
      case 'unavailable':
        return 'Serviço indisponível no momento. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Erro ao salvar seus dados. Tente novamente.';
    }
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validações simples e claras
    if (name.isEmpty) {
      _showMessage('Digite seu nome.', isError: true);
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Preencha e-mail e senha.', isError: true);
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Insira um e-mail válido.', isError: true);
      return;
    }
    if (password.trim().length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    UserCredential? userCredential;

    try {
      // 1) Cria usuário no Auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'UID ausente',
        );
      }

      // 2) Salva perfil no Firestore (use serverTimestamp)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Cadastro realizado com sucesso!');
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthError(e), isError: true);
    } on FirebaseException catch (e) {
      // Se Auth criou a conta mas Firestore falhou, evita “conta fantasma”
      // (você pode trocar isso por “continuar e salvar depois”, mas aqui é o mais seguro pro beta)
      try {
        await userCredential?.user?.delete();
      } catch (_) {}

      _showMessage(_friendlyFirestoreError(e), isError: true);
    } catch (_) {
      // fallback genérico
      try {
        await userCredential?.user?.delete();
      } catch (_) {}

      _showMessage('Erro inesperado ao cadastrar. Tente novamente.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Cadastre-se',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
      ),
      body: Container(
        color: const Color.fromRGBO(11, 18, 34, 1.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/logo_tiny.png', width: 300, height: 300),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: 'Digite seu nome',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: 'Digite seu e-mail',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: 'Digite sua senha',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _signUp(),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor:
                                  const Color.fromRGBO(11, 18, 34, 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cadastrar',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
