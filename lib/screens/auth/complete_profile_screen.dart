import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/top_notification.dart';
import '../home/home_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String? phone;
  const CompleteProfileScreen({Key? key, this.phone}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _agreedToTerms = false;
  bool _isPhoneReadOnly = false;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    
    // Check if initial phone is provided or exists in UserProvider
    String initialPhone = widget.phone ?? userProvider.phone;
    // Clean default placeholders
    if (initialPhone == "+91 00000 00000" || initialPhone == "+910000000000") {
      initialPhone = "";
    }
    
    // Clean country prefix for editing if we edit it
    String editablePhone = initialPhone;
    if (editablePhone.startsWith('+91')) {
      editablePhone = editablePhone.substring(3);
    }
    editablePhone = editablePhone.replaceAll(RegExp(r'\D'), '');

    _phoneController = TextEditingController(text: editablePhone);
    
    String initialName = userProvider.name;
    if (initialName.toLowerCase() == 'new user' || initialName.toLowerCase() == 'user') {
      initialName = "";
    }
    _nameController = TextEditingController(text: initialName);

    String initialEmail = userProvider.email;
    if (initialEmail.toLowerCase() == 'user@example.com') {
      initialEmail = "";
    }
    _emailController = TextEditingController(text: initialEmail);

    // If initialPhone is valid and not empty, mark as read-only
    _isPhoneReadOnly = initialPhone.isNotEmpty && initialPhone.replaceAll(RegExp(r'\D'), '').length >= 10;
  }

  void _onComplete() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    
    if (name.isEmpty) {
      TopNotification.show(context, message: 'Please enter your full name', type: NotificationType.error);
      return;
    }
    
    // Email Validation
    if (email.isEmpty) {
      TopNotification.show(context, message: 'Please enter your email address', type: NotificationType.error);
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      TopNotification.show(context, message: 'Please enter a valid email address', type: NotificationType.error);
      return;
    }

    // Phone Validation
    if (rawPhone.length != 10) {
      TopNotification.show(context, message: 'Please enter a valid 10-digit phone number', type: NotificationType.error);
      return;
    }
    final formattedPhone = '+91$rawPhone';

    if (!_agreedToTerms) {
      TopNotification.show(context, message: 'Please agree to terms and privacy policy', type: NotificationType.error);
      return;
    }

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF94C66)),
      ),
    );

    // SAVE TO PROVIDER (handles Cloud Firestore saving and background sync/merge)
    try {
      context.read<UserProvider>().updateProfile(
        name: name,
        phone: formattedPhone,
        email: email,
      );
      
      // Close loader
      Navigator.pop(context);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      TopNotification.show(context, message: "Profile completed successfully!", type: NotificationType.success);
    } catch (e) {
      Navigator.pop(context); // Close loader
      TopNotification.show(context, message: "Failed to complete profile: $e", type: NotificationType.error);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Progress Bar (Screen 7 style - Full)
              Row(
                children: [
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66), borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 40),
              
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF94C66).withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF94C66).withOpacity(0.1), width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Color(0xFFF94C66), size: 45),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF94C66),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  "Complete Your Profile",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Set up your account with secure credentials",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 40),
              
              _buildLabel("Phone Number"),
              if (_isPhoneReadOnly)
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.phone ?? context.read<UserProvider>().phone,
                        style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: const Text(
                        "+91",
                        style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: "Enter 10-digit number",
                            hintStyle: TextStyle(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w500),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              
              _buildLabel("Full Name"),
              _buildTextField(_nameController, "Enter your full name", TextInputType.name),
              const SizedBox(height: 20),
              
              _buildLabel("Email Address"),
              _buildTextField(_emailController, "Enter your Email Address", TextInputType.emailAddress),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: const Color(0xFFF94C66),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: "I agree to ",
                        style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: "Terms & Privacy Policy",
                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF94C66).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("Verify & Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, TextInputType type) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
