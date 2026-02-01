import React, { useEffect, useRef, useState } from 'react';
import { useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { PLYLoader } from 'three/examples/jsm/loaders/PLYLoader';

function GaussianSplatViewer({ plyUrl }) {
  const { scene } = useThree();
  const meshRef = useRef();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!plyUrl) return;

    const loader = new PLYLoader();
    
    loader.load(
      plyUrl,
      (geometry) => {
        try {
          // Clear previous mesh
          if (meshRef.current) {
            scene.remove(meshRef.current);
            meshRef.current.geometry.dispose();
            meshRef.current.material.dispose();
          }

          // Center and scale geometry
          geometry.computeBoundingBox();
          const center = new THREE.Vector3();
          geometry.boundingBox.getCenter(center);
          geometry.translate(-center.x, -center.y, -center.z);

          // Compute vertex normals for better lighting
          geometry.computeVertexNormals();

          // Create material
          const material = new THREE.PointsMaterial({
            size: 0.01,
            vertexColors: true,
            sizeAttenuation: true,
          });

          // Check if we have colors
          if (!geometry.attributes.color) {
            material.color.setHex(0x888888);
          }

          // Create points mesh
          const points = new THREE.Points(geometry, material);
          meshRef.current = points;
          scene.add(points);
          
          setLoading(false);
        } catch (err) {
          console.error('Error processing geometry:', err);
          setError('Failed to render 3D model');
          setLoading(false);
        }
      },
      (progress) => {
        console.log('Loading:', (progress.loaded / progress.total * 100).toFixed(2) + '%');
      },
      (error) => {
        console.error('Error loading PLY:', error);
        setError('Failed to load PLY file');
        setLoading(false);
      }
    );

    // Cleanup
    return () => {
      if (meshRef.current) {
        scene.remove(meshRef.current);
        if (meshRef.current.geometry) {
          meshRef.current.geometry.dispose();
        }
        if (meshRef.current.material) {
          meshRef.current.material.dispose();
        }
      }
    };
  }, [plyUrl, scene]);

  if (loading) {
    return null; // Loading handled by parent
  }

  if (error) {
    return null; // Error handled by parent
  }

  return null; // Mesh is added directly to scene
}

export default GaussianSplatViewer;