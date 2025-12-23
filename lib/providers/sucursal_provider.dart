import 'package:flutter/material.dart';

class SucursalProvider extends ChangeNotifier {
  int? _selectedSucursalId;
  String? _selectedSucursalName;

  int? get selectedSucursalId => _selectedSucursalId;
  String? get selectedSucursalName => _selectedSucursalName;

  void setSucursal(int id, String name) {
    _selectedSucursalId = id;
    _selectedSucursalName = name;
    notifyListeners();
  }

  void clearSucursal() {
    _selectedSucursalId = null;
    _selectedSucursalName = null;
    notifyListeners();
  }
}

class SucursalInherited extends InheritedWidget {
  final SucursalProvider provider;

  const SucursalInherited({
    Key? key,
    required this.provider,
    required Widget child,
  }) : super(key: key, child: child);

  static SucursalProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SucursalInherited>()?.provider;
  }

  @override
  bool updateShouldNotify(SucursalInherited oldWidget) {
    return oldWidget.provider != provider;
  }
}

class ScaffoldKeyInherited extends InheritedWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ScaffoldKeyInherited({
    Key? key,
    required this.scaffoldKey,
    required Widget child,
  }) : super(key: key, child: child);

  static GlobalKey<ScaffoldState>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScaffoldKeyInherited>()?.scaffoldKey;
  }

  @override
  bool updateShouldNotify(ScaffoldKeyInherited oldWidget) {
    return oldWidget.scaffoldKey != scaffoldKey;
  }
}

