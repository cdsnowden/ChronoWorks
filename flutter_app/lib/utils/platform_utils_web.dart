// Web-specific platform utilities
import 'dart:html' as html;

String? getCurrentPath() {
  return html.window.location.pathname;
}

String? getCurrentSearch() {
  return html.window.location.search;
}
