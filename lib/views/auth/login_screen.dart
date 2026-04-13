// lib/views/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:album_filmes_app/views/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // BUG FIX: Tradução completa dos códigos de erro do Firebase Auth para pt-BR.
  // Versões mais recentes do Firebase usam 'invalid-credential' ao invés de
  // 'user-not-found' / 'wrong-password' por motivos de segurança.
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Não encontramos uma conta com esse e-mail.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente.';
      // Firebase SDK moderno unifica credencial inválida neste código
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-mail ou senha incorretos. Verifique e tente novamente.';
      case 'invalid-email':
        return 'E-mail inválido. Verifique e tente novamente.';
      case 'user-disabled':
        return 'Essa conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      case 'operation-not-allowed':
        return 'Login por e-mail não está habilitado no momento.';
      default:
        return 'Não foi possível fazer login. Tente novamente.';
    }
  }

  Future<void> _forgotPassword({String? prefilledEmail}) async {
    final emailController = TextEditingController(text: prefilledEmail ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        bool isSending = false;
        // BUG FIX: A mensagem de erro do dialog agora é exibida dentro do próprio
        // dialog (usando setStateDialog), e não mais no formulário de login,
        // que era o comportamento anterior incorreto.
        String dialogError = '';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> send() async {
              final email = emailController.text.trim();

              if (email.isEmpty) {
                setStateDialog(() {
                  dialogError = 'Digite seu e-mail para recuperar a senha.';
                });
                return;
              }
              if (!email.contains('@')) {
                setStateDialog(() {
                  dialogError = 'Digite um e-mail válido.';
                });
                return;
              }

              setStateDialog(() {
                isSending = true;
                dialogError = '';
              });

              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);

                if (!context.mounted) return;
                Navigator.pop(context);

                // Exibe confirmação no formulário de login
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'E-mail de recuperação enviado. Verifique sua caixa de entrada.'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                // BUG FIX: Erro agora é exibido dentro do dialog, não no setState do login
                String msg;
                switch (e.code) {
                  case 'user-not-found':
                    msg = 'Não encontramos uma conta com esse e-mail.';
                    break;
                  case 'invalid-email':
                    msg = 'E-mail inválido. Verifique e tente novamente.';
                    break;
                  case 'too-many-requests':
                    msg = 'Muitas tentativas. Tente novamente mais tarde.';
                    break;
                  case 'network-request-failed':
                    msg = 'Sem conexão. Verifique sua internet e tente novamente.';
                    break;
                  default:
                    msg = 'Não foi possível enviar o e-mail. Tente novamente.';
                }
                setStateDialog(() {
                  dialogError = msg;
                });
              } catch (_) {
                setStateDialog(() {
                  dialogError = 'Erro inesperado. Tente novamente.';
                });
              } finally {
                setStateDialog(() => isSending = false);
              }
            }

            return AlertDialog(
              backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
              title: const Text(
                'Recuperar senha',
                style: TextStyle(
                    color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFFFFD700)),
                    cursorColor: const Color(0xFFFFD700),
                    decoration: InputDecoration(
                      hintText: 'Digite seu e-mail',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Color(0xFFFFD700), width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => isSending ? null : send(),
                  ),
                  // BUG FIX: Mensagem de erro exibida corretamente dentro do dialog
                  if (dialogError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dialogError,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0D1B2A),
                  ),
                  onPressed: isSending ? null : send,
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        // BUG FIX: Usa o método centralizado de tradução de erros
        setState(() {
          _errorMessage = _friendlyAuthError(e);
        });
      } catch (e) {
        // BUG FIX: loga o erro real para facilitar diagnóstico futuro.
        // Causa mais comum: Firebase não inicializado (API key ausente/inválida).
        debugPrint('[Login] Erro inesperado: $e');
        setState(() {
          _errorMessage = 'Erro inesperado ao fazer login. Tente novamente.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromRGBO(11, 18, 34, 1.0),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo_tiny.png', width: 300, height: 300),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                              hintText: 'Seu email',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira seu email';
                              }
                              if (!value.contains('@')) {
                                return 'Por favor, insira um email válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Senha',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                              hintText: 'Sua senha',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira sua senha';
                              }
                              if (value.length < 6) {
                                return 'A senha deve ter pelo menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _forgotPassword(
                                  prefilledEmail: _emailController.text),
                              child: const Text(
                                'Esqueceu sua senha?',
                                style: TextStyle(color: Color(0xFFFFD700)),
                              ),
                            ),
                          ),
                          // BUG FIX: Mensagem de erro exibida com visual adequado
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF0D1B2A)),
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        color: Color(0xFF0D1B2A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/signup');
                              },
                              child: const Text(
                                'Ainda não tem conta? Cadastre-se',
                                style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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
