import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SucursalProvider extends ChangeNotifier {
  int? _selectedSucursalId;
  String? _selectedSucursalName;

  int? get selectedSucursalId => _selectedSucursalId;
  String? get selectedSucursalName => _selectedSucursalName;

  SucursalProvider() {
    print('SucursalProvider: Constructor called');
    _loadFromPrefs();
  }

  void setSucursal(int id, String name) {
    print('SucursalProvider: setSucursal called with id=$id, name=$name');
    _selectedSucursalId = id;
    _selectedSucursalName = name;
    _saveToPrefs();
    notifyListeners();
  }

  void clearSucursal() {
    print('SucursalProvider: clearSucursal called');
    _selectedSucursalId = null;
    _selectedSucursalName = null;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedSucursalId != null) {
      await prefs.setInt('selectedSucursalId', _selectedSucursalId!);
      await prefs.setString('selectedSucursalName', _selectedSucursalName ?? '');
      print('SucursalProvider: Saved to prefs - id=$_selectedSucursalId, name=$_selectedSucursalName');
    } else {
      await prefs.remove('selectedSucursalId');
      await prefs.remove('selectedSucursalName');
      print('SucursalProvider: Removed from prefs');
    }
  }

  Future<void> _loadFromPrefs() async {
    print('SucursalProvider: _loadFromPrefs started');
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('selectedSucursalId');
    final name = prefs.getString('selectedSucursalName');
    print('SucursalProvider: Loaded from prefs - id=$id, name=$name');
    if (id != null) {
      _selectedSucursalId = id;
      _selectedSucursalName = name;
      notifyListeners();
      print('SucursalProvider: Set from prefs - id=$_selectedSucursalId, name=$_selectedSucursalName');
    } else {
      print('SucursalProvider: No saved sucursal in prefs');
    }
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
