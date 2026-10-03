import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/auth_provider.dart';
import 'package:mainapp/config/api_config.dart';
import 'package:mainapp/config/permissions.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      setState(() {
        _hasAccess = auth.hasPermission(permAdminPanel);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Panel")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "You don't have access to the admin panel.",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                "Contact an administrator to request access.",
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: "Users"),
            Tab(icon: Icon(Icons.shield_outlined), text: "Roles"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UsersTab(),
          _RolesTab(),
        ],
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<dynamic> _users = [];
  List<dynamic> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final usersRes = await auth.dio.get(ApiConfig.adminUsersUrl);
      final rolesRes = await auth.dio.get(ApiConfig.adminRolesUrl);
      setState(() {
        _users = usersRes.data as List;
        _roles = rolesRes.data as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load users.";
        _isLoading = false;
      });
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'staff':
        return Colors.blue;
      case 'moderator':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleBan(dynamic user) async {
    final auth = context.read<AuthProvider>();
    final isActive = user["is_active"] as bool;
    final canBan = auth.hasPermission(permUserBan);
    final canUnban = auth.hasPermission(permUserUnban);

    if (isActive && !canBan) {
      _showSnack("You don't have permission to ban users.", isError: true);
      return;
    }
    if (!isActive && !canUnban) {
      _showSnack("You don't have permission to unban users.", isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? "Ban User" : "Unban User"),
        content: Text(
          isActive
              ? "Are you sure you want to ban ${user["username"]}? They will no longer be able to log in."
              : "Are you sure you want to unban ${user["username"]}? They will be able to log in again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: isActive ? Colors.red : Colors.green,
            ),
            child: Text(isActive ? "Ban" : "Unban"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final url = isActive
            ? ApiConfig.adminUserBanUrl(user["id"])
            : ApiConfig.adminUserUnbanUrl(user["id"]);
        await auth.dio.post(url);
        _showSnack(
          isActive
              ? "${user["username"]} has been banned."
              : "${user["username"]} has been unbanned.",
        );
        _loadData();
      } catch (e) {
        _showSnack("Failed to update user.", isError: true);
      }
    }
  }

  Future<void> _changeRole(dynamic user) async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasPermission(permUserManageRoles)) {
      _showSnack("You don't have permission to manage roles.", isError: true);
      return;
    }
    if (user["is_superuser"] == true) {
      _showSnack("Cannot change the role of a superuser.", isError: true);
      return;
    }

    final currentRoleId = _roles.firstWhere(
      (r) => r["name"] == user["role"],
      orElse: () => _roles.isNotEmpty ? _roles[0] : null,
    )?["id"];

    final selectedRoleId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text("Change role for ${user["username"]}"),
        children: _roles.map<SimpleDialogOption>((role) {
          final isSelected = role["id"] == currentRoleId;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, role["id"]),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _roleColor(role["name"]),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(role["display_name"]),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selectedRoleId != null && selectedRoleId != currentRoleId) {
      try {
        await auth.dio.patch(
          ApiConfig.adminUserUpdateRoleUrl(user["id"]),
          data: {"role_id": selectedRoleId},
        );
        final role = _roles.firstWhere((r) => r["id"] == selectedRoleId);
        _showSnack(
          "${user["username"]}'s role changed to ${role["display_name"]}.",
        );
        _loadData();
      } catch (e) {
        _showSnack("Failed to change role.", isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text("Retry")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final role = user["role"] ?? "user";
          final isActive = user["is_active"] ?? true;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive ? null : Colors.grey[300],
                child: Text(
                  (user["username"] ?? "?")[0].toUpperCase(),
                  style: TextStyle(
                    color: isActive ? null : Colors.grey[600],
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user["username"] ?? "N/A",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor(role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _roleColor(role),
                      ),
                    ),
                  ),
                  if (!isActive) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "BANNED",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                user["email"] ?? "N/A",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'role':
                      _changeRole(user);
                      break;
                    case 'ban':
                      _toggleBan(user);
                      break;
                  }
                },
                itemBuilder: (context) {
                  final auth = context.read<AuthProvider>();
                  final items = <PopupMenuEntry<String>>[];

                  if (auth.hasPermission(permUserManageRoles)) {
                    items.add(const PopupMenuItem(
                      value: 'role',
                      child: Text("Change Role"),
                    ));
                  }

                  if (isActive && auth.hasPermission(permUserBan)) {
                    items.add(PopupMenuItem(
                      value: 'ban',
                      child: const Text("Ban User",
                          style: TextStyle(color: Colors.red)),
                    ));
                  } else if (!isActive && auth.hasPermission(permUserUnban)) {
                    items.add(PopupMenuItem(
                      value: 'ban',
                      child: const Text("Unban User",
                          style: TextStyle(color: Colors.green)),
                    ));
                  }

                  return items;
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RolesTab extends StatefulWidget {
  const _RolesTab();

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  List<dynamic> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoles());
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.dio.get(ApiConfig.adminRolesUrl);
      setState(() {
        _roles = response.data as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load roles.";
        _isLoading = false;
      });
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'staff':
        return Colors.blue;
      case 'moderator':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadRoles, child: const Text("Retry")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoles,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _roles.length,
        itemBuilder: (context, index) {
          final role = _roles[index];
          final color = _roleColor(role["name"]);
          final permissions = (role["permissions"] as List)
              .map<String>((p) => p["code"] as String)
              .toList();
          final userCount = role["user_count"] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              title: Row(
                children: [
                  Text(
                    role["display_name"],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "$userCount users",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Permissions:",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (context.read<AuthProvider>().hasPermission(permUserManageRoles))
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _managePermissions(role),
                              tooltip: "Edit Permissions",
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: permissions.map((perm) {
                          return Chip(
                            label: Text(perm, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _managePermissions(Map<String, dynamic> role) async {
    final auth = context.read<AuthProvider>();
    
    List<dynamic> allPermissions = [];
    try {
      final res = await auth.dio.get(ApiConfig.adminPermissionsUrl);
      allPermissions = res.data as List;
    } catch (e) {
      _showSnack("Failed to load permissions.", isError: true);
      return;
    }
    
    if (!mounted) return;
    
    final currentRolePermIds = (role["permissions"] as List)
        .map<int>((p) => p["id"] as int)
        .toSet();
        
    final selectedPermIds = Set<int>.from(currentRolePermIds);
    
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Manage ${role['display_name']} Permissions"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allPermissions.length,
                  itemBuilder: (context, idx) {
                    final perm = allPermissions[idx];
                    final permId = perm["id"] as int;
                    final isChecked = selectedPermIds.contains(permId);
                    
                    return CheckboxListTile(
                      title: Text(perm["name"] ?? ""),
                      subtitle: Text(perm["description"] ?? perm["code"] ?? ""),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedPermIds.add(permId);
                          } else {
                            selectedPermIds.remove(permId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedPermIds),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await auth.dio.patch(
          ApiConfig.adminRoleUpdateUrl(role["id"] as int),
          data: {"permission_ids": result.toList()},
        );
        _showSnack("Permissions updated successfully.");
        _loadRoles();
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnack("Failed to update permissions.", isError: true);
      }
    }
  }
}
