# Parchment texture experiment

Asset: `Sources/TaleApp/Resources/Textures/PaperGrain@2x.png`

Created with the built-in imagegen tool. The original 1254 × 1254 PNG is bundled at 2× scale, producing a 627-point tile without stretching the fibers as the window resizes. SwiftUI multiplies it over the background color in both light and dark mode, using the same opacity and smoothing. `TaleBackground.textureOpacity` controls the strength.

The current trial uses 14% opacity with a 2.5-point blur and high-quality image interpolation. It restores the paper's presence while smoothing away more of the fine fibers, following an 8% opacity / 1-point blur trial that felt too faint. `textureSoftness` controls the blur; the texture remains stationary.

## Generation prompt

Use case: photorealistic-natural. Asset type: seamless square tiled paper texture for a native macOS productivity app background. Generate a 1024 by 1024 pixel flat, perfectly top-down scan of fine handmade book paper. Neutral grayscale (no yellow tint; the app supplies its own parchment color), light gray average tone, delicate visible interwoven short organic paper fibers and very soft irregular broad tonal variation. Uniform diffuse illumination across the entire image. Quiet elegant archival paper that suggests an old fantasy book but remains professional in an office setting. Fine scale, subtle contrast, no dominant marks, no directional pattern. CRITICAL: truly seamless and repeatable horizontally and vertically, opposite edges match, texture fills image edge to edge. No borders, page edges, vignette, dark corners, wrinkles, folds, stains, speckles that look like dirt, objects, letters, text, watermarks, or illustrations. This is the raw texture asset, not an app mockup.
