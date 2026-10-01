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
