import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/navigation/nav_items.dart';
import 'package:headmouse_pro/screens/admin_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/caregiver_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/diagnosis_edit_screen.dart';
import 'package:headmouse_pro/screens/functional_state_form_screen.dart';
import 'package:headmouse_pro/screens/patient_data_form_screen.dart';
import 'package:headmouse_pro/screens/patient_history_screen.dart';
import 'package:headmouse_pro/screens/patient_record_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/care_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/utils/date_format.dart';
import 'package:headmouse_pro/utils/validators.dart';
import 'package:headmouse_pro/widgets/gradient_button.dart';

import 'fake_admin_service.dart';
import 'fake_care_service.dart';
import 'fake_records_service.dart';

AppUser _caregiver(String uid) => AppUser(
  uid: uid,
  email: '$uid@correo.com',
  role: UserRole.cuidador,
  nombres: 'María',
  apellidos: 'González',
);

void main() {
  group('fechas', () {
    test('la fecha sin hora va y vuelve como texto', () {
      expect(toIsoDate(DateTime(2018, 5, 20)), '2018-05-20');
      expect(parseIsoDate('2018-05-20'), DateTime(2018, 5, 20));
      expect(parseIsoDate('2023-02-31'), isNull);
      expect(parseIsoDate('20/05/2018'), isNull);
      expect(parseIsoDate(null), isNull);
    });

    test('la edad cuenta los años cumplidos', () {
      final birth = DateTime(1998, 3, 14);
      expect(ageOn(birth, now: DateTime(2026, 3, 13)), 27);
      expect(ageOn(birth, now: DateTime(2026, 3, 14)), 28);
      expect(formatLongDate(birth), '14 mar 1998');
    });

    test('el teléfono es opcional pero tiene que ser válido', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('+595 981 234-567'), isNull);
      expect(Validators.optionalPhone('abc'), isNotNull);
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('no-es-correo'), isNotNull);
    });
  });

  group('modelos', () {
    test('la ficha del paciente se guarda y se lee igual', () {
      final record = FakeRecordsService().patients['p1']!;
      final map = {
        ...record.toPersonalMap(),
        'estadoFuncional': record.estadoFuncional!.toMap(),
      };
      expect(map['fechaNacimiento'], '1998-03-14');
      expect(map['sexo'], 'masculino');
      final read = PatientRecord.fromMap(map);
      expect(read.toPersonalMap(), record.toPersonalMap());
      expect(read.estadoFuncional!.toMap(), record.estadoFuncional!.toMap());
      expect(read.estadoFuncional!.movilidadCervical, Mobility.parcial);
    });

    test('sin evaluación no hay estado funcional', () {
      expect(PatientRecord.fromMap(null).estadoFuncional, isNull);
      expect(PatientRecord.fromMap({'telefono': '1'}).estadoFuncional, isNull);
    });

    test('si falta el dato se asume que puede usar los dos clips', () {
      final state = FunctionalState.fromMap(const {});
      expect(state.puedeClipIzquierdo, isTrue);
      expect(state.puedeClipDerecho, isTrue);
      expect(state.movilidadCervical, isNull);
    });

    test('estado = false en Firestore es un diagnóstico anulado', () {
      final d = Diagnosis.fromMap('x', const {
        'idPaciente': 'p1',
        'tipoDiagnostico': 'principal',
        'diagnostico': 'Parálisis cerebral',
        'fechaDiagnostico': '2018-05-20',
        'esActual': true,
        'estado': false,
      });
      expect(d.anulado, isTrue);
      expect(d.isCurrent, isFalse);
      expect(d.fechaDiagnostico, DateTime(2018, 5, 20));
      expect(d.tipo, DiagnosisType.principal);
    });

    test('las listas muestran primero lo vigente y al final lo anulado', () {
      final list = [...FakeRecordsService().diagnoses.reversed]
        ..sort(Diagnosis.compare);
      expect([for (final d in list) d.id], ['d1', 'd2', 'd3', 'd4']);
    });

    test('los cambios se detectan solo en lo editable', () {
      final d = FakeRecordsService().diagnoses.first;
      expect(d.sameContentAs(d.copyWith()), isTrue);
      expect(d.sameContentAs(d.copyWith(esActual: false)), isFalse);
      expect(
        d.sameContentAs(d.copyWith(fechaDiagnostico: () => null)),
        isFalse,
      );
    });

    test('junta los diagnósticos de varios pacientes sin repetir', () async {
      final fake = FakeRecordsService()
        ..diagnoses.add(
          const Diagnosis(
            id: 'd9',
            idPaciente: 'p2',
            tipo: DiagnosisType.principal,
            diagnostico: 'ELA',
          ),
        );
      final all = await fake.watchDiagnosesFor(['p1', 'p2', 'p1']).first;
      expect(all.length, 5);
      expect(await fake.watchDiagnosesFor(const []).first, isEmpty);
    });
  });

  group('pantallas', () {
    late FakeRecordsService fake;

    setUp(() {
      fake = FakeRecordsService();
      RecordsService.instance = fake;
      CareService.instance = FakeCareService();
      AdminService.instance = FakeAdminService();
    });
    tearDown(() => AuthService.instance.current = null);

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      // Primero termina el desplazamiento que hace el campo con foco.
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('el cuidador con permiso registra un diagnóstico', (
      tester,
    ) async {
      AuthService.instance.current = _caregiver('c1');
      await pump(tester, const CaregiverDiagnosesScreen());

      expect(find.text('Parálisis cerebral espástica'), findsOneWidget);
      // Los anulados no se muestran al cuidador.
      expect(find.text('Cargado por error'), findsNothing);

      await tapText(tester, '+ Nuevo diagnóstico');
      expect(find.text('Nuevo diagnóstico'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Diagnóstico (ej. Parálisis cerebral)',
        ),
        'Epilepsia refractaria',
      );
      await tapText(tester, 'Guardar diagnóstico');

      expect(fake.calls, [
        'add p1 principal Epilepsia refractaria actual=true',
      ]);
      expect(find.text('Diagnóstico registrado.'), findsOneWidget);
    });

    testWidgets('sin permiso de edición no se puede registrar', (tester) async {
      AuthService.instance.current = _caregiver('c2');
      await pump(tester, const CaregiverDiagnosesScreen());

      final button = tester.widget<GradientButton>(find.byType(GradientButton));
      expect(button.onPressed, isNull);
      expect(find.textContaining('permiso "editar datos"'), findsOneWidget);
      // Igual puede consultar.
      expect(find.text('Contractura cervical crónica'), findsOneWidget);
    });

    testWidgets('no se guarda un diagnóstico sin nombre', (tester) async {
      await pump(
        tester,
        const DiagnosisEditScreen(
          diagnosis: Diagnosis(
            idPaciente: 'p1',
            tipo: DiagnosisType.principal,
            diagnostico: '',
          ),
          patientName: 'Juan Paredes',
        ),
      );
      await tapText(tester, 'Guardar diagnóstico');
      expect(find.text('Escribí el diagnóstico.'), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('un principal vigente avisa que reemplaza al anterior', (
      tester,
    ) async {
      await pump(
        tester,
        const DiagnosisEditScreen(
          diagnosis: Diagnosis(
            idPaciente: 'p1',
            tipo: DiagnosisType.secundario,
            diagnostico: '',
          ),
          patientName: 'Juan Paredes',
        ),
      );
      expect(find.textContaining('pasa a "No vigente"'), findsNothing);
      await tapText(tester, 'Principal');
      expect(find.textContaining('pasa a "No vigente"'), findsOneWidget);
    });

    testWidgets('anular pide confirmación y no borra', (tester) async {
      await pump(
        tester,
        DiagnosisEditScreen(
          diagnosis: fake.diagnoses.first,
          patientName: 'Juan Paredes',
        ),
      );
      await tapText(tester, 'Anular diagnóstico');
      expect(find.text('¿Anular el diagnóstico?'), findsOneWidget);
      await tapText(tester, 'Sí, anular');
      expect(fake.calls, ['annul d1']);
    });

    testWidgets('en solo lectura no se puede guardar ni anular', (
      tester,
    ) async {
      await pump(
        tester,
        DiagnosisEditScreen(
          diagnosis: fake.diagnoses.first,
          patientName: 'Juan Paredes',
          readOnly: true,
        ),
      );
      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.text('Anular diagnóstico'), findsNothing);
      expect(find.text('Parálisis cerebral espástica'), findsOneWidget);
      expect(
        find.textContaining('Registrado por María González'),
        findsOneWidget,
      );
    });

    testWidgets('el paciente no ve los diagnósticos anulados', (tester) async {
      await pump(
        tester,
        PatientHistoryScreen(
          navItems: patientNavItems(),
          currentIndex: patientTabIndex(PatientTab.historial),
        ),
      );
      expect(find.text('Parálisis cerebral espástica'), findsOneWidget);
      expect(find.text('Cargado por error'), findsNothing);

      // El primero es el filtro; el otro, la etiqueta de la tarjeta.
      final chip = find.text('Antecedente').first;
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Cirugía de columna cervical'), findsOneWidget);
      expect(find.text('Parálisis cerebral espástica'), findsNothing);
    });

    testWidgets('el administrador ve los anulados con su filtro', (
      tester,
    ) async {
      await pump(tester, const AdminDiagnosesScreen());
      await tapText(tester, 'Anulados');
      expect(find.text('Cargado por error'), findsOneWidget);
      expect(find.text('Juan Paredes'), findsOneWidget);
      expect(find.text('Contractura cervical crónica'), findsNothing);
    });

    testWidgets('el paciente solo edita su contacto', (tester) async {
      await pump(
        tester,
        PatientDataFormScreen(
          patientUid: 'p1',
          patientName: 'Juan Paredes',
          record: fake.patients['p1']!,
          selfEdit: true,
        ),
      );
      expect(find.text('Número o referencia de registro'), findsNothing);
      expect(find.text('Fecha de nacimiento'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, '0981 234 567'),
        'abc',
      );
      await tapText(tester, 'Guardar');
      expect(find.text('Ingresá un teléfono válido.'), findsOneWidget);
      expect(fake.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'abc'),
        '0991 000 111',
      );
      await tapText(tester, 'Guardar');
      expect(fake.calls, ['savePatient p1 selfEdit=true tel=0991 000 111']);
    });

    testWidgets('la evaluación funcional avisa lo que falta', (tester) async {
      await pump(
        tester,
        const FunctionalStateFormScreen(
          patientUid: 'p9',
          patientName: 'Paciente Nuevo',
        ),
      );
      await tapText(tester, 'Guardar evaluación');
      expect(
        find.textContaining('Falta indicar: movilidad cervical'),
        findsOneWidget,
      );
      // Espera a que se vaya el aviso para que no tape los botones.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);

      Future<void> tapNth(String text, int index) async {
        final target = find.text(text).at(index);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tapNth('No conservada', 0); // cervical
      await tapNth('Conservada', 1); // miofacial
      await tapNth('Inestable', 0);
      await tapNth('Dependiente', 0);
      await tapText(tester, 'Guardar evaluación');
      expect(fake.calls, ['saveFunctionalState p9 cervical=no_conservada']);
    });

    testWidgets('la ficha sin permiso de edición solo muestra datos', (
      tester,
    ) async {
      await pump(
        tester,
        const PatientRecordScreen(
          patientUid: 'p1',
          patientName: 'Juan Paredes',
          canEdit: false,
        ),
      );
      expect(find.text('Editar datos personales'), findsNothing);
      expect(find.text('+ Registrar diagnóstico'), findsNothing);
      await tester.ensureVisible(find.text('SEN-2024-00871'));
      expect(find.text('4567890'), findsOneWidget);
    });
  });
}
