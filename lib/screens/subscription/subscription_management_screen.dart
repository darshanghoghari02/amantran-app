import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/user_repository.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/app_data_provider.dart';
import '../../models/template_model.dart';
import '../../models/category_model.dart';
import '../../utils/image_resolver.dart';
import '../template/template_detail_screen.dart';
import '../../services/firestore_service.dart';
import '../../models/subscription_plan.dart';
import 'mock_payment_screen.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _MockTransaction {
  final String planId;
  final double amount;
  final DateTime date;
  final String details;

  _MockTransaction({
    required this.planId,
    required this.amount,
    required this.date,
    required this.details,
  });
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  String _selectedBillingCycle = ''; 
  List<_MockTransaction> _txns = [];
  bool _loadingTxns = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SubscriptionProvider>().fetchSubscriptionStatus();
      }
    });
  }

  Future<void> _fetchTransactions() async {
    final uid = FirestoreService().resolvedUid;
    if (uid == null) return;
    try {
      final listData = await UserRepository().fetchTransactions(uid);
      
      final list = (listData ?? []).map((data) {
        DateTime dt = DateTime.now();
        if (data['timestamp'] != null) {
          dt = DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now();
        }
        return _MockTransaction(
          planId: data['planId'] ?? 'template',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          date: dt,
          details: data['details'] ?? (data['type'] == 'single_purchase' ? 'Lifetime single purchase' : 'Subscription Checkout'),
        );
      }).toList();

      list.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _txns = list;
          _loadingTxns = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading invoices: $e");
      if (mounted) {
        setState(() {
          _loadingTxns = false;
        });
      }
    }
  }

  void _showCancelConfirmation() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          lang.cancelSubscription,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.cancelSubscriptionMessage,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.keepPremium, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<SubscriptionProvider>().cancelActiveSubscription();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? lang.autoRenewDisabled : lang.failedToCancel),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
              _fetchTransactions();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF94C66)),
            child: Text(lang.confirmCancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final appDataProvider = context.watch<AppDataProvider>();
    final isSubscribed = subProvider.isSubscribed;
    final plans = subProvider.plans;

    if (plans.isNotEmpty && (plans.indexWhere((p) => p.id == _selectedBillingCycle) == -1)) {
      final hasYearly = plans.any((p) => p.id == 'yearly');
      _selectedBillingCycle = hasYearly ? 'yearly' : plans.first.id;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F12),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                lang.amantranPremium,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2C1216), Color(0xFF0F0F12)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.workspace_premium,
                    size: 80,
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header Card
                  _buildStatusHeader(subProvider),
                  const SizedBox(height: 28),

                  _buildPurchasedTemplates(subProvider, appDataProvider, lang),

                  // Toggle selector
                  _buildToggleSelector(plans),
                  const SizedBox(height: 24),

                  // Active subscription plan selection cards
                  _buildPlanShowcase(plans),
                  const SizedBox(height: 28),

                  if (isSubscribed) ...[
                    // Subscriber Management Controls
                    Text(
                      lang.manageSubscription,
                      style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    _buildSubscribedControls(plans),
                    const SizedBox(height: 28),
                  ],

                  // Premium features comparison list
                  _buildFeaturesList(),
                  const SizedBox(height: 28),

                  // Invoices List
                  Text(
                    lang.invoiceTransactionHistory,
                    style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  _buildInvoicesList(appDataProvider, lang),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasedTemplates(SubscriptionProvider subProvider, AppDataProvider appDataProvider, LanguageProvider lang) {
    final purchasedIds = subProvider.purchasedTemplates;
    if (purchasedIds.isEmpty) return const SizedBox.shrink();

    // Look up the actual templates
    final templates = purchasedIds
        .map((id) => appDataProvider.getTemplateById(id))
        .whereType<TemplateModel>()
        .toList();

    if (templates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.currentLanguage == 'Gujarati'
              ? "ખરીદેલ ટેમ્પ્લેટ્સ"
              : (lang.currentLanguage == 'Hindi' ? "खरीदे गए टेम्पलेट्स" : "Purchased Templates"),
          style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final category = appDataProvider.categories.firstWhere(
                    (c) => c.id == template.categoryId,
                    orElse: () => CategoryModel(id: '', name: 'Template', slug: '', coverImage: '', displayOrder: 99),
                  );
                  final categoryDisplayName = lang.getCategoryTranslation(category.name);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: isNetworkImage(template.thumbnail)
                              ? NetworkImage(resolveImageUrl(template.thumbnail))
                              : AssetImage(cleanAssetPath(template.thumbnail)) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      template.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      categoryDisplayName,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                    trailing: Text(
                      lang.currentLanguage == 'Gujarati'
                          ? "આજીવન ખરીદી"
                          : (lang.currentLanguage == 'Hindi' ? "आजीवन खरीद" : "Lifetime Purchase"),
                      style: const TextStyle(color: Color(0xFFF94C66), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplateDetailScreen(
                            categoryName: category.name,
                            template: template,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildStatusHeader(SubscriptionProvider provider) {
    final lang = context.read<LanguageProvider>();
    final sub = provider.subscription;
    final isSub = provider.isSubscribed;
    
    String planLabel = lang.freeAccount;
    String details = lang.subscribeToUnlock;
    Color statusColor = Colors.white38;
    IconData statusIcon = Icons.info_outline;

    if (isSub) {
      statusIcon = Icons.stars;
      if (sub.planType == 'trial') {
        planLabel = lang.threeDayFreeTrial;
        details = "${lang.trialActiveUntil} ${_formatDate(sub.expiryDate)}";
        statusColor = const Color(0xFFFFD700);
      } else {
        final matchingPlan = provider.plans.firstWhere(
          (p) => p.id == sub.planType,
          orElse: () => SubscriptionPlanModel(
            id: sub.planType,
            name: sub.planType.toLowerCase().contains('lifetime')
                ? "Lifetime Premium Pass"
                : sub.planType == 'yearly'
                    ? lang.yearlyPremiumPass
                    : sub.planType == 'monthly'
                        ? lang.monthlyPremiumPass
                        : "${sub.planType.toUpperCase()} Pass",
            price: 0.0,
            description: '',
            isActive: true,
            includedCategories: [],
            includedTemplateIds: [],
          ),
        );
        planLabel = matchingPlan.name;
        statusColor = const Color(0xFFF94C66);

        if (sub.planType.toLowerCase().contains('lifetime')) {
          details = "Lifetime access • Never expires";
        } else if (sub.autoRenew && sub.status != 'cancelled') {
          details = "${lang.renewsAutomaticallyOn} ${_formatDate(sub.expiryDate)}";
        } else {
          details = "${lang.expiresOn} ${_formatDate(sub.expiryDate)} ${lang.autoRenewOff}";
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSelector(List<SubscriptionPlanModel> plans) {
    final lang = context.read<LanguageProvider>();
    if (plans.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: plans.map((plan) {
          String text = plan.name;
          if (plan.id == 'monthly') {
            text = lang.monthly;
          } else if (plan.id == 'yearly') {
            text = lang.yearlySave;
          }
          return Expanded(
            child: _billingTab(text, plan.id),
          );
        }).toList(),
      ),
    );
  }

  Widget _billingTab(String text, String code) {
    final isSelected = _selectedBillingCycle == code;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBillingCycle = code;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF94C66) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanShowcase(List<SubscriptionPlanModel> plans) {
    final lang = context.read<LanguageProvider>();
    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF16161A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            lang.noPlansAvailable,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    final selectedPlan = plans.firstWhere(
      (p) => p.id == _selectedBillingCycle,
      orElse: () => plans.first,
    );

    final planId = selectedPlan.id;
    final planName = selectedPlan.name;
    final price = selectedPlan.price;
    final durationDesc = selectedPlan.durationType == 'yearly'
        ? lang.perYear
        : selectedPlan.durationType == 'monthly'
            ? lang.perMonth
            : '/${selectedPlan.durationDays}${lang.perDays}';

    final isPopular = planId == 'yearly';

    final subProvider = context.watch<SubscriptionProvider>();
    final sub = subProvider.subscription;
    final isSub = subProvider.isSubscribed;
    final activePlanId = sub.planType;
    final isActivePlanSelected = isSub && (selectedPlan.id == activePlanId);

    // Dynamic button text & action
    String buttonText = "Unlock Premium Now";
    VoidCallback? buttonAction;
    bool isButtonEnabled = true;

    if (isActivePlanSelected) {
      final isCancelled = sub.status == 'cancelled' || !sub.autoRenew;
      if (isCancelled) {
        buttonText = "Reactivate Auto-renew";
        buttonAction = () async {
          final success = await context.read<SubscriptionProvider>().reactivateSubscription();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? "Auto-renew re-enabled." : "Failed to enable auto-renew. Try again."),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
          _fetchTransactions();
        };
      } else {
        buttonText = "Active Plan";
        isButtonEnabled = false;
      }
    } else {
      if (isSub) {
        buttonText = "Switch to ${selectedPlan.name}";
      }
      buttonAction = () async {
        final isEligible = await context.read<SubscriptionProvider>().checkTrialEligibility();
        if (!mounted) return;

        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MockPaymentScreen(
              planId: planId,
              planName: planName,
              price: price,
              isTrial: isEligible && !isSub, // only allow trial if they don't have an active sub
            ),
          ),
        );

        if (completed == true) {
          _fetchTransactions();
        }
      };
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(isPopular ? 0.3 : 0.05), width: 1.5),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPopular) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 0.5),
                ),
                child: Text(
                  lang.mostPopularSave,
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              if (isActivePlanSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF94C66).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF94C66).withOpacity(0.4), width: 0.5),
                  ),
                  child: const Text(
                    "ACTIVE",
                    style: TextStyle(color: Color(0xFFF94C66), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
            ],
          ),
          if (selectedPlan.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              selectedPlan.description,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "₹${price.toInt()}",
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                durationDesc,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isButtonEnabled ? buttonAction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled ? const Color(0xFFF94C66) : Colors.white12,
              foregroundColor: isButtonEnabled ? Colors.white : Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      "Access all Premium Wedding layouts",
      "Unlimited High-Quality PDF exports",
      "No watermarks or app logos",
      "Exclusive premium stickers & vectors",
      "Auto-save layout drafts in Cloud",
      "Secure payment checkout integration"
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "INCLUDED PREMIUM FEATURES",
          style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFF94C66), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    f,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSubscribedControls(List<SubscriptionPlanModel> plans) {
    final subProvider = context.watch<SubscriptionProvider>();
    final sub = subProvider.subscription;
    final isAutoRenewOn = sub.autoRenew && sub.status != 'cancelled';
    final isCancelled = sub.status == 'cancelled' || !isAutoRenewOn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCancelled ? "Subscription Status" : "Plan Renewal",
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCancelled 
                          ? "Subscription cancelled • Auto-renew disabled" 
                          : (isAutoRenewOn 
                              ? "Autorenew is enabled by gateway" 
                              : "Autorenew is disabled"), 
                      style: TextStyle(
                        color: isCancelled ? const Color(0xFFF94C66) : Colors.white.withOpacity(0.4), 
                        fontSize: 11
                      )
                    ),
                  ],
                ),
              ),
              Switch(
                value: isAutoRenewOn,
                activeColor: const Color(0xFFF94C66),
                onChanged: (val) async {
                  if (!val) {
                    _showCancelConfirmation();
                  } else {
                    final success = await context.read<SubscriptionProvider>().reactivateSubscription();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? "Auto-renew re-enabled." : "Failed to enable auto-renew. Try again."),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                    _fetchTransactions();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(AppDataProvider appDataProvider, LanguageProvider lang) {
    if (_loadingTxns) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF94C66))),
      );
    }

    if (_txns.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "No payments billed to this account.",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _txns.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final tx = _txns[index];
              
              String titleText = tx.planId.toUpperCase();
              String detailsText = tx.details;

              // Check if this transaction is a single template purchase
              final template = appDataProvider.getTemplateById(tx.planId);
              if (template != null) {
                final category = appDataProvider.categories.firstWhere(
                  (c) => c.id == template.categoryId,
                  orElse: () => CategoryModel(id: '', name: 'Template', slug: '', coverImage: '', displayOrder: 99),
                );
                final categoryDisplayName = lang.getCategoryTranslation(category.name);
                titleText = template.title;
                
                final purchaseLabel = lang.currentLanguage == 'Gujarati'
                    ? "ટેમ્પ્લેટ ખરીદી"
                    : (lang.currentLanguage == 'Hindi' ? "टेम्पलेट खरीद" : "Template Purchase");
                detailsText = "$categoryDisplayName • $purchaseLabel";
              } else if (tx.planId.toLowerCase().startsWith('tem_') || tx.details.toLowerCase().contains('template')) {
                final purchaseLabel = lang.currentLanguage == 'Gujarati'
                    ? "ટેમ્પ્લેટ ખરીદી"
                    : (lang.currentLanguage == 'Hindi' ? "टेम्पलेट खरीद" : "Template Purchase");
                detailsText = purchaseLabel;
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                title: Text(
                  titleText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  "${_formatDate(tx.date)} • $detailsText",
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
                trailing: Text(
                  "₹${tx.amount.toInt()}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }
}
