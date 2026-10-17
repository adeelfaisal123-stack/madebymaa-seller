/// Response from `POST /api/otp/send` when MSG91 is active.
class OtpSendResult {
  const OtpSendResult({
    required this.mobile,
    this.requestId,
    this.devOtp,
  });

  /// MSG91 mobile (country code + number, no +), e.g. `919876543210`.
  final String mobile;
  final String? requestId;

  /// Local backend only (`OTP_DEV_BYPASS=true`) — no SMS; use this code.
  final String? devOtp;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      mobile: _parseMobile(json['mobile']),
      requestId: (json['request_id'] as String?)?.trim(),
      devOtp: (json['dev_otp'] as String?)?.trim(),
    );
  }

  static String _parseMobile(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is String) return value.trim();
    return '';
  }
}
