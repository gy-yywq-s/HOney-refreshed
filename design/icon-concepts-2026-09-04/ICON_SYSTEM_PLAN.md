# HOney icon system — exploration plan

Status: concept exploration only. None of these assets replace the current iOS or Web icon yet.

## Product character

HOney is an everyday school utility: quick, friendly and useful. It should not look like a school crest, a magazine, a luxury brand, or a conceptual design studio.

The icon system therefore uses:

- flat colour rather than gradients or glossy material;
- rounded, slightly asymmetric geometry rather than formal symmetry;
- one dark utility stroke plus one or two small cheerful colour moments;
- no literal `HO`, no `web` text, and no large platform badge;
- the same mother mark for native and Web.

## Concept families

| ID | Direction | Character | Main risk |
| --- | --- | --- | --- |
| A | Open day loop | friendly, simple, active | can resemble a power/loading symbol |
| B | Day dial | cheerful, timetable-adjacent | can resemble sunrise or a cloche |
| C | Connected paths | social, moving | generic infinity association |
| D | Open portal | access-oriented, approachable | fingerprint/headphone association |
| E | Pocket cards | most obviously useful and versatile | less abstractly distinctive |
| F | Quick route | most playful and energetic | needs tighter brand ownership |

## Web companion

The Web version remains the same product mark. A small secondary sign differentiates the installed PWA:

1. line globe;
2. browser window;
3. cursor;
4. external-link arrow.

No `web` word strip is retained. The final Web export keeps all essential artwork inside the central maskable safe zone.

## Production pass after selection

1. Refine the selected geometry on a 1024-unit grid.
2. Test at 1024, 180, 64, 32 and 16 px.
3. Produce iOS default, dark and tinted variants without pre-baked system effects.
4. Produce PWA 512/192 maskable and regular icons, Apple touch icon and favicon.
5. Preview native and Web variants together on actual Home Screen/Dock contexts.
6. Only after approval, replace the repo assets and run build/manifest checks.

## Image generation boundary

ImageGen produced one optional paper-grain component. It was intentionally not used after the direction changed away from editorial material. All visible icon concepts and Web markers are deterministic SVG geometry.
