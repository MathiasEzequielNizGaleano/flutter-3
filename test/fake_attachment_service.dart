import 'dart:async';
import 'dart:typed_data';

import 'package:headmouse_pro/services/attachment_service.dart';
import 'package:headmouse_pro/services/records_service.dart';

/// Adjuntos en memoria: un informe vigente y una foto quitada en d1.
class FakeAttachmentService extends AttachmentService {
  final attachments = <Attachment>[
    Attachment(
      id: 'a1',
      idPaciente: 'p1',
      idDiagnostico: 'd1',
      nombre: 'informe_neurologia.pdf',
      tipo: 'application/pdf',
      tamano: 845 * 1024,
      partes: 2,
      nombreSubidor: 'María González',
      fechaSubida: DateTime(2026, 9, 1, 10),
    ),
    Attachment(
      id: 'a2',
      idPaciente: 'p1',
      idDiagnostico: 'd1',
      nombre: 'foto_estudio.jpg',
      tipo: 'image/jpeg',
      tamano: 1200 * 1024,
      partes: 2,
      activo: false,
      nombreSubidor: 'María González',
      fechaSubida: DateTime(2026, 9, 2, 10),
      nombreQuitador: 'María González',
    ),
  ];

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  /// Si no es null, la subida falla con este mensaje.
  String? failUpload;

  final _changes = StreamController<void>.broadcast();

  List<Attachment> _of(String diagnosisId) => [
    for (final a in attachments)
      if (a.idDiagnostico == diagnosisId) a,
  ]..sort(Attachment.compare);

  @override
  Stream<List<Attachment>> watch(Diagnosis diagnosis) async* {
    yield _of(diagnosis.id);
    await for (final _ in _changes.stream) {
      yield _of(diagnosis.id);
    }
  }

  @override
  Future<void> upload(
    Diagnosis diagnosis,
    PickedFile file, {
    required String paciente,
  }) async {
    calls.add('subir ${diagnosis.id} ${file.name}');
    if (failUpload != null) throw Exception(failUpload);
    attachments.add(
      Attachment(
        id: 'n${attachments.length}',
        idPaciente: diagnosis.idPaciente,
        idDiagnostico: diagnosis.id,
        nombre: file.name,
        tipo: file.mimeType!,
        tamano: file.size,
        partes: splitParts(file.bytes).length,
        nombreSubidor: 'María González',
        fechaSubida: DateTime(2026, 11, 16, 9),
      ),
    );
    _changes.add(null);
  }

  @override
  Future<Uint8List> download(Attachment attachment) async {
    calls.add('bajar ${attachment.id}');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> remove(Attachment attachment, {required String paciente}) async {
    calls.add('quitar ${attachment.id}');
    final i = attachments.indexWhere((a) => a.id == attachment.id);
    final a = attachments[i];
    attachments[i] = Attachment(
      id: a.id,
      idPaciente: a.idPaciente,
      idDiagnostico: a.idDiagnostico,
      nombre: a.nombre,
      tipo: a.tipo,
      tamano: a.tamano,
      partes: a.partes,
      activo: false,
      nombreSubidor: a.nombreSubidor,
      fechaSubida: a.fechaSubida,
      nombreQuitador: 'María González',
    );
    _changes.add(null);
  }
}

/// Selector de archivos que devuelve [next] y registra lo que se abre.
class FakeFileAccess extends FileAccess {
  PickedFile? next;
  final opened = <String>[];

  @override
  Future<PickedFile?> pick() async => next;

  @override
  Future<String?> open(String name, Uint8List bytes) async {
    opened.add(name);
    return null;
  }
}
