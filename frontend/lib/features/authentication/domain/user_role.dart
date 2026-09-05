enum UserRole {
  consumer('consumer'),
  producer('producer'),
  prosumer('prosumer'),
  technician('technician'),
  gridOperator('grid_operator'),
  admin('admin'),
  unsupported('unsupported');

  const UserRole(this.value);

  final String value;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.unsupported,
    );
  }
}
