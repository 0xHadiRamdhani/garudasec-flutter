import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'security_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();
  final SecurityService _securityService = SecurityService();

  Stream<User?> get user => _auth.authStateChanges();

  // Sign Up
  Future<User?> signUp(String email, String password, String username) async {
    try {
      // 1. Create User in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // 2. Generate RSA Keys locally
        await _securityService.generateAndStoreKeys();

        // 3. Get Public Key
        String? publicKey = await _securityService.getPublicKey();

        if (publicKey != null) {
          // 4. Save User Profile with Public Key to Firestore
          await _dbService.saveUser(user.uid, email, username, publicKey);
        } else {
          // Handle error: Keys not generated
          await user.delete(); // Rollback
          return null;
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign up';
    } catch (e) {
      throw 'An error occurred';
    }
  }

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // NOTE: On new device, we might need to regenerate keys or import them.
      // For this "GarudaSec" demo, we assume keys are device-bound (True E2EE).
      // If user logs in on new device, they might lose history or need to regenerate keys.
      // Here we check if keys exist, if not, generate them (but old messages won't be readable).

      await _securityService.generateAndStoreKeys();
      // Update public key in Firestore if it changed?
      // For simplicity, we keep original flow. If keys are missing, generate new ones.

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign in';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
