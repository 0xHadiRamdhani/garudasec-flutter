import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();
  final _securityService = SecurityService();

  bool _biometricEnabled = true;
  String _publicKeyShort = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bioParams = await _storage.read(key: 'biometric_enabled');
    final key = await _securityService.getPublicKey();

    if (mounted) {
      setState(() {
        _biometricEnabled = bioParams != 'false'; // Default to true if not set
        if (key != null) {
          // Remove PEM headers for cleaner display
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
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          _buildSectionHeader("Identity"),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.redAccent,
              ),
            ),
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
            activeColor: Colors.redAccent,
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
            onTap: () {
              // Could show full key dialog here
            },
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
                backgroundColor: const Color(
                  0xFF330000,
                ), // Darker red for danger
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
