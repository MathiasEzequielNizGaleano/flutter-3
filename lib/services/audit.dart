// Registro de auditoría compartido por todos los servicios.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// Datos de un documento de `auditoria` firmado por la sesión actual.
/// Las reglas solo aceptan registros cuyo `idActor` sea quien escribe.
Map<String, Object?> auditRecord({
  required String accion,
  required String detalle,
  required String entidad,
  required String idEntidad,
  String categoria = 'Cambios de datos',
}) {
  final actor = AuthService.instance.current;
  return {
    'idActor': FirebaseAuth.instance.currentUser?.uid,
    'nombreActor': actor?.fullName ?? 'Usuario',
    'rolActor': actor?.role.id,
    'categoria': categoria,
    'accion': accion,
    'detalle': detalle,
    'entidad': entidad,
    'idEntidad': idEntidad,
    'fechaHora': FieldValue.serverTimestamp(),
  };
}
