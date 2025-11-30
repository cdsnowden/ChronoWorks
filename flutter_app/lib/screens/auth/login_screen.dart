import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/super_admin_service.dart';
import '../../routes.dart';
import '../../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Get returnUrl from route arguments if available
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final returnUrl = args?['returnUrl'] as String?;

    final authProvider = context.read<app_auth.AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      // Check if user is super admin first
      final superAdminService = SuperAdminService();
      final isSuperAdmin = await superAdminService.isSuperAdmin();

      if (isSuperAdmin) {
        // Super admin goes to super admin dashboard or returnUrl
        // Clear any error messages from the auth provider
        authProvider.clearError();
        Navigator.of(context).pushReplacementNamed(
          returnUrl ?? AppRoutes.adminDashboard,
        );
        return;
      }

      // Navigate based on role for regular users
      final user = authProvider.currentUser!;

      // Check if user needs to change password
      if (user.requiresPasswordChange == true) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.changePassword);
        return;
      }

      if (user.role == 'account_manager') {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
      } else if (user.isAdmin) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
      } else if (user.isManager) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.managerDashboard);
      } else {
        // For employees, check if profile is complete
        if (!user.isProfileComplete) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.completeProfile);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.employeeDashboard);
        }
      }
    } else {
      // Sign in failed - check if it's an Account Manager or Super Admin
      // (they don't have entries in the users collection)
      // Clear the error from the failed attempt before trying alternative auth
      authProvider.clearError();

      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        // Check if super admin
        final superAdminService = SuperAdminService();
        final isSuperAdmin = await superAdminService.isSuperAdmin();

        if (isSuperAdmin) {
          // Clear any error messages from the auth provider
          authProvider.clearError();
          Navigator.of(context).pushReplacementNamed(
            returnUrl ?? AppRoutes.adminDashboard,
          );
          return;
        }

        // Check if account manager
        final isAccountManager = await _checkIfAccountManager();
        if (isAccountManager) {
          // Clear any error messages from the auth provider
          authProvider.clearError();
          Navigator.of(context).pushReplacementNamed(
            returnUrl ?? AppRoutes.adminDashboard,
          );
          return;
        }

        // If not super admin or account manager, sign out and show error
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _checkIfAccountManager() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('accountManagers')
          .doc(user.uid)
          .get();

      return doc.exists && (doc.data()?['status'] == 'active');
    } catch (e) {
      print('Error checking if account manager: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, child) {
                
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Logo/Icon
                      Icon(
                        Icons.access_time_filled,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),

                      // App Name
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'Time Tracking & Scheduling',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !authProvider.isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !authProvider.isLoading,
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < AppConstants.minPasswordLength) {
                                  return 'Password must be at least ${AppConstants.minPasswordLength} characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).pushNamed(
                                          AppRoutes.passwordReset,
                                        );
                                      },
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            ElevatedButton(
                              onPressed: authProvider.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      
                      const SizedBox(height: 24),

                      // Version Info
                      Text(
                        'Version ${AppConstants.appVersion}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
