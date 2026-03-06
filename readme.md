# AiCore
`Cre8tive Sync's` Most Prized Possession

Checks all prerequisites upfront including cl and nvcc — stops early with a clear message if anything is missing
Creates fresh aicorescan conda env
Sets all CUDA env vars automatically before any compilation
Installs gsplat cleanly via pip
Clones MASt3R, inits its submodules, installs it, then downloads the 1.5GB weights
Clones SuGaR, installs its dependencies in the right order, then attempts to compile its CUDA extensions with all the fixes applied
Sets up React + Electron frontend
Creates start-dev.bat so you never have to redo the env setup again
