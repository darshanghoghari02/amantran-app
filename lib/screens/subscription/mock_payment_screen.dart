import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';

class MockPaymentScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final double price;
  final bool isTrial;

  const MockPaymentScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.price,
    required this.isTrial,
  });

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  String _selectedMethod = 'card'; // 'card', 'upi', 'netbanking'
  String _processingStep = 'idle'; // 'idle', 'processing', 'success', 'failure'
  String _errorMessage = '';
  
  // Form text inputs
  final TextEditingController _cardNumberController = TextEditingController(text: '4111 2222 3333 4444');
  final TextEditingController _expiryController = TextEditingController(text: '12/28');
  final TextEditingController _cvvController = TextEditingController(text: '123');
  final TextEditingController _upiController = TextEditingController(text: 'amantran@ybl');

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _triggerPayment(bool simulateSuccess) async {
    setState(() {
      _processingStep = 'processing';
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    if (simulateSuccess) {
      final success = await context.read<SubscriptionProvider>().executeMockPurchase(
        widget.planId,
        widget.price,
        widget.isTrial,
      );

      if (success) {
        setState(() {
          _processingStep = 'success';
        });
        // Stay on success screen for 2 seconds then navigate back
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _processingStep = 'failure';
          _errorMessage = 'Database write failed. Check connection.';
        });
      }
    } else {
      setState(() {
        _processingStep = 'failure';
        _errorMessage = 'Mock Sandbox payment rejected by gateway.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double displayAmount = widget.isTrial ? 0.0 : widget.price;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          "Payment Sandbox Gateway",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_processingStep == 'idle') ...[
                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.planName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isTrial ? "3-Day Free Trial" : "Premium Subscription",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "₹${displayAmount.toInt()}",
                            style: const TextStyle(
                              color: Color(0xFFF94C66),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Gateway Mode",
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                          ),
                          const Text(
                            "SANDBOX TEST",
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Method Selectors
                const Text(
                  "SELECT PAYMENT METHOD",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _methodButton("Credit Card", 'card', Icons.credit_card),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _methodButton("UPI / App", 'upi', Icons.account_balance_wallet),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form details
                Expanded(
                  child: SingleChildScrollView(
                    child: _selectedMethod == 'card' ? _buildCardForm() : _buildUpiForm(),
                  ),
                ),

                // Bottom pay triggers (Success vs Failure)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () => _triggerPayment(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF94C66),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        widget.isTrial ? "Simulate Payment (Trial: ₹0)" : "Simulate Success (Pay ₹${displayAmount.toInt()})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _triggerPayment(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Simulate Payment Failure",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Loading / Success / Failure screens
                Expanded(
                  child: Center(
                    child: _buildProcessingState(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodButton(String title, String code, IconData icon) {
    final isSelected = _selectedMethod == code;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = code;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E24) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF94C66) : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFF94C66) : Colors.white60),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField("Card Number", _cardNumberController, Icons.credit_card_outlined),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField("Expiration Date", _expiryController, Icons.calendar_today_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField("CVV Code", _cvvController, Icons.lock_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpiForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField("Virtual Payment Address (VPA / UPI ID)", _upiController, Icons.alternate_email_outlined),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF151518),
            prefixIcon: Icon(icon, color: Colors.white30, size: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF94C66)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    if (_processingStep == 'processing') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFF94C66),
          ),
          const SizedBox(height: 24),
          const Text(
            "Contacting payment sandbox...",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Verifying funds with mock Stripe API",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      );
    } else if (_processingStep == 'success') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            "Payment Successful!",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Your invoice transaction has been completed.",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            "Payment Failed",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _processingStep = 'idle';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Try Again", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }
  }
}
