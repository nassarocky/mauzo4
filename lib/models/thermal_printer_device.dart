/// Platform-agnostic thermal printer entry for UI and [ThermalPrinterService].
class ThermalPrinterDevice {
  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    this.isSystemDialog = false,
  });

  final String name;

  /// MAC / device id. Empty when [isSystemDialog] is true.
  final String address;

  /// Windows fallback: OS print dialog (USB / installed drivers).
  final bool isSystemDialog;

  /// Alias matching [BluetoothInfo.macAdress] spelling used by existing UI.
  String get macAdress => address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThermalPrinterDevice &&
          address == other.address &&
          isSystemDialog == other.isSystemDialog;

  @override
  int get hashCode => Object.hash(address, isSystemDialog);
}
