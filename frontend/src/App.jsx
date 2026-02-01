import React, { useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, PerspectiveCamera } from '@react-three/drei';
import GaussianSplatViewer from './components/GaussianSplatViewer';
import ImageUpload from './components/ImageUpload';
import './App.css';

function App() {
  const [plyFile, setPlyFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [uploadedImages, setUploadedImages] = useState([]);
  const [iterations, setIterations] = useState(1000);
  const [progress, setProgress] = useState('');

  const handleImagesSelected = async (images) => {
    setUploadedImages(images);
    setError(null);
    setLoading(true);
    setPlyFile(null);
    setProgress('Uploading images...');

    try {
      // Create FormData
      const formData = new FormData();
      images.forEach((image) => {
        formData.append('files', image);
      });

      setProgress('Processing with InstantSplat...');

      // Send to FastAPI backend
      const response = await fetch(
        `http://localhost:8000/api/generate-splat?iterations=${iterations}`,
        {
          method: 'POST',
          body: formData,
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to generate Gaussian Splat');
      }

      setProgress('Downloading result...');

      // Get the PLY file
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      setPlyFile(url);
      setProgress('');
      
    } catch (err) {
      console.error('Error:', err);
      setError(err.message);
      setProgress('');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setPlyFile(null);
    setUploadedImages([]);
    setError(null);
    setProgress('');
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>⚡ InstantSplat - Sparse-View 3D Reconstruction</h1>
        <p>Upload 3-20 smartphone photos • Fast SfM-free reconstruction</p>
      </header>

      <main className="app-main">
        {!plyFile && !loading && (
          <>
            <ImageUpload 
              onImagesSelected={handleImagesSelected}
              maxImages={20}
              minImages={3}
            />
            
            <div className="settings-panel">
              <h3>Processing Settings</h3>
              <div className="setting-group">
                <label htmlFor="iterations">
                  Training Iterations: {iterations}
                  <span className="setting-hint">
                    (1000 = Fast ~40s, 3000 = Better quality ~2min, 5000 = Best ~3min)
                  </span>
                </label>
                <input
                  id="iterations"
                  type="range"
                  min="500"
                  max="5000"
                  step="500"
                  value={iterations}
                  onChange={(e) => setIterations(parseInt(e.target.value))}
                  className="slider"
                />
              </div>
            </div>
          </>
        )}

        {loading && (
          <div className="loading-container">
            <div className="spinner"></div>
            <p className="loading-text">{progress}</p>
            <p className="loading-subtitle">
              Estimated time: ~{Math.round(iterations / 20)}s
            </p>
            <div className="progress-info">
              <p>📸 Images: {uploadedImages.length}</p>
              <p>🔄 Iterations: {iterations}</p>
            </div>
          </div>
        )}

        {error && (
          <div className="error-container">
            <h3>❌ Error</h3>
            <p>{error}</p>
            <button onClick={handleReset} className="btn-reset">
              Try Again
            </button>
          </div>
        )}

        {plyFile && (
          <div className="viewer-container">
            <div className="viewer-controls">
              <button onClick={handleReset} className="btn-reset">
                Upload New Images
              </button>
              <a 
                href={plyFile} 
                download="instantsplat_scene.ply"
                className="btn-download"
              >
                Download PLY
              </a>
            </div>
            
            <div className="viewer-canvas">
              <Canvas>
                <PerspectiveCamera makeDefault position={[0, 0, 5]} />
                <OrbitControls 
                  enableDamping 
                  dampingFactor={0.05}
                  minDistance={1}
                  maxDistance={20}
                />
                <ambientLight intensity={0.5} />
                <pointLight position={[10, 10, 10]} />
                <GaussianSplatViewer plyUrl={plyFile} />
              </Canvas>
            </div>

            <div className="viewer-info">
              <p>🖱️ Left click + drag to rotate</p>
              <p>🖱️ Right click + drag to pan</p>
              <p>🖱️ Scroll to zoom</p>
            </div>
          </div>
        )}
      </main>

      <footer className="app-footer">
        <p>Powered by InstantSplat (NVlabs) | FastAPI | React | Three.js</p>
      </footer>
    </div>
  );
}

export default App;