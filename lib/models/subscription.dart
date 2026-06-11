class Subscription {
  final String planType; // "monthly" / "yearly" / "none"
  final bool isActive;
  final DateTime expiryDate;
  final bool autoRenew;
  final String status;

  Subscription({
    required this.planType,
    required this.isActive,
    required this.expiryDate,
    required this.autoRenew,
    required this.status,
  });

  factory Subscription.none() {
    return Subscription(
      planType: 'none',
      isActive: false,
      expiryDate: DateTime.fromMillisecondsSinceEpoch(0),
      autoRenew: false,
      status: 'none',
    );
  }
}
