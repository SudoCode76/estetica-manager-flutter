# App Estética

Aplicación Flutter para la gestión de una estética: tickets, sesiones, clientes, pagos y reportes. Este README describe la estructura del proyecto, cómo ponerlo en marcha, las decisiones de arquitectura (refactor a Repositories), y notas útiles para desarrollo y depuración.

> Lenguaje: Spanish

---

## Resumen

App Estética es una aplicación móvil multi-rol (administrador / empleado) que usa Supabase como backend. Contiene pantallas para gestionar:
- Tickets y sesiones
- Clientes
- Pagos (incluye detalle e historial)
- Reportes financieros, de clientes y de servicios
- Empleados / Usuarios

Se migró recientemente la lógica de llamadas a la API desde un `ApiService` monolítico hacia Repositories específicos por entidad (Auth, Ticket, Cliente, Catalog, Reports). Los Providers consumen ahora esos Repositories para mantener el código modular y testable.

---

## Estado del proyecto (lo que hay que saber)
- Versión app: `1.0.0+1` (ver `pubspec.yaml`).
- SDK Dart: `^3.9.2`.
- Dependencias principales: `supabase_flutter`, `provider`, `fl_chart`, `url_launcher`, `shared_preferences`, `intl`, `pdf`, `printing`, `share_plus`, `path_provider`.
- El proyecto ya contiene refactorizaciones: `lib/services/api_service.dart` quedó reducido y la lógica pesada fue movida a `lib/repositories/*`.

---

## Estructura principal (rutas y archivos importantes)

- `lib/main.dart` — Punto de entrada; inicializa Supabase y registra Providers y Repositories compartidos.
- `lib/config/` — Configuración (p. ej. `api_config.dart`, `supabase_config.dart`).
- `lib/repositories/` — Repositories por entidad (Auth, Ticket, Cliente, Catalog, Reports, ...).
  - `ticket_repository.dart` — Lógica de tickets, sesiones, abonos y eliminación atómica (RPC `eliminar_ticket_atomico`).
  - `reports_repository.dart` — Lógica para invocar RPCs de reportes.
  - `cliente_repository.dart`, `catalog_repository.dart`, `auth_repository.dart`, etc.
- `lib/providers/` — Providers que consumen los Repositories y exponen estado a la UI.
  - `ticket_provider.dart`, `reports_provider.dart`, `sucursal_provider.dart`, etc.
- `lib/screens/` — Pantallas organizadas por roles y módulos.
  - `lib/screens/admin/` — Panel admin (tickets, sesiones, clientes, pagos, reports, empleados, etc.).
  - `lib/screens/employee/` — Versión para empleados (subset de pantallas).
  - `lib/screens/login/` — Login.
  - `lib/screens/about_screen.dart` — Nueva pantalla "Acerca de" (botón abrir web y WhatsApp con fallback y copia manual).
- `lib/services/` — Servicios de apoyo (auth service, share service, helpers). `api_service.dart` ahora debe contener solo helpers mínimos.
- `lib/widgets/` — Componentes reutilizables (dialogs, etc.).

---

## Dependencias (del `pubspec.yaml`)
Principales dependencias (versión usada en el repo):

- flutter
- flutter_localizations
- cupertino_icons ^1.0.8
- http ^1.6.0
- shared_preferences ^2.5.4
- intl ^0.20.2
- url_launcher ^6.3.2
- pdf ^3.11.3
- printing ^5.14.2
- share_plus ^12.0.1
- path_provider ^2.1.5
- provider ^6.1.5+1
- fl_chart ^1.1.1
- supabase_flutter ^2.12.0

Ejecuta `flutter pub get` para instalarlas.

---

## Cómo ejecutar la aplicación

1. Prerrequisitos:
   - Flutter SDK (compatible con Dart SDK indicado en `pubspec.yaml`).
   - Cuenta/instancia Supabase configurada y claves en `lib/config/supabase_config.dart`.

2. Instalar paquetes:

```bash
flutter pub get
```

3. Ejecutar en un emulador/dispositivo:

```bash
flutter run
```

4. Verificar análisis de código y lints:

```bash
flutter analyze
```

Recomiendo hacer un `flutter clean` y luego `flutter pub get` si migras entre ramas grandes.

---

## Arquitectura y convenios

- Repositories: cada entidad del dominio (tickets, clientes, auth, catalog, reports) tiene su `Repository` en `lib/repositories/`. Estos encapsulan las llamadas a Supabase y transformaciones de datos.
- Providers: usan Repositories inyectados (o instanciados) vía `Provider` en `main.dart` y exponen estado y acciones hacia la UI.
- Screens: UI debe consumir Providers (idealmente no llamar Repositories directamente salvo componentes puntuales). Varios screens ya fueron migrados.
- Uso de Supabase SDK: los Repositories usan `Supabase.instance.client` y las RPCs (`rpc()`) donde se requieren operaciones atómicas (p. ej. `eliminar_ticket_atomico`).

---

## Cambios y decisiones importantes (historial de refactor)

- Se movió la lógica de tickets/sesiones de `lib/services/api_service.dart` a `lib/repositories/ticket_repository.dart`.
- Implementación de eliminación atómica en DB: función SQL `eliminar_ticket_atomico(p_ticket_id BIGINT)` (borrado de pagos → sesiones → ticket) y `TicketRepository.eliminarTicket(...)` que la invoca vía RPC.
- `ReportsRepository` y `ReportsProvider` creados para consumir funciones RPC de reportes (`reporte_financiero`, `reporte_clientes`, `reporte_servicios`).
- Pantallas de reportes actualizadas (`lib/screens/admin/reports/*`) para recibir los JSON devueltos por las RPC y mostrarlos con `fl_chart`.
- Se añadió la pantalla `lib/screens/about_screen.dart` con botones para abrir el sitio web y WhatsApp; se implementaron múltiples fallbacks para Android y un diálogo para copiar el enlace si no se puede lanzar.
- Se corrigieron varios problemas UI (Drawer, selección automática de sucursal, selección de cliente al crear ticket en UI, filtros en `treatments_screen`).

---

## Notas de desarrollo — puntos clave y debugging

1. Tokens y funciones serverless
   - Algunas funciones que crean/eliminen usuarios (`crear-usuario`, `eliminar-usuario`) requieren que el `AuthRepository` envíe `token_admin` con el `accessToken` del admin actual. Revisa `lib/repositories/auth_repository.dart`.

2. RPCs y SQL
   - Si un RPC falla, revisa logs de Supabase. Para debug local en Supabase SQL editor prueba consultas directas que reproduzcan la agregación que esperas. Ejemplo (para `reporte_financiero`):

```sql
SELECT to_char(p.fecha_pago, 'DD') as label, SUM(p.monto) as value
FROM pago p
JOIN ticket t ON p.ticket_id = t.id
WHERE t.sucursal_id = <SUCURSAL_ID> AND p.fecha_pago BETWEEN '<START_ISO>'::timestamptz AND '<END_ISO>'::timestamptz
GROUP BY 1 ORDER BY MIN(p.fecha_pago);
```

3. Abrir URLs en Android
   - `url_launcher` puede comportarse distinto según la configuración del dispositivo. Implementamos varios fallbacks en `AboutScreen`:
     - intent `whatsapp://` (nativo), luego `https://api.whatsapp.com`, y por último mostrar diálogo con enlace para copiar.
   - Si `launchUrl` siempre retorna false, prueba manualmente abrir la URL en el navegador del dispositivo o comprobar si hay restricciones en el emulador.

4. Problemas conocidos
   - Si el Drawer no muestra un item esperado: hacer `full restart` (hot reload no siempre actualiza layout/Drawer). Se añadieron varios puntos para que "Acerca de" sea visible.
   - Errores de render (hit test / size missing) en reportes con `fl_chart`: suelen ocurrir cuando un widget gráfico recibe una lista vacía o está incrustado en un contenedor sin tamaño. Asegúrate que los widgets `BarChart`/`PieChart` estén dentro de `SizedBox` con altura definida o `Expanded` dentro de layouts flexibles.

5. Tests rápidos sugeridos
   - Ejecuta `flutter analyze`.
   - Abre Reports y cambia periodo (Hoy/Semana/Mes/Año) y revisa consola para ver los `debugPrint` del `ReportsProvider` con fechas (deben ser UTC).
   - Para la eliminación atómica: borrar un ticket y verificar que pagos y sesiones relacionados desaparecen en supabase.

---

## Contribuciones / Cómo ayudar

- Sigue el patrón Repository → Provider → Screen.
- Cuando muevas funciones desde `api_service.dart`, elimina el wrapper en ApiService y actualiza los imports en los Providers/Pantallas.
- Agrega tests unitarios para Repositories (simulando respuestas de Supabase si deseas) y tests de integración para flujos críticos (crear ticket → pagar → eliminar).

---

## Comandos útiles

- Instalar deps: `flutter pub get`
- Ejecutar app: `flutter run`
- Analizar: `flutter analyze`
- Formatear: `dart format .`

---

## Archivos clave (lista corta)

- `lib/main.dart`
- `lib/config/supabase_config.dart`, `lib/config/api_config.dart`
- `lib/repositories/` (ticket_repository.dart, reports_repository.dart, catalog_repository.dart, cliente_repository.dart, auth_repository.dart)
- `lib/providers/` (ticket_provider.dart, reports_provider.dart, sucursal_provider.dart)
- `lib/screens/admin/reports/` (financial_report.dart, clients_report.dart, services_report.dart, reports_screen.dart)
- `lib/screens/admin/tickets/` (tickets_screen.dart, new_ticket_screen.dart, ticket_detail_screen.dart)
- `lib/screens/about_screen.dart`

---

## Contacto
Si necesitas que documente más internamente (ej. crear README por módulo, añadir diagramas), dime qué módulo quieres primero (Tickets, Reports, Repositories) y genero documentación técnica adicional.

---

README generado automáticamente por análisis del workspace (fecha: 2026-02-12).

