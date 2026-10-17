import 'seller_payout_method.dart';
import '../utils/order_number.dart';

class SellerWalletSnapshot {
  const SellerWalletSnapshot({
    required this.balance,
    required this.totalCredited,
    required this.totalWithdrawn,
    required this.pendingWithdrawal,
    required this.payoutMethods,
    required this.credits,
    required this.withdrawals,
  });

  final double balance;
  final double totalCredited;
  final double totalWithdrawn;
  final double pendingWithdrawal;
  final List<SellerPayoutMethod> payoutMethods;
  final List<SellerWalletCreditEntry> credits;
  final List<SellerWalletWithdrawal> withdrawals;

  bool get hasPayoutMethods => payoutMethods.isNotEmpty;

  factory SellerWalletSnapshot.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'];
    final methods = wallet is Map ? wallet['payout_methods'] : null;
    final credits = json['credits'];
    final withdrawals = json['withdrawals'];

    return SellerWalletSnapshot(
      balance: _double(wallet is Map ? wallet['balance'] : 0),
      totalCredited: _double(wallet is Map ? wallet['total_credited'] : 0),
      totalWithdrawn: _double(wallet is Map ? wallet['total_withdrawn'] : 0),
      pendingWithdrawal: _double(wallet is Map ? wallet['pending_withdrawal'] : 0),
      payoutMethods: methods is List
          ? methods
              .whereType<Map<String, dynamic>>()
              .map(SellerPayoutMethod.fromJson)
              .toList()
          : const [],
      credits: credits is List
          ? credits
              .whereType<Map<String, dynamic>>()
              .map(SellerWalletCreditEntry.fromJson)
              .toList()
          : const [],
      withdrawals: withdrawals is List
          ? withdrawals
              .whereType<Map<String, dynamic>>()
              .map(SellerWalletWithdrawal.fromJson)
              .toList()
          : const [],
    );
  }

  bool get canWithdraw =>
      hasPayoutMethods && balance >= 1 && pendingWithdrawal <= 0;
}

class SellerWalletCreditEntry {
  const SellerWalletCreditEntry({
    required this.id,
    required this.amount,
    required this.orderNumber,
    required this.label,
    required this.createdAtHuman,
  });

  final int id;
  final double amount;
  final String orderNumber;
  final String label;
  final String createdAtHuman;

  factory SellerWalletCreditEntry.fromJson(Map<String, dynamic> json) {
    return SellerWalletCreditEntry(
      id: json['id'] as int? ?? 0,
      amount: _double(json['amount']),
      orderNumber: normalizeOrderNumber(_str(json['order_number'])),
      label: _str(json['label']).isEmpty ? 'Order delivered' : _str(json['label']),
      createdAtHuman: _str(json['created_at_human']),
    );
  }
}

class SellerWalletWithdrawal {
  const SellerWalletWithdrawal({
    required this.id,
    required this.amount,
    required this.status,
    required this.statusLabel,
    required this.payoutType,
    required this.destinationLabel,
    required this.bankName,
    required this.bankAccountTitle,
    required this.bankAccountNumber,
    required this.bankIban,
    required this.upiId,
    required this.requestedAtHuman,
    this.processedAtHuman,
    this.adminNote,
  });

  final int id;
  final double amount;
  final String status;
  final String statusLabel;
  final String payoutType;
  final String destinationLabel;
  final String bankName;
  final String bankAccountTitle;
  final String bankAccountNumber;
  final String bankIban;
  final String upiId;
  final String requestedAtHuman;
  final String? processedAtHuman;
  final String? adminNote;

  bool get isUpi => payoutType == 'upi';

  factory SellerWalletWithdrawal.fromJson(Map<String, dynamic> json) {
    return SellerWalletWithdrawal(
      id: json['id'] as int? ?? 0,
      amount: _double(json['amount']),
      status: _str(json['status']),
      statusLabel: _str(json['status_label']),
      payoutType: _str(json['payout_type']).isEmpty ? 'bank' : _str(json['payout_type']),
      destinationLabel: _str(json['destination_label']).isEmpty
          ? _str(json['bank_name'])
          : _str(json['destination_label']),
      bankName: _str(json['bank_name']),
      bankAccountTitle: _str(json['bank_account_title']),
      bankAccountNumber: _str(json['bank_account_number']),
      bankIban: _str(json['bank_ifsc']).isNotEmpty
          ? _str(json['bank_ifsc'])
          : _str(json['bank_iban']),
      upiId: _str(json['upi_id']),
      requestedAtHuman: _str(json['requested_at_human']),
      processedAtHuman: json['processed_at_human'] as String?,
      adminNote: json['admin_note'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  String get reference => 'WD-${id.toString().padLeft(5, '0')}';

  List<SellerWithdrawalTimelineStep> get timelineSteps {
    final destination = isUpi ? upiId : bankName;

    if (isRejected) {
      return [
        SellerWithdrawalTimelineStep(
          key: 'requested',
          title: 'Request submitted',
          subtitle: 'Withdrawal amount reserved from wallet',
          timestamp: requestedAtHuman,
          state: SellerWithdrawalStepState.done,
        ),
        SellerWithdrawalTimelineStep(
          key: 'review',
          title: 'Admin review',
          subtitle: 'Payout details verified',
          timestamp: processedAtHuman ?? requestedAtHuman,
          state: SellerWithdrawalStepState.done,
        ),
        SellerWithdrawalTimelineStep(
          key: 'rejected',
          title: 'Request rejected',
          subtitle: adminNote?.trim().isNotEmpty == true
              ? adminNote!.trim()
              : 'Amount returned to your wallet balance',
          timestamp: processedAtHuman,
          state: SellerWithdrawalStepState.failed,
        ),
      ];
    }

    if (isCompleted) {
      return [
        SellerWithdrawalTimelineStep(
          key: 'requested',
          title: 'Request submitted',
          subtitle: 'Withdrawal amount reserved from wallet',
          timestamp: requestedAtHuman,
          state: SellerWithdrawalStepState.done,
        ),
        SellerWithdrawalTimelineStep(
          key: 'review',
          title: 'Admin approved',
          subtitle: isUpi ? 'Transfer initiated to UPI' : 'Transfer initiated to your bank',
          timestamp: processedAtHuman ?? requestedAtHuman,
          state: SellerWithdrawalStepState.done,
        ),
        SellerWithdrawalTimelineStep(
          key: 'completed',
          title: isUpi ? 'Transferred to UPI' : 'Transferred to bank',
          subtitle: isUpi ? 'Sent to $destination' : 'Payout sent to $bankName',
          timestamp: processedAtHuman,
          state: SellerWithdrawalStepState.done,
        ),
      ];
    }

    return [
      SellerWithdrawalTimelineStep(
        key: 'requested',
        title: 'Request submitted',
        subtitle: 'Withdrawal amount reserved from wallet',
        timestamp: requestedAtHuman,
        state: SellerWithdrawalStepState.done,
      ),
      SellerWithdrawalTimelineStep(
        key: 'review',
        title: 'Admin review',
        subtitle: 'We are verifying your payout details',
        timestamp: null,
        state: SellerWithdrawalStepState.active,
      ),
      SellerWithdrawalTimelineStep(
        key: 'transfer',
        title: isUpi ? 'UPI transfer' : 'Bank transfer',
        subtitle: isUpi ? 'Funds will be sent to $destination' : 'Funds will be sent to $bankName',
        timestamp: null,
        state: SellerWithdrawalStepState.upcoming,
      ),
    ];
  }
}

enum SellerWithdrawalStepState { done, active, upcoming, failed }

class SellerWithdrawalTimelineStep {
  const SellerWithdrawalTimelineStep({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.state,
    this.timestamp,
  });

  final String key;
  final String title;
  final String subtitle;
  final SellerWithdrawalStepState state;
  final String? timestamp;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _str(dynamic value) => value == null ? '' : '$value';

String formatWalletAmount(num amount) {
  final rounded = amount.round();
  return '₹$rounded';
}
