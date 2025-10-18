import '../../shared/custom_logger.dart';
import '../../shared/services/telemetry_service.dart';

Future<void> initializeBackend(
  CustomLogger logger,
  TelemetryService telemetryService,
) async {
  logger.info(
    'Web environment detected, skipping local backend startup.',
    'Platform initialization',
  );
  // No local backend or FFI database is available on the web target.
}
