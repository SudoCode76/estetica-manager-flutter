import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SucursalProvider extends ChangeNotifier {
  int? _selectedSucursalId;
  String? _selectedSucursalName;
  bool _wasSetManually =
      false; // Flag para evitar que _loadFromPrefs sobrescriba

  int? get selectedSucursalId => _selectedSucursalId;
  String? get selectedSucursalName => _selectedSucursalName;

  SucursalProvider() {
    debugPrint('SucursalProvider: Constructor called');
    _loadFromPrefs();
  }

  void setSucursal(int id, String name) {
    debugPrint('SucursalProvider: setSucursal called with id=$id, name=$name');
    _selectedSucursalId = id;
    _selectedSucursalName = name;
    _wasSetManually = true; // Marcar que fue establecido manualmente
    _saveToPrefs();
    notifyListeners();
  }

  void clearSucursal() {
    debugPrint('SucursalProvider: clearSucursal called');
    _selectedSucursalId = null;
    _selectedSucursalName = null;
    _wasSetManually = false; // Reset flag al limpiar
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedSucursalId != null) {
      await prefs.setInt('selectedSucursalId', _selectedSucursalId!);
      await prefs.setString(
        'selectedSucursalName',
        _selectedSucursalName ?? '',
      );
      debugPrint(
        'SucursalProvider: Saved to prefs - id=$_selectedSucursalId, name=$_selectedSucursalName',
      );
    } else {
      await prefs.remove('selectedSucursalId');
      await prefs.remove('selectedSucursalName');
      debugPrint('SucursalProvider: Removed from prefs');
    }
  }

  Future<void> _loadFromPrefs() async {
    debugPrint('SucursalProvider: _loadFromPrefs started');
    // No sobrescribir si ya fue establecido manualmente
    if (_wasSetManually) {
      debugPrint(
        'SucursalProvider: Skipping _loadFromPrefs - value was set manually',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('selectedSucursalId');
    final name = prefs.getString('selectedSucursalName');
    debugPrint('SucursalProvider: Loaded from prefs - id=$id, name=$name');
    // Solo establecer si no fue establecido manualmente mientras tanto
    if (id != null && !_wasSetManually) {
      _selectedSucursalId = id;
      _selectedSucursalName = name;
      notifyListeners();
      debugPrint(
        'SucursalProvider: Set from prefs - id=$_selectedSucursalId, name=$_selectedSucursalName',
      );
    } else {
      debugPrint(
        'SucursalProvider: No saved sucursal in prefs or was set manually',
      );
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
    return context
        .dependOnInheritedWidgetOfExactType<SucursalInherited>()
        ?.provider;
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
    return context
        .dependOnInheritedWidgetOfExactType<ScaffoldKeyInherited>()
        ?.scaffoldKey;
  }

  @override
  bool updateShouldNotify(ScaffoldKeyInherited oldWidget) {
    return oldWidget.scaffoldKey != scaffoldKey;
  }
}
