// Why this file exists, when Flutter would otherwise generate one:
//
// By default the engine fetches CanvasKit (~5-7MB of WASM) from
// https://www.gstatic.com/flutter-canvaskit on every cold load, rather than
// from wherever the rest of the app is served. On a slow or inconsistent
// mobile connection - exactly the condition a shop in Tanzania should be
// built for - that external fetch is the difference between the app painting
// in a couple of seconds and sitting on a blank white screen indefinitely
// while it waits on a CDN the rest of the page never touches.
//
// Setting canvasKitBaseUrl below makes it load from this same deployment
// instead: one origin, one CDN (Vercel's), no dependency on gstatic.com being
// fast - or reachable at all - from wherever the till happens to be.
//
// Everything else here is Flutter's own generated bootstrap, unchanged: the
// {{...}} placeholders are filled in by `flutter build web` at build time, the
// same way they would be if this file did not exist.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: {
    canvasKitBaseUrl: "canvaskit/"
  }
});
