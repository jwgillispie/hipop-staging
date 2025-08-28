import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class PhoneAuthScreen extends StatefulWidget {
  final String userType;
  final bool isLogin;

  const PhoneAuthScreen({
    super.key,
    required this.userType,
    this.isLogin = true,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _completePhoneNumber = '';
  String? _verificationId;
  int? _resendToken;
  bool _codeSent = false;
  int _resendTimer = 0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendTimer--;
        });
      }
      return _resendTimer > 0 && mounted;
    });
  }

  Color _getUserTypeColor() {
    switch (widget.userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      default:
        return HiPopColors.shopperAccent;
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.userType) {
      case 'vendor':
        return [
          HiPopColors.vendorAccent,
          HiPopColors.vendorAccent.withOpacity(0.7),
        ];
      case 'market_organizer':
        return [
          HiPopColors.organizerAccent,
          HiPopColors.organizerAccent.withOpacity(0.7),
        ];
      default:
        return [
          HiPopColors.shopperAccent,
          HiPopColors.shopperAccent.withOpacity(0.7),
        ];
    }
  }

  String _getUserTypeTitle() {
    switch (widget.userType) {
      case 'vendor':
        return 'Vendor';
      case 'market_organizer':
        return 'Market Organizer';
      default:
        return 'Shopper';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PhoneAuthCodeSent) {
          setState(() {
            _codeSent = true;
            _verificationId = state.verificationId;
            _resendToken = state.resendToken;
          });
          _startResendTimer();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification code sent!'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
        } else if (state is PhoneAuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: HiPopColors.errorPlum,
            ),
          );
        } else if (state is Authenticated) {
          // Navigate to appropriate dashboard
          if (state.userProfile != null) {
            switch (state.userProfile!.userType) {
              case 'vendor':
                context.go('/vendor-dashboard');
                break;
              case 'market_organizer':
                context.go('/organizer-dashboard');
                break;
              default:
                context.go('/shopper-home');
            }
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getGradientColors(),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: HiPopColors.darkSurface,
                      ),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: !_codeSent
                                ? _buildPhoneInputSection()
                                : _buildOtpSection(),
                          ),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _getGradientColors(),
            ),
            boxShadow: [
              BoxShadow(
                color: _getUserTypeColor().withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.phone_android,
            size: 48,
            color: HiPopColors.darkSurface,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${_getUserTypeTitle()} ${widget.isLogin ? 'Login' : 'Sign Up'}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _codeSent
              ? 'Enter the 6-digit code sent to\n$_completePhoneNumber'
              : widget.isLogin
                  ? 'Welcome back! Sign in to continue'
                  : 'Join HiPop Markets as a ${_getUserTypeTitle()}',
          style: TextStyle(
            fontSize: 16,
            color: HiPopColors.darkTextSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhoneInputSection() {
    return Column(
      key: const ValueKey('phone-input'),
      children: [
        _buildPhoneInput(),
        if (!widget.isLogin) ...[
          const SizedBox(height: 20),
          _buildNameInput(),
        ],
        const SizedBox(height: 32),
        _buildSendCodeButton(),
        const SizedBox(height: 16),
        _buildAlternativeAuthButton(),
      ],
    );
  }

  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp-input'),
      children: [
        _buildOtpInput(),
        const SizedBox(height: 32),
        _buildVerifyButton(),
        const SizedBox(height: 16),
        if (_resendTimer == 0)
          _buildResendButton()
        else
          Text(
            'Resend code in $_resendTimer seconds',
            style: TextStyle(
              color: HiPopColors.darkTextTertiary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _codeSent = false;
              _otpController.clear();
            });
          },
          child: Text(
            'Change Phone Number',
            style: TextStyle(
              color: _getUserTypeColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return IntlPhoneField(
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HiPopColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _getUserTypeColor(), width: 2),
        ),
        filled: true,
        fillColor: HiPopColors.darkBackground,
      ),
      style: TextStyle(color: HiPopColors.darkTextPrimary),
      initialCountryCode: 'US',
      onChanged: (phone) {
        _completePhoneNumber = phone.completeNumber;
      },
      validator: (phone) {
        if (phone == null || phone.number.isEmpty) {
          return 'Please enter a phone number';
        }
        return null;
      },
    );
  }

  Widget _buildNameInput() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Full Name',
        labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
        prefixIcon: Icon(Icons.person_outline, color: _getUserTypeColor()),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HiPopColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _getUserTypeColor(), width: 2),
        ),
        filled: true,
        fillColor: HiPopColors.darkBackground,
      ),
      style: TextStyle(color: HiPopColors.darkTextPrimary),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (!widget.isLogin && (value == null || value.trim().isEmpty)) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildOtpInput() {
    return Column(
      children: [
        Text(
          'Verification Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 20),
        PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _otpController,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(12),
            fieldHeight: 55,
            fieldWidth: 45,
            activeFillColor: HiPopColors.darkBackground,
            inactiveFillColor: HiPopColors.darkSurface,
            selectedFillColor: _getUserTypeColor().withOpacity(0.1),
            activeColor: _getUserTypeColor(),
            inactiveColor: HiPopColors.darkBorder,
            selectedColor: _getUserTypeColor(),
          ),
          cursorColor: _getUserTypeColor(),
          animationDuration: const Duration(milliseconds: 300),
          enableActiveFill: true,
          keyboardType: TextInputType.number,
          textStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
          onChanged: (value) {},
          beforeTextPaste: (text) {
            return text != null && RegExp(r'^\d{6}$').hasMatch(text);
          },
        ),
      ],
    );
  }

  Widget _buildSendCodeButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is PhoneAuthInProgress;
        
        return ElevatedButton(
          onPressed: isLoading ? null : _sendVerificationCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getUserTypeColor(),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isLoading ? 0 : 4,
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.darkSurface),
                  ),
                )
              : const Text(
                  'Send Verification Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is PhoneAuthInProgress;
        
        return ElevatedButton(
          onPressed: isLoading ? null : _verifyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getUserTypeColor(),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isLoading ? 0 : 4,
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.darkSurface),
                  ),
                )
              : const Text(
                  'Verify & Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildResendButton() {
    return TextButton.icon(
      onPressed: _resendCode,
      icon: const Icon(Icons.refresh),
      label: const Text('Resend Code'),
      style: TextButton.styleFrom(
        foregroundColor: _getUserTypeColor(),
      ),
    );
  }

  Widget _buildAlternativeAuthButton() {
    return TextButton.icon(
      onPressed: () {
        // Navigate back to email auth
        context.go('/auth-landing');
      },
      icon: const Icon(Icons.email_outlined),
      label: const Text('Use Email Instead'),
      style: TextButton.styleFrom(
        foregroundColor: HiPopColors.darkTextSecondary,
      ),
    );
  }

  void _sendVerificationCode() {
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid phone number'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }

    if (!widget.isLogin && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your name'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(
      PhoneSignInRequestedEvent(
        phoneNumber: _completePhoneNumber,
        userType: widget.isLogin ? null : widget.userType,
        displayName: widget.isLogin ? null : _nameController.text.trim(),
      ),
    );
  }

  void _verifyCode() {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the 6-digit code'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }

    if (_verificationId != null) {
      context.read<AuthBloc>().add(
        VerifyPhoneCodeEvent(
          verificationId: _verificationId!,
          smsCode: _otpController.text,
          userType: widget.isLogin ? null : widget.userType,
          displayName: widget.isLogin ? null : _nameController.text.trim(),
        ),
      );
    }
  }

  void _resendCode() {
    context.read<AuthBloc>().add(
      ResendPhoneCodeEvent(
        phoneNumber: _completePhoneNumber,
        resendToken: _resendToken,
      ),
    );
    _startResendTimer();
  }
}