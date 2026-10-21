import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/l10n/app_strings.dart';
import 'package:headmouse_pro/main.dart';
import 'package:headmouse_pro/theme/app_colors.dart';
import 'package:headmouse_pro/theme/app_theme.dart';
import 'package:headmouse_pro/widgets/accessible_tap.dart';
import 'package:headmouse_pro/widgets/filter_chips.dart';
import 'package:headmouse_pro/widgets/state_views.dart';
import 'package:headmouse_pro/widgets/unsaved_changes_guard.dart';

void main() {
  tearDown(() => AppTheme.instance.setMode(ThemeMode.dark));

  group('Login', () {
    testWidgets('muestra el formulario de acceso', (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.login), findsOneWidget);
    });

    testWidgets('valida el correo en línea, sin SnackBar', (tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.enterText(find.byType(TextFormField).first, 'ana@correo');
      await tester.pump();

      expect(find.text(AppStrings.invalidEmail), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).first,
        'ana@correo.com',
      );
      await tester.pump();
      expect(find.text(AppStrings.invalidEmail), findsNothing);
    });
  });

  group('Estados de carga y error', () {
    testWidgets('AsyncBody muestra carga y luego el contenido', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBody(
            loader: () => Future<void>.delayed(const Duration(seconds: 1)),
            builder: (_) => const Text('contenido'),
          ),
        ),
      );

      expect(find.text(AppStrings.loading), findsOneWidget);
      expect(find.text('contenido'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('AsyncBody muestra el error y reintenta', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBody(
            loader: () async {
              calls++;
              if (calls == 1) throw Exception('sin red');
            },
            builder: (_) => const Text('contenido'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.errorTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.retry));
      await tester.pump();
      await tester.pump();

      expect(calls, 2);
      expect(find.text('contenido'), findsOneWidget);
    });
  });

  group('Accesibilidad', () {
    testWidgets('los chips de filtro tienen área táctil de 48 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterChips(
              options: const ['Todos', 'Activos'],
              selected: 'Todos',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AccessibleTap).first);
      expect(size.height, greaterThanOrEqualTo(kMinTapSize));
    });

    testWidgets('el chip expone rol de botón y estado seleccionado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterChips(
              options: const ['Todos', 'Activos'],
              selected: 'Activos',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Activos')),
        matchesSemantics(
          label: 'Filtro: Activos',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('Tema claro/oscuro', () {
    testWidgets('cambia la paleta al alternar el modo', (tester) async {
      AppTheme.instance.setMode(ThemeMode.dark);
      final darkBackground = AppColors.bgDeep;
      expect(AppColors.isDark, isTrue);

      AppTheme.instance.setMode(ThemeMode.light);
      expect(AppColors.isDark, isFalse);
      expect(AppColors.bgDeep, isNot(darkBackground));
    });

    testWidgets('el texto claro tiene contraste suficiente (>= 4.5)', (
      tester,
    ) async {
      AppTheme.instance.setMode(ThemeMode.light);
      for (final foreground in [AppColors.text, AppColors.textMute]) {
        expect(
          _contrast(foreground, AppColors.bgDeep),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        _contrast(AppColors.cyan, AppColors.bgPanel),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('UnsavedChangesGuard', () {
    Future<void> openGuardedPage(
      WidgetTester tester, {
      required bool Function() hasChanges,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UnsavedChangesGuard(
                      hasChanges: hasChanges,
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Editar')),
                        body: const SizedBox(),
                      ),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('sale sin preguntar si no hay cambios', (tester) async {
      await openGuardedPage(tester, hasChanges: () => false);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.unsavedTitle), findsNothing);
      expect(find.text('Editar'), findsNothing);
    });

    testWidgets('pide confirmación y permite seguir editando', (tester) async {
      await openGuardedPage(tester, hasChanges: () => true);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.unsavedTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.keepEditing));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.unsavedTitle), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('permite descartar los cambios y salir', (tester) async {
      await openGuardedPage(tester, hasChanges: () => true);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.discardChanges));
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
