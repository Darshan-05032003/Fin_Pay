class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String icon;
  final String? recipient;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.icon,
    this.recipient,
  });
}

enum TransactionType {
  payment,
  sendMoney,
  receiveMoney,
  topUp,
}

