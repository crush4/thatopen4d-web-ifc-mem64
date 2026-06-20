# @thatopen4d/web-ifc-mem64

Ein **Memory64-Fork von [`@thatopen/engine_web-ifc`](https://github.com/ThatOpen/engine_web-ifc)**, der die 4-GB-Heap-Grenze von 32-Bit-WebAssembly beseitigt. Drop-in-Ersatz für `web-ifc`, ausschliesslich gedacht für IFC-Modelle ab ~1.5 GB, bei denen der offizielle Build mit `bad_alloc` aussteigt.

## Was ist anders

| | Offizielles `web-ifc` 0.0.77 | `@thatopen4d/web-ifc-mem64` 0.0.77-mem64.1 |
|---|---|---|
| WASM-Memory-Modus | 32-Bit (`wasm32`) | 64-Bit (`wasm64`) via `-sMEMORY64=1` |
| Maximaler Heap | 4 GB | 16 GB (Browser-Tab-RAM-limitiert) |
| Bundle-Groesse `.wasm` | ~1.30 MB | ~1.36 MB (+4 %) |
| Browser-Anforderung | Alle | Chrome ≥ 123, Firefox ≥ 134 |
| JS-API | Number-Pointer | BigInt-Pointer (transparent durch Wrapper) |

## Verwendung im Browser

```html
<!-- IIFE-Bundle: `window.WebIFC` global -->
<script src="/dist/web-ifc-api-iife.js"></script>
<script type="module">
  const ifcAPI = new window.WebIFC.IfcAPI();
  ifcAPI.SetWasmPath(`${location.origin}/dist/`, true);
  await ifcAPI.Init(undefined, /* forceSingleThread */ true);

  const file = await fileInput.files[0];
  const bytes = new Uint8Array(await file.arrayBuffer());
  const modelID = ifcAPI.OpenModel(bytes);
  console.log("Schema:", ifcAPI.GetModelSchema(modelID));
</script>
```

ESM-Variante per `import { IfcAPI } from "@thatopen4d/web-ifc-mem64"` analog.

Fuer sehr grosse Dateien (>1.5 GB) wird der Streaming-Pfad empfohlen:

```js
const modelID = ifcAPI.OpenModelFromCallback((offset, size) => {
  return readChunk(offset, size); // sync Uint8Array
});
```

Im Worker-Scope geht das mit `FileReaderSync` synchron.

## Verwendung im Hauptprojekt (ThatOpen4D-App)

```json
"dependencies": {
  "@thatopen4d/web-ifc-mem64": "github:crush4/thatopen4d-web-ifc-mem64#v0.0.77-mem64.1"
}
```

Die App entscheidet pro Datei-Groesse zwischen Standard-`web-ifc` (klein, schnell) und `@thatopen4d/web-ifc-mem64` (gross, 64-Bit-Heap).

## Patches gegenueber Upstream

Drei chirurgische Patches in `patches/`:

1. **[01-cmake-mem64.patch](patches/01-cmake-mem64.patch)** — `CMakeLists.txt`: `-sMEMORY64=1` + `-sMAXIMUM_MEMORY=16GB` an alle drei Emscripten-Targets (`web-ifc`, `web-ifc-node`, `web-ifc-mt`).

2. **[02-cpp-mem64-pointer.patch](patches/02-cpp-mem64-pointer.patch)** — `src/cpp/wasm/web-ifc-wasm.cpp`:
   - `(uint32_t)dest` → `(uintptr_t)dest` (Zeile 57, 71) — Pointer-Cast haette auf wasm64 die oberen 32 Bit verloren
   - `long d` → `int32_t d` (Zeile 689) — `emscripten::val`-Wire-Type-Slot ist 4 Byte

3. **[03-ts-bigint-pointer.patch](patches/03-ts-bigint-pointer.patch)** — `src/ts/web-ifc-api.ts`: `Number(ptr)` + `Number(size)` in den Callbacks von `OpenModel`, `OpenModelFromCallback`, `SaveModel`, `SaveModelToCallback`, `getSubArray`. BigInt-Pointer aus dem WASM landen sonst in `HEAPU8.subarray()`-Aufrufen, die nur Number akzeptieren.

## Build selbst

Voraussetzung: Docker. Der Build laeuft im `emscripten/emsdk:4.0.23`-Image.

```bash
git clone --recurse-submodules https://github.com/crush4/thatopen4d-web-ifc-mem64.git
cd thatopen4d-web-ifc-mem64
bash scripts/build.sh
# Output: dist/web-ifc.wasm, dist/web-ifc-mt.wasm, dist/web-ifc-api-iife.js, ...
```

Der Build pinnt **web-ifc auf v0.0.77** (Submodule `vendor/web-ifc`). Bei Upstream-Updates wird das Submodule auf den neuen Tag umgehaengt und der Patch-Set rebased.

## Wartungs-Modell

Konservativ: Rebase nur bei Major-Updates von web-ifc oder konkretem Bedarf (Bugfix, neues Feature). Nicht automatisch bei jedem Minor-Release.

## Lizenz

[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) — gleiche Lizenz wie `web-ifc` Upstream.
