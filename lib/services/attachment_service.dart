// Documentación de respaldo de los diagnósticos: informes, estudios, fotos.
//
// Firebase Storage pide el plan Blaze, así que los archivos se guardan en
// Firestore (plan gratuito), partidos en trozos porque un documento admite
// hasta 1 MiB:
//
// - `pacientes/{pid}/diagnosticos/{did}/adjuntos/{aid}`: nombre, tipo,
//   tamaño, cuántas partes tiene y quién lo subió.
// - `.../adjuntos/{aid}/partes/{n}`: los bytes de la parte n (0, 1, ...).
//
// La ficha, las partes, el contador del diagnóstico y el registro de
// auditoría se escriben en una sola operación: o se sube todo o nada. Nada
// se borra: un adjunto se quita con estado = false y queda en el historial.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'audit.dart';
import 'auth_service.dart';
import 'records_service.dart';

/// Tamaño máximo de un archivo: 5 MB.
const maxAttachmentBytes = 5 * 1024 * 1024;

/// Bytes por parte. Con el nombre de los campos, cada documento queda bien
/// por debajo del límite de 1 MiB de Firestore.
const attachmentPartBytes = 700 * 1024;

/// Extensiones que se pueden adjuntar y su tipo.
const attachmentTypes = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
};

/// Tipo del archivo según su extensión, o `null` si no se admite.
String? mimeTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return attachmentTypes[fileName.substring(dot + 1).toLowerCase()];
}

/// "850 KB", "2,3 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Parte los bytes en trozos de [size].
List<Uint8List> splitParts(Uint8List bytes, {int size = attachmentPartBytes}) {
  return [
    for (var start = 0; start < bytes.length; start += size)
      Uint8List.sublistView(bytes, start, min(start + size, bytes.length)),
  ];
}

/// Une las partes en orden.
Uint8List joinParts(List<Uint8List> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.takeBytes();
}

/// Un archivo elegido en el teléfono, todavía sin subir.
class PickedFile {
  /// Con [size] y sin [bytes] cuando el archivo es demasiado grande y no
  /// vale la pena leerlo.
  PickedFile({required this.name, required this.bytes, int? size})
    : size = size ?? bytes.length;

  final String name;
  final Uint8List bytes;

  /// Bytes del archivo.
  final int size;

  String? get mimeType => mimeTypeFor(name);

  /// Motivo por el que no se puede adjuntar, o `null` si está bien.
  String? get problem {
    if (mimeType == null) return 'Solo se pueden adjuntar PDF, JPG o PNG.';
    if (size > maxAttachmentBytes) {
      return 'El archivo pesa ${formatBytes(size)}. El máximo es '
          '${formatBytes(maxAttachmentBytes)}.';
    }
    if (bytes.isEmpty) return 'El archivo está vacío.';
    return null;
  }
}

String _text(Object? value) => value is String ? value : '';
DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

/// Documento adjunto a un diagnóstico.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.idPaciente,
    required this.idDiagnostico,
    required this.nombre,
    required this.tipo,
    required this.tamano,
    required this.partes,
    this.activo = true,
    this.nombreSubidor = '',
    this.fechaSubida,
    this.nombreQuitador = '',
    this.fechaQuitado,
  });

  factory Attachment.fromMap(String id, Map<String, dynamic> data) =>
      Attachment(
        id: id,
        idPaciente: _text(data['idPaciente']),
        idDiagnostico: _text(data['idDiagnostico']),
        nombre: _text(data['nombre']),
        tipo: _text(data['tipo']),
        tamano: (data['tamano'] as num?)?.toInt() ?? 0,
        partes: (data['partes'] as num?)?.toInt() ?? 0,
        activo: data['estado'] != false,
        nombreSubidor: _text(data['nombreSubidor']),
        fechaSubida: _time(data['fechaSubida']),
        nombreQuitador: _text(data['nombreQuitador']),
        fechaQuitado: _time(data['fechaQuitado']),
      );

  final String id;
  final String idPaciente;
  final String idDiagnostico;
  final String nombre;

  /// Tipo MIME ("application/pdf", "image/jpeg").
  final String tipo;

  /// Bytes.
  final int tamano;
  final int partes;

  /// `false` si se quitó (no se borra).
  final bool activo;
  final String nombreSubidor;
  final DateTime? fechaSubida;
  final String nombreQuitador;
  final DateTime? fechaQuitado;

  bool get isImage => tipo.startsWith('image/');

  /// Los vigentes primero y, entre ellos, el más nuevo arriba.
  static int compare(Attachment a, Attachment b) {
    if (a.activo != b.activo) return a.activo ? -1 : 1;
    final ta = a.fechaSubida, tb = b.fechaSubida;
    if (ta == null || tb == null) return ta == null ? (tb == null ? 0 : -1) : 1;
    return tb.compareTo(ta);
  }
}

/// Punto de acceso de las pantallas. En los tests se reemplaza [instance].
abstract class AttachmentService {
  static AttachmentService instance = FirestoreAttachmentService();

  /// Adjuntos del diagnóstico, quitados incluidos.
  Stream<List<Attachment>> watch(Diagnosis diagnosis);

  /// Sube el archivo. Lanza [AuthException] con un mensaje si no se puede.
  Future<void> upload(
    Diagnosis diagnosis,
    PickedFile file, {
    required String paciente,
  });

  /// Contenido del archivo, unido a partir de sus partes.
  Future<Uint8List> download(Attachment attachment);

  /// Lo quita de la lista vigente. No se borra.
  Future<void> remove(Attachment attachment, {required String paciente});
}

class FirestoreAttachmentService extends AttachmentService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String get _actorName => AuthService.instance.current?.fullName ?? 'Usuario';

  /// Los archivos no cambian: lo descargado se guarda mientras dura la app.
  final _cache = <String, Uint8List>{};

  DocumentReference<Map<String, dynamic>> _diagnosis(
    String patientUid,
    String diagnosisId,
  ) => _db.doc('pacientes/$patientUid/diagnosticos/$diagnosisId');

  DocumentReference<Map<String, dynamic>> _ref(Attachment a) => _diagnosis(
    a.idPaciente,
    a.idDiagnostico,
  ).collection('adjuntos').doc(a.id);

  @override
  Stream<List<Attachment>> watch(Diagnosis diagnosis) {
    try {
      return _diagnosis(diagnosis.idPaciente, diagnosis.id)
          .collection('adjuntos')
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                Attachment.fromMap(doc.id, doc.data()),
            ]..sort(Attachment.compare),
          );
    } catch (e) {
      return Stream.error(e);
    }
  }

  @override
  Future<void> upload(
    Diagnosis diagnosis,
    PickedFile file, {
    required String paciente,
  }) async {
    final problem = file.problem;
    if (problem != null) throw AuthException(problem);
    final diagnosisRef = _diagnosis(diagnosis.idPaciente, diagnosis.id);
    final ref = diagnosisRef.collection('adjuntos').doc();
    final parts = splitParts(file.bytes);
    try {
      final batch = _db.batch();
      batch.set(ref, {
        'idPaciente': diagnosis.idPaciente,
        'idDiagnostico': diagnosis.id,
        'nombre': file.name,
        'tipo': file.mimeType,
        'tamano': file.size,
        'partes': parts.length,
        'estado': true,
        'subidoPor': FirebaseAuth.instance.currentUser?.uid,
        'nombreSubidor': _actorName,
        'fechaSubida': FieldValue.serverTimestamp(),
      });
      for (var i = 0; i < parts.length; i++) {
        batch.set(ref.collection('partes').doc('$i'), {
          'datos': Blob(parts[i]),
        });
      }
      batch.update(diagnosisRef, {'adjuntos': FieldValue.increment(1)});
      batch.set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: 'Adjuntó un documento a un diagnóstico de $paciente',
          detalle:
              '${file.name} (${formatBytes(file.size)}) · '
              '${diagnosis.diagnostico}',
          entidad: 'adjuntos',
          idEntidad: '${diagnosis.idPaciente}/${diagnosis.id}/${ref.id}',
        ),
      );
      await batch.commit();
      _cache[ref.id] = file.bytes;
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Future<Uint8List> download(Attachment attachment) async {
    final cached = _cache[attachment.id];
    if (cached != null) return cached;
    try {
      final snap = await _ref(attachment).collection('partes').get();
      final byIndex = {
        for (final doc in snap.docs)
          int.tryParse(doc.id) ?? -1: (doc.data()['datos'] as Blob).bytes,
      };
      final parts = [
        for (var i = 0; i < attachment.partes; i++)
          byIndex[i] ??
              (throw const AuthException(
                'El archivo está incompleto. Volvé a adjuntarlo.',
              )),
      ];
      return _cache[attachment.id] = joinParts(parts);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Future<void> remove(Attachment attachment, {required String paciente}) async {
    try {
      final batch = _db.batch();
      batch.update(_ref(attachment), {
        'estado': false,
        'quitadoPor': FirebaseAuth.instance.currentUser?.uid,
        'nombreQuitador': _actorName,
        'fechaQuitado': FieldValue.serverTimestamp(),
      });
      batch.update(
        _diagnosis(attachment.idPaciente, attachment.idDiagnostico),
        {'adjuntos': FieldValue.increment(-1)},
      );
      batch.set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: 'Quitó un documento de un diagnóstico de $paciente',
          detalle: attachment.nombre,
          entidad: 'adjuntos',
          idEntidad:
              '${attachment.idPaciente}/${attachment.idDiagnostico}/'
              '${attachment.id}',
        ),
      );
      await batch.commit();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }
}

/// Elegir archivos del teléfono y abrirlos con otra app. En los tests se
/// reemplaza [instance].
abstract class FileAccess {
  static FileAccess instance = DeviceFileAccess();

  /// `null` si la persona cancela.
  Future<PickedFile?> pick();

  /// Abre el archivo con la app del teléfono que corresponda (visor de PDF,
  /// galería). Devuelve un mensaje si no se pudo.
  Future<String?> open(String name, Uint8List bytes);
}

class DeviceFileAccess extends FileAccess {
  @override
  Future<PickedFile?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: attachmentTypes.keys.toList(),
    );
    if (file == null) return null;
    final size = await file.length();
    // No se lee entero un archivo que igual no se va a poder subir.
    if (size != null && size > maxAttachmentBytes) {
      return PickedFile(name: file.name, bytes: Uint8List(0), size: size);
    }
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<String?> open(String name, Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: mimeTypeFor(name));
      return switch (result.type) {
        ResultType.done => null,
        ResultType.noAppToOpen =>
          'No hay ninguna app en el teléfono para abrir este archivo.',
        _ => 'No se pudo abrir el archivo (${result.message}).',
      };
    } catch (e) {
      return 'No se pudo abrir el archivo.';
    }
  }
}
