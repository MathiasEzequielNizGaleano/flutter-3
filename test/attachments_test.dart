import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/screens/diagnosis_edit_screen.dart';
import 'package:headmouse_pro/services/attachment_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/widgets/diagnosis_card.dart';

import 'fake_attachment_service.dart';
import 'fake_records_service.dart';

const _caregiver = AppUser(
  uid: 'c1',
  email: 'maria.gonzalez@correo.com',
  role: UserRole.cuidador,
  nombres: 'María',
  apellidos: 'González',
);

PickedFile _file(String name, int size) =>
    PickedFile(name: name, bytes: Uint8List(size));

void main() {
  group('datos', () {
    test('reconoce PDF, JPG y PNG sin importar mayúsculas', () {
      expect(mimeTypeFor('Informe.PDF'), 'application/pdf');
      expect(mimeTypeFor('foto.jpeg'), 'image/jpeg');
      expect(mimeTypeFor('foto.JPG'), 'image/jpeg');
      expect(mimeTypeFor('estudio.png'), 'image/png');
      expect(mimeTypeFor('nota.docx'), isNull);
      expect(mimeTypeFor('sin_extension'), isNull);
    });

    test('muestra el tamaño legible', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(845 * 1024), '845 KB');
      expect(formatBytes((2.3 * 1024 * 1024).round()), '2,3 MB');
    });

    test('parte el archivo y lo vuelve a unir igual', () {
      final bytes = Uint8List.fromList(
        List.generate(1500 * 1024, (i) => i % 251),
      );
      final parts = splitParts(bytes);
      expect(parts.length, 3);
      expect(parts.every((p) => p.length <= attachmentPartBytes), isTrue);
      expect(joinParts(parts), bytes);
      // El máximo (5 MB) entra en las 8 partes que permiten las reglas.
      expect(splitParts(Uint8List(maxAttachmentBytes)).length, lessThan(9));
    });

    test('rechaza tipos no admitidos, vacíos y de más de 5 MB', () {
      expect(_file('informe.pdf', 1000).problem, isNull);
      expect(
        _file('nota.docx', 1000).problem,
        'Solo se pueden adjuntar PDF, JPG o PNG.',
      );
      expect(_file('vacio.pdf', 0).problem, 'El archivo está vacío.');
      expect(
        PickedFile(
          name: 'grande.pdf',
          bytes: Uint8List(0),
          size: 6 * 1024 * 1024,
        ).problem,
        'El archivo pesa 6,0 MB. El máximo es 5,0 MB.',
      );
    });
  });

  group('pantalla del diagnóstico', () {
    late FakeAttachmentService attachments;
    late FakeFileAccess files;
    late FakeRecordsService records;

    setUp(() {
      attachments = FakeAttachmentService();
      files = FakeFileAccess();
      records = FakeRecordsService();
      AttachmentService.instance = attachments;
      FileAccess.instance = files;
      RecordsService.instance = records;
      AuthService.instance.current = _caregiver;
    });
    tearDown(() => AuthService.instance.current = null);

    Future<void> pump(
      WidgetTester tester,
      Diagnosis diagnosis, {
      bool readOnly = false,
    }) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final message = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiagnosisEditScreen(
                          diagnosis: diagnosis,
                          patientName: 'Juan Paredes',
                          readOnly: readOnly,
                        ),
                      ),
                    );
                    if (message != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    Diagnosis d(String id) => records.diagnoses.firstWhere((x) => x.id == id);

    testWidgets('lista los documentos, con los quitados marcados', (
      tester,
    ) async {
      await pump(tester, d('d1'));

      expect(find.text('DOCUMENTACIÓN DE RESPALDO'), findsOneWidget);
      expect(find.text('informe_neurologia.pdf'), findsOneWidget);
      expect(find.text('foto_estudio.jpg'), findsOneWidget);
      expect(find.text('Quitado'), findsOneWidget);
      expect(find.textContaining('845 KB · María González'), findsOneWidget);
    });

    testWidgets('adjunta un archivo al diagnóstico guardado', (tester) async {
      await pump(tester, d('d1'));
      files.next = _file('resonancia.png', 2048);

      await tapText(tester, 'Adjuntar documento');

      expect(attachments.calls, ['subir d1 resonancia.png']);
      expect(find.text('Documento adjuntado.'), findsOneWidget);
      expect(find.text('resonancia.png'), findsOneWidget);
    });

    testWidgets('no sube un archivo de más de 5 MB ni de otro tipo', (
      tester,
    ) async {
      await pump(tester, d('d1'));

      files.next = PickedFile(
        name: 'tomografia.pdf',
        bytes: Uint8List(0),
        size: 6 * 1024 * 1024,
      );
      await tapText(tester, 'Adjuntar documento');
      expect(
        find.text('El archivo pesa 6,0 MB. El máximo es 5,0 MB.'),
        findsOneWidget,
      );

      files.next = _file('notas.docx', 100);
      await tapText(tester, 'Adjuntar documento');
      expect(
        find.text('Solo se pueden adjuntar PDF, JPG o PNG.'),
        findsOneWidget,
      );
      expect(attachments.calls, isEmpty);
    });

    testWidgets('abre el PDF con otra app', (tester) async {
      await pump(tester, d('d1'));

      await tapText(tester, 'informe_neurologia.pdf');

      expect(attachments.calls, ['bajar a1']);
      expect(files.opened, ['informe_neurologia.pdf']);
    });

    testWidgets('quitar pide confirmación y no borra', (tester) async {
      await pump(tester, d('d1'));

      await tester.ensureVisible(
        find.byTooltip('Quitar informe_neurologia.pdf'),
      );
      await tester.tap(find.byTooltip('Quitar informe_neurologia.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('¿Quitar el documento?'), findsOneWidget);
      await tester.tap(find.text('Sí, quitar'));
      await tester.pumpAndSettle();

      expect(attachments.calls, ['quitar a1']);
      expect(find.text('Quitado'), findsNWidgets(2));
      expect(find.text('informe_neurologia.pdf'), findsOneWidget);
    });

    testWidgets('en un diagnóstico nuevo los sube al guardar', (tester) async {
      await pump(
        tester,
        const Diagnosis(
          idPaciente: 'p1',
          tipo: DiagnosisType.secundario,
          diagnostico: '',
        ),
      );
      expect(find.textContaining('Se suben al guardar'), findsOneWidget);

      files.next = _file('informe.pdf', 4096);
      await tapText(tester, 'Adjuntar documento');
      expect(find.text('informe.pdf'), findsOneWidget);
      expect(find.textContaining('se sube al guardar'), findsOneWidget);
      expect(attachments.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Diagnóstico (ej. Parálisis cerebral)',
        ),
        'Escoliosis',
      );
      await tapText(tester, 'Guardar diagnóstico');

      expect(records.calls, ['add p1 secundario Escoliosis actual=true']);
      expect(attachments.calls, ['subir nuevo informe.pdf']);
      expect(
        find.text('Diagnóstico registrado con 1 documento.'),
        findsOneWidget,
      );
    });

    testWidgets('si falla la subida avisa que el diagnóstico quedó', (
      tester,
    ) async {
      attachments.failUpload = 'sin conexión';
      await pump(
        tester,
        const Diagnosis(
          idPaciente: 'p1',
          tipo: DiagnosisType.secundario,
          diagnostico: '',
        ),
      );
      files.next = _file('informe.pdf', 4096);
      await tapText(tester, 'Adjuntar documento');
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Diagnóstico (ej. Parálisis cerebral)',
        ),
        'Escoliosis',
      );
      await tapText(tester, 'Guardar diagnóstico');

      expect(
        find.text(
          'Diagnóstico registrado, pero no se pudo subir informe.pdf. '
          'Podés adjuntarlo desde el diagnóstico.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('quitar un archivo elegido no pide confirmación', (
      tester,
    ) async {
      await pump(
        tester,
        const Diagnosis(
          idPaciente: 'p1',
          tipo: DiagnosisType.secundario,
          diagnostico: '',
        ),
      );
      files.next = _file('informe.pdf', 4096);
      await tapText(tester, 'Adjuntar documento');

      await tester.tap(find.byTooltip('Quitar informe.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('informe.pdf'), findsNothing);
    });

    testWidgets('quien solo consulta ve los documentos pero no adjunta', (
      tester,
    ) async {
      await pump(tester, d('d1'), readOnly: true);

      expect(find.text('informe_neurologia.pdf'), findsOneWidget);
      expect(find.text('Adjuntar documento'), findsNothing);
      expect(find.byTooltip('Quitar informe_neurologia.pdf'), findsNothing);
    });

    testWidgets('a un diagnóstico anulado no se le adjunta nada', (
      tester,
    ) async {
      await pump(tester, d('d4'));

      expect(find.text('No hay documentos adjuntos.'), findsOneWidget);
      expect(find.text('Adjuntar documento'), findsNothing);
    });

    testWidgets('la tarjeta del diagnóstico cuenta los documentos', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiagnosisCard(diagnosis: d('d1'))),
        ),
      );
      expect(find.text('1 documento de respaldo'), findsOneWidget);
    });
  });
}
