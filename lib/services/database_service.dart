import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? uid;

  // Constructor with optional user ID
  DatabaseService({this.uid}) {
    debugPrint('DatabaseService initialized with uid: $uid');
    if (uid == null) {
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current Firebase user: ${currentUser?.uid ?? 'null'}');
      logAuthState();
    }
  }

  // Get user ID (current user if not specified)
  String get userId {
    final id = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (id == null || id.isEmpty) {
      debugPrint('WARNING: Attempted to use DatabaseService with no user ID');
      throw Exception('User not authenticated. Please sign in again.');
    }
    return id;
  }

  // Collection references
  CollectionReference get usersCollection => _firestore.collection('users');
  CollectionReference get transactionsCollection =>
      usersCollection.doc(userId).collection('transactions');

  void logAuthState() {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Current auth state: ${user != null ? 'Authenticated as ${user.uid}' : 'Not authenticated'}');
  }

  // Read and write user data
  Future<UserPreferences> getUserPreferences() async {
    try {
      final doc = await usersCollection.doc(userId).get();
      return UserPreferences.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return UserPreferences(); // Return default preferences on error
    }
  }

  Future<void> updateUserPreferences(UserPreferences preferences) async {
    try {
      await usersCollection.doc(userId).set(
        preferences.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
      rethrow;
    }
  }

  // Update theme mode
  Future<void> updateThemeMode(bool isDarkMode) async {
    try {
      await usersCollection.doc(userId).set({
        'darkMode': isDarkMode,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating theme mode: $e');
      rethrow;
    }
  }

  Future<void> ensureUserDocumentExists() async {
    try {
      // Check if user document exists
      final docSnapshot = await usersCollection.doc(userId).get();

      // If document doesn't exist, create it with default values
      if (!docSnapshot.exists) {
        debugPrint('Creating new user document for $userId');
        await usersCollection.doc(userId).set({
          'totalBudget': 0.0,
          'isMonthly': true,
          // Add any other default fields you need
        });
        debugPrint('User document created successfully');
      }
    } catch (e) {
      debugPrint('Error ensuring user document exists: $e');
      rethrow;
    }
  }

  // Updates budget
  Future<void> updateBudget(double amount, bool isMonthly) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID is empty. User might not be authenticated.');
      }

      debugPrint('Updating budget for user $userId: $amount, isMonthly: $isMonthly');

      // Ensure the document exists first
      await ensureUserDocumentExists();

      await usersCollection.doc(userId).set({
        'totalBudget': amount,
        'isMonthly': isMonthly,
      }, SetOptions(merge: true));

      debugPrint('Budget update successful');
    } catch (e) {
      debugPrint('Error updating budget: $e');
      rethrow;
    }
  }

  // Add transactions
  Future<String> addTransaction(TransactionItem transaction) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID is empty. User might not be authenticated.');
      }

      debugPrint('Adding transaction for user $userId: ${transaction.name}, Amount: ${transaction.amount}');

      // Create a map for Firestore (explicit field mapping to avoid issues)
      final Map<String, dynamic> transactionData = {
        'name': transaction.name,
        'amount': transaction.amount,
        'category': transaction.category.name,
        'timestamp': Timestamp.fromDate(transaction.date),
      };

      // Use await with get() to ensure the write completes and sync happens
      final docRef = await transactionsCollection.add(transactionData);

      debugPrint('Transaction added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionItem transaction) async {
    try {
      await transactionsCollection.doc(transaction.id).update(
        transaction.toMap(),
      );
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await transactionsCollection.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Get transactions
  Stream<List<TransactionItem>> getTransactionsStream(DateRange dateRange) {
    return transactionsCollection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.endDate))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionItem.fromFirestore(doc, availableCategories))
          .toList();
    });
  }

  // Get transactions as a Future
  Future<List<TransactionItem>> getTransactions(DateRange dateRange) async {
    try {
      final snapshot = await transactionsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionItem.fromFirestore(doc, availableCategories))
          .toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  // Get category statistics
  Future<Map<String, double>> getCategoryTotals(DateRange dateRange) async {
    try {
      final snapshot = await transactionsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.endDate))
          .get();

      Map<String, double> categoryTotals = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] as String? ?? 'Other';
        final amount = (data['amount'] as num).toDouble();

        categoryTotals.update(
            category,
                (value) => value + amount,
            ifAbsent: () => amount
        );
      }

      return categoryTotals;
    } catch (e) {
      debugPrint('Error getting category totals: $e');
      return {};
    }
  }

  // Get spending over time
  Future<Map<DateTime, double>> getDailySpending(DateRange dateRange) async {
    try {
      final snapshot = await transactionsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.endDate))
          .orderBy('timestamp')
          .get();

      Map<DateTime, double> dailySpending = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['timestamp'] as Timestamp).toDate();
        final amount = (data['amount'] as num).toDouble();

        // Normalize to just the date part
        final dayKey = DateTime(date.year, date.month, date.day);

        dailySpending.update(
            dayKey,
                (value) => value + amount,
            ifAbsent: () => amount
        );
      }

      return dailySpending;
    } catch (e) {
      debugPrint('Error getting daily spending: $e');
      return {};
    }
  }

  // Calculate budget health (percentage of budget remaining)
  Future<double> calculateBudgetHealth(DateRange dateRange) async {
    try {
      // Get user preferences to get budget
      final prefs = await getUserPreferences();
      if (prefs.totalBudget == null || prefs.totalBudget == 0) {
        return 0.0; // No budget set
      }

      // Get total spending in date range
      final snapshot = await transactionsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.endDate))
          .get();

      double totalSpent = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalSpent += (data['amount'] as num).toDouble();
      }

      // Calculate health as percentage of budget remaining
      double remaining = prefs.totalBudget! - totalSpent;
      if (remaining < 0) remaining = 0;

      return (remaining / prefs.totalBudget!).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating budget health: $e');
      return 0.0;
    }
  }

  // Calculate streak (consecutive days with transactions)
  Future<int> calculateStreak() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get all transactions in reverse chronological order
      final snapshot = await transactionsCollection
          .orderBy('timestamp', descending: true)
          .get();

      // Group by day
      final Set<String> daysWithTransactions = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['timestamp'] as Timestamp).toDate();
        final dateStr = '${date.year}-${date.month}-${date.day}';
        daysWithTransactions.add(dateStr);
      }

      // Check for consecutive days
      int streak = 0;
      DateTime checkDate = today;

      while (true) {
        final dateStr = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        if (!daysWithTransactions.contains(dateStr)) {
          break;
        }

        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  // Get username from email
  Future<String?> getUsernameFromEmail(String email) async {
    try {
      final querySnapshot = await usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        return data['username'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting username from email: $e');
      return null;
    }
  }

  // Get email from username
  Future<String?> getEmailFromUsername(String username) async {
    try {
      final querySnapshot = await usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        return data['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting email from username: $e');
      return null;
    }
  }

  // Check if username is taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final querySnapshot = await usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if username is taken: $e');
      // Default to true if there's an error to prevent duplicate usernames
      return true;
    }
  }
}