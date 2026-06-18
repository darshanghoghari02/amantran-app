import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../repositories/user_repository.dart';
import '../../providers/language_provider.dart';
import '../../services/firestore_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _currentUid = FirestoreService().resolvedUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _userRepository.fetchAllUsers();
      if (list != null) {
        setState(() {
          _users = list;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1F22)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.userManagement,
          style: const TextStyle(
            color: Color(0xFF1E1F22),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search by name or email...",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFF94C66)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          // Users List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF94C66),
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "No users found",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : () {
                        // Filter locally
                        final filteredUsers = _users.where((user) {
                          final name = (user['name'] ?? user['displayName'] ?? '').toString().toLowerCase();
                          final email = (user['email'] ?? '').toString().toLowerCase();
                          return name.contains(_searchQuery) || email.contains(_searchQuery);
                        }).toList();

                        if (filteredUsers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  "No users found matching query",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final uid = user['uid'] ?? user['id'] ?? '';
                            final name = user['name'] ?? user['displayName'] ?? 'No Name';
                            final email = user['email'] ?? 'No Email';
                            final photoUrl = user['profilePhoto'] as String?;
                            final role = user['role'] ?? 'user';
                            final status = user['accountStatus'] ?? 'active';
                            final isSelf = uid == _currentUid;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFF94C66).withOpacity(0.1),
                                backgroundImage: photoUrl != null && photoUrl.startsWith('http')
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null || !photoUrl.startsWith('http')
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Color(0xFFF94C66),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E1F22),
                                      ),
                                    ),
                                  ),
                                  if (isSelf)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "YOU",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Role Chip
                                      _buildChip(
                                        label: role.toUpperCase(),
                                        isPrimary: role == 'admin',
                                        primaryColor: const Color(0xFF6C63FF),
                                        secondaryColor: Colors.grey[400]!,
                                      ),
                                      const SizedBox(width: 8),
                                      // Status Chip
                                      _buildChip(
                                        label: status.toUpperCase(),
                                        isPrimary: status == 'active',
                                        primaryColor: const Color(0xFF2EC4B6),
                                        secondaryColor: const Color(0xFFFF4D6D),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () => _showEditUserDialog(uid, name, role, status, isSelf),
                            );
                          },
                        );
                      }(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isPrimary,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final activeColor = isPrimary ? primaryColor : secondaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: activeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showEditUserDialog(
    String uid,
    String name,
    String currentRole,
    String currentStatus,
    bool isSelf,
  ) {
    final lang = context.read<LanguageProvider>();
    String selectedRole = currentRole;
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Manage $name",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelf) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber[800], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You cannot modify your own role or status to prevent lockout.",
                              style: TextStyle(color: Colors.amber[900], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    lang.userRole,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text("User")),
                      DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: isSelf
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedRole = val;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.accountStatus,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text("Active")),
                      DropdownMenuItem(value: 'suspended', child: Text("Suspended")),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: isSelf
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedStatus = val;
                              });
                            }
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSelf
                      ? null
                      : () async {
                          Navigator.pop(context); // Close dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFF94C66),
                              ),
                            ),
                          );

                          try {
                            await _userRepository.updateAppUser(
                              uid: uid,
                              role: selectedRole,
                              accountStatus: selectedStatus,
                            );
                            await _fetchUsers();
                            if (context.mounted) {
                              Navigator.pop(context); // Pop loader
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User updated successfully.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Pop loader
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update user: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(lang.saveChanges),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
