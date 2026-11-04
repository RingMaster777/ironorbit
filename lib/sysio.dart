/// Conditional file write: real dart:io on native platforms, no-op on web
/// (where backups go through the browser download instead).
export 'sysio_stub.dart' if (dart.library.io) 'sysio_vm.dart';
