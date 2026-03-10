import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();
  final _securityService = SecurityService();
  final _dbService = DatabaseService();
  final _imagePicker = ImagePicker();

  bool _biometricEnabled = true;
  String _publicKeyShort = "Loading...";

  // Profile State
  bool _isLoadingProfile = true;
  String? _username;
  String? _photoUrl;
  File? _newProfileImage;
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _username = doc.data()?['username'];
            _photoUrl = doc.data()?['photo_url'];
            _usernameController.text = _username ?? '';
            _isLoadingProfile = false;
          });
        } else {
          if (mounted) setState(() => _isLoadingProfile = false);
        }
      } catch (e) {
        debugPrint("Error loading profile: $e");
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      debugPrint("Attempting to pick image...");
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );

      if (pickedFile != null) {
        debugPrint("Image picked successfully: ${pickedFile.path}");
        setState(() {
          _newProfileImage = File(pickedFile.path);
        });
      } else {
        debugPrint("Image picking cancelled by user");
      }
    } catch (e) {
      debugPrint("EXCEPTION picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingProfile = true);

    try {
      String? newPhotoUrl;
      if (_newProfileImage != null) {
        newPhotoUrl = await _dbService.uploadProfileImage(
          user.uid,
          _newProfileImage!,
        );
      }

      await _dbService.updateUserProfile(
        user.uid,
        username: _usernameController.text.trim(),
        photoUrl: newPhotoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        setState(() {
          if (newPhotoUrl != null) _photoUrl = newPhotoUrl;
          _username = _usernameController.text.trim();
          _newProfileImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadSettings() async {
    final bioParams = await _storage.read(key: 'biometric_enabled');
    final key = await _securityService.getPublicKey();

    if (mounted) {
      setState(() {
        _biometricEnabled = bioParams != 'false';
        if (key != null) {
          final cleanKey = key
              .replaceAll('-----BEGIN PUBLIC KEY-----', '')
              .replaceAll('-----END PUBLIC KEY-----', '')
              .replaceAll('\n', '');
          _publicKeyShort = cleanKey.length > 20
              ? "${cleanKey.substring(0, 10)}...${cleanKey.substring(cleanKey.length - 10)}"
              : cleanKey;
        } else {
          _publicKeyShort = "Not Generated";
        }
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    await _storage.write(key: 'biometric_enabled', value: value.toString());
    setState(() => _biometricEnabled = value);
  }

  void _copyUid() {
    Clipboard.setData(ClipboardData(text: _auth.currentUser?.uid ?? ""));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("UID copied to clipboard")));
  }

  @override
  Widget build(BuildContext context) {
    // Redefining build to include profile editing
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoadingProfile ? null : _saveProfile,
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSectionHeader("Identity"),
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    backgroundImage: _newProfileImage != null
                        ? FileImage(_newProfileImage!)
                        : (_photoUrl != null ? NetworkImage(_photoUrl!) : null)
                              as ImageProvider?,
                    child: (_newProfileImage == null && _photoUrl == null)
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            size: 50,
                            color: Colors.redAccent,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                prefixIcon: Icon(CupertinoIcons.person),
              ),
            ),
          ),
          ListTile(
            title: Text(user?.email ?? "Unknown"),
            subtitle: Text("UID: ${user?.uid.substring(0, 8)}..."),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: _copyUid,
            ),
          ),

          _buildSectionHeader("Security"),
          SwitchListTile(
            secondary: const Icon(
              CupertinoIcons.lock_shield,
              color: Colors.redAccent,
            ),
            // activeColor removed (deprecated), relies on Theme
            title: const Text("Biometric Lock"),
            subtitle: const Text("Require authentication on startup"),
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
          ),
          ListTile(
            leading: const Icon(
              CupertinoIcons.barcode,
              color: Colors.redAccent,
            ),
            title: const Text("Public Key Fingerprint"),
            subtitle: Text(
              _publicKeyShort,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            ),
            onTap: () {},
          ),

          _buildSectionHeader("Application"),
          const ListTile(
            leading: Icon(CupertinoIcons.info, color: Colors.redAccent),
            title: Text("Version"),
            subtitle: Text("1.0.0 (GarudaSec Build)"),
          ),

          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton(
              onPressed: () {
                AuthService().signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF330000),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text("NO ESCAPE (LOG OUT)"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          fontSize: 12,
          shadows: [Shadow(color: Colors.red, blurRadius: 5)],
        ),
      ),
    );
  }
}
