import processing.sound.*; //<>//
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

// #################### EDIT HERE ####################

// SOUND PARAMETERS
// OSC
float minFreq = 1000;            // in Hz
float maxFreq = 3500;
float minAmp = -40;             // in dB
float maxAmp = -20;
float playbackLength = 5.0;     // in seconds
float linePlaybackSpeed = 250;  // playbackspeed for the custom axis in px/second

// ADSR
float minR = 0.05;              // min-release time
float maxR = 0.5;               // max-release time

// PROGRAMM CONSTANTS
int imagePreset = 0;            // image to analyze (try 0, 1, 2 or 3)
color cText = #ffffff;          // color of numbers being shown within the particles
color cDrawParticles = color(255, 102, 153, 50); // color to draw the particles in, if shown on the screen

// #################### STOP EDITING HERE ####################

// INTERNAL CONSTANTS
color cSearch = #ffffff;             // color to look for in particles
color cFoundWhitePixel = #006080;    // color being used to mark found particle pixels
color cFoundBlackPixel = #010101;    // color being used to mark pixels that do not belong to particles
String location = "images/";
String[] mapfiles = {"1902022_028-v200-1b-720.png", "1902022_032-v200-3b-720.png", "1902022_034-v200-4b-720.png", "1902023_032-v200-5b-720.png"};
String[] bgfiles = {"1902022_028-v200-1-720.png", "1902022_032-v200-3-720.png", "1902022_034-v200-4-720.png", "1902023_032-v200-5-720.jpg"};


// MINIM AUDIO LIBRARY
Minim minim;
AudioOutput out;

float playbackStartMillis;       // time the user started the playback
boolean playback = false;        // indicates if the playback is running
boolean linePlayback = false;    // indicates if the lineplayback is running

// ADSR PRESET (will be overwritten)
float a = 0.01;    // attack
float d = 0;       // decay time
float sL = 1;      // sustain level
float r = 0.05;    // release time

// INTERNAL VARIABLES
PImage bg, img, draw, transparent;                                      // graphic layers
PFont mono;                                                             // font
HashMap<Character, ArrayList<Section>> keys;                            // keybindings
Section clickedSection;                                                 // the selected section to get a new keybinding
ArrayList<PVector> particleCoords = new ArrayList<PVector>();           // collection of all particle pixel being found
int column;                                                             // the column of pixels being scanned
ArrayList<Section> db;                                                  // central storage for all the section objects created
boolean measured;                                                       // indicates if the analysis terminated
int max, maxWidth;                                                      // the greatest sum measured
int coordsCounted, xCoordCounter, yCoordCounter;                        // number of pixels counted, sum of all x and y coordinated (necesary for averaging the position)
PVector lineStart, lineEnd;                                             // custom axis coordinates
float linePlaybackLength;                                               // in seconds of playbacktime 
ArrayList<Section> selection = new ArrayList<Section>();                // chord note selection

void setup() {
  size(1280, 770);
  pixelDensity(displayDensity());
  frameRate(60);
  stroke(255, 0, 0);

  mono = createFont("Andale Mono", 32);
  textFont(mono);
  // minim
  minim = new Minim(this);
  out = minim.getLineOut(Minim.MONO, 2048);

  createSetup();
}

void createSetup() {
  max = 0;
  maxWidth = 0;
  column = 0;
  keys = new HashMap<Character, ArrayList<Section>>();
  db = new ArrayList<Section>();
  
  bg = loadImage(location + bgfiles[imagePreset]);
  img = loadImage(location + mapfiles[imagePreset]);
  img.loadPixels();
  transparent = createImage(img.width, img.height, ARGB);
  draw = transparent.copy();
  draw.loadPixels();
  for (int i = 0; i < draw.pixels.length; i++) {
    draw.pixels[i] = color(0, 0, 0, 0);
  }

  measureSizes();
  fill(cText);
  textAlign(CENTER);

  drawFrame();
}

void draw() {
  if (playback) {
    if (millis() - playbackStartMillis < playbackLength * 1000) {
      strokeWeight(4);
      line(0, height-52, map(millis() - playbackStartMillis, 0, playbackLength * 1000, 0, width), height-52);
    } else {
      playback = false;
      drawFrame();
    }
  }
  if (linePlayback) {
    if (millis() - playbackStartMillis < linePlaybackLength * 1000) {
      stroke(255, 0, 0);
      PVector linePlaybackPos = PVector.lerp(lineStart, lineEnd, (millis() - playbackStartMillis) / (linePlaybackLength * 1000));
      line(lineStart.x, lineStart.y, linePlaybackPos.x, linePlaybackPos.y);
    } else {
      linePlayback = false;
      lineStart = null;
      lineEnd = null;
      drawFrame();
    }
  }
  if (mousePressed && lineStart != null) {
    line(mouseX, mouseY, lineStart.x, lineStart.y);
  }
}

// draws the basic framesetup
void drawFrame() {
  background(0);
  image(bg, 0, 0);
  drawTexts();
  image(draw, 0, 0);
  textAlign(LEFT);
  textSize(12);
  text("[LEFT] Previous preset", 20, 750);
  text("[RIGHT] Next preset", 210, 750);
  text("[RETURN] Play", 380, 750);
  text("[CLICK] Select", 500, 750);
  text("[BACKSPACE] Reset selection", 630, 750);
  text("[ANY KEY] Save chord", 850, 750);
  text("[CLICK & PULL] Play custom axis", 1030, 750);
}

// draws all pixelsums to the center the sections
void drawTexts() {
  textAlign(CENTER);
  for (int i = 0; i < db.size(); i++) {
    Section s = db.get(i);
    textSize(map((float)dBtoG(-s.sum/2000), 0, 1, 65, 8));
    text((int)s.sum, s.center.x, s.center.y);
  }
}

// plays back the whole image
void playback() {
  out.pauseNotes();
  for (int i = 0; i < db.size(); i++) {
    playSection(db.get(i), null);
  }
  out.resumeNotes();
}

// plays back the custom axis playback
void linePlayback(PVector start, PVector end) {
  float dist = start.dist(end);
  linePlaybackLength = dist / linePlaybackSpeed;
  Section lastSec = null;
  out.pauseNotes();
  for (int i = 0; i < (int)dist; i++) {
    Section s = getSection(PVector.lerp(start, end, float(i)/dist));
    if (s != null && s != lastSec) {
      playSection(s, (float(i)/dist)*linePlaybackLength);
      println((float(i)/dist)*linePlaybackLength);
      println(i);
      println(dist);
      println(linePlaybackLength);
      lastSec = s;
    }
  }
  out.resumeNotes();
}

// plays one section
void playSection(Section section, Float time) {
  if (time == null) { // should the note played right now or programmed onto the timeline based on its lowest x-coordinate?
    time = map(section.corner.x, 0, width, 0, playbackLength);
  }
  float noteLength = ((float)section.getWidth())/((float)width)*playbackLength/10;
  out.playNote(time, noteLength, makeADSR(section));
}

// plays a set of sections
void playSections(ArrayList<Section> sections) {
  out.pauseNotes();
  for (Section s : sections) {
    playSection(s, 0.0);
  }
  out.resumeNotes();
}

// heres, where the sound parameters are passed
ADSRInstrument makeADSR(Section section) {
  r = map(section.getWidth(), 1, maxWidth, minR, maxR);
  float freq = map((float)dBtoG(-section.sum/2000), 0, 1, minFreq, maxFreq);
  float amp = map((float)dBtoG(-section.sum/2000), 0, 1, 1, 0);
  return new ADSRInstrument(freq, amp, a, d, sL, r);
}

void keyPressed() {
  if (key == ENTER) {                                                     // Song abspielen
    playbackStartMillis = millis();
    playback = true;
    playback();
  } else if (key == BACKSPACE) {
    resetSelection();
  } else if (keyCode == LEFT) {
    if (imagePreset > 0) {
      imagePreset--;
      createSetup();
    }
  } else if (keyCode == RIGHT) {
    if (imagePreset < mapfiles.length - 1) {
      imagePreset++;
      createSetup();
    }
  } else if (keys.get(key) != null && selection.size() == 0) {            // Gebundenen Ton abspielen
    playSections(keys.get(key));
  } else if (keys.get(key) == null && selection.size() != 0) {            // Ton binden
    keys.put(key, selection);
    clickedSection = null;
    resetSelection();
    playSections(keys.get(key));
    println(key + "-key set to combination!");
  } else if (keys.get(key)!= null && selection.size() != 0) {
    keys.put(key, selection);
    clickedSection = null;
    resetSelection();
    println(key + " re-set!");
  }
    //else if (key == 's' && clickedSection != null) {
    //  clickedSection.savePlan();
    //  println("Plan of Section #" + (int)clickedSection.sum + " saved!");
    //}
}

void mouseClicked() {
  if (measured) {
    clickedSection = getSection(new PVector(mouseX, mouseY));
    if (clickedSection == null) {
      return;
    }
    selection.add(clickedSection);
    drawSection(clickedSection);
    playSection(clickedSection, 0.0);
    println("Press a key to bind the combination:");
    for (Section s : selection) {
      print(s.sum + " ");
    }
    println();
  }
}

void mousePressed() {
  lineStart = new PVector(mouseX, mouseY);
}

void mouseReleased() {
  lineEnd = new PVector(mouseX, mouseY);
  if (lineStart.dist(lineEnd) < 5) {
    lineStart = null;
    lineEnd = null;
    return;
  }
  playbackStartMillis = millis();
  linePlayback = true;
  linePlayback(lineStart, lineEnd);
  drawFrame();
}

// returns the section on a given coordinate, if there is one 
Section getSection(PVector pos) {
  for (Section s : db) {
    if (s.isInside(pos)) {
      return s;
    }
  }
  return null;
}

// general analyze methode for any image
void measureSizes(PImage image) {
  for (int i = 0; i < width; i++) {
    scanColumn(image);
  }
}

// general analyze methode for the preset image
void measureSizes() {
  for (int i = 0; i < width; i++) {
    scanColumn(img);
  }
  measured = true;
}

// scans the column for white pixels and initiates the counting process
void scanColumn(PImage image) {
  for (int y = 0; y < image.height - 1; y++) {
    if (noMarkIsWhite(image, column, y)) {
      measureSize(image, column, y);
      if (particleCoords.size() > 0) { // Partikel gefunden
        max = max(max, particleCoords.size());
        saveSection();
      }
    }
  }
  column++;
}

// saves the section to the database
void saveSection() {
  PVector min = new PVector(width, height);
  PVector max = new PVector(0, 0);
  for (PVector coord : particleCoords) {
    min.x = min(min.x, coord.x);
    min.y = min(min.y, coord.y);
    max.x = max(max.x, coord.x);
    max.y = max(max.y, coord.y);
  }
  int sWidth =  1 + (int)(max.x - min.x);
  maxWidth = max(maxWidth, sWidth);
  int sHeight = 1 + (int)(max.y - min.y);
  PImage plan = createImage(sWidth, sHeight, ARGB);
  plan.loadPixels();
  for (int i = 0; i < plan.pixels.length; i++) {
    plan.pixels[i] = color(0, 0);
  }
  for (int i = 0; i < particleCoords.size(); i++) {
    PVector coord = particleCoords.get(i);
    colorPixel(plan, (int)(coord.x - min.x), (int)(coord.y - min.y), cDrawParticles, false);
  }
  db.add(new Section(particleCoords.size(), min, plan));
  resetCounters();
}

// counts recursivly all adjecent (white) pixels outgoing from a given coordinate
void measureSize(PImage image, int x, int y) {
  if (!noMarkIsWhite(image, x, y)) {
    return;
  }
  int columnUp = countPixelsInRow(image, x, y-1, 0);
  int columnDown = countPixelsInRow(image, x, y, 2);

  for (int i = y - columnUp; i < y + columnDown; i++) {
    if (noMarkIsWhite(image, x+1, i)) {
      measureSize(image, x+1, i);
    }
    if (noMarkIsWhite(image, x-1, i)) {
      measureSize(image, x-1, i);
    }
  }
}

// counts recursivly all (white) pixels in one direction outgoing from a given coordinate that isn't counted
// 0 = N    1 = W    2 = S    3 = E
private int countPixelsInRow(PImage image, int x, int y, int dir) {
  if (!isWhite(image, x, y)) {
    return 0;
  } else {
    particleCoords.add(new PVector(x, y)); // here is where we count;
    switch(dir) {
    case 0:
      return 1 + countPixelsInRow(image, x, y-1, 0);

    case 1:
      return 1 + countPixelsInRow(image, x+1, y, 1);

    case 2:
      return 1 + countPixelsInRow(image, x, y+1, 2);

    case 3:
      return 1 + countPixelsInRow(image, x-1, y, 3);

    default:
      return 0;
    }
  }
}

// checks if the pixel is white and marks it as found afterwards
boolean isWhite(PImage image, int x, int y) {
  if (pixel(image, x, y) == cSearch) {
    colorPixel(image, x, y, cFoundWhitePixel, false);
    coordsCounted++;
    xCoordCounter += x;
    yCoordCounter += y;
    return true;
  } else if (pixel(image, x, y) == color(0)) {
    colorPixel(image, x, y, cFoundBlackPixel, false);
  }
  return false;
}

// checks if the pixel is white without marking it as found
boolean noMarkIsWhite(PImage image, int x, int y) {
  return pixel(image, x, y) == cSearch;
}

// averages the counted positions
PVector averagePosition() {
  PVector res = new PVector(xCoordCounter/coordsCounted, yCoordCounter/coordsCounted);
  return res;
}

// resets the counting statistics 
void resetCounters() {
  xCoordCounter = 0;
  yCoordCounter = 0;
  coordsCounted = 0;
  particleCoords = new ArrayList<PVector>();
}

// resets the selection and clears the screen
void resetSelection() {
  draw = transparent.copy();
  selection = new ArrayList<Section>();
  drawFrame();
}

// marks the given section on the screen for selection 
void drawSection(Section section) {
  image(section.plan, section.corner.x, section.corner.y);
} 

// returns the color value for the pixel at given coordinates in the standart image
color pixel(int x, int y) {
  return pixel(img, x, y);
}

// returns the color value for the pixel at given coordinates in a given image
color pixel(PImage image, int x, int y) {
  if (image.width * y + x >= image.width * image.height) {
    println("Pixel außerhalb der Riechweite");
    return 0;
  }
  return image.pixels[image.width * y + x];
}

// colors the pixel in the standart image the given color
void colorPixel(int x, int y, color c, boolean update) {
  colorPixel(img, x, y, c, update);
}

// colors the pixel at coordinates in a PImage the given color
void colorPixel(PImage image, int x, int y, color c, boolean update) {
  image.pixels[image.width * y + x] = c;
  if (update) {
    image.updatePixels();
  }
}

// colors the pixel at pixel index in a PImage the given color
void colorPixel(PImage image, int index, color c, boolean update) {
  image.pixels[index] = c;
  if (update) {
    image.updatePixels();
  }
}

double dBtoG(float v) {
  return Math.pow(2, v/6);
}
