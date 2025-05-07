import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected sign in error: $e');
      rethrow;
    }
  }

  // Sign in with username and password
  Future<UserCredential> signInWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    try {
      // Find the email associated with the username
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this username.',
        );
      }

      // Get the email from the user document
      final userDoc = querySnapshot.docs.first;
      final email = userDoc.get('email') as String?;

      if (email == null) {
        throw FirebaseAuthException(
          code: 'invalid-user',
          message: 'User account is incomplete. Please contact support.',
        );
      }

      // Sign in with the email
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in with username error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected sign in with username error: $e');
      rethrow;
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      // Check if username is already taken
      final usernameExists = await _isUsernameTaken(username);
      if (usernameExists) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'The username is already taken.',
        );
      }

      // Create the user account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Initialize user document in Firestore with default settings
      await _createUserDocument(credential.user!.uid, username, email);

      // Update display name in Firebase Auth
      await credential.user!.updateDisplayName(username);

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Create user error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected create user error: $e');
      rethrow;
    }
  }

  // Check if username is already taken
  Future<bool> _isUsernameTaken(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if username is taken: $e');
      // Default to true if there's an error to prevent duplicate usernames
      return true;
    }
  }

  // Initialize user document with default settings
  // Update in AuthService._createUserDocument
  Future<void> _createUserDocument(String uid, String username, String email) async {
    try {
      // Add a delay to ensure auth state is fully established
      await Future.delayed(Duration(milliseconds: 500));

      await _firestore.collection('users').doc(uid).set({
        'username': username.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isMonthly': true, // Default to monthly budget
        'darkMode': false, // Default to light mode
      });

      // Verify document was written successfully
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (!docSnapshot.exists) {
        debugPrint('Warning: User document not created successfully');
      }
    } catch (e) {
      debugPrint('Error creating user document: $e');
      // Don't rethrow - we don't want account creation to fail if this fails
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);

        // Also update the display name in Firestore
        if (displayName != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'username': displayName.trim(),
          });
        }
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }
}