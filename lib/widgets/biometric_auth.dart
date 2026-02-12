import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthWrapper extends StatefulWidget {
  final Widget child;

  const BiometricAuthWrapper({super.key, required this.child});

  @override
  State<BiometricAuthWrapper> createState() => _BiometricAuthWrapperState();
}

class _BiometricAuthWrapperState extends State<BiometricAuthWrapper> {
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  bool _isFaceId = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    // Check if user disabled biometrics in settings
    final bioEnabled = await _storage.read(key: 'biometric_enabled');
    if (bioEnabled == 'false') {
      setState(() => _isAuthenticated = true);
      return;
    }

    try {
      _canCheckBiometrics =
          await auth.canCheckBiometrics && await auth.isDeviceSupported();

      if (_canCheckBiometrics) {
        final availableBiometrics = await auth.getAvailableBiometrics();
        if (availableBiometrics.contains(BiometricType.face)) {
          setState(() => _isFaceId = true);
        }
        _authenticate();
      } else {
        // Fallback or allow if no biometrics (for emulator/testing)
        setState(() => _isAuthenticated = true);
      }
    } on PlatformException catch (e) {
      debugPrint("Biometric check failed: $e");
      // Fallback
      setState(() => _isAuthenticated = true);
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access GarudaSec',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow passcode backup
        ),
      );
      setState(() => _isAuthenticated = authenticated);
    } on PlatformException catch (e) {
      debugPrint("Authentication error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isFaceId ? Icons.face_retouching_natural : Icons.lock_outline,
              size: 64,
              color: Colors.redAccent,
              shadows: const [Shadow(color: Colors.red, blurRadius: 20)],
            ),
            const SizedBox(height: 16),
            const Text(
              'GarudaSec Locked',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.red, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 16),
            if (_canCheckBiometrics)
              ElevatedButton(
                onPressed: _authenticate,
                child: Text(
                  _isFaceId ? 'Unlock with Face ID' : 'Unlock System',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
