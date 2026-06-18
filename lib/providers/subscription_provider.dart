import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Kept for Timestamp type parsing fallback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/firestore_service.dart';
import '../models/subscription.dart';
import '../models/subscription_plan.dart';
import '../models/template_model.dart';
import '../services/subscription_manager.dart';

class SubscriptionProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Subscription _subscription = Subscription.none();
  List<String> _purchasedTemplates = [];
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = false;
  
  StreamSubscription? _authSubscription;
  Timer? _expiryTimer;

  SubscriptionProvider() {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("SubscriptionProvider: App resumed, fetching subscription status");
      fetchSubscriptionStatus();
    }
  }

  Subscription get subscription => _subscription;
  List<String> get purchasedTemplates => _purchasedTemplates;
  List<SubscriptionPlanModel> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isSubscribed => SubscriptionManager.isSubscriptionValid(_subscription);

  bool isTemplatePurchased(String templateId) {
    final searchId = templateId.toLowerCase().trim();
    return _purchasedTemplates.any((id) => id.toLowerCase().trim() == searchId);
  }

  bool isTemplateUnlocked(TemplateModel template) {
    // Non-premium templates are always unlocked
    if (!template.isPremium) return true;
    
    // Purchased templates are always unlocked (regardless of admin validation status)
    if (isTemplatePurchased(template.id)) return true;
    
    // For subscription-based unlocks, template must be active (validated by admin)
    if (!template.isActive) return false;
    
    if (!isSubscribed) return false;

    // 1. Check for lifetime plan - unlocks all templates
    if (_subscription.planType == "lifetime" || 
        _subscription.planType.toLowerCase().contains('lifetime')) {
      return true;
    }

    // 2. Check legacy plan inclusions (monthly / yearly built-in flags)
    if (_subscription.planType == "monthly" && template.includedInMonthlyPlan) {
      return true;
    }
    if (_subscription.planType == "yearly" && template.includedInYearlyPlan) {
      return true;
    }
    
    // 3. Check dynamic plan configurations
    final activePlans = _plans.where((p) => p.id == _subscription.planType);
    if (activePlans.isNotEmpty) {
      final activePlan = activePlans.first;
      if (activePlan.isActive) {
        // Monthly/yearly duration types → use legacy flags
        if ((activePlan.durationType == 'monthly' || activePlan.id == 'monthly') &&
            template.includedInMonthlyPlan) {
          return true;
        }
        if ((activePlan.durationType == 'yearly' || activePlan.id == 'yearly') &&
            template.includedInYearlyPlan) {
          return true;
        }

        // Check if this specific template is listed in the plan's includedTemplateIds
        final templateMatch = activePlan.includedTemplateIds
            .any((id) => id.toLowerCase().trim() == template.id.toLowerCase().trim());
        if (templateMatch) return true;

        // Category-based unlock is a FALLBACK — only used when the plan has NO specific
        // templates listed. If includedTemplateIds is non-empty, categories are ignored.
        // This prevents admin from accidentally unlocking all templates in a category
        // when they only intended to include specific templates.
        if (activePlan.includedTemplateIds.isEmpty &&
            activePlan.includedCategories.contains(template.categoryId)) {
          return true;
        }
      }
    } else {
      // Fallback: parse planType name to see if it indicates monthly, yearly, or lifetime
      final planTypeLower = _subscription.planType.toLowerCase();
      if (planTypeLower.contains('lifetime')) {
        return true;
      }
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

    fetchPlans();

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
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/$resolvedUid'));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        // If planType is none or not found, user is eligible for trial
        return map['planType'] == null || map['planType'] == 'none';
      }
    } catch (e) {
      debugPrint("Error checking trial eligibility: $e");
    }
    return false;
  }

  /// Fetches subscription plans from Express API
  Future<void> fetchPlans() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/subscriptions'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        _plans = list
            .map((data) => SubscriptionPlanModel.fromJson(Map<String, dynamic>.from(data), data['id'] ?? ''))
            .where((p) => p.isActive)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching plans from API: $e");
    }
  }

  /// Fetches subscription status from Express API
  Future<void> fetchSubscriptionStatus() async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) {
      debugPrint("fetchSubscriptionStatus: No resolved UID found");
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("fetchSubscriptionStatus: Fetching for user $resolvedUid");
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/$resolvedUid'));
      debugPrint("fetchSubscriptionStatus: Response status code: ${response.statusCode}");
      debugPrint("fetchSubscriptionStatus: Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("fetchSubscriptionStatus: Parsed data - planType: ${map['planType']}, purchasedTemplates: ${map['purchasedTemplates']}");
        
        if (map['planType'] != null && map['planType'] != 'none') {
          _subscription = Subscription(
            planType: map['planType'] ?? 'none',
            isActive: map['isActive'] == true,
            expiryDate: _parseDate(map['expiryDate']),
            autoRenew: map['autoRenew'] != false,
            status: map['status'] ?? 'active',
          );
        } else {
          _subscription = Subscription.none();
          debugPrint("fetchSubscriptionStatus: No active subscription planType found");
        }

        final templates = map['purchasedTemplates'];
        if (templates is List) {
          _purchasedTemplates = templates.map((e) => e.toString()).toList();
          debugPrint("fetchSubscriptionStatus: Updated purchased templates: $_purchasedTemplates");
        } else {
          _purchasedTemplates = [];
          debugPrint("fetchSubscriptionStatus: No purchased templates list found in response");
        }
      } else {
        _subscription = Subscription.none();
        _purchasedTemplates = [];
        debugPrint("fetchSubscriptionStatus: API returned non-200 status");
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
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/$resolvedUid/cancel'));
      if (response.statusCode == 200) {
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
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/$resolvedUid/reactivate'));
      if (response.statusCode == 200) {
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

  /// Executes Mock Purchase simulation
  Future<bool> executeMockPurchase(String planType, double price, bool isTrial) async {
    final resolvedUid = FirestoreService().resolvedUid;
    if (resolvedUid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/purchase'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': resolvedUid,
          'planType': planType,
          'price': price,
          'isTrial': isTrial,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchSubscriptionStatus();
        return true;
      }
      return false;
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
    if (resolvedUid == null) {
      debugPrint("purchaseTemplate: No resolved UID found");
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("purchaseTemplate: Purchasing template $templateId for user $resolvedUid");
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/user-subscriptions/purchase-template'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': resolvedUid,
          'templateId': templateId,
          'price': price,
        }),
      );

      debugPrint("purchaseTemplate: Response status code: ${response.statusCode}");
      debugPrint("purchaseTemplate: Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("purchaseTemplate: Purchase successful, fetching subscription status");
        await fetchSubscriptionStatus();
        debugPrint("purchaseTemplate: Current purchased templates: $_purchasedTemplates");
        return true;
      }
      debugPrint("purchaseTemplate: Purchase failed with status ${response.statusCode}");
      return false;
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
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
