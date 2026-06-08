import '../models/subscription.dart';

class SubscriptionManager {
  static bool isSubscriptionValid(Subscription sub) {
    if (!sub.isActive) return false;

    if (sub.expiryDate.isBefore(DateTime.now())) {
      return false;
    }

    return true;
  }

  static bool isMonthly(Subscription sub) {
    return isSubscriptionValid(sub) && sub.planType == "monthly";
  }

  static bool isYearly(Subscription sub) {
    return isSubscriptionValid(sub) && sub.planType == "yearly";
  }
}
