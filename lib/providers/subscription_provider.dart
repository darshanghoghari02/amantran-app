import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/subscription.dart';
import '../models/subscription_plan.dart';
import '../models/template_model.dart';
import '../services/subscription_manager.dart';

class SubscriptionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Subscription _subscription = Subscription.none();
  List<String> _purchasedTemplates = [];
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = false;
  
  StreamSubscription? _authSubscription;
  StreamSubscription? _plansSubscription;
  StreamSubscription? _userSubSubscription;
  Timer? _expiryTimer;

  SubscriptionProvider() {
    _init();
  }

  Subscription get subscription => _subscription;
  List<String> _history = [];
  List<String> get purchasedTemplates => _purchasedTemplates;
  List<SubscriptionPlanModel> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isSubscribed => SubscriptionManager.isSubscriptionValid(_subscription);

  bool isTemplatePurchased(String templateId) {
    return _purchasedTemplates.contains(templateId);
  }

  bool isTemplateUnlocked(TemplateModel template) {
    if (!template.isPremium) return true;
    if (isTemplatePurchased(template.id)) return true;
    
    if (!isSubscribed) return false;

    // 1. Check legacy plan inclusions
    if (_subscription.planType == "monthly" && template.includedInMonthlyPlan) {
      return true;
    }
    if (_subscription.planType == "yearly" && template.includedInYearlyPlan) {
      return true;
    }
    
    // 2. Check dynamic Firestore plan configurations
    final activePlans = _plans.where((p) => p.id == _subscription.planType);
    if (activePlans.isNotEmpty) {
      final activePlan = activePlans.first;
      if (activePlan.isActive) {
        if ((activePlan.durationType == 'monthly' || activePlan.id == 'monthly') && template.includedInMonthlyPlan) {
          return true;
        }
        if ((activePlan.durationType == 'yearly' || activePlan.id == 'yearly') && template.includedInYearlyPlan) {
          return true;
        }
        if (activePlan.includedTemplateIds.contains(template.id) ||
            activePlan.includedCategories.contains(template.categoryId)) {
          return true;
        }
      }
    } else {
      // Fallback: parse planType name to see if it indicates monthly or yearly
      final planTypeLower = _subscription.planType.toLowerCase();
      if (planTypeLower.contains('monthly') || planTypeLower.contains('month')) {
        if (template.includedInMonthlyPlan) return true;
      }
      if (planTypeLower.contains('yearly') || planTypeLower.contains('year')) {
        if (template.includedInYearlyPlan) return true;
      }
    }
    
    return false;
  }

  void _updateSubscriptionFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docsSnapshot, String resolvedUid) {
    if (docsSnapshot.isNotEmpty) {
      final docs = docsSnapshot.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();

      // Sort by startDate descending (latest first)
      docs.sort((a, b) {
        final aDate = _parseDate(a['startDate'] ?? a['createdAt']);
        final bDate = _parseDate(b['startDate'] ?? b['createdAt']);
        return bDate.compareTo(aDate);
      });

      var latest = docs[0];
      final DateTime now = DateTime.now();
      final DateTime expiry = _parseDate(latest['expiryDate']);

      // Check if expired and perform auto-renewal if applicable
      if (expiry.isBefore(now)) {
        final String status = latest['status'] ?? 'active';
        final bool autoRenew = latest['autoRenew'] ?? true;

        if ((status == 'active' || status == 'trial') && autoRenew) {
          // Auto-renew subscription
          _firestore.collection("user_subscriptions").doc(latest['id']).update({
            'isActive': false,
            'status': 'expired',
            'updatedAt': now.toIso8601String(),
          }).then((_) {
            int durationDays = 30;
            double price = 99.0;
            if (latest['planType'] == 'yearly') {
              durationDays = 365;
              price = 499.0;
            }
            final newExpiry = now.add(Duration(days: durationDays));

            _firestore.collection("user_subscriptions").add({
              'userId': resolvedUid,
              'planType': latest['planType'],
              'status': 'active',
              'isActive': true,
              'startDate': now.toIso8601String(),
              'expiryDate': newExpiry.toIso8601String(),
              'amountPaid': price,
              'autoRenew': true,
              'createdAt': now.toIso8601String(),
            });

            _firestore.collection("transactions").add({
              'userId': resolvedUid,
              'type': 'subscription',
              'amount': price,
              'planId': latest['planType'],
              'status': 'success',
              'timestamp': now.toIso8601String(),
              'details': 'Auto-renewal subscription check',
            });
          });
          return;
        } else {
          // Cancelled or no autoRenew: set status to expired
          if (latest['isActive'] == true || latest['status'] != 'expired') {
            _firestore.collection("user_subscriptions").doc(latest['id']).update({
              'isActive': false,
              'status': 'expired',
              'updatedAt': now.toIso8601String(),
            });
            latest['isActive'] = false;
            latest['status'] = 'expired';
          }
        }
      }

      // Set state
      _subscription = Subscription(
        planType: latest['planType'] ?? 'none',
        isActive: latest['isActive'] ?? false,
        expiryDate: expiry,
        autoRenew: latest['autoRenew'] ?? true,
        status: latest['status'] ?? 'active',
      );

      // Fetch user subscription records and combine template list
      final Set<String> allPurchased = {};
      for (final doc in docsSnapshot) {
        final data = doc.data();
        final templates = data['purchasedTemplates'];
        if (templates is List) {
          allPurchased.addAll(templates.map((e) => e.toString()));
        }
      }
      _purchasedTemplates = allPurchased.toList();
    } else {
      _subscription = Subscription.none();
      _purchasedTemplates = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  void _init() {
    // Listen to resolved UID stream
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) async {
      _userSubSubscription?.cancel();
      if (uid != null) {
        _userSubSubscription = _firestore
            .collection("user_subscriptions")
            .where("userId", isEqualTo: uid)
            .snapshots()
            .listen((snapshot) {
          _updateSubscriptionFromDocs(snapshot.docs, uid);
        }, onError: (e) {
          debugPrint("Error listening to user subscriptions: $e");
        });
      } else {
        _subscription = Subscription.none();
        _purchasedTemplates = [];
        notifyListeners();
      }
    });

    final initialUid = FirestoreService().resolvedUid;
    if (initialUid != null) {
      _userSubSubscription?.cancel();
      _userSubSubscription = _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: initialUid)
          .snapshots()
          .listen((snapshot) {
        _updateSubscriptionFromDocs(snapshot.docs, initialUid);
      }, onError: (e) {
        debugPrint("Error listening to user subscriptions: $e");
      });
    }

    // Listen to active subscription plans from Firestore
    try {
      _plansSubscription = _firestore
          .collection("subscriptions")
          .snapshots()
          .listen((snapshot) {
        _plans = snapshot.docs
            .map((doc) => SubscriptionPlanModel.fromJson(doc.data(), doc.id))
            .where((p) => p.isActive)
            .toList();
        notifyListeners();
      }, onError: (e) {
        debugPrint("Error listening to subscriptions: $e");
      });
    } catch (e) {
      debugPrint("Error starting subscription plans listener: $e");
    }

    // Start periodic 10-minute expiry validation
    _expiryTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_subscription.isActive && _subscription.expiryDate.isBefore(DateTime.now())) {
        fetchSubscriptionStatus();
      }
    });
  }

  DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (val is String) {
      return DateTime.tryParse(val) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (val is Timestamp) {
      return val.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Check trial eligibility: has user ever had a subscription record?
  Future<bool> checkTrialEligibility() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;
    try {
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      debugPrint("Error checking trial eligibility: $e");
      return false;
    }
  }

  /// Fetches subscription status from Firestore `user_subscriptions` collection
  Future<void> fetchSubscriptionStatus() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docs = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data()
        }).toList();

        // Sort by startDate descending (latest first)
        docs.sort((a, b) {
          final aDate = _parseDate(a['startDate'] ?? a['createdAt']);
          final bDate = _parseDate(b['startDate'] ?? b['createdAt']);
          return bDate.compareTo(aDate);
        });

        var latest = docs[0];
        final DateTime now = DateTime.now();
        final DateTime expiry = _parseDate(latest['expiryDate']);

        // Check if expired and perform auto-renewal if applicable
        if (expiry.isBefore(now)) {
          final String status = latest['status'] ?? 'active';
          final bool autoRenew = latest['autoRenew'] ?? true;

          if ((status == 'active' || status == 'trial') && autoRenew) {
            // Auto-renew subscription
            await _firestore.collection("user_subscriptions").doc(latest['id']).update({
              'isActive': false,
              'status': 'expired',
              'updatedAt': now.toIso8601String(),
            });

            int durationDays = 30;
            double price = 99.0;
            if (latest['planType'] == 'yearly') {
              durationDays = 365;
              price = 499.0;
            }
            final newExpiry = now.add(Duration(days: durationDays));

            await _firestore.collection("user_subscriptions").add({
              'userId': resolvedUid,
              'planType': latest['planType'],
              'status': 'active',
              'isActive': true,
              'startDate': now.toIso8601String(),
              'expiryDate': newExpiry.toIso8601String(),
              'amountPaid': price,
              'autoRenew': true,
              'createdAt': now.toIso8601String(),
            });

            await _firestore.collection("transactions").add({
              'userId': resolvedUid,
              'type': 'subscription',
              'amount': price,
              'planId': latest['planType'],
              'status': 'success',
              'timestamp': now.toIso8601String(),
              'details': 'Auto-renewal subscription check',
            });

            await fetchSubscriptionStatus();
            return;
          } else {
            // Cancelled or no autoRenew: set status to expired
            if (latest['isActive'] == true || latest['status'] != 'expired') {
              await _firestore.collection("user_subscriptions").doc(latest['id']).update({
                'isActive': false,
                'status': 'expired',
                'updatedAt': now.toIso8601String(),
              });
              latest['isActive'] = false;
              latest['status'] = 'expired';
            }
          }
        }

        // Set state
        _subscription = Subscription(
          planType: latest['planType'] ?? 'none',
          isActive: latest['isActive'] ?? false,
          expiryDate: expiry,
          autoRenew: latest['autoRenew'] ?? true,
          status: latest['status'] ?? 'active',
        );

        // Fetch user subscription records and combine template list
        final Set<String> allPurchased = {};
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final templates = data['purchasedTemplates'];
          if (templates is List) {
            allPurchased.addAll(templates.map((e) => e.toString()));
          }
        }
        _purchasedTemplates = allPurchased.toList();
      } else {
        _subscription = Subscription.none();
        _purchasedTemplates = [];
      }
    } catch (e) {
      debugPrint("Error fetching subscription status: $e");
      _subscription = Subscription.none();
      _purchasedTemplates = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels auto-renewal of the current active subscription
  Future<bool> cancelActiveSubscription() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final docs = querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();

      docs.sort((a, b) {
        final aDate = _parseDate(a['startDate'] ?? a['createdAt']);
        final bDate = _parseDate(b['startDate'] ?? b['createdAt']);
        return bDate.compareTo(aDate);
      });

      final latest = docs[0];
      if (latest['isActive'] == true && latest['status'] != 'cancelled') {
        final now = DateTime.now();
        await _firestore.collection("user_subscriptions").doc(latest['id']).update({
          'status': 'cancelled',
          'autoRenew': false,
          'updatedAt': now.toIso8601String(),
        });

        await _firestore.collection("transactions").add({
          'userId': resolvedUid,
          'type': 'subscription',
          'amount': 0.0,
          'planId': latest['planType'],
          'status': 'success',
          'timestamp': now.toIso8601String(),
          'details': 'Subscription auto-renew cancelled by user',
        });

        await fetchSubscriptionStatus();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error cancelling subscription: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reactivates auto-renewal of the current active subscription
  Future<bool> reactivateSubscription() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final docs = querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();

      docs.sort((a, b) {
        final aDate = _parseDate(a['startDate'] ?? a['createdAt']);
        final bDate = _parseDate(b['startDate'] ?? b['createdAt']);
        return bDate.compareTo(aDate);
      });

      final latest = docs[0];
      if (latest['isActive'] == true && latest['status'] == 'cancelled') {
        final now = DateTime.now();
        await _firestore.collection("user_subscriptions").doc(latest['id']).update({
          'status': 'active',
          'autoRenew': true,
          'updatedAt': now.toIso8601String(),
        });

        await _firestore.collection("transactions").add({
          'userId': resolvedUid,
          'type': 'subscription',
          'amount': 0.0,
          'planId': latest['planType'],
          'status': 'success',
          'timestamp': now.toIso8601String(),
          'details': 'Subscription auto-renew reactivated by user',
        });

        await fetchSubscriptionStatus();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error reactivating subscription: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Executes Mock Payment Gateway checkout and logs transaction
  Future<bool> executeMockPurchase(String planType, double price, bool isTrial) async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      
      // Deactivate any existing active subscriptions first
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();

      for (final doc in querySnapshot.docs) {
        if (doc.data()['isActive'] == true) {
          await doc.reference.update({
            'isActive': false,
            'status': 'expired',
            'updatedAt': now.toIso8601String(),
          });
        }
      }

      DateTime expiry;
      String status;
      double finalPrice;

      if (isTrial) {
        expiry = now.add(const Duration(days: 3));
        status = 'trial';
        finalPrice = 0.0;
      } else {
        status = 'active';
        finalPrice = price;
        int durationDays = 30;
        if (planType == 'yearly') {
          durationDays = 365;
        } else {
          final plan = _plans.firstWhere(
            (p) => p.id == planType, 
            orElse: () => SubscriptionPlanModel(
              id: planType, 
              name: planType, 
              price: price, 
              description: '', 
              isActive: true, 
              includedCategories: [], 
              includedTemplateIds: []
            )
          );
          durationDays = plan.durationDays;
        }
        expiry = now.add(Duration(days: durationDays));
      }

      await _firestore.collection("user_subscriptions").add({
        'userId': resolvedUid,
        'planType': planType,
        'status': status,
        'isActive': true,
        'startDate': now.toIso8601String(),
        'expiryDate': expiry.toIso8601String(),
        'amountPaid': finalPrice,
        'autoRenew': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      await _firestore.collection("transactions").add({
        'userId': resolvedUid,
        'type': 'subscription',
        'amount': finalPrice,
        'planId': planType,
        'status': 'success',
        'timestamp': now.toIso8601String(),
        'details': isTrial ? '3-day free trial activated' : 'Mock payment gateway checkout successful',
      });

      await fetchSubscriptionStatus();
      return true;
    } catch (e) {
      debugPrint("Error executing purchase: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers an individual template lifetime purchase
  Future<bool> purchaseTemplate(String templateId, {double price = 49.0}) async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection("user_subscriptions")
          .where("userId", isEqualTo: resolvedUid)
          .get();

      DocumentReference docRef;
      List<String> currentPurchased = [];

      if (querySnapshot.docs.isNotEmpty) {
        // Retrieve the latest doc of the user to append purchases to it
        final docs = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data()
        }).toList();

        docs.sort((a, b) {
          final aDate = _parseDate(a['startDate'] ?? a['createdAt']);
          final bDate = _parseDate(b['startDate'] ?? b['createdAt']);
          return bDate.compareTo(aDate);
        });

        final latestId = docs[0]['id'];
        docRef = _firestore.collection("user_subscriptions").doc(latestId);

        final templates = docs[0]['purchasedTemplates'];
        if (templates is List) {
          currentPurchased = templates.map((e) => e.toString()).toList();
        }
      } else {
        // Create a basic blank document
        docRef = await _firestore.collection("user_subscriptions").add({
          'userId': resolvedUid,
          'planType': 'none',
          'status': 'expired',
          'isActive': false,
          'startDate': DateTime.now().toIso8601String(),
          'expiryDate': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
          'amountPaid': 0.0,
          'autoRenew': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      if (!currentPurchased.contains(templateId)) {
        currentPurchased.add(templateId);
      }

      await docRef.set({
        'purchasedTemplates': currentPurchased,
      }, SetOptions(merge: true));

      // Log transaction
      await _firestore.collection("transactions").add({
        'userId': resolvedUid,
        'type': 'single_purchase',
        'amount': price,
        'planId': templateId,
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
        'details': 'Lifetime template purchase',
      });

      _purchasedTemplates = currentPurchased;
      await fetchSubscriptionStatus();
      return true;
    } catch (e) {
      debugPrint("Error purchasing template: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _plansSubscription?.cancel();
    _userSubSubscription?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
