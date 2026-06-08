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
  Timer? _expiryTimer;

  SubscriptionProvider() {
    _init();
  }

  Subscription get subscription => _subscription;
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

  void _init() {
    // Listen to resolved UID stream
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) async {
      if (uid != null) {
        await fetchSubscriptionStatus();
      } else {
        _subscription = Subscription.none();
        _purchasedTemplates = [];
        notifyListeners();
      }
    });

    final initialUid = FirestoreService().resolvedUid;
    if (initialUid != null) {
      fetchSubscriptionStatus();
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
        _subscription = Subscription.none();
        notifyListeners();
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

  /// Fetches subscription status from Firestore `user_subscriptions/{userId}`
  Future<void> fetchSubscriptionStatus() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection("user_subscriptions").doc(resolvedUid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _subscription = Subscription(
          planType: data["planType"] ?? "none",
          isActive: data["isActive"] ?? false,
          expiryDate: _parseDate(data["expiryDate"]),
        );
        
        final templates = data["purchasedTemplates"];
        if (templates is List) {
          _purchasedTemplates = templates.map((e) => e.toString()).toList();
        } else {
          _purchasedTemplates = [];
        }
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

  /// Activates or updates a plan for the user in Firestore and memory
  Future<bool> purchaseSubscription(String planType) async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      
      // Calculate dynamic expiry based on plan properties
      SubscriptionPlanModel? plan;
      for (final p in _plans) {
        if (p.id == planType) {
          plan = p;
          break;
        }
      }
      final String planName = plan?.name ?? planType;
      
      DateTime expiry;
      if (plan != null) {
        if (plan.durationType == 'custom') {
          if (plan.customEndDate != null) {
            final parsedEnd = DateTime.tryParse(plan.customEndDate!);
            if (parsedEnd != null) {
              // Set to end of day: 23:59:59
              expiry = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day, 23, 59, 59);
            } else {
              expiry = now.add(const Duration(days: 30));
            }
          } else {
            expiry = now.add(const Duration(days: 30));
          }
        } else {
          int days = plan.durationDays;
          if (days <= 0) {
            switch (plan.durationType) {
              case '1day':
                days = 1;
                break;
              case 'weekly':
                days = 7;
                break;
              case 'monthly':
                days = 30;
                break;
              case 'yearly':
                days = 365;
                break;
              default:
                days = 30;
            }
          }
          expiry = now.add(Duration(days: days));
        }
      } else {
        int days = 30; // Default fallback to 30 days
        final planNameLower = planName.toLowerCase();
        if (planType == "yearly" || planNameLower.contains("yearly") || planNameLower.contains("year")) {
          final RegExp yearRegExp = RegExp(r'(\d+)\s*year');
          final match = yearRegExp.firstMatch(planNameLower);
          if (match != null) {
            final int years = int.tryParse(match.group(1) ?? '1') ?? 1;
            days = 365 * years;
          } else {
            days = 365;
          }
        } else if (planType == "monthly" || planNameLower.contains("monthly") || planNameLower.contains("month")) {
          final RegExp monthRegExp = RegExp(r'(\d+)\s*month');
          final match = monthRegExp.firstMatch(planNameLower);
          if (match != null) {
            final int months = int.tryParse(match.group(1) ?? '1') ?? 1;
            days = 30 * months;
          } else {
            days = 30;
          }
        } else if (planNameLower.contains("quarterly") || planNameLower.contains("quarter")) {
          days = 90;
        } else if (planNameLower.contains("weekly") || planNameLower.contains("week")) {
          final RegExp weekRegExp = RegExp(r'(\d+)\s*week');
          final match = weekRegExp.firstMatch(planNameLower);
          if (match != null) {
            final int weeks = int.tryParse(match.group(1) ?? '1') ?? 1;
            days = 7 * weeks;
          } else {
            days = 7;
          }
        }
        expiry = now.add(Duration(days: days));
      }

      final String nowStr = now.toIso8601String();
      final String expiryStr = expiry.toIso8601String();

      final subscriptionData = {
        'planType': planType,
        'isActive': true,
        'startDate': nowStr,
        'expiryDate': expiryStr,
        'updatedAt': nowStr,
      };

      // Write to Firebase Firestore (use set merge to preserve other fields like purchasedTemplates!)
      await _firestore.collection("user_subscriptions").doc(resolvedUid).set(subscriptionData, SetOptions(merge: true));

      // Update in memory
      _subscription = Subscription(
        planType: planType,
        isActive: true,
        expiryDate: expiry,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error purchasing subscription: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers an individual template lifetime purchase
  Future<bool> purchaseTemplate(String templateId) async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _firestore.collection("user_subscriptions").doc(resolvedUid);
      final doc = await docRef.get();

      List<String> currentPurchased = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final templates = data["purchasedTemplates"];
        if (templates is List) {
          currentPurchased = templates.map((e) => e.toString()).toList();
        }
      }

      if (!currentPurchased.contains(templateId)) {
        currentPurchased.add(templateId);
      }

      await docRef.set({
        'purchasedTemplates': currentPurchased,
      }, SetOptions(merge: true));

      _purchasedTemplates = currentPurchased;
      notifyListeners();
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
    _expiryTimer?.cancel();
    super.dispose();
  }
}
