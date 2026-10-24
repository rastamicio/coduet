# Assets and the approval loop

Any asset made by Codex (images, sprites, icons, audio, video, 3D, presentations). Production is automatic; approval is always the user's: no asset enters the project without their ok.

| Type | How | Notes |
|---|---|---|
| Images, sprites | Codex's built-in image generation (paid ChatGPT; not if "Image generation" = no) | Transparent backgrounds are unreliable: ask for a flat background (#00FF00 or the project's colour) and cut it out with a script |
| Vector, icons, UI | SVG/HTML code | Reliable |
| Audio | Code: synthesis (e.g. Python writing WAV), MIDI | Retro effects and simple music; not realistic audio |
| Video, animation | Frames from code + ffmpeg (if installed) | Graphic animation yes, realistic video no |
| 3D | Code writing glTF, or Blender scripts (if installed) | Simple low-poly yes, complex organic no |
| Presentations, docs | Code (HTML, PPTX) | Reliable |

If a request falls in a "no", say so before starting and offer an alternative.

## Before producing

- Use the project's own asset conventions if any (guides, prompts, import tools, cutout colour, folders): look in `docs/`, README and scripts first.
- Otherwise create with the user `docs/stile-asset.md`: style, palette, sizes, formats, audio length/volume, 3D polygons/scale, approved references.
- Start with the trial assets parameter per type; full production only after the user approves the style.
- Drafts go to `assets/_bozze/<asset>/v<n>.<ext>`; only approved ones are copied to the final folder. Remove drafts from `codex/<task>` before merging.
- Assets use a lot of Codex quota (images most): produce them in batches.

## Loop per batch

1. **Produce**: prompt with the style guide; attach visual references with `codex-run --image <file>` (Windows `-Image <file1>,<file2>`), other references by path.
2. **Technical check** before the user sees anything:
   - images: size, format, cut-out background, frame count and alignment, consistency (look at them);
   - audio: opens, format, sample rate, length, peaks/clipping, leading/trailing silence, seamless loop;
   - video: opens, length, resolution, fps, codec;
   - 3D: valid file, polygon count, scale and orientation, textures, preview render;
   - presentations/docs: open, layout (look), text.
   On failure regenerate with a corrected prompt, up to the regenerations parameter, then tell the user.
3. **Preview page** `assets/_bozze/anteprima.html`: the right viewer per type (image/GIF, `<audio>`, `<video>`, `<model-viewer>`); per asset name, version, "Approved"/"Redo" buttons, a note field; a "Copy result" button producing e.g. `run_v2: ok | jump_v1: redo - arm disappears in frame 3`. Send: `Coduet · 🖼 <n> assets ready to approve: open <path> and paste me the result.`
4. **Targeted regeneration**: turn notes into precise instructions; redo only what's needed, pass the previous version as reference, add the fix to the asset's cumulative prompt. User-requested regenerations have no limit but are counted.
5. **Approval**: copy the approved version to the final folder; add good references to `docs/stile-asset.md`.

## Log and autonomy

`docs/asset-registro.md`: per asset, every version with prompt, check result, user note, status (draft/approved/discarded), regeneration count. When the user is away, production and checks continue but assets stay "awaiting approval"; the project uses placeholders.
