import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/state_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _avatarController;
  final _passwordController = TextEditingController();

  String _preferredCurrency = 'INR';
  String _language = 'en';
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<StateManager>(context, listen: false);
    final user = state.currentUserModel;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _mobileController = TextEditingController(text: user?.mobileNumber ?? '');
    _avatarController = TextEditingController(text: user?.avatarUrl ?? '');
    _preferredCurrency = user?.preferredCurrency ?? 'INR';
    _language = user?.language ?? 'en';
    _emailNotifications = user?.emailNotifications ?? true;
    _pushNotifications = user?.pushNotifications ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final state = Provider.of<StateManager>(context, listen: false);
    final result = await state.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      mobileNumber: _mobileController.text.trim(),
      avatarUrl: _avatarController.text.trim(),
      preferredCurrency: _preferredCurrency,
      language: _language,
      emailNotifications: _emailNotifications,
      pushNotifications: _pushNotifications,
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
        _passwordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update profile'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D9488)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.1, 0.7, 1.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFF0D9488),
                          backgroundImage: _avatarController.text.isNotEmpty
                              ? NetworkImage(_avatarController.text)
                              : null,
                          child: _avatarController.text.isEmpty
                              ? Text(
                                  _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0F172A)),
                              onPressed: () {
                                _showAvatarUrlDialog();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Info Card
                  _buildSectionTitle('Personal Info'),
                  _buildCard([
                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Full Name', Icons.person),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration('Email Address (Optional)', Icons.email),
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(val.trim())) return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Mobile Number
                    TextFormField(
                      controller: _mobileController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _buildInputDecoration('Mobile Number', Icons.phone).copyWith(counterText: ''),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your mobile number';
                        final reg = RegExp(r'^[6-9]\d{9}$');
                        if (!reg.hasMatch(val.trim())) return 'Enter a valid 10-digit number starting with 6-9';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Preferences Card
                  _buildSectionTitle('Preferences'),
                  _buildCard([
                    // Preferred Currency
                    DropdownButtonFormField<String>(
                      value: _preferredCurrency,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Preferred Currency', Icons.monetization_on),
                      items: const [
                        DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _preferredCurrency = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Preferred Language
                    DropdownButtonFormField<String>(
                      value: _language,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Language', Icons.language),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                        DropdownMenuItem(value: 'es', child: Text('Spanish')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _language = val);
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Notifications Card
                  _buildSectionTitle('Notifications'),
                  _buildCard([
                    SwitchListTile(
                      title: const Text('Email Notifications', style: TextStyle(color: Colors.white)),
                      value: _emailNotifications,
                      activeColor: const Color(0xFF14B8A6),
                      onChanged: (val) => setState(() => _emailNotifications = val),
                    ),
                    const Divider(color: Colors.white10),
                    SwitchListTile(
                      title: const Text('Push Notifications', style: TextStyle(color: Colors.white)),
                      value: _pushNotifications,
                      activeColor: const Color(0xFF14B8A6),
                      onChanged: (val) => setState(() => _pushNotifications = val),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Change Password Card
                  _buildSectionTitle('Security'),
                  _buildCard([
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('New Password (Optional)', Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          if (val.length < 8) return 'Password must be at least 8 characters';
                          final reg = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$');
                          if (!reg.hasMatch(val)) return 'Must contain 1 uppercase, 1 lowercase, 1 digit & 1 special char';
                        }
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Save Profile Button
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                  else
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF0D9488), size: 20),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D9488))),
    );
  }

  void _showAvatarUrlDialog() {
    final controller = TextEditingController(text: _avatarController.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Change Avatar URL', style: TextStyle(color: Colors.white)),
          content: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Avatar Image URL',
              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D9488))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _avatarController.text = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Apply', style: TextStyle(color: Color(0xFF0D9488))),
            ),
          ],
        );
      },
    );
  }
}
