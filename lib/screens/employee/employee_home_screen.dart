// Extracted helper method to show the no-sucursal SnackBar
void showNoSucursalSnackBar(BuildContext context) {
  final snackBar = SnackBar(
    content: Text(
      'No hay sucursal asignada.',
      style: TextStyle(color: Colors.red),
    ),
    duration: Duration(seconds: 3),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

// Existing method that triggers the SnackBar
void someMethod() {
  // Assuming this method gets called when no sucursal is assigned
  showNoSucursalSnackBar(context);
  // Other existing behavior remains unchanged...
}