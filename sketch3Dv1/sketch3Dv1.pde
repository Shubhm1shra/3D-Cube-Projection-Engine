// ─── Constants ────────────────────────────────────────────────────────────────
final color FOREGROUND   = #12FF12;   // lime green — default vertex / edge colour
final color COL_HOVER    = #FF69B4;   // hot pink  — hovered vertex
final color COL_DRAG     = #C2447F;   // dark pink — vertex being dragged
final color BACKGROUND   = 0;
final int   FRAME_RATE   = 60;
final int   POINT_SIZE   = 8;
final float HOVER_RADIUS = 10.0;      // screen-pixel radius for hover hit-test
final float FOV          = PI / 3.0;  // 60° field of view

// ─── Key state ────────────────────────────────────────────────────────────────
boolean keyLeft  = false;
boolean keyRight = false;
boolean keyUp    = false;
boolean keyDown  = false;

final float TURN_SPEED = 1.2;   // radians per second

// ─── Vertex interaction state ─────────────────────────────────────────────────
int   hoveredVertex = -1;   // index of vertex currently under the mouse (-1 = none)
int   draggedVertex = -1;   // index of vertex being dragged              (-1 = none)

// ─── Globals ──────────────────────────────────────────────────────────────────
Cube   cube;
Camera cam;

// ─── Setup / Draw ─────────────────────────────────────────────────────────────
void setup(){
  size(800, 600);
  frameRate(FRAME_RATE);
  cube = new Cube();
  cam  = new Camera();
}

void draw(){
  background(BACKGROUND);

  // Arrow-key rotation
  float delta = TURN_SPEED / FRAME_RATE;
  if (keyLeft)  cam.orbit(-delta, 0);
  if (keyRight) cam.orbit( delta, 0);
  if (keyUp)    cube.rotateX(-delta);
  if (keyDown)  cube.rotateX( delta);

  // Reproject all vertices this frame so hover test uses fresh screen positions
  Point[] screenPts = cube.projectAll(cam);

  // Update hover: find the closest visible vertex to the mouse, within HOVER_RADIUS.
  // If a vertex is being dragged we keep hoveredVertex locked to it.
  if (draggedVertex == -1){
    hoveredVertex = cube.closestVertex(screenPts, mouseX, mouseY);
  } else{
    hoveredVertex = draggedVertex;
  }

  cube.draw(cam, screenPts, hoveredVertex, draggedVertex);
  cam.drawHUD();
}

// ─── Mouse input ──────────────────────────────────────────────────────────────
void mousePressed(){
  // Lock in whichever vertex is currently hovered as the dragged one
  if (hoveredVertex != -1) draggedVertex = hoveredVertex;
}

void mouseReleased(){
  draggedVertex = -1;
}

void mouseDragged(){
  float dx = mouseX - pmouseX;
  float dy = mouseY - pmouseY;

  if (draggedVertex != -1){
    // ── Vertex drag ────────────────────────────────────────────────────────────
    // Unproject the screen delta back into world space at the vertex's depth,
    // then update the vertex position directly in the cube's vertex array.
    cube.dragVertex(draggedVertex, dx, dy, cam);

  } else{
    // ── Camera controls (only when no vertex is grabbed) ──────────────────────
    if (mouseButton == LEFT){
      cam.pan(dx, dy);
    } else if (mouseButton == RIGHT){
      cam.orbit(dx * 0.01, dy * 0.01);
    }
  }
}

void mouseWheel(MouseEvent e){
  cam.dolly(e.getCount() * 0.3);
}

// ─── Key input ────────────────────────────────────────────────────────────────
void keyPressed(){
  if (key == CODED){
    if (keyCode == LEFT)  keyLeft  = true;
    if (keyCode == RIGHT) keyRight = true;
    if (keyCode == UP)    keyUp    = true;
    if (keyCode == DOWN)  keyDown  = true;
  }
}

void keyReleased(){
  if (key == CODED){
    if (keyCode == LEFT)  keyLeft  = false;
    if (keyCode == RIGHT) keyRight = false;
    if (keyCode == UP)    keyUp    = false;
    if (keyCode == DOWN)  keyDown  = false;
  }
}

// ─── Camera Class ─────────────────────────────────────────────────────────────
class Camera{
  float yaw   =  0.5;
  float pitch =  0.0;
  float dist  =  3.0;

  float targetX = 0, targetY = 0, targetZ = 0;

  final float PITCH_LIMIT = PI / 2 - 0.05;
  final float f = 1.0 / tan(FOV / 2.0);

  void pan(float dScreenX, float dScreenY){
    float speed  = dist * 0.001;
    float rightX =  cos(yaw);
    float rightZ = -sin(yaw);
    float upX    = -sin(pitch) * sin(yaw);
    float upY    =  cos(pitch);
    float upZ    = -sin(pitch) * cos(yaw);
    targetX += (-dScreenX * rightX + dScreenY * upX) * speed;
    targetY +=  (dScreenY * upY) * speed;
    targetZ += (-dScreenX * rightZ + dScreenY * upZ) * speed;
  }

  void orbit(float dYaw, float dPitch){
    yaw  += dYaw;
    pitch = constrain(pitch + dPitch, -PITCH_LIMIT, PITCH_LIMIT);
  }

  void dolly(float amount){
    dist = max(0.8, dist + amount);
  }

  Point position(){
    float x = targetX + dist * cos(pitch) * sin(yaw);
    float y = targetY + dist * sin(pitch);
    float z = targetZ + dist * cos(pitch) * cos(yaw);
    return new Point(x, y, z);
  }

  Point worldToCamera(Point world){
    Point eye = position();
    float tx = world.x - eye.x;
    float ty = world.y - eye.y;
    float tz = world.z - eye.z;

    float cy = cos(-yaw), sy = sin(-yaw);
    float rx =  tx * cy + tz * sy;
    float ry =  ty;
    float rz = -tx * sy + tz * cy;

    float cp = cos(pitch), sp = sin(pitch);
    float fx =  rx;
    float fy =  ry * cp + rz * sp;
    float fz = -ry * sp + rz * cp;

    return new Point(fx, fy, fz);
  }

  // Inverse of worldToCamera: camera-local point → world space.
  // Used when unprojecting a dragged screen position back to world coords.
  Point cameraToWorld(Point c){
    // Undo pitch (rotate around X by -pitch)
    float cp = cos(-pitch), sp = sin(-pitch);
    float ux =  c.x;
    float uy =  c.y * cp - c.z * sp;
    float uz =  c.y * sp + c.z * cp;

    // Undo yaw (rotate around Y by +yaw)
    float cy = cos(yaw), sy = sin(yaw);
    float wx =  ux * cy + uz * sy;
    float wy =  uy;
    float wz = -ux * sy + uz * cy;

    // Re-add eye position
    Point eye = position();
    return new Point(wx + eye.x, wy + eye.y, wz + eye.z);
  }

  void drawHUD(){
    fill(FOREGROUND);
    noStroke();
    textSize(13);
    text(String.format("yaw: %.2f  pitch: %.2f  dist: %.2f", yaw, pitch, dist), 10, 20);
    text(String.format("target: (%.2f, %.2f, %.2f)", targetX, targetY, targetZ), 10, 38);
    text("←/→: orbit cam  |  ↑/↓: rotate cube  |  Left-drag: pan  |  Right-drag: orbit  |  Scroll: zoom", 10, height - 12);
  }
}

// ─── Cube Class ───────────────────────────────────────────────────────────────
class Cube{

  Point[] vertices = {
    new Point(-0.5, -0.5,  0.5),  // 0 front-top-left
    new Point(-0.5,  0.5,  0.5),  // 1 front-bottom-left
    new Point( 0.5,  0.5,  0.5),  // 2 front-bottom-right
    new Point( 0.5, -0.5,  0.5),  // 3 front-top-right
    new Point(-0.5, -0.5, -0.5),  // 4 back-top-left
    new Point(-0.5,  0.5, -0.5),  // 5 back-bottom-left
    new Point( 0.5,  0.5, -0.5),  // 6 back-bottom-right
    new Point( 0.5, -0.5, -0.5)   // 7 back-top-right
  };

  int[][] faces = {
    {0, 1, 2, 3},
    {4, 5, 6, 7},
    {0, 4},
    {1, 5},
    {2, 6},
    {3, 7}
  };

  float rotX = 0;

  void rotateX(float angle) { rotX += angle; }

  Point applyRotX(Point p){
    float c = cos(rotX), s = sin(rotX);
    return new Point(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
  }

  // Inverse of applyRotX — used when writing a dragged world position back
  // into the vertex array, which stores pre-rotation coords.
  Point unapplyRotX(Point p){
    float c = cos(-rotX), s = sin(-rotX);
    return new Point(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
  }

  // ── Project all vertices, returning screen-space Points (z = cam depth).
  // Called once per frame; shared by draw() and the hover test.
  Point[] projectAll(Camera cam){
    Point[] pts = new Point[vertices.length];
    for (int i = 0; i < vertices.length; i++){
      Point rotated = applyRotX(vertices[i]);
      Point camPt   = cam.worldToCamera(rotated);
      pts[i]        = toScreen(project(camPt, cam.f));
    }
    return pts;
  }

  // ── Hover hit-test ──────────────────────────────────────────────────────────
  // Returns the index of the closest visible vertex within HOVER_RADIUS of
  // (mx, my), preferring the one nearest the camera (smallest depth = closest).
  // Returns -1 if none qualify.
  int closestVertex(Point[] screenPts, float mx, float my){
    int   best      = -1;
    float bestDepth = Float.MAX_VALUE;
    for (int i = 0; i < screenPts.length; i++){
      Point p = screenPts[i];
      if (p.z <= 0) continue;                        // behind camera
      float d = dist(mx, my, p.x, p.y);
      if (d <= HOVER_RADIUS && p.z < bestDepth){    // within radius and closer?
        best      = i;
        bestDepth = p.z;
      }
    }
    return best;
  }

  // ── Vertex drag ─────────────────────────────────────────────────────────────
  // Converts a screen-space drag delta (dx, dy) into a world-space displacement
  // at the vertex's current camera depth, then stores the result back into the
  // pre-rotation vertex array.
  // Kill me pls
  void dragVertex(int idx, float dx, float dy, Camera cam){
    // 1. Current world position of the vertex (post-rotation)
    Point worldPos = applyRotX(vertices[idx]);

    // 2. Camera-space position, to read the depth
    Point camPos = cam.worldToCamera(worldPos);
    float depth  = -camPos.z;
    if (depth <= 0) return;

    // 3. Unproject screen delta - camera-space displacement at that depth.
    //    Reverse of:  screenX = (ndcX/aspect + 1)/2 * width,  ndcX = f*camX/depth
    float aspect = float(width) / float(height);
    float dCamX  =  (dx / width  * 2.0 * aspect) * depth / cam.f;
    float dCamY  = -(dy / height * 2.0)           * depth / cam.f;  // flip Y yayyy

    // 4. Convert both old and new camera-space positions to world space,
    //    take the difference as a pure world-space displacement.
    Point newCamPos = new Point(camPos.x + dCamX, camPos.y + dCamY, camPos.z);
    Point newWorld  = cam.cameraToWorld(newCamPos);
    Point oldWorld  = cam.cameraToWorld(camPos);

    // 5. Apply displacement to the rotated world position, then un-rotate back
    //    into the vertex array's pre-rotX local space.
    Point movedWorld = new Point(
      worldPos.x + (newWorld.x - oldWorld.x),
      worldPos.y + (newWorld.y - oldWorld.y),
      worldPos.z + (newWorld.z - oldWorld.z)
    );
    vertices[idx] = unapplyRotX(movedWorld);
  }

  // ── Draw ────────────────────────────────────────────────────────────────────
  void draw(Camera cam, Point[] screenPts, int hovered, int dragged) {
    drawEdges(screenPts);
    drawVertices(screenPts, hovered, dragged);
  }

  void drawVertices(Point[] pts, int hovered, int dragged){
    noStroke();
    for (int i = 0; i < pts.length; i++){
      Point p = pts[i];
      if (p.z <= 0) continue;
      if      (i == dragged) fill(COL_DRAG);
      else if (i == hovered) fill(COL_HOVER);
      else                   fill(FOREGROUND);
      rect(p.x - POINT_SIZE / 2, p.y - POINT_SIZE / 2, POINT_SIZE, POINT_SIZE);
    }
  }

  void drawEdges(Point[] pts){
    stroke(FOREGROUND);
    strokeWeight(2);
    noFill();
    for (int[] face : faces){
      int n = face.length;
      for (int i = 0; i < n; i++){
        Point p1 = pts[face[i]];
        Point p2 = pts[face[(i + 1) % n]];
        if (p1.z > 0 && p2.z > 0) line(p1.x, p1.y, p2.x, p2.y);
      }
    }
  }

  // ── Projection helpers ──────────────────────────────────────────────────────
  Point project(Point p, float f){
    float depth = -p.z;
    if (depth <= 0.001) return new Point(-9999, -9999, depth);
    return new Point(f * p.x / depth, f * p.y / depth, depth);
  }

  Point toScreen(Point p){
    float aspect = float(width) / float(height);
    float sx = ( p.x / aspect + 1) / 2.0 * width;
    float sy = (-p.y          + 1) / 2.0 * height;
    return new Point(sx, sy, p.z);
  }
}

// ─── Point Class ──────────────────────────────────────────────────────────────
class Point{
  float x, y, z;
  Point()                         { x = 0;    y = 0;    z = 0; }
  Point(float x, float y)         { this.x=x; this.y=y; this.z=1; }
  Point(float x, float y, float z){ this.x=x; this.y=y; this.z=z; }
}
