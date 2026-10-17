import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:pinput/pinput.dart';

import '../config/optica2_config.dart';
import '../firebase_bootstrap.dart';
import '../seller_auth_prefs.dart';
import '../models/otp_config.dart';
import '../services/optica2_api.dart';
import '../services/seller_auth_navigation.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../utils/msg91_phone.dart';
import '../widgets/app_toast.dart';
import '../widgets/locale_phone_field.dart';

/// Phone + OTP sign-in. Provider comes from admin SMS Gateway (`GET /api/otp/config`):
/// Firebase Phone Auth on-device, or MSG91 via Optica2 `/api/otp/send` + `/verify`.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _BootstrapRetryCard extends StatelessWidget {
  const _BootstrapRetryCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bootstrapWarningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bootstrapWarningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.terracotta.withValues(alpha: 0.9),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepGreen.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.brandPurple,
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
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

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  final _optica2 = Optica2Api();

  PhoneNumber? _phone;
  OtpConfig? _otpConfig;
  bool _firebaseReady = false;
  bool _msg91Ready = false;
  String? _bootstrapError;

  bool get _useFirebase => _otpConfig?.isFirebase ?? false;

  bool get _authReady {
    final config = _otpConfig;
    if (config == null) return false;
    if (config.isMsg91) return _msg91Ready;
    return _firebaseReady;
  }

  bool get _hasSetupBlockingError {
    final message = _bootstrapError?.toLowerCase() ?? '';

    return message.contains('not configured') ||
        message.contains('selected in admin') ||
        message.contains('firebase') ||
        message.contains('sms gateway');
  }

  bool get _isRateLimitedBootstrapError {
    final message = _bootstrapError?.toLowerCase() ?? '';

    return message.contains('too many attempts') ||
        message.contains('too many requests') ||
        message.contains('rate limit');
  }

  bool _sending = false;
  bool _verifying = false;
  bool _restoringSession = false;
  bool _otpSent = false;
  bool _registrationFlow = false;
  String? _pendingPhoneE164;
  String? _msg91Mobile;
  String? _msg91RequestId;
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  int _resendSeconds = 0;
  Timer? _resendTimer;
  Timer? _sendOtpWatchdog;

  int get _otpLength => _otpConfig?.otpLength ?? 6;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _bootstrapError = null;
        _firebaseReady = false;
        _msg91Ready = false;
        _otpConfig = null;
      });
    }

    try {
      await Optica2Config.refresh();
      final config = await _optica2.fetchOtpConfig();
      if (!mounted) return;

      setState(() => _otpConfig = config);
      debugPrint(
        'OTP bootstrap: ${config.provider} @ ${Optica2Config.baseUrl}',
      );

      await _configureForProvider(config);
      if (!mounted || _bootstrapError != null) return;

      final otpDone = await SellerAuthPrefs.isOtpVerified();
      if (!otpDone || !mounted) return;

      final phone = config.isMsg91
          ? await SellerAuthPrefs.phoneE164()
          : (FirebaseAuth.instance.currentUser?.phoneNumber ??
              await SellerAuthPrefs.phoneE164());
      if (phone == null || phone.isEmpty) return;

      unawaited(_restoreSavedSession(phone));
    } catch (e, st) {
      debugPrint('PhoneAuth bootstrap failed: $e\n$st');
      if (mounted) {
        setState(() {
          _bootstrapError = e is Optica2ApiException
              ? e.message
              : 'Could not load OTP settings from the server. '
                  'Check your connection and try again.';
          _firebaseReady = false;
          _msg91Ready = false;
        });
      }
    }
  }

  /// Applies admin SMS Gateway choice: Firebase on-device or MSG91 API.
  Future<void> _configureForProvider(OtpConfig config) async {
    if (config.isMsg91) {
      if (!config.configured) {
        if (mounted) {
          setState(() {
            _bootstrapError =
                'MSG91 is selected in Admin → SMS Gateway but is not configured. '
                'Add the Auth Key and save, or switch to Firebase.';
            _msg91Ready = false;
            _firebaseReady = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _bootstrapError = null;
          _msg91Ready = true;
          _firebaseReady = false;
          _verificationId = null;
          _webConfirmation = null;
          _resendToken = null;
        });
      }
      return;
    }

    try {
      await ensureFirebaseInitialized();
      if (!mounted) return;
      setState(() {
        _bootstrapError = null;
        _firebaseReady = true;
        _msg91Ready = false;
        _msg91Mobile = null;
        _msg91RequestId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = firebaseBootstrapErrorMessage(e);
        _firebaseReady = false;
        _msg91Ready = false;
      });
    }
  }

  /// Ensures OTP provider matches admin setting before send/verify.
  Future<OtpConfig> _resolveOtpConfig() async {
    final config = await _optica2.fetchOtpConfig();
    debugPrint('OTP refresh: ${config.provider} @ ${Optica2Config.baseUrl}');
    if (mounted) {
      setState(() {
        _otpConfig = config;
        _bootstrapError = null;
      });
      await _configureForProvider(config);
    }
    if (_bootstrapError != null) {
      throw Optica2ApiException(_bootstrapError!);
    }
    return config;
  }

  Future<void> _ensureFirebaseReady() async {
    if (_firebaseReady) return;
    await ensureFirebaseInitialized();
    if (mounted) setState(() => _firebaseReady = true);
  }

  Future<void> _restoreSavedSession(String phone) async {
    if (!mounted) return;
    setState(() => _restoringSession = true);
    try {
      await SellerAuthNavigation.routeFromSavedSession(
        context,
        _optica2,
        phone,
      );
    } catch (e, st) {
      debugPrint('Saved session restore failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  void _cancelSendOtpWatchdog() {
    _sendOtpWatchdog?.cancel();
    _sendOtpWatchdog = null;
  }

  void _startSendOtpWatchdog() {
    _cancelSendOtpWatchdog();
    _sendOtpWatchdog = Timer(const Duration(seconds: 95), () {
      if (!mounted) return;
      if (!_sending || _otpSent) return;
      setState(() => _sending = false);
      AppToast.warning(
        context,
        'SMS is taking longer than usual. Tap Send OTP to try again.',
      );
    });
  }

  void _finishSendingOtp({bool showOtpStep = true}) {
    _cancelSendOtpWatchdog();
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (showOtpStep) _otpSent = true;
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _cancelSendOtpWatchdog();
    _optica2.close();
    _phoneController.dispose();
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  String _e164(PhoneNumber phone) {
    final complete = phone.completeNumber.replaceAll(RegExp(r'\s'), '');
    if (complete.isNotEmpty) {
      return toDisplayE164(complete);
    }
    final cc = phone.countryCode.replaceAll(RegExp(r'\D'), '');
    final national = phone.number.replaceAll(RegExp(r'\D'), '');
    if (cc.isEmpty || national.isEmpty) return '';
    return '+$cc$national';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String _phoneE164ForSend({required bool resend}) {
    if (resend &&
        _pendingPhoneE164 != null &&
        _pendingPhoneE164!.isNotEmpty) {
      return toDisplayE164(_pendingPhoneE164!);
    }
    final phone = _phone;
    if (phone == null || phone.number.trim().isEmpty) return '';
    return _e164(phone);
  }

  String _msg91MobileForVerify() {
    if (_msg91Mobile != null && _msg91Mobile!.isNotEmpty) {
      return toMsg91Mobile(_msg91Mobile!);
    }
    return toMsg91Mobile(_phoneE164ForSession());
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (_sending || _hasSetupBlockingError) return;

    if (!resend) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _formKey.currentState!.save();
    }

    final e164 = _phoneE164ForSend(resend: resend);
    if (e164.isEmpty) {
      AppToast.warning(context, 'Enter a valid phone number.');
      return;
    }
    _pendingPhoneE164 = e164;
    setState(() {
      _sending = true;
      _pinController.clear();
    });
    _startSendOtpWatchdog();

    OtpConfig otpConfig;
    try {
      otpConfig = await _resolveOtpConfig();
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      _cancelSendOtpWatchdog();
      setState(() => _sending = false);
      AppToast.danger(context, e.message);
      return;
    }

    try {
      final check = await _optica2.probeSellerPhone(e164);
      if (!mounted) return;

      if (check.isNotRegistered) {
        _registrationFlow = true;
      } else if (!check.canLogin &&
          !check.kycPending &&
          !check.isAwaitingAdminApproval) {
        _cancelSendOtpWatchdog();
        setState(() => _sending = false);
        AppToast.danger(context, check.message);
        return;
      } else {
        _registrationFlow = false;
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      _cancelSendOtpWatchdog();
      setState(() => _sending = false);
      AppToast.danger(context, e.message);
      return;
    }

    try {
      if (otpConfig.isMsg91) {
        if (!otpConfig.configured) {
          throw StateError('MSG91 is not configured on the server.');
        }
        debugPrint('OTP send via MSG91 API');
        final mobile = toMsg91Mobile(e164);
        if (mobile.length < 11) {
          throw StateError(
            'Enter your full number with country code (e.g. +923001234567).',
          );
        }
        _msg91Mobile = mobile;
        final sent = await _optica2.sendOtp(mobile, resend: resend);
        if (!mounted) return;
        setState(() {
          _msg91Mobile = sent.mobile.isNotEmpty
              ? toMsg91Mobile(sent.mobile)
              : mobile;
          _msg91RequestId = sent.requestId;
        });
        debugPrint(
          'MSG91 sent → mobile=${sent.mobile} requestId=${sent.requestId}',
        );
        if (kDebugMode &&
            otpConfig.devBypass &&
            sent.devOtp != null &&
            sent.devOtp!.isNotEmpty) {
          debugPrint('DEV OTP (local, no SMS): ${sent.devOtp}');
          AppToast.warning(
            context,
            'Local dev code: ${sent.devOtp} (no SMS sent)',
          );
        }
        _finishSendingOtp();
        _startResendCooldown();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _pinFocus.requestFocus(),
        );
        return;
      }

      if (!otpConfig.isFirebase) {
        throw StateError('Unknown OTP provider: ${otpConfig.provider}');
      }

      debugPrint('OTP send via Firebase Phone Auth');
      await _ensureFirebaseReady();
      await _sendFirebaseOtp(e164, resend: resend);
    } catch (e) {
      if (!mounted) return;
      _cancelSendOtpWatchdog();
      setState(() => _sending = false);
      AppToast.danger(context, '$e');
    }
  }

  Future<void> _sendFirebaseOtp(String full, {bool resend = false}) async {
    if (kIsWeb) {
      _webConfirmation =
          await FirebaseAuth.instance.signInWithPhoneNumber(full);
      if (!mounted) return;
      _finishSendingOtp();
      _startResendCooldown();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pinFocus.requestFocus(),
      );
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: full,
      timeout: const Duration(seconds: 90),
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) async {
        _cancelSendOtpWatchdog();
        if (!mounted) return;
        // Show verify screen even when Firebase auto-retrieves the SMS code.
        _finishSendingOtp();
        setState(() => _verifying = true);
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            await _routeAfterSignIn(_pendingPhoneE164 ?? full);
          }
        } catch (e) {
          if (!mounted) return;
          AppToast.danger(context, '$e');
        } finally {
          if (mounted) setState(() => _verifying = false);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        _cancelSendOtpWatchdog();
        setState(() => _sending = false);
        AppToast.danger(
          context,
          e.message ?? 'Verification failed',
        );
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = forceResendingToken;
        });
        _finishSendingOtp();
        _startResendCooldown();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _pinFocus.requestFocus(),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        setState(() => _verificationId = verificationId);
        _finishSendingOtp();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _pinFocus.requestFocus(),
        );
      },
    );
  }

  Future<void> _verifyOtp(String pin) async {
    final code = pin.replaceAll(RegExp(r'\D'), '');
    if (code.length != _otpLength || _verifying) return;

    final otpConfig = await _resolveOtpConfig();
    if (!mounted) return;

    if (otpConfig.isMsg91) {
      if (!_msg91Ready) return;
    } else {
      await _ensureFirebaseReady();
      if (!mounted) return;
    }

    setState(() => _verifying = true);

    try {
      if (otpConfig.isMsg91) {
        final mobile = _msg91MobileForVerify();
        if (mobile.length < 11) {
          throw StateError('Enter your phone number again.');
        }
        debugPrint('OTP verify via MSG91 API → mobile=$mobile');
        await _optica2.verifyOtp(
          mobile,
          code,
          requestId: _msg91RequestId,
        );
        if (mounted) {
          await _routeAfterSignIn(
            _pendingPhoneE164 ?? toDisplayE164(mobile),
          );
        }
        return;
      }

      if (!otpConfig.isFirebase) {
        throw StateError('Unknown OTP provider: ${otpConfig.provider}');
      }

      debugPrint('OTP verify via Firebase Phone Auth');
      if (kIsWeb) {
        final conf = _webConfirmation;
        if (conf == null) {
          throw StateError('No web confirmation. Send OTP again.');
        }
        await conf.confirm(code);
      } else {
        final vid = _verificationId;
        if (vid == null) {
          throw StateError('Missing verification id. Send OTP again.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: vid,
          smsCode: code,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (mounted) await _routeAfterSignIn(_phoneE164ForSession());
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message ?? 'Invalid code');
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppToast.danger(context, '$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _backFromOtp() {
    _cancelSendOtpWatchdog();
    setState(() {
      _otpSent = false;
      _registrationFlow = false;
      _verificationId = null;
      _webConfirmation = null;
      _pendingPhoneE164 = null;
      _msg91Mobile = null;
      _msg91RequestId = null;
      _pinController.clear();
      _sending = false;
    });
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 0);
  }

  String _phoneE164ForSession() {
    final pending = _pendingPhoneE164;
    if (pending != null && pending.isNotEmpty) return pending;

    if (_useFirebase) {
      final firebasePhone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (firebasePhone != null && firebasePhone.isNotEmpty) {
        return firebasePhone;
      }
    }

    final phone = _phone;
    if (phone != null) return _e164(phone);
    return '';
  }

  String? get _verifyPhoneDisplay {
    final e164 = _pendingPhoneE164 ?? _phoneE164ForSession();
    if (e164.isEmpty) return null;
    return toDisplayE164(e164);
  }

  Future<void> _routeAfterSignIn(String phoneE164) async {
    if (phoneE164.isEmpty) {
      AppToast.danger(context, 'Could not read phone number.');
      return;
    }

    if (_registrationFlow) {
      await SellerAuthNavigation.routeToRegisterAfterOtp(
        context,
        phoneE164,
      );
      return;
    }

    await SellerAuthNavigation.routeAfterFirebaseAuth(
      context,
      _optica2,
      phoneE164,
    );
  }

  PinTheme _pinTheme(Color border) {
    return PinTheme(
      width: 46,
      height: 52,
      textStyle: GoogleFonts.exo2(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.deepGreen,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    final focused = AppColors.brandPurple;

    if (_bootstrapError != null && _hasSetupBlockingError) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            AppSystemUi.topInset(context, 24),
            24,
            AppSystemUi.bottomInset(context, 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  'Setup needed',
                  style: GoogleFonts.exo2(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _bootstrapError!,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.deepGreen.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _bootstrap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      );
    }

    final top = AppSystemUi.topInset(context);
    final bottom = AppSystemUi.bottomInset(context, 32);

    return Scaffold(
      backgroundColor: AppColors.cream,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, top + 8, 24, bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_otpSent) ...[
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: AppColors.deepGreen,
                        onPressed: _backFromOtp,
                      ),
                      Text(
                        'Verify code',
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Sign in',
                  style: GoogleFonts.exo2(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                  Text(
                    'We’ll text a one-time code to your phone.',
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: AppColors.deepGreen.withValues(alpha: 0.72),
                    ),
                  ),
                  if (_bootstrapError != null && !_isRateLimitedBootstrapError) ...[
                    const SizedBox(height: 16),
                    _BootstrapRetryCard(
                      message: _bootstrapError!,
                      onRetry: _bootstrap,
                    ),
                  ],
                  const SizedBox(height: 36),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: _otpSent
                      ? Column(
                          key: const ValueKey('otp'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Enter the $_otpLength-digit code',
                              style: GoogleFonts.exo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen,
                              ),
                            ),
                            if (_verifyPhoneDisplay != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Sent to ${_verifyPhoneDisplay!}',
                                style: GoogleFonts.exo2(
                                  fontSize: 13,
                                  color: AppColors.deepGreen.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Center(
                              child: Pinput(
                                length: _otpLength,
                                controller: _pinController,
                                focusNode: _pinFocus,
                                autofocus: true,
                                defaultPinTheme: _pinTheme(border),
                                focusedPinTheme: _pinTheme(focused),
                                submittedPinTheme: _pinTheme(focused),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onCompleted: _verifyOtp,
                              ),
                            ),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: _verifying
                                  ? null
                                  : () => _verifyOtp(_pinController.text),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _verifying
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Verify & continue',
                                      style: GoogleFonts.exo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: (_sending || _resendSeconds > 0)
                                  ? null
                                  : () => _sendOtp(resend: true),
                              child: Text(
                                _resendSeconds > 0
                                    ? 'Resend code in ${_resendSeconds}s'
                                    : 'Resend code',
                                style: GoogleFonts.exo2(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('phone'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Phone number',
                              style: GoogleFonts.exo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LocalePhoneField(
                              controller: _phoneController,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              onSaved: (PhoneNumber? phone) => _phone = phone,
                              decoration: InputDecoration(
                                hintText: 'Mobile number',
                                hintStyle: GoogleFonts.exo2(
                                  color: AppColors.deepGreen.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: focused,
                                    width: 1.6,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 12,
                                ),
                              ),
                              dropdownTextStyle: GoogleFonts.exo2(
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepGreen,
                              ),
                              style: GoogleFonts.exo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepGreen,
                              ),
                              flagsButtonPadding: const EdgeInsets.only(left: 8),
                              onChanged: (PhoneNumber phone) => _phone = phone,
                            ),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: _sending ? null : () => _sendOtp(),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _authReady ? 'Send OTP' : 'Retry & send OTP',
                                      style: GoogleFonts.exo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            if (_restoringSession) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Checking your saved session…',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.exo2(
                                  fontSize: 12,
                                  color: AppColors.deepGreen.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
