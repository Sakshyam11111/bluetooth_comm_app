// models/bluetooth_device.dart
class BluetoothDeviceModel {
  final String id;
  final String name;
  final bool isConnected;
  final String? address;
  final int? rssi;

  BluetoothDeviceModel({
    required this.id,
    required this.name,
    required this.isConnected,
    this.address,
    this.rssi,
  });

  BluetoothDeviceModel copyWith({
    String? id,
    String? name,
    bool? isConnected,
    String? address,
    int? rssi,
  }) {
    return BluetoothDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
    );
  }
}