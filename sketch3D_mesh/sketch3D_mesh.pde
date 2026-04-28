// ─── Constants ────────────────────────────────────────────────────────────────
final color FOREGROUND   = #12FF12;   // lime green — default vertex / edge colour
final color COL_HOVER    = #FF69B4;   // hot pink   — hovered vertex
final color COL_DRAG     = #C2447F;   // dark pink  — vertex being dragged
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
int hoveredVertex = -1;
int draggedVertex = -1;

// ─── Globals ──────────────────────────────────────────────────────────────────
Mesh   mesh;
Camera cam;

// ─── Setup / Draw ─────────────────────────────────────────────────────────────
void setup(){
  size(800, 600);
  frameRate(FRAME_RATE);
  cam  = new Camera();

  // ── Load a mesh from the sketch's data/ folder.
  // Drop any .obj file there and change the filename to switch models.
  mesh = loadOBJ("cylinder.obj");

  // Fallback: if the file is missing, build the same unit cube in code
  // so the sketch never starts with a blank screen.
  if (mesh == null){
    println("cube.obj not found in data/ — using built-in fallback cube.");
    mesh = fallbackCube();
  }
}

void draw(){
  background(BACKGROUND);

  float delta = TURN_SPEED / FRAME_RATE;
  if (keyLeft)  cam.orbit(delta, 0);
  if (keyRight) cam.orbit(-delta, 0);
  if (keyUp)    mesh.rotateX(-delta);
  if (keyDown)  mesh.rotateX( delta);

  Point[] screenPts = mesh.projectAll(cam);

  if (draggedVertex == -1){
    hoveredVertex = mesh.closestVertex(screenPts, mouseX, mouseY);
  } else{
    hoveredVertex = draggedVertex;
  }

  mesh.draw(cam, screenPts, hoveredVertex, draggedVertex);
  cam.drawHUD(mesh.sourceName);
}

// ─── Mouse input ──────────────────────────────────────────────────────────────
void mousePressed(){
  if (hoveredVertex != -1) draggedVertex = hoveredVertex;
}

void mouseReleased(){
  draggedVertex = -1;
}

void mouseDragged(){
  float dx = mouseX - pmouseX;
  float dy = mouseY - pmouseY;

  if (draggedVertex != -1){
    mesh.dragVertex(draggedVertex, dx, dy, cam);
  } else{
    if      (mouseButton == LEFT)  cam.pan(dx, dy);
    else if (mouseButton == RIGHT) cam.orbit(dx * 0.01, dy * 0.01);
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

// ═══════════════════════════════════════════════════════════════════════════════
// ─── OBJ Loader ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
//
// Reads a Wavefront .obj file from the sketch's data/ folder and returns a
// Mesh.  Only geometry is parsed — normals, UVs, materials are ignored.
//
// https://funprogramming.org/152-Exporting-3D-shapes-as-obj-files-in-Processing.html <-- for future project reference
//
// Supported face syntaxes (OBJ is 1-indexed; we subtract 1):
//   f v1 v2 v3          (triangle, indices only)
//   f v1/t1 v2/t2 ...   (with texture coords — t ignored)
//   f v1/t1/n1 ...      (with normals — t and n ignored)
//   f v1//n1 ...        (with normals, no UVs — n ignored)
// Faces may have any number of vertices (tri, quad, n-gon).
//
// Returns null if the file cannot be opened, so the caller can fall back
// gracefully.

Mesh loadOBJ(String filename){
  String[] lines = loadStrings(filename);   // looks in data/ automatically
  if (lines == null) return null;

  ArrayList<Point>  verts = new ArrayList<Point>();
  ArrayList<int[]>  faces = new ArrayList<int[]>();

  for (String raw : lines){
    String line = trim(raw);

    // ── Vertex line: "v x y z [w]"
    if (line.startsWith("v ")){
      String[] tok = splitTokens(line.substring(2));
      if (tok.length >= 3){
        verts.add(new Point(float(tok[0]), float(tok[1]), float(tok[2])));
      }

    // ── Face line: "f i[/j[/k]] i[/j[/k]] ..."
    } else if (line.startsWith("f ")){
      String[] tok  = splitTokens(line.substring(2));
      int[]    face = new int[tok.length];
      for (int i = 0; i < tok.length; i++){
        // Take only the part before the first '/' for the vertex index
        String vi = split(tok[i], '/')[0];
        face[i] = int(vi) - 1;   // OBJ is 1-based → 0-based
      }
      faces.add(face);
    }
    // Lines starting with #, vn, vt, usemtl, mtllib, o, g, s — all ignored
  }

  if (verts.size() == 0){
    println("loadOBJ: no vertices found in " + filename);
    return null;
  }

  // Convert ArrayLists to plain arrays for the Mesh constructor
  Point[] va = verts.toArray(new Point[0]);
  int[][] fa = faces.toArray(new int[0][]);

  println("loadOBJ: loaded " + filename + " — "+ va.length + " vertices, " + fa.length + " faces.");
  return new Mesh(va, fa, filename);
}

// ─── Built-in fallback cube ───────────────────────────────────────────────────
// Identical geometry to the original Cube class, used when no .obj is found.
// Using that default stupid cube
Mesh fallbackCube(){
  Point[] v = {
    new Point(-0.5, -0.5,  0.5),
    new Point(-0.5,  0.5,  0.5),
    new Point( 0.5,  0.5,  0.5),
    new Point( 0.5, -0.5,  0.5),
    new Point(-0.5, -0.5, -0.5),
    new Point(-0.5,  0.5, -0.5),
    new Point( 0.5,  0.5, -0.5),
    new Point( 0.5, -0.5, -0.5)
  };
  int[][] f = {
    {0,1,2,3}, {4,5,6,7},
    {0,4}, {1,5}, {2,6}, {3,7}
  };
  return new Mesh(v, f, "fallback cube");
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── Camera Class ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
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
    targetY +=  ( dScreenY * upY) * speed;
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
    return new Point(
      targetX + dist * cos(pitch) * sin(yaw),
      targetY + dist * sin(pitch),
      targetZ + dist * cos(pitch) * cos(yaw)
    );
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
    return new Point(rx, ry * cp + rz * sp, -ry * sp + rz * cp);
  }

  Point cameraToWorld(Point c){
    float cp = cos(-pitch), sp = sin(-pitch);
    float ux = c.x;
    float uy = c.y * cp - c.z * sp;
    float uz = c.y * sp + c.z * cp;

    float cy = cos(yaw), sy = sin(yaw);
    float wx =  ux * cy + uz * sy;
    float wy =  uy;
    float wz = -ux * sy + uz * cy;

    Point eye = position();
    return new Point(wx + eye.x, wy + eye.y, wz + eye.z);
  }

  void drawHUD(String modelName){
    fill(FOREGROUND);
    noStroke();
    textSize(13);
    text("model: " + modelName, 10, 20);
    text(String.format("yaw: %.2f  pitch: %.2f  dist: %.2f", yaw, pitch, dist), 10, 38);
    text(String.format("target: (%.2f, %.2f, %.2f)", targetX, targetY, targetZ), 10, 56);
    text("←/→: orbit cam  |  ↑/↓: rotate mesh  |  Left-drag: pan  |  Right-drag: orbit  |  Scroll: zoom",
         10, height - 12);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── Mesh Class  (generalised replacement for Cube) ───────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
// Gods of code, make mesh work... pls
class Mesh{

  Point[]  vertices;   // mutable — drag edits these directly
  int[][]  faces;      // index lists; any polygon size supported
  String   sourceName; // filename or "fallback cube" — shown in HUD
  float    rotX = 0;

  Mesh(Point[] vertices, int[][] faces, String sourceName){
    this.vertices   = vertices;
    this.faces      = faces;
    this.sourceName = sourceName;
  }

  // ── Rotation ────────────────────────────────────────────────────────────────
  void rotateX(float angle) { rotX += angle; }

  Point applyRotX(Point p){
    float c = cos(rotX), s = sin(rotX);
    return new Point(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
  }

  Point unapplyRotX(Point p){
    float c = cos(-rotX), s = sin(-rotX);
    return new Point(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
  }

  // ── Projection ──────────────────────────────────────────────────────────────
  // Returns screen-space Points with z = camera depth.
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

  // ── Hover hit-test ──────────────────────────────────────────────────────────
  // Among all visible vertices within HOVER_RADIUS pixels of (mx,my),
  // returns the index of the one closest to the camera (smallest depth).
  // Remember about 0 hit
  int closestVertex(Point[] screenPts, float mx, float my){
    int   best      = -1;
    float bestDepth = Float.MAX_VALUE;
    for (int i = 0; i < screenPts.length; i++){
      Point p = screenPts[i];
      if (p.z <= 0) continue;
      if (dist(mx, my, p.x, p.y) <= HOVER_RADIUS && p.z < bestDepth){
        best      = i;
        bestDepth = p.z;
      }
    }
    return best;
  }

  // ── Vertex drag ─────────────────────────────────────────────────────────────
  void dragVertex(int idx, float dx, float dy, Camera cam){
    Point worldPos = applyRotX(vertices[idx]);
    Point camPos   = cam.worldToCamera(worldPos);
    float depth    = -camPos.z;
    if (depth <= 0) return;

    float aspect = float(width) / float(height);
    float dCamX  =  (dx / width  * 2.0 * aspect) * depth / cam.f;
    float dCamY  = -(dy / height * 2.0)           * depth / cam.f;

    Point newCamPos = new Point(camPos.x + dCamX, camPos.y + dCamY, camPos.z);
    Point newWorld  = cam.cameraToWorld(newCamPos);
    Point oldWorld  = cam.cameraToWorld(camPos);

    Point movedWorld = new Point(
      worldPos.x + (newWorld.x - oldWorld.x),
      worldPos.y + (newWorld.y - oldWorld.y),
      worldPos.z + (newWorld.z - oldWorld.z)
    );
    vertices[idx] = unapplyRotX(movedWorld);
  }

  // ── Draw ────────────────────────────────────────────────────────────────────
  void draw(Camera cam, Point[] screenPts, int hovered, int dragged){
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
      rect(p.x - POINT_SIZE / 2, p.y - POINT_SIZE / 2, POINT_SIZE, POINT_SIZE); // Comment incase of (no-vertex)
    }
  }

  void drawEdges(Point[] pts){
    stroke(FOREGROUND);
    strokeWeight(2);
    noFill();
    for (int[] face : faces){
      int n = face.length;
      for (int i = 0; i < n; i++){
        int ai = face[i], bi = face[(i + 1) % n];
        // Guard against out-of-range indices from a malformed OBJ
        if (ai < 0 || ai >= pts.length || bi < 0 || bi >= pts.length) continue;
        Point p1 = pts[ai], p2 = pts[bi];
        if (p1.z > 0 && p2.z > 0) line(p1.x, p1.y, p2.x, p2.y);
      }
    }
  }
}

// ─── Point Class ──────────────────────────────────────────────────────────────
class Point{
  float x, y, z;
  Point()                          { x = 0;    y = 0;    z = 0; }
  Point(float x, float y)          { this.x=x; this.y=y; this.z=1; }
  Point(float x, float y, float z) { this.x=x; this.y=y; this.z=z; }
}
