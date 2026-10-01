# Web UI Canvas

Standalone visual web UI editor.

Web UI Canvas is deliberately independent from any website repository or brand system. Its interaction model is inspired by the Website & Template Maker in CircuitCurios Studio, but the project model, component library and export pipeline are generic.

## Product

- Edit an independent .webui project.
- Build pages visually on a free canvas.
- Use semantic web components instead of CircuitCurios-specific blocks.
- Preview the design without touching an existing website.
- Export a self-contained HTML/CSS website shell.
- Keep the editor project so the UI can be reopened and changed later.

## Current foundation

- free-size canvas
- component palette with drag & drop
- selection and direct movement
- 8 resize handles
- direct rotation handle
- layers
- visibility / locking
- undo / redo
- grid and snapping
- inspector for geometry, typography, colors, links and anchors
- image loading
- .webui save/open
- standalone HTML/CSS export
- preview mode

## Bootstrap

After cloning on Windows:

    ./tool/bootstrap_windows.ps1
    flutter pub get
    flutter run -d windows

See docs/ARCHITECTURE.md and docs/ROADMAP.md.


## Android

The same editor codebase includes a compact touch layout for phones and tablets:

- full-screen canvas instead of permanent sidebars
- Elements, Properties and Layers as bottom sheets
- touch pan and pinch zoom
- larger resize and rotation targets
- automatic initial canvas fit
- the current desktop editor features remain shared with Android

Build a release APK on Windows:

    build_android.bat

The script generates the lightweight Android host on first use, runs analysis with infos/warnings non-fatal, builds the release APK and opens Explorer on:

    dist/web-ui-canvas-android.apk

GitHub Actions also builds the APK and publishes it as the `Web-UI-Canvas-Android` workflow artifact.
