// Mobile-specific file download
// For mobile, file downloads would typically use path_provider and share packages
// For now, this is a stub that throws an error
import 'dart:convert';

void downloadFile(String content, String filename) {
  // TODO: Implement mobile file download using path_provider
  // For now, throw an error indicating this feature is web-only
  throw UnsupportedError(
    'File download on mobile requires additional implementation. '
    'Please use the web version for exporting payroll data.'
  );
}
