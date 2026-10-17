/// OTP provider from `GET /api/otp/config` (admin SMS Gateway setting).
class OtpConfig {
  const OtpConfig({
    required this.provider,
    required this.configured,
    this.otpLength = 6,
    this.devBypass = false,
  });

  final String provider;
  final bool configured;
  final int otpLength;

  /// Local Laravel: OTP in logs / toast, no SMS (`OTP_DEV_BYPASS=true`).
  final bool devBypass;

  bool get isFirebase => provider == 'firebase';

  bool get isMsg91 => provider == 'msg91';

  factory OtpConfig.fromJson(Map<String, dynamic> json) {
    final otp = json['otp'];
    if (otp is! Map) {
      return const OtpConfig(provider: 'firebase', configured: true);
    }
    final map = Map<String, dynamic>.from(otp);
    final raw = map['provider'];
    final normalized = raw is String
        ? raw.trim().toLowerCase()
        : 'firebase';
    final provider = normalized == 'msg91' ? 'msg91' : 'firebase';

    int otpLength = 6;
    final msg91 = map['msg91'];
    if (msg91 is Map) {
      final len = msg91['otp_length'];
      if (len is int && len >= 4 && len <= 9) {
        otpLength = len;
      } else if (len is String) {
        final parsed = int.tryParse(len);
        if (parsed != null && parsed >= 4 && parsed <= 9) {
          otpLength = parsed;
        }
      }
    }

    return OtpConfig(
      provider: provider,
      configured: map['configured'] == true,
      otpLength: otpLength,
      devBypass: map['dev_bypass'] == true,
    );
  }
}
