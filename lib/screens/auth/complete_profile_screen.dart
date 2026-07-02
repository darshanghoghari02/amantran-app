import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import '../../utils/country_codes.dart';

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
  Country _selectedCountry = countries.firstWhere((c) => c.code == 'IN');
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    
    // Check if initial phone is provided or exists in UserProvider
    String initialPhone = widget.phone ?? userProvider.phone;
    // Clean default placeholders
    if (initialPhone.contains("00000 00000") || initialPhone.contains("0000000000")) {
      initialPhone = "";
    }
    
    if (initialPhone.isNotEmpty) {
      _selectedCountry = CountryParser.parsePhone(initialPhone);
      final local = CountryParser.getLocalNumber(initialPhone);
      _phoneController = TextEditingController(text: local);
    } else {
      _phoneController = TextEditingController();
      // Auto detect country by device locale if empty
      try {
        final countryCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
        _selectedCountry = CountryParser.detectCountry(countryCode);
      } catch (_) {}
    }
    
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
    final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
    _isPhoneReadOnly = initialPhone.isNotEmpty && digits.length >= 9;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<Country> filteredList = countries.where((c) {
              final query = _searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialCode.contains(query) ||
                  c.code.toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Select Country",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() {
                              _searchQuery = val;
                            });
                          },
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: "Search country or dial code...",
                            hintStyle: TextStyle(
                              color: Colors.black26,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Icon(Icons.search, color: Color(0xFFF94C66)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(
                              child: Text(
                                "No country found",
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final country = filteredList[index];
                                final isSelected = country.code == _selectedCountry.code;
                                return ListTile(
                                  onTap: () {
                                    setState(() {
                                      _selectedCountry = country;
                                    });
                                    Navigator.pop(context);
                                  },
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    country.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFFF94C66) : const Color(0xFF1A1A1A),
                                      fontSize: 15,
                                    ),
                                  ),
                                  trailing: Text(
                                    country.dialCode,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                                      color: isSelected ? const Color(0xFFF94C66) : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _searchQuery = "";
    });
  }

  void _onPhoneChanged(String val) {
    String text = val.trim();
    if (text.isEmpty) return;

    if (text.startsWith('00')) {
      text = '+' + text.substring(2);
    }

    if (text.startsWith('+')) {
      final country = CountryParser.parsePhone(text);
      final local = CountryParser.getLocalNumber(text);
      setState(() {
        _selectedCountry = country;
      });
      _phoneController.value = TextEditingValue(
        text: local,
        selection: TextSelection.collapsed(offset: local.length),
      );
      return;
    }

    if (text.length > 10) {
      final sorted = List<Country>.from(countries)
        ..sort((a, b) => b.dialCode.replaceAll(RegExp(r'\D'), '').length.compareTo(
            a.dialCode.replaceAll(RegExp(r'\D'), '').length));
      for (var country in sorted) {
        final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
        if (dialDigits.isNotEmpty && text.startsWith(dialDigits)) {
          final local = text.substring(dialDigits.length);
          setState(() {
            _selectedCountry = country;
          });
          _phoneController.value = TextEditingValue(
            text: local,
            selection: TextSelection.collapsed(offset: local.length),
          );
          return;
        }
      }
    }
  }

  void _onComplete() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    
    final mismatchError = CountryParser.checkPhoneMismatch(_selectedCountry.dialCode, rawPhone);
    if (mismatchError != null) {
      TopNotification.show(context, message: mismatchError, type: NotificationType.error);
      return;
    }
    
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
    if (!RegExp(r'^\d{7,15}$').hasMatch(rawPhone)) {
      TopNotification.show(context, message: 'Please enter a valid phone number', type: NotificationType.error);
      return;
    }
    final formattedPhone = '${_selectedCountry.dialCode}$rawPhone';

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
      await context.read<UserProvider>().updateProfile(
        name: name,
        phone: formattedPhone,
        email: email,
      );
      
      // Close loader
      Navigator.pop(context);

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      TopNotification.show(context, message: "Profile completed successfully!", type: NotificationType.success);
    } catch (e) {
      Navigator.pop(context); // Close loader
      final cleanMsg = e.toString().replaceAll('Exception: ', '').replaceAll('Exception', '');
      TopNotification.show(context, message: cleanMsg, type: NotificationType.error);
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
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.read<UserProvider>().logout();
            }
          },
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
              
              _buildLabel(lang.phoneNumber),
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
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountry.dialCode,
                              style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.black54,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          onChanged: _onPhoneChanged,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                            LengthLimitingTextInputFormatter(15),
                          ],
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: lang.enterPhoneNumber,
                            hintStyle: const TextStyle(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w500),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              
              _buildLabel(lang.fullName),
              _buildTextField(_nameController, "Enter your full name", TextInputType.name),
              const SizedBox(height: 20),
              
              _buildLabel(lang.emailAddress),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
