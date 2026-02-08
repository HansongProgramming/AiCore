import React, { useState } from 'react';
import ImageUpload from './components/imageUpload';
import GaussianSplatViewer from './components/GaussianSplatViewer';
import './App.css';

function App() {
  const [modelUrl, setModelUrl] = useState(null);
  const [showViewer, setShowViewer] = useState(false);

  const handleImagesSelected = (files) => {
    console.log('Images selected:', files.length);
    // This is called when images are selected, before upload
  };

  const handleModelReady = (url) => {
    console.log('Model ready:', url);
    setModelUrl(url);
    setShowViewer(true);
  };

  const handleReset = () => {
    setModelUrl(null);
    setShowViewer(false);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🌟 InstantSplat 3D Reconstruction</h1>
        <p className="subtitle">Transform your photos into 3D models</p>
      </header>

      <main className="App-main">
        {!showViewer ? (
          <ImageUpload 
            onImagesSelected={handleImagesSelected}
            minImages={3}
            maxImages={10}
          />
        ) : (
          <div className="viewer-container">
            <button className="btn-back" onClick={handleReset}>
              ← Upload New Images
            </button>
            <GaussianSplatViewer modelUrl={modelUrl} />
          </div>
        )}
      </main>

      <footer className="App-footer">
        <p>
          Powered by <a href="https://github.com/NVlabs/InstantSplat" target="_blank" rel="noopener noreferrer">
            InstantSplat
          </a> by NVIDIA Research
        </p>
      </footer>
    </div>
  );
}

export default App;