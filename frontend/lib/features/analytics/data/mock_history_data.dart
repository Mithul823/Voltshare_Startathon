class MockEnergyTransaction {
  const MockEnergyTransaction({
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
  });

  final String title;
  final String date;
  final double amount;
  final bool isCredit;
}

const weeklyEnergyHistory = [22.0, 28.5, 27.2, 25.8, 37.6, 29.4, 36.8];

const mockEnergyTransactions = [
  MockEnergyTransaction(
    title: 'Sold 4.2 kWh to Anjali',
    date: 'Today, 6:20 PM',
    amount: 21.84,
    isCredit: true,
  ),
  MockEnergyTransaction(
    title: 'Purchased 2.0 kWh from Ravi',
    date: 'Today, 10:15 AM',
    amount: 10.40,
    isCredit: false,
  ),
  MockEnergyTransaction(
    title: 'Sold 3.5 kWh to Community Pool',
    date: 'Yesterday, 7:05 PM',
    amount: 18.20,
    isCredit: true,
  ),
  MockEnergyTransaction(
    title: 'Purchased 1.5 kWh reserve energy',
    date: 'Yesterday, 8:40 AM',
    amount: 7.80,
    isCredit: false,
  ),
  MockEnergyTransaction(
    title: 'Sold 5.0 kWh evening peak',
    date: 'Jul 16, 2026',
    amount: 29.00,
    isCredit: true,
  ),
];
