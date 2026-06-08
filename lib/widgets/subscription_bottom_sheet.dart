import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/template_model.dart';
import '../models/subscription_plan.dart';

class SubscriptionBottomSheet extends StatefulWidget {
  final TemplateModel? template;
  const SubscriptionBottomSheet({super.key, this.template});

  @override
  State<SubscriptionBottomSheet> createState() => _SubscriptionBottomSheetState();
}

class _SubscriptionBottomSheetState extends State<SubscriptionBottomSheet> {
  String? _selectedPlan; // "monthly" / "yearly" / "lifetime"

  bool _canPlanUnlockTemplate(SubscriptionPlanModel plan, TemplateModel template) {
    if (plan.includedTemplateIds.contains(template.id)) {
      return true;
    }
    if (plan.includedCategories.contains(template.categoryId)) {
      return true;
    }
    if ((plan.id == 'monthly' || plan.durationType == 'monthly') && template.includedInMonthlyPlan) {
      return true;
    }
    if ((plan.id == 'yearly' || plan.durationType == 'yearly') && template.includedInYearlyPlan) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // Default select lifetime if template has a single purchase price
    if (widget.template != null && widget.template!.singlePurchasePrice != null && widget.template!.singlePurchasePrice! > 0) {
      _selectedPlan = 'lifetime';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final theme = Theme.of(context);

    // Get the list of displayable plans
    final List<SubscriptionPlanModel> displayPlans = [];
    if (widget.template == null) {
      displayPlans.addAll(subProvider.plans);
    } else {
      for (final plan in subProvider.plans) {
        if (_canPlanUnlockTemplate(plan, widget.template!)) {
          displayPlans.add(plan);
        }
      }
    }

    // Set default selected plan if not set yet and plans are loaded
    if (_selectedPlan == null) {
      if (widget.template != null && widget.template!.singlePurchasePrice != null && widget.template!.singlePurchasePrice! > 0) {
        _selectedPlan = 'lifetime';
      } else if (displayPlans.isNotEmpty) {
        final hasYearly = displayPlans.any((p) => p.id == 'yearly' || p.durationType == 'yearly');
        if (hasYearly) {
          _selectedPlan = displayPlans.firstWhere((p) => p.id == 'yearly' || p.durationType == 'yearly').id;
        } else {
          _selectedPlan = displayPlans.first.id;
        }
      } else {
        // Fallback default
        if (widget.template == null || widget.template!.includedInYearlyPlan) {
          _selectedPlan = 'yearly';
        } else if (widget.template!.includedInMonthlyPlan) {
          _selectedPlan = 'monthly';
        } else {
          _selectedPlan = 'lifetime';
        }
      }
    }

    return Container(
      // Sleek premium black bottom sheet
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header with Premium Icon / Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFFFD700),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  "Unlock Premium Access",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Get unlimited access to all premium templates, high-quality downloads, and exclusive features.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Plan Options
            if (widget.template != null && widget.template!.singlePurchasePrice != null && widget.template!.singlePurchasePrice! > 0) ...[
              _buildPlanCard(
                title: "Unlock This Template Only",
                price: "₹${widget.template!.singlePurchasePrice!.toInt()}",
                period: " lifetime",
                description: "Lifetime access to this specific design",
                type: "lifetime",
                isSelected: _selectedPlan == "lifetime",
                badge: "LIFETIME PASS",
              ),
              const SizedBox(height: 16),
            ],
            
            if (subProvider.plans.isEmpty) ...[
              _buildPlanCard(
                title: "Monthly Plan",
                price: "₹99",
                period: "/month",
                description: "Perfect for a single wedding event",
                type: "monthly",
                isSelected: _selectedPlan == "monthly",
                badge: null,
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                title: "Yearly Plan",
                price: "₹499",
                period: "/year",
                description: "Best for wedding planners & agencies",
                type: "yearly",
                isSelected: _selectedPlan == "yearly",
                badge: "SAVE 58%",
              ),
            ] else ...[
              for (var plan in displayPlans) ...[
                _buildPlanCard(
                  title: plan.name,
                  price: "₹${plan.price.toInt()}",
                  period: plan.id == "monthly" || plan.durationType == "monthly"
                      ? "/month"
                      : plan.id == "yearly" || plan.durationType == "yearly"
                          ? "/year"
                          : " subscription",
                  description: plan.description,
                  type: plan.id,
                  isSelected: _selectedPlan == plan.id,
                  badge: plan.id == "yearly" || plan.durationType == "yearly" ? "SAVE 58%" : null,
                ),
                const SizedBox(height: 16),
              ]
            ],
            const SizedBox(height: 12),

            // Action Button
            ElevatedButton(
              onPressed: subProvider.isLoading
                  ? null
                  : () async {
                      if (_selectedPlan == null) return;

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      bool success;
                      if (_selectedPlan == 'lifetime') {
                        success = await context
                            .read<SubscriptionProvider>()
                            .purchaseTemplate(widget.template!.id);
                      } else {
                        success = await context
                            .read<SubscriptionProvider>()
                            .purchaseSubscription(_selectedPlan!);
                      }
                      
                      if (!mounted) return;

                      if (success) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(_selectedPlan == 'lifetime'
                                ? "Template unlocked successfully! Enjoy full editing and downloading."
                                : "Subscription activated successfully! Enjoy Premium features."),
                            backgroundColor: Colors.green,
                          ),
                        );
                        navigator.pop(true);
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Purchase failed. Please try again."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF94C66),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: subProvider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _selectedPlan == 'lifetime' ? "Unlock Template Now" : "Subscribe Now",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            
            // Subtitle info
            Text(
              "Cancel anytime. Secure payment integration enabled.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required String description,
    required String type,
    required bool isSelected,
    required String? badge,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlan = type;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E1E) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF94C66) : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF94C66).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Selection Radio / Indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF94C66) : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFFF94C66) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Plan Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (badge != null) ...[
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: SizedBox(width: 8),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Pricing Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      period,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
