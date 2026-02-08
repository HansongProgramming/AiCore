import React, { useState, useRef, useEffect } from 'react';
import './ImageUpload.css';

function ImageUpload({ onImagesSelected, minImages = 3, maxImages = 10 }) {
  const [previews, setPreviews] = useState([]);
  const [dragActive, setDragActive] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);
  const [healthStatus, setHealthStatus] = useState(null);
  const [sessionId, setSessionId] = useState(null);
  const [isCheckingHealth, setIsCheckingHealth] = useState(true);
  const fileInputRef = useRef(null);
  const [selectedFiles, setSelectedFiles] = useState([]);

  // Check backend health on mount and retry if needed
  useEffect(() => {
    let retries = 0;
    const maxRetries = 3;
    
    const checkWithRetry = async () => {
      setIsCheckingHealth(true);
      
      while (retries < maxRetries) {
        try {
          const response = await fetch('http://localhost:8000/health', {
            method: 'GET',
            headers: {
              'Accept': 'application/json',
            },
          });
          
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
          }
          
          const data = await response.json();
          setHealthStatus(data);
          setIsCheckingHealth(false);
          
          if (!data.instantsplat_installed) {
            setError({
              message: 'InstantSplat not properly installed. Please run setup.bat',
              details: data.checks
            });
          } else {
            // Clear any previous errors if backend is now healthy
            setError(null);
          }
          
          return; // Success, exit
          
        } catch (err) {
          retries++;
          console.log(`Health check attempt ${retries} failed:`, err.message);
          
          if (retries < maxRetries) {
            // Wait 1 second before retrying
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        }
      }
      
      // All retries failed
      setIsCheckingHealth(false);
      setError({
        message: 'Cannot connect to backend',
        details: 'Make sure the backend server is running on http://localhost:8000'
      });
    };
    
    checkWithRetry();
  }, []);

  const handleFiles = (files) => {
    const fileArray = Array.from(files);
    
    // Clear previous errors
    setError(null);
    
    // Validate file count
    if (fileArray.length < minImages) {
      setError({
        message: `Please select at least ${minImages} images`
      });
      return;
    }
    
    if (fileArray.length > maxImages) {
      setError({
        message: `Maximum ${maxImages} images allowed`
      });
      return;
    }

    // Validate file types
    const validFiles = fileArray.filter(file => 
      file.type.startsWith('image/')
    );

    if (validFiles.length !== fileArray.length) {
      setError({
        message: 'Please select only image files (JPG, PNG, etc.)'
      });
      return;
    }

    // Create previews
    const previewUrls = validFiles.map(file => URL.createObjectURL(file));
    setPreviews(previewUrls);
    setSelectedFiles(validFiles);

    // Send to parent if provided
    if (onImagesSelected) {
      onImagesSelected(validFiles);
    }
  };

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFiles(e.dataTransfer.files);
    }
  };

  const handleChange = (e) => {
    e.preventDefault();
    if (e.target.files && e.target.files.length > 0) {
      handleFiles(e.target.files);
    }
  };

  const handleButtonClick = (e) => {
    e.stopPropagation();
    fileInputRef.current?.click();
  };

  const handleUploadAndReconstruct = async () => {
    if (selectedFiles.length < minImages) {
      setError({
        message: `Please select at least ${minImages} images`
      });
      return;
    }

    setUploading(true);
    setError(null);

    const formData = new FormData();
    selectedFiles.forEach(file => {
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
      await handleReconstruct(data.session_id);
      
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
      
      // Trigger download
      window.open(downloadUrl, '_blank');
      
      // Show success message
      setError({
        message: '✓ Success! Your 3D model is ready and downloading.',
        isSuccess: true
      });
      
    } catch (err) {
      setError({
        message: 'Reconstruction failed',
        details: err.message
      });
      setProcessing(false);
    }
  };

  const renderHealthStatus = () => {
    if (isCheckingHealth) {
      return (
        <div className="health-status checking">
          <div className="health-indicator">
            <span className="status-dot status-checking"></span>
            <span className="status-text">Connecting to backend...</span>
          </div>
        </div>
      );
    }

    if (!healthStatus) return null;

    const isOk = healthStatus.status === 'ok';
    
    return (
      <div className={`health-status ${healthStatus.status}`}>
        <div className="health-indicator">
          <span className={`status-dot ${isOk ? 'status-ok' : 'status-error'}`}></span>
          <span className="status-text">
            Backend: {isOk ? 'Ready ✓' : 'Not Ready ✗'}
          </span>
        </div>
        {!isOk && healthStatus.checks && (
          <details className="health-details">
            <summary>Show Details</summary>
            <ul>
              {Object.entries(healthStatus.checks).map(([key, value]) => (
                <li key={key} className={value ? 'check-ok' : 'check-fail'}>
                  {value ? '✓' : '✗'} {key.replace(/_/g, ' ')}
                </li>
              ))}
            </ul>
          </details>
        )}
      </div>
    );
  };

  const renderError = () => {
    if (!error) return null;

    return (
      <div className={`error-box ${error.isSuccess ? 'success-box' : ''}`}>
        <p className="error-message">{error.message}</p>
        {error.details && typeof error.details === 'object' && (
          <details className="error-details">
            <summary>Technical Details</summary>
            <pre>{JSON.stringify(error.details, null, 2)}</pre>
          </details>
        )}
        {error.details && typeof error.details === 'string' && (
          <p className="error-details-text">{error.details}</p>
        )}
      </div>
    );
  };

  return (
    <div className="image-upload">
      {renderHealthStatus()}
      {renderError()}
      
      <div
        className={`upload-dropzone ${dragActive ? 'drag-active' : ''} ${uploading || processing ? 'disabled' : ''}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        onClick={!uploading && !processing ? handleButtonClick : undefined}
      >
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/*"
          onChange={handleChange}
          style={{ display: 'none' }}
          disabled={uploading || processing}
        />
        
        <div className="upload-content">
          <div className="upload-icon">📷</div>
          <h3>Upload Your Photos</h3>
          <p>Drag and drop {minImages}-{maxImages} images here</p>
          <p className="upload-or">or</p>
          <button 
            className="btn-select"
            onClick={handleButtonClick}
            disabled={uploading || processing}
          >
            Select Files
          </button>
        </div>
      </div>

      {previews.length > 0 && (
        <div className="preview-grid">
          <h4>Selected Images ({previews.length})</h4>
          <div className="preview-images">
            {previews.map((preview, index) => (
              <div key={index} className="preview-item">
                <img src={preview} alt={`Preview ${index + 1}`} />
              </div>
            ))}
          </div>
          
          <button
            className="btn-reconstruct"
            onClick={handleUploadAndReconstruct}
            disabled={uploading || processing || selectedFiles.length < minImages}
          >
            {uploading && '⏳ Uploading...'}
            {processing && '🔄 Processing (this may take a few minutes)...'}
            {!uploading && !processing && '🚀 Upload & Reconstruct 3D Model'}
          </button>
          
          <div className="upload-info">
            <p>💡 Tips for best results:</p>
            <ul>
              <li>Take photos from different angles around your object</li>
              <li>Ensure good lighting and minimal blur</li>
              <li>Include overlapping views between consecutive photos</li>
              <li>Processing typically takes 2-5 minutes</li>
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}

export default ImageUpload;