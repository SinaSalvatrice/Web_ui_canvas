# Architecture

## Goal

Web UI Canvas is a standalone web-interface designer. It does not know about CircuitCurios, Etsy, product folders, a fixed website repository or fixed page names.

The existing CircuitCurios Website & Template Maker is the UX reference, not a runtime dependency.

## Source of truth

A .webui file is the canonical editable project.

The model contains:

- pages
- canvas dimensions
- semantic element type
- geometry
- style
- links
- image references
- anchors
- visibility / lock state

The editor never stores website-specific repository paths in the project.

## Editor layers

1. project model
2. editor controller + history
3. component library
4. canvas interaction
5. inspector / layers
6. preview runtime
7. exporters

## Export

The first exporter writes a self-contained HTML/CSS shell plus copied image assets.

The exporter is deliberately separate from the editor. Later exporters can target semantic responsive HTML, React or another runtime without changing the canvas interaction engine.

## Migration from the brand editor

Keep / generalize:

- free canvas
- drag/drop
- move, resize, rotate
- crop positioning
- grid/snap
- undo/redo
- typography
- colors and borders
- links
- anchors
- layers
- image loading
- adjustable page height

Remove:

- CircuitCurios repository discovery
- fixed pages such as prozess.html / ueber.html / shop.html
- product image library coupling
- texture-card / process / about brand blocks
- direct write-back to CircuitCurios-website
- brand fonts/colors as defaults
- Studio workspace/session dependencies
