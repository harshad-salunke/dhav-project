class PaymentRecord {
  final String paymentId;
  final double amount;
  final String paymentMode;
  final int paymentDate;
  final String? notes;

  const PaymentRecord({
    required this.paymentId,
    required this.amount,
    required this.paymentMode,
    required this.paymentDate,
    this.notes,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
        paymentId: j['payment_id'] as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        paymentMode: (j['payment_mode'] ?? '') as String,
        paymentDate: (j['payment_date'] ?? 0) as int,
        notes: j['notes'] as String?,
      );
}

class WeeklySettlement {
  final String settlementId;
  final String storeId;
  final String weekStart;
  final String weekEnd;
  final int totalOrdersDelivered;
  final double totalPlatformFeeOwed;
  final double totalFeePaid;
  final double balanceDue;
  final String status; // pending | partially_paid | settled
  final List<PaymentRecord> paymentRecords;
  final bool isOverdue;
  final int? createdAt;

  const WeeklySettlement({
    required this.settlementId,
    required this.storeId,
    required this.weekStart,
    required this.weekEnd,
    required this.totalOrdersDelivered,
    required this.totalPlatformFeeOwed,
    required this.totalFeePaid,
    required this.balanceDue,
    required this.status,
    required this.paymentRecords,
    required this.isOverdue,
    this.createdAt,
  });

  factory WeeklySettlement.fromJson(Map<String, dynamic> j) => WeeklySettlement(
        settlementId: j['settlement_id'] as String,
        storeId: (j['store_id'] ?? '') as String,
        weekStart: (j['week_start'] ?? '') as String,
        weekEnd: (j['week_end'] ?? '') as String,
        totalOrdersDelivered: (j['total_orders_delivered'] ?? 0) as int,
        totalPlatformFeeOwed: ((j['total_platform_fee_owed'] ?? 0) as num).toDouble(),
        totalFeePaid: ((j['total_fee_paid'] ?? 0) as num).toDouble(),
        balanceDue: ((j['balance_due'] ?? 0) as num).toDouble(),
        status: (j['status'] ?? 'pending') as String,
        paymentRecords: ((j['payment_records'] as List?) ?? const [])
            .map((e) => PaymentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isOverdue: (j['is_overdue'] ?? false) as bool,
        createdAt: j['created_at'] as int?,
      );
}
