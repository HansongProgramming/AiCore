import { useState } from 'react';
import './ImageUpload.css';

function ImageUpload({ onUploadComplete }) {
  const [files, setFiles] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);
  const [sessionId, setSessionId] = useState(null);
  const [healthStatus, setHealthStatus] = useState(null);

  // Check backend health on mount
  useState(() => {
    checkHealth();
  }, []);

  const checkHealth = async () => {
    try {
      const response = await fetch('http://localhost:8000/health');
      const data = await response.json();
      setHealthStatus(data);
      
      if (!data.instantsplat_installed) {
        setError({
          message: 'InstantSplat not properly installed',
          details: data.checks
        });
      }
    } catch (err) {
      setError({
        message: 'Cannot connect to backend',
        details: err.message
      });
    }
  };

  const handleFileChange = (e) => {
    const selectedFiles = Array.from(e.target.files);
    
    // Validate file types
    const validFiles = selectedFiles.filter(file => 
      file.type.startsWith('image/')
    );
    
    if (validFiles.length !== selectedFiles.length) {
      setError({
        message: 'Some files were not images and were skipped'
      });
    }
    
    setFiles(validFiles);
    setError(null);
  };

  const handleUpload = async () => {
    if (files.length < 3) {
      setError({
        message: 'Please select at least 3 images'
      });
      return;
    }

    setUploading(true);
    setError(null);

    const formData = new FormData();
    files.forEach(file => {
      formData.append('files', file);
    });

    try {
      const response = await fetch('http://localhost:8000/upload', {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail?.error || errorData.detail || 'Upload failed');
      }

      const data = await response.json();
      setSessionId(data.session_id);
      setUploading(false);
      
      // Start reconstruction
      handleReconstruct(data.session_id);
      
    } catch (err) {
      setError({
        message: 'Upload failed',
        details: err.message
      });
      setUploading(false);
    }
  };

  const handleReconstruct = async (sid) => {
    setProcessing(true);
    setError(null);

    try {
      const response = await fetch(`http://localhost:8000/reconstruct/${sid}`, {
        method: 'POST',
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail?.error || errorData.detail || 'Reconstruction failed');
      }

      const data = await response.json();
      
      // Download the result
      const downloadUrl = `http://localhost:8000/download/${sid}/${data.output_file}`;
      setProcessing(false);
      
      if (onUploadComplete) {
        onUploadComplete(downloadUrl);
      }
      
    } catch (err) {
      setError({
        message: 'Reconstruction failed',
        details: err.message
      });
      setProcessing(false);
    }
  };

  const renderError = () => {
    if (!error) return null;

    return (
      <div className="error-box">
        <h3>❌ Error</h3>
        <p>{error.message}</p>
        {error.details && typeof error.details === 'object' && (
          <details>
            <summary>Details</summary>
            <pre>{JSON.stringify(error.details, null, 2)}</pre>
          </details>
        )}
        {error.details && typeof error.details === 'string' && (
          <p className="error-details">{error.details}</p>
        )}
      </div>
    );
  };

  const renderHealthStatus = () => {
    if (!healthStatus) return null;

    return (
      <div className={`health-status ${healthStatus.status}`}>
        <h4>Backend Status: {healthStatus.status === 'ok' ? '✓' : '✗'}</h4>
        {healthStatus.checks && (
          <details>
            <summary>Installation Details</summary>
            <ul>
              {Object.entries(healthStatus.checks).map(([key, value]) => (
                <li key={key}>
                  {value ? '✓' : '✗'} {key}: {value ? 'OK' : 'Missing'}
                </li>
              ))}
            </ul>
          </details>
        )}
      </div>
    );
  };

  return (
    <div className="upload-container">
      <h2>Upload Images for 3D Reconstruction</h2>
      
      {renderHealthStatus()}
      {renderError()}
      
      <div className="upload-section">
        <input
          type="file"
          multiple
          accept="image/*"
          onChange={handleFileChange}
          disabled={uploading || processing}
        />
        
        {files.length > 0 && (
          <div className="file-list">
            <h3>Selected Files ({files.length}):</h3>
            <ul>
              {files.map((file, index) => (
                <li key={index}>
                  {file.name} ({(file.size / 1024 / 1024).toFixed(2)} MB)
                </li>
              ))}
            </ul>
          </div>
        )}
        
        <button
          onClick={handleUpload}
          disabled={files.length < 3 || uploading || processing}
          className="upload-button"
        >
          {uploading && 'Uploading...'}
          {processing && 'Processing (this may take a few minutes)...'}
          {!uploading && !processing && 'Upload & Reconstruct'}
        </button>
        
        {files.length > 0 && files.length < 3 && (
          <p className="warning">Please select at least 3 images</p>
        )}
      </div>
      
      <div className="instructions">
        <h3>Instructions:</h3>
        <ul>
          <li>Select at least 3 images of the same object/scene from different angles</li>
          <li>Images should have good overlap between views</li>
          <li>Better coverage = better 3D reconstruction</li>
          <li>Processing typically takes 2-5 minutes depending on image count</li>
        </ul>
      </div>
    </div>
  );
}

export default ImageUpload;