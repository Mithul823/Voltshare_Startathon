class WalletSummary {
  const WalletSummary({
    required this.incomeTodayPaise,
    required this.incomeThisWeekPaise,
    required this.incomeThisMonthPaise,
    required this.spendingTodayPaise,
    required this.spendingThisWeekPaise,
    required this.spendingThisMonthPaise,
    required this.netBalanceChangePaise,
    required this.energyBoughtKwh,
    required this.energySoldKwh,
  });

  final int incomeTodayPaise;
  final int incomeThisWeekPaise;
  final int incomeThisMonthPaise;
  final int spendingTodayPaise;
  final int spendingThisWeekPaise;
  final int spendingThisMonthPaise;
  final int netBalanceChangePaise;
  final double energyBoughtKwh;
  final double energySoldKwh;
}
