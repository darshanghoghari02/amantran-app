class Subscription {
  final String planType; // "monthly" / "yearly" / "none"
  final bool isActive;
  final DateTime expiryDate;

  Subscription({
    required this.planType,
    required this.isActive,
    required this.expiryDate,
  });

  factory Subscription.none() {
    return Subscription(
      planType: 'none',
      isActive: false,
      expiryDate: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
