```
         /\			
        /  \
       /    \
      /  /\  \
     /  /  \  \
    /__/____\__\
 ╭─╯ _________  \
╭╯  /         \__\
│  │
│  │
│  │            ___   
╰╮ ╰╮__________/  /
 ╰──╮         ╭──╯
    ╰─────────╯    

          A I C O R E
   Advanced Imaging for Crime
 Observation and Reconstruction
         Enhancement
```

## Files in this package

| File | Purpose |
|---|---|
| `aicore_full_setup.py` | Full install script for new machines |
| `aicore_setup.py` | Patch-only script (if repo already cloned) |
| `resize_images.py` | Resize images to 1600px before scanning |
| `convert_heic.py` | Convert iPhone HEIC photos to PNG |
| `aicore_splat_viewer.html` | View .ply splat files in browser |

---

## Prerequisites (manual, one time per machine)

Install these in order before running the setup script:

1. **NVIDIA GPU** — required, no AMD/Intel support
2. **CUDA Toolkit 12.1** — https://developer.nvidia.com/cuda-12-1-0-download-archive
3. **Visual Studio 2022 Build Tools** with "Desktop development with C++" workload
   → https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
4. **Git** — https://git-scm.com/download/win
5. **Miniconda** — https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe

---

## Fresh Install (new machine)

1. Open **x64 Native Tools Command Prompt for VS 2022** (search Start Menu)
2. Add conda to PATH if needed:
   ```
   set PATH=C:\Users\<yourname>\miniconda3\Scripts;C:\Users\<yourname>\miniconda3;%PATH%
   ```
3. Navigate to where you want InstantSplat installed:
   ```
   cd D:\YourFolder
   ```
4. Run the setup script:
   ```
   python aicore_full_setup.py
   ```
5. Wait ~30-60 min (downloads ~3GB total including model weights)

---

## Running InstantSplat

Every time you want to use it:

```
conda activate instantsplat
cd InstantSplat_Windows
python instantsplat_gradio.py
```

Then open http://127.0.0.1:7860 in Chrome.

---

## Using the Gradio UI

- **Image path** → folder containing your `images\` subfolder (e.g. `C:\Cases\Scene01`)
- **Output path** → where results are saved
- **n_views** → number of photos in your images folder (max 50)
- **Iterations** → 7000 recommended, 9000+ for best quality

Your folder must look like:
```
Scene01\
    images\
        photo1.jpg
        photo2.jpg
        ...
```

---

## Image Preparation

**Resize before scanning** (recommended — images >1600px are auto-downscaled anyway):
```
cd your\images\folder
python resize_images.py
```

**Convert iPhone HEIC photos:**
```
pip install pillow-heif
cd your\images\folder
python convert_heic.py
```

---

## Viewing Results

Open `aicore_splat_viewer.html` in Chrome.
Drag your `.ply` file from the output folder onto it.

Controls:
- Left drag → Rotate
- Scroll → Zoom
- Right drag → Pan

---

## Photo Guide for Best Results

Crime scene photos should follow this pattern:

1. **4 wide shots** — full room from each corner
2. **8-10 perimeter shots** — walk slowly around the room, never skip more than ~30 degrees
3. **4-6 subject shots** — keep the room visible in frame, don't zoom tight
4. **3-4 detail shots** — specific evidence items

Avoid: mirrors, glass, harsh shadows, motion blur, jumping between far-apart angles.

---

## Troubleshooting

| Error | Fix |
|---|---|
| `conda not recognized` | Run: `set PATH=C:\Users\<name>\miniconda3\Scripts;...;%PATH%` |
| `DISTUTILS_USE_SDK not set` | Must run from x64 Native Tools Command Prompt |
| `unsupported compiler version` | setup.py patches not applied — run `aicore_setup.py patch` |
| `images\images not found` | Paste parent folder path in UI, not the images folder itself |
| `KeyError: 7` | Set n_views to match exact number of photos |
| Video render fails at end | Ignore — your .ply is saved, video step is optional |
