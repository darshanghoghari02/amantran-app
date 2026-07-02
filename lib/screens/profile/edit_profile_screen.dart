import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/app_image.dart';
import '../../utils/country_codes.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  String? _tempImagePath;
  Country _selectedCountry = countries.firstWhere((c) => c.code == 'IN');
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameController = TextEditingController(text: user.name);
    
    if (user.phone.isNotEmpty) {
      _selectedCountry = CountryParser.parsePhone(user.phone);
      final local = CountryParser.getLocalNumber(user.phone);
      _phoneController = TextEditingController(text: local);
    } else {
      _phoneController = TextEditingController();
      // Auto detect country by device locale if empty
      try {
        final countryCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
        _selectedCountry = CountryParser.detectCountry(countryCode);
      } catch (_) {}
    }
    
    _emailController = TextEditingController(text: user.email);
    _tempImagePath = user.profileImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _tempImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      _showError("Failed to select image: $e");
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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

  void _handleUpdate() async {
    final lang = context.read<LanguageProvider>();
    
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showError(lang.pleaseEnterName);
      return;
    }
    
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final mismatchError = CountryParser.checkPhoneMismatch(_selectedCountry.dialCode, rawPhone);
    if (mismatchError != null) {
      _showError(mismatchError);
      return;
    }

    if (!RegExp(r'^\d{7,15}$').hasMatch(rawPhone)) {
      _showError(lang.pleaseEnterPhone);
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      _showError(lang.pleaseEnterEmail);
      return;
    }

    try {
      await context.read<UserProvider>().updateProfile(
        name: _nameController.text.trim(),
        phone: "${_selectedCountry.dialCode}$rawPhone",
        email: _emailController.text.trim(),
        profileImagePath: _tempImagePath,
      );

      // Refresh profile from backend to get the updated image URL
      await context.read<UserProvider>().fetchProfileFromCloud(silent: true);

      if (mounted) {
        Navigator.pop(context); // Pop EditProfileScreen
        TopNotification.show(context, message: lang.profileUpdated);
      }
    } catch (e) {
      final cleanMsg = e.toString().replaceAll('Exception: ', '').replaceAll('Exception', '');
      _showError(cleanMsg);
    }
  }

  void _showError(String message) {
    TopNotification.show(context, message: message, type: NotificationType.error);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            )
                          ]
                        ),
                        child: const Icon(Icons.arrow_back, color: Color(0xFFF94C66), size: 20),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lang.yourProfile,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── Profile Photo ──
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: AppImage(
                          src: _tempImagePath ?? '',
                          fit: BoxFit.cover,
                          errorWidget: Image.asset(
                            'assets/images/banner_image.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF94C66),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Name & Email display ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    Text(
                      _nameController.text,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── Form Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF94C66).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_outline, color: Color(0xFFF94C66), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            lang.personalInformation,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      _buildFieldLabel(lang.fullName),
                      _buildTextField(_nameController, lang),

                      const SizedBox(height: 20),

                      // Phone Number
                      _buildFieldLabel(lang.phoneNumber),
                      _buildTextField(_phoneController, lang, isPhone: true),

                      const SizedBox(height: 20),

                      // Email
                      _buildFieldLabel(lang.email),
                      _buildTextField(_emailController, lang, isEmail: true),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Update Button ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF94C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: Text(
                      lang.updateProfile,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, LanguageProvider lang, {bool isPhone = false, bool isEmail = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          if (isPhone)
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedCountry.dialCode,
                      style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54, size: 16),
                  ],
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (val) {
                if (isPhone) {
                  _onPhoneChanged(val);
                } else {
                  setState(() {});
                }
              },
              keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.name),
              inputFormatters: isPhone ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(15),
              ] : null,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 8 : 16,
                  vertical: 14,
                ),
                suffixIcon: isEmail ? Padding(
                  padding: const EdgeInsets.only(right: 16, top: 14),
                  child: Text(
                    lang.change,
                    style: const TextStyle(color: Color(0xFFF94C66), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
