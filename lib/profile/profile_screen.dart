import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../views/auth/login_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isSaving = false;
  String _displayName = '';
  String _photoUrl = '';

  User? get _user => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) return;

    setState(() {
      _displayName = user.displayName ?? '';
      _photoUrl = user.photoURL ?? '';
    });

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!mounted || data == null) return;

      setState(() {
        _displayName = (data['name'] ?? _displayName).toString();
        _photoUrl = (data['photoUrl'] ?? _photoUrl).toString();
      });
    } catch (_) {
      // mantém fallback do Auth
    }
  }

  Future<void> _updateProfile(
      {String? name, String? photoUrl, bool manageLoading = true}) async {
    final user = _user;
    if (user == null) return;

    if (manageLoading) setState(() => _isSaving = true);
    try {
      final newName = (name ?? _displayName).trim();
      final newPhoto = (photoUrl ?? _photoUrl).trim();

      await user.updateDisplayName(newName.isEmpty ? null : newName);
      await user.updatePhotoURL(newPhoto.isEmpty ? null : newPhoto);

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': newName,
        'email': user.email,
        'photoUrl': newPhoto,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _photoUrl = newPhoto;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar perfil: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o perfil.')),
      );
    } finally {
      if (manageLoading && mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _displayName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar nome',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'Seu nome',
              hintStyle: TextStyle(color: Colors.white54)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _updateProfile(name: controller.text);
            },
            child: const Text('Salvar',
                style: TextStyle(color: Color(0xFF0D1B2A))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhotoFromGallery() async {
    final user = _user;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null) return;

      setState(() => _isSaving = true);

      final file = File(picked.path);
      final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
      final fileExt = ext.isEmpty ? 'jpg' : ext;
      final ref = FirebaseStorage.instance.ref().child(
          'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt');

      final snapshot = await ref.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _updateProfile(photoUrl: downloadUrl, manageLoading: false);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar foto: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível escolher a foto.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showPhotoUrlDialog() async {
    final controller = TextEditingController(text: _photoUrl);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Adicionar/alterar foto (URL)',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'https://...',
              hintStyle: TextStyle(color: Colors.white54)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _updateProfile(photoUrl: controller.text);
            },
            child: const Text('Salvar',
                style: TextStyle(color: Color(0xFF0D1B2A))),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto() async {
    await _updateProfile(photoUrl: '');
  }

  Future<void> _changePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alterar senha',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Nova senha',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                  labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            onPressed: () async {
              final current = currentController.text.trim();
              final next = newController.text.trim();
              final confirm = confirmController.text.trim();

              if (next.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Nova senha deve ter ao menos 6 caracteres.')),
                );
                return;
              }
              if (next != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Confirmação de senha não confere.')),
                );
                return;
              }

              final user = _user;
              if (user == null || user.email == null) return;

              try {
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: current,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(next);

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Senha alterada com sucesso!')),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          e.message ?? 'Não foi possível alterar a senha.')),
                );
              }
            },
            child: const Text('Alterar',
                style: TextStyle(color: Color(0xFF0D1B2A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? 'Sem e-mail';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        title: const Text(
          'Minha Conta',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                ProfilePic(
                  photoUrl: _photoUrl,
                  onChangePhoto: _pickPhotoFromGallery,
                ),
                const SizedBox(height: 12),
                Text(
                  _displayName.isEmpty ? 'Usuário' : _displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ProfileMenu(
                  text: 'Editar nome',
                  iconData: Icons.badge,
                  press: _showEditNameDialog,
                ),
                ProfileMenu(
                  text: 'Escolher foto da galeria',
                  iconData: Icons.photo_library,
                  press: _pickPhotoFromGallery,
                ),
                ProfileMenu(
                  text: 'Inserir URL da foto',
                  iconData: Icons.link,
                  press: _showPhotoUrlDialog,
                ),
                ProfileMenu(
                  text: 'Remover foto',
                  iconData: Icons.delete_outline,
                  press: _removePhoto,
                ),
                ProfileMenu(
                  text: 'Alterar senha',
                  iconData: Icons.lock_reset,
                  press: _changePasswordDialog,
                ),
                ProfileMenu(
                  text: 'Preferências',
                  iconData: Icons.settings,
                  press: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    );
                  },
                ),
                ProfileMenu(
                  text: 'Log Out',
                  iconData: Icons.logout,
                  press: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfilePic extends StatelessWidget {
  const ProfilePic({
    super.key,
    required this.photoUrl,
    required this.onChangePhoto,
  });

  final String photoUrl;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (photoUrl.trim().isNotEmpty) {
      imageProvider = NetworkImage(photoUrl.trim());
    } else {
      imageProvider = const AssetImage('assets/icons/user.jpg');
    }
    return SizedBox(
      height: 115,
      width: 115,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(backgroundImage: imageProvider),
          Positioned(
            right: -16,
            bottom: 0,
            child: SizedBox(
              height: 46,
              width: 46,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: const BorderSide(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFF5F6F9),
                ),
                onPressed: onChangePhoto,
                child: SvgPicture.string(cameraIcon),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    super.key,
    required this.text,
    required this.iconData,
    this.press,
  });

  final String text;
  final IconData? iconData;
  final VoidCallback? press;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFD700),
          padding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: const Color(0xFFF5F6F9),
        ),
        onPressed: press,
        child: Row(
          children: [
            Icon(iconData, color: const Color.fromRGBO(11, 18, 34, 1.0)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF757575),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF757575),
            ),
          ],
        ),
      ),
    );
  }
}

const cameraIcon =
    '''<svg width="20" height="16" viewBox="0 0 20 16" fill="none" xmlns="http://www.w3.org/2000/svg">
<path fill-rule="evenodd" clip-rule="evenodd" d="M10 12.0152C8.49151 12.0152 7.26415 10.8137 7.26415 9.33902C7.26415 7.86342 8.49151 6.6619 10 6.6619C11.5085 6.6619 12.7358 7.86342 12.7358 9.33902C12.7358 10.8137 11.5085 12.0152 10 12.0152ZM10 5.55543C7.86698 5.55543 6.13208 7.25251 6.13208 9.33902C6.13208 11.4246 7.86698 13.1217 10 13.1217C12.133 13.1217 13.8679 11.4246 13.8679 9.33902C13.8679 7.25251 12.133 5.55543 10 5.55543ZM18.8679 13.3967C18.8679 14.2226 18.1811 14.8935 17.3368 14.8935H2.66321C1.81887 14.8935 1.13208 14.2226 1.13208 13.3967V5.42346C1.13208 4.59845 1.81887 3.92664 2.66321 3.92664H4.75C5.42453 3.92664 6.03396 3.50952 6.26604 2.88753L6.81321 1.41746C6.88113 1.23198 7.06415 1.10739 7.26604 1.10739H12.734C12.9358 1.10739 13.1189 1.23198 13.1877 1.41839L13.734 2.88845C13.966 3.50952 14.5755 3.92664 15.25 3.92664H17.3368C18.1811 3.92664 18.8679 4.59845 18.8679 5.42346V13.3967ZM17.3368 2.82016H15.25C15.0491 2.82016 14.867 2.69466 14.7972 2.50917L14.2519 1.04003C14.0217 0.418041 13.4113 0 12.734 0H7.26604C6.58868 0 5.9783 0.418041 5.74906 1.0391L5.20283 2.50825C5.13302 2.69466 4.95094 2.82016 4.75 2.82016H2.66321C1.19434 2.82016 0 3.98846 0 5.42346V13.3967C0 14.8326 1.19434 16 2.66321 16H17.3368C18.8057 16 20 14.8326 20 13.3967V5.42346C20 3.98846 18.8057 2.82016 17.3368 2.82016Z" fill="#757575"/>
</svg>
''';
