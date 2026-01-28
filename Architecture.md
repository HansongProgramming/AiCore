# 🏗️ System Architecture

## 📐 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ELECTRON DESKTOP APP                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    REACT FRONTEND                      │  │
│  │  ┌──────────────┐  ┌─────────────────────────────┐   │  │
│  │  │   Image      │  │     Three.js Viewer         │   │  │
│  │  │   Upload     │  │  ┌───────────────────────┐  │   │  │
│  │  │  Component   │  │  │ GaussianSplatViewer   │  │   │  │
│  │  └──────────────┘  │  │  - OrbitControls      │  │   │  │
│  │         │          │  │  - PLYLoader          │  │   │  │
│  │         │          │  │  - PointsMaterial     │  │   │  │
│  │         ▼          │  └───────────────────────┘  │   │  │
│  │  ┌──────────────┐  └─────────────────────────────┘   │  │
│  │  │  API Client  │                                     │  │
│  │  └──────────────┘                                     │  │
│  └───────────┬───────────────────────────────────────────┘  │
│              │ HTTP/REST                                     │
└──────────────┼───────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     FASTAPI BACKEND                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  API Endpoints                         │  │
│  │  • POST /api/generate-splat (Upload images)           │  │
│  │  • GET  /health              (Health check)           │  │
│  │  • GET  /api/outputs/:id     (Download result)        │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                     │
│  ┌─────────────────────▼─────────────────────────────────┐  │
│  │              Processing Pipeline                       │  │
│  │  1. Receive images                                    │  │
│  │  2. Validate & Save temporarily                       │  │
│  │  3. Load with dust3r.utils                           │  │
│  │  4. Run Splatt3R inference                           │  │
│  │  5. Export to .ply                                    │  │
│  │  6. Return file                                       │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                     │
│  ┌─────────────────────▼─────────────────────────────────┐  │
│  │                 Splatt3R Model                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  MASt3R Encoder (Frozen ViT)                    │  │  │
│  │  │  • Encode both input images                     │  │  │
│  │  │  • Cross-attention between views                │  │  │
│  │  └─────────────────┬───────────────────────────────┘  │  │
│  │                    │                                   │  │
│  │  ┌─────────────────▼───────────────────────────────┐  │  │
│  │  │  Gaussian Prediction Head                        │  │  │
│  │  │  • 3D positions                                  │  │  │
│  │  │  • Spherical harmonics (color)                   │  │  │
│  │  │  • Rotations (quaternions)                       │  │  │
│  │  │  • Scales (3D)                                   │  │  │
│  │  │  • Opacities                                     │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Model Management                          │  │
│  │  • HuggingFace Hub download                           │  │
│  │  • Checkpoint: brandonsmart/splatt3r_v1.0            │  │
│  │  • CUDA/CPU device management                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### 1. Image Upload Flow

```
User
  │
  │ 1. Select 2-10 images
  ▼
ImageUpload Component
  │
  │ 2. Validate (type, count)
  │ 3. Create previews
  ▼
FormData Creation
  │
  │ 4. Append files
  ▼
HTTP POST /api/generate-splat
  │
  │ 5. Send to backend
  ▼
FastAPI Endpoint
  │
  │ 6. Receive multipart/form-data
  ▼
Temporary Storage
  │
  │ 7. Save images to temp directory
  ▼
Image Loading (dust3r)
  │
  │ 8. Load & resize to 512x512
  ▼
Splatt3R Inference
  │
  │ 9. Model prediction (30-60s)
  ▼
PLY Export
  │
  │ 10. Write to outputs/
  ▼
FileResponse
  │
  │ 11. Stream .ply back to client
  ▼
Browser Download
  │
  │ 12. Create blob URL
  ▼
GaussianSplatViewer
  │
  │ 13. Load with PLYLoader
  │ 14. Render with Three.js
  ▼
User sees 3D model
```

### 2. Model Initialization Flow

```
Backend Startup
  │
  ▼
load_splatt3r_model()
  │
  │ Check if model loaded
  ▼
HuggingFace Hub
  │
  │ hf_hub_download()
  │ Repo: brandonsmart/splatt3r_v1.0
  │ File: epoch=19-step=1200.ckpt
  ▼
Download Checkpoint (~1.5GB)
  │
  │ Cache: ~/.cache/huggingface/
  ▼
Load Model
  │
  │ MAST3RGaussians.load_from_checkpoint()
  ▼
Move to Device
  │
  │ CUDA if available, else CPU
  ▼
Set Eval Mode
  │
  │ model.eval()
  ▼
Ready for Inference
```

## 🧩 Component Details

### Backend Components

#### 1. FastAPI Application (`main.py`)
```python
Responsibilities:
- HTTP endpoint handling
- CORS configuration
- File upload management
- Model initialization
- Response formatting

Key Functions:
- startup_event(): Load model on start
- generate_splat(): Main processing endpoint
- health_check(): Status monitoring
```

#### 2. Splatt3R Integration
```python
Components:
- main.MAST3RGaussians: Core model
- dust3r.utils.image.load_images: Image loader
- export.export_to_ply: File exporter

Model Architecture:
- Encoder: Frozen MASt3R ViT
- Decoder: Gaussian prediction head
- Output: 3D Gaussians per pixel
```

### Frontend Components

#### 1. App Component (`App.jsx`)
```javascript
State Management:
- plyFile: URL to loaded .ply
- loading: Processing status
- error: Error messages
- uploadedImages: Selected files

Key Functions:
- handleImagesSelected(): Upload to API
- handleReset(): Clear state
```

#### 2. ImageUpload Component
```javascript
Features:
- Drag & drop support
- File validation
- Preview generation
- Count validation (2-10 images)

Events:
- onDrag: Visual feedback
- onDrop: Handle file drop
- onChange: Handle file selection
```

#### 3. GaussianSplatViewer Component
```javascript
Three.js Integration:
- PLYLoader: Load .ply files
- PointsMaterial: Render points
- OrbitControls: Camera control

Processing:
- Geometry centering
- Normal computation
- Color handling
```

### Electron Components

#### 1. Main Process (`main.js`)
```javascript
Responsibilities:
- Window management
- Backend process spawning
- IPC communication
- Lifecycle management

Functions:
- startBackend(): Launch Python server
- createWindow(): Initialize BrowserWindow
- Cleanup: Kill processes on quit
```

#### 2. Preload Script (`preload.js`)
```javascript
Security:
- Context isolation
- Limited API exposure
- Safe IPC communication
```

## 🔐 Security Considerations

### Backend
- ✅ File type validation
- ✅ File size limits (implicit via multipart)
- ✅ Temporary file cleanup
- ✅ CORS configuration
- ⚠️ TODO: Rate limiting
- ⚠️ TODO: Authentication

### Frontend
- ✅ Client-side validation
- ✅ File type checking
- ✅ Count validation
- ⚠️ TODO: File size validation
- ⚠️ TODO: Progress indicators

### Electron
- ✅ Context isolation
- ✅ No nodeIntegration
- ✅ Preload script
- ⚠️ TODO: CSP headers
- ⚠️ TODO: Auto-updates

## 📊 Performance Optimization

### Backend
- Model singleton (load once)
- GPU utilization
- Async file operations
- Connection pooling

### Frontend
- React memoization
- Three.js instance reuse
- Blob URL management
- Lazy loading

### Electron
- Window preloading
- Backend health checks
- Graceful shutdown

## 🚀 Scalability Considerations

### Current (Single User)
```
User → Electron → FastAPI → Splatt3R → Response
(Local processing)
```

### Production (Multi-User)
```
Users → Load Balancer → FastAPI Cluster
                           ↓
                     Job Queue (Celery)
                           ↓
                     Worker Nodes (GPU)
                           ↓
                     Object Storage (S3)
```

### Cloud Deployment Architecture
```
┌────────────┐
│   Users    │
└─────┬──────┘
      │
      ▼
┌─────────────────┐
│  CloudFront CDN │ (React Static Files)
└─────┬───────────┘
      │
      ▼
┌─────────────────┐
│   API Gateway   │
└─────┬───────────┘
      │
      ▼
┌─────────────────┐
│  ECS/K8s Cluster│
│  ┌───────────┐  │
│  │  FastAPI  │  │
│  │  Workers  │  │
│  └─────┬─────┘  │
└────────┼────────┘
         │
         ▼
┌─────────────────┐
│  EC2 GPU Nodes  │
│  (Splatt3R)     │
└─────┬───────────┘
      │
      ▼
┌─────────────────┐
│   S3 Storage    │
│  (.ply outputs) │
└─────────────────┘
```
## 📈 Monitoring & Logging

### Metrics to Track
- Request latency
- Processing time
- Error rates
- GPU utilization
- Memory usage
- Queue depth

### Logging Points
- Image upload
- Model inference start/end
- Export success/failure
- API errors
- Health checks

## 🔧 Configuration

### Environment Variables
```bash
# Backend
DEVICE=cuda              # or 'cpu'
MODEL_PATH=checkpoints/
OUTPUT_DIR=outputs/
MAX_IMAGES=10
IMAGE_SIZE=512

# Frontend
REACT_APP_API_URL=http://localhost:8000
REACT_APP_MAX_FILE_SIZE=10485760  # 10MB

# Electron
NODE_ENV=production
BACKEND_PORT=8000
```

---

This architecture provides:
- ✅ Separation of concerns
- ✅ Scalability path
- ✅ Security boundaries
- ✅ Performance optimization
- ✅ Maintainability
- ✅ Clear data flow