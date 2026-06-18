import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import '../../utils/image_resolver.dart';

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

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone.replaceAll(RegExp(r'[^0-9]'), ''));
    if (_phoneController.text.startsWith('91') && _phoneController.text.length > 10) {
      _phoneController.text = _phoneController.text.substring(_phoneController.text.length - 10);
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

  Future<void> _pickImage() async {
    // Request storage permissions
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        _showError("Permission denied. Please grant storage permission to select image.");
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _tempImagePath = pickedFile.path;
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _handleUpdate() async {
    final lang = context.read<LanguageProvider>();
    
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showError(lang.pleaseEnterName);
      return;
    }
    
    if (_phoneController.text.length != 10) {
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
        phone: "+91${_phoneController.text}",
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
                        child: _tempImagePath != null && _tempImagePath!.isNotEmpty
                            ? (_tempImagePath!.startsWith('http')
                                ? Image.network(
                                    resolveImageUrl(_tempImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Error loading temp profile image: $error');
                                      return Image.asset('assets/images/banner_image.png', fit: BoxFit.cover);
                                    },
                                  )
                                : Image.file(File(_tempImagePath!), fit: BoxFit.cover))
                            : Image.asset('assets/images/banner_image.png', fit: BoxFit.cover),
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
      child: TextField(
        controller: controller,
        onChanged: (val) => setState(() {}),
        keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.name),
        inputFormatters: isPhone ? [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ] : null,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixText: isPhone ? "+91 " : null,
          prefixStyle: const TextStyle(color: Colors.black87, fontSize: 14),
          suffixText: isPhone || isEmail ? lang.change : null,
          suffixStyle: const TextStyle(color: Color(0xFFF94C66), fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
