import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';


class AuthScreen extends StatefulWidget {
  final String userType;
  final bool isLogin;
  
  const AuthScreen({
    super.key, 
    required this.userType,
    required this.isLogin,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;
  
  bool get _isLogin => widget.isLogin;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorSnackBar('Passwords do not match');
        return;
      }
      
      if (!_termsAccepted) {
        _showErrorSnackBar('Please accept the Terms of Service and Privacy Policy to continue');
        return;
      }
      
      context.read<AuthBloc>().add(SignUpEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: widget.userType,
      ));
    } else {
      context.read<AuthBloc>().add(LoginEvent(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.errorPlum,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Scaffold(
      backgroundColor: isDarkTheme ? HiPopColors.darkBackground : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back, 
            color: isDarkTheme ? HiPopColors.darkTextPrimary : Colors.white,
          ),
          onPressed: () => context.go('/auth'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showErrorSnackBar(state.message);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isDarkTheme 
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _getGradientColors(),
                ),
            color: isDarkTheme ? HiPopColors.darkBackground : null,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: isDarkTheme ? 0 : 8,
                  color: isDarkTheme ? HiPopColors.darkSurface : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDarkTheme 
                      ? BorderSide(
                          color: HiPopColors.accentMauve.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildForm(),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildTermsAcceptance(),
                          ],
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                          const SizedBox(height: 16),
                          _buildToggleButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Column(
      children: [
        Icon(
          widget.userType == 'vendor' 
              ? Icons.store 
              : widget.userType == 'market_organizer'
                  ? Icons.business
                  : Icons.shopping_bag,
          size: 64,
          color: _getUserTypeColor(),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.userType == 'vendor' ? 'Vendor' : widget.userType == 'market_organizer' ? 'Market Organizer' : 'Shopper'} ${_isLogin ? 'Login' : 'Sign Up'}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin 
              ? 'Welcome back! Please sign in'
              : 'Create your account to get started',
          style: TextStyle(
            fontSize: 16,
            color: isDarkTheme 
              ? HiPopColors.darkTextSecondary 
              : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    final Color accentColor = _getUserTypeColor();
    
    final InputDecoration baseDecoration = InputDecoration(
      filled: true,
      fillColor: isDarkTheme ? HiPopColors.darkSurfaceVariant : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDarkTheme 
          ? BorderSide(color: HiPopColors.darkBorder)
          : const BorderSide(),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDarkTheme 
          ? BorderSide(color: HiPopColors.darkBorder.withValues(alpha: 0.5))
          : const BorderSide(),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: accentColor,
          width: 2,
        ),
      ),
      labelStyle: TextStyle(
        color: isDarkTheme ? HiPopColors.darkTextSecondary : null,
      ),
      hintStyle: TextStyle(
        color: isDarkTheme 
          ? HiPopColors.darkTextSecondary.withValues(alpha: 0.5)
          : null,
      ),
      prefixIconColor: isDarkTheme ? HiPopColors.darkTextSecondary : null,
    );
    
    return Column(
      children: [
        if (!_isLogin) ...[
          TextFormField(
            controller: _nameController,
            style: TextStyle(
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
            decoration: baseDecoration.copyWith(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _emailController,
          style: TextStyle(
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
          decoration: baseDecoration.copyWith(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          style: TextStyle(
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
          decoration: baseDecoration.copyWith(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your password';
            }
            if (!_isLogin && value.trim().length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        if (!_isLogin) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            style: TextStyle(
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
            decoration: baseDecoration.copyWith(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getUserTypeColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isLogin ? 'Sign In' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildToggleButton() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return TextButton(
      onPressed: () {
        if (_isLogin) {
          context.go('/signup?type=${widget.userType}');
        } else {
          context.go('/login?type=${widget.userType}');
        }
      },
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: isDarkTheme 
              ? HiPopColors.darkTextSecondary
              : Colors.grey[600],
          ),
          children: [
            TextSpan(
              text: _isLogin 
                  ? "Don't have an account? "
                  : 'Already have an account? ',
            ),
            TextSpan(
              text: _isLogin ? 'Sign Up' : 'Sign In',
              style: TextStyle(
                color: _getUserTypeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUserTypeColor() {
    switch (widget.userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      case 'shopper':
        // Use mauve for shopper instead of soft sage
        return HiPopColors.accentMauve;
      default:
        return HiPopColors.accentMauve;
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.userType) {
      case 'vendor':
        return [HiPopColors.vendorAccent, HiPopColors.vendorAccentDark];
      case 'market_organizer':
        return [HiPopColors.organizerAccent, HiPopColors.organizerAccentDark];
      case 'shopper':
        // Use mauve gradient for shoppers
        return [HiPopColors.accentMauve, HiPopColors.accentMauveDark];
      default:
        return [HiPopColors.accentMauve, HiPopColors.accentMauveDark];
    }
  }

  Widget _buildTermsAcceptance() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme 
          ? HiPopColors.darkSurfaceVariant 
          : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkTheme 
            ? HiPopColors.darkBorder.withValues(alpha: 0.5)
            : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() {
                _termsAccepted = value ?? false;
              });
            },
            activeColor: _getUserTypeColor(),
            side: isDarkTheme 
              ? BorderSide(color: HiPopColors.darkTextSecondary)
              : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    Text(
                      'I agree to the ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme 
                          ? HiPopColors.darkTextPrimary
                          : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/legal'),
                      child: Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getUserTypeColor(),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' and ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme 
                          ? HiPopColors.darkTextPrimary
                          : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/legal'),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getUserTypeColor(),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'This includes consent for payment processing through Stripe, analytics data collection, and our three-sided marketplace platform terms.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkTheme 
                      ? HiPopColors.darkTextSecondary
                      : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}