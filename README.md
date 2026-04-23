# 3D-Cube-Projection-Engine

A lightweight, from-scratch implementation of a 3D environment in Processing. This project bypasses built-in 3D libraries (like P3D) to manually handle the mathematics of perspective projection, camera transformations, and vertex manipulation.

## 🚀 Overview
This engine simulates a 3D wireframe cube that users can interact with in real-time. It serves as a practical exploration of computer graphics fundamentals, specifically the **Pinhole Camera Model**.

## ✨ Features
- **Manual Projection Math**: Calculates 3D points to 2D screen coordinates using focal length and aspect ratio adjustments.
- **Interactive Vertex Dragging**: Includes logic to "unproject" a 2D mouse drag back into 3D world space at the correct depth.
- **Full Camera System**:
  - **Orbit**: Rotate around the center of the world.
  - **Pan**: Move the camera view laterally.
  - **Dolly**: Smooth zooming using the mouse wheel.
- **Z-Buffer Depth Testing**: Interactive elements (like hovering over a vertex) prioritize the point closest to the camera.

## 📐 Mathematical Concepts Used
- **Rotation Matrices**: Implementing $R_x$ rotations for the object.
- **Coordinate Spaces**: Handling transitions between Local Space, World Space, Camera Space, and Screen Space.
- **Inverse Transformations**: Using inverse matrices to allow screen-based interaction to affect 3D data.

## 🎬 Demo 
![Demo Video](media/sketch3Dv1-trial-1.gif)

## 📥 Installation
1. Download and install [Processing](https://processing.org/).
2. Clone this repository.
3. Open `sketch3Dv1.pde` in the Processing IDE and hit **Run**.
