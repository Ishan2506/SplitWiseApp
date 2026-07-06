import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../state/state_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isAuthenticating = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D9488)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.1, 0.6, 1.2],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Brand Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                const Text(
                  'SplitWise Premium',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Split bills, share experiences, 100% ad-free.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                
                const Spacer(),

                // Premium Features List Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(Icons.block, 'Ad-Free Experience', 'No popup ads, no waiting screens'),
                      const SizedBox(height: 16),
                      _buildFeatureItem(Icons.all_inclusive, 'Unlimited Entries', 'Log as many split expenses as you need'),
                      const SizedBox(height: 16),
                      _buildFeatureItem(Icons.auto_graph, 'Debt Simplification', 'Minimizes peer-to-peer settlement steps'),
                    ],
                  ),
                ),

                const Spacer(),

                // Sign in with Google Button
                if (_isAuthenticating)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleGoogleSignIn(state),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                            height: 20,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF14B8A6), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn(StateManager state) async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Trigger the real Google Sign-In native chooser flow
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        state.loginWithGoogleAccount(
          name: account.displayName ?? 'Google User',
          email: account.email,
          avatarUrl: account.photoUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D9488),
              content: Text('Logged in successfully as ${account.displayName}!'),
            ),
          );
        }
      } else {
        // User cancelled the sign-in chooser dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign-in cancelled.'),
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      
      // Fallback instruction helper snackbar if app is not signed (SHA-1/Firebase configurations missing)
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Configuration Required', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: const Text(
                'To complete Real Google Sign-In, please register your app Package Name/SHA-1 fingerprint in Firebase Console and place your "google-services.json" file in your project\'s android/app directory.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
}
