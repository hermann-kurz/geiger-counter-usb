/**
 * LaunchPad / Geiger GUI
 *
 * Martin Kurz martinkurz@kurzschluss.com
 *
 * This code is written in the "processing" programing language, see
 * http://processing.org/
 * 
 * Select COM port that LaunchPad is connected to
 * receive serial communication from LaunchPad for 
 * geiger events.
 *
 *
 * TODOs:
 * - help: 'h' key displays all available keys
 * - history: 'd' toggles display; work in progess, needs some improvements
 * - single geiger tick as a sound file
**/


import processing.serial.*;
import ddf.minim.*;

static final int UPDATE_RATE = 1;        // 1 / second
static final int FRAME_RATE = 30;
static final int NUM_VALUES = 3600;      // == seconds


interface IndexValueConversion {
  float indexToValue(int idx);
  int valueToIndex(float v);
}

class LDiagram {
  LDiagram(int maxNumValues,
           int diagramWidth, int diagramHeight,
           PFont font,
           int fontSize)
  {
    values = new float[maxNumValues];
    this.maxNumValues = maxNumValues;
    this.numValues = 0;
    this.diagramWidth = diagramWidth;
    this.diagramHeight = diagramHeight;
    this.font = font;
    this.fontSize = fontSize;
    
    annotationX = 0;
    annotationY = 0;
  }
  
  void addValue(float value) {
    boolean newMax = false;
    boolean newMin = false;
    if (value > maxValue && !fixedMax) {
      internalSetMaxValue(value);
      newMax = true;
    }
    if (value < minValue && !fixedMin) {
      internalSetMinValue(value);
      newMin = true;
    }
    numValues++;
    if (numValues > maxNumValues) {
      numValues = maxNumValues;
    }
    
    currentPos = (currentPos+1) % maxNumValues;
    if (autoRecalcMinMax && values[currentPos] >= maxValue && !newMax) {
      values[currentPos] = 0;
      recalcMaxValue();
    }
    if (autoRecalcMinMax && values[currentPos] <= minValue && !newMin) {
      values[currentPos] = 0;
      recalcMinValue();
    }
    values[currentPos] = value;
  }
  
  void draw(int x, int y) {

    if (drawBG) {
      fill(bgColor);
    } else {
      noFill();
    }
    if (drawBGStroke) {
      stroke(bgStroke);
    } else {
      noStroke();
    }
    if (drawBGStroke || drawBG) {
      rect(x,y,diagramWidth,diagramHeight);
    }

    if (drawXAxis) {
      annotationX = fontSize*2;
    } else {
      annotationX = 0;
    }
    
    if (drawYAxis) {
      AnnotationInfo ai = preDrawYAxis();
      doDrawYAxis(x, y, ai);
    }

    if (drawXAxis) {
      doDrawXAxis(x, y);
    }

    
    noFill();
    stroke(lineColor);
    
    int idx = (1 + currentPos + 0) % maxNumValues;
    int lx = 0;
    float ly = values[idx];
    
    for (int i=1; i<maxNumValues; i++) {
      idx = (1 + currentPos + i) % maxNumValues;
      int xp = i;
      float yp = values[idx];
      if (clip) {
        lineTClipped(x, y, lx, ly, xp, yp);
      } else {
        lineT(x, y, lx, ly, xp, yp);
      }
      lx = xp;
      ly = yp;
    }
  }

  class AnnotationInfo {
    int high, low, d, L;
  }
  
  private AnnotationInfo preDrawYAxis() {
    AnnotationInfo ai = new AnnotationInfo();
    int maxN = (int)((diagramHeight-annotationX) / (1.0*fontSize));
    ai.d = gridStep(maxValue - minValue, maxN);
    
    if (ai.d == 0) {
      ai.d = 1;
    }

    ai.low = ceil(minValue);
    ai.low = ai.d*(ai.low/ai.d);

    ai.high = floor(maxValue);
    ai.high = ai.d*(ai.high/ai.d);

    String tst1 = "" + ai.high;
    String tst2 = "" + ai.low;
    int L1 = tst1.length();
    int L2 = tst2.length();
    ai.L = L1 > L2 ? L1 : L2;
    annotationY = (int)((1+ai.L) * fontSize*0.5);
    return ai;
  }
  
  private void doDrawYAxis(int x, int y, AnnotationInfo ai) {

    textFont(font, fontSize);
    fill(textColor);
    
    for (int i=ai.low; i<=maxValue; i+=ai.d) {
      
      float ym = valueToY(i);
      
      stroke(gridColor);
      line(x + annotationY, y + ym, x + diagramWidth, y + ym);
      boolean ok = true;
      if (i==ai.high && clipUpperText) {
        if (ym - fontSize/2 < maxValueT) {
          ok = false;
        }
      }
      if (i==ai.low && clipOriginText) {
        if (ym + fontSize/2 > minValueT) {
          ok = false;
        }
      }
      if (ok) {
        String s = "" + i;
        int l = s.length();
        for (int j=0; j<ai.L-l; j++) {
          s = " " + s;
        }
        textAlign(LEFT);
        text(s, x, y + ym + fontSize/2);
      }
    }
  }

  private void doDrawXAxis(int x, int y) {

    float minValueX;
    float maxValueX;
    if (converter != null) {
      minValueX = converter.indexToValue(0);
      maxValueX = converter.indexToValue(maxNumValues - 1);
    } else {
      minValueX = 0;
      maxValueX = maxNumValues - 1;
    }
    
    float fontWidth = 0.5*fontSize;
    
    String tst1 = "" + floor(maxValueX);
    String tst2 = "" + floor(minValueX);
    int L1 = tst1.length();
    int L2 = tst2.length();
    int L = L1 > L2 ? L1 : L2;
    int labelWidth = (int)(L*fontWidth);
    // int labelWidth = (int)(3*font.width('0'));
    
    int maxValueTX = (int)valueToX(0);
    int minValueTX = (int)valueToX(maxNumValues - 1);
    
    AnnotationInfo ai = new AnnotationInfo();
    int maxN = (int)((diagramWidth-annotationY) / (1.5*labelWidth));
    ai.d = gridStep(maxValueX - minValueX, maxN);
    
    ai.low = ceil(minValueX);
    ai.low = ai.d*(ai.low/ai.d);

    ai.high = floor(maxValueX);
    ai.high = ai.d*(ai.high/ai.d);

    tst1 = "" + ai.high;
    tst2 = "" + ai.low;
    L1 = tst1.length();
    L2 = tst2.length();
    ai.L = L1 > L2 ? L1 : L2;
    annotationX = fontSize*2;

    textFont(font, fontSize);
    fill(textColor);

    int range = ai.high - ai.low;
    int n = abs(range / ai.d);
    for (int j=0; j<=n; j++) {
      int i=ai.low+ai.d*j;

      int I;
      if (converter != null) {
        I = converter.valueToIndex(i);
      } else {
        I = i;
      }
      
      float xm = valueToX(I);
      
      stroke(gridColor);
      line(x + xm, y, x + xm, y + diagramHeight - annotationX);
      boolean ok = true;
      if (i==ai.high && clipRightText) {
        if (xm + labelWidth > diagramWidth) {
          ok = false;
        }
      }
      if (i==ai.low && clipOriginText) {
        if (xm + labelWidth < minValueTX) {
          ok = false;
        }
      }
      if (ok) {
        // String s = "" + i;
        String s = "" + i;
        textAlign(CENTER);
        text(s, x + xm, y+diagramHeight - fontSize/2);
      }
    }
  }
  
  private int gridStep(float range, int maxN) {
    
    int s = range > 0 ? 1 : -1;
    range *= s;
    
    if (range <= maxN) {
      return s;
    }
    
    int n = 1;
    float d = range / (1.0*maxN);          // 1307 / 10 = 130.7
    int m = 1;
    while (d > 10) {
      m *= 10;                             // 10    100
      d /= 10;                             // 13.7  1.37
    }
    
    if (d < 1) {
      return s*1*m;
    } else if (d < 2) {
      return s*2*m;
    } else if (d < 5) {
      return s*5*m;
    } else {
      return s*10*m;
    }
  }
  
  void lineT(int xo, int yo, int x1, float y1, int x2, float y2) {
    float X1 = valueToX(x1);
    float Y1 = valueToY(y1);
    float X2 = valueToX(x2);
    float Y2 = valueToY(y2);
    line(xo+X1, yo+Y1, xo+X2, yo+Y2);
  }
  
  void lineTClipped(int xo, int yo, int x1, float y1, int x2, float y2) {
    
    // 1    
    if (y1 < minValue) {
      // 1
      if (y2 < minValue) {
        return;
      }
      // 2
      if (y2 > maxValue) {
        int ix1 = intersect(x1, y1, x2, y2, minValue);
        int ix2 = intersect(x1, y1, x2, y2, maxValue);
        lineT(xo, yo, ix1, minValue, ix2, maxValue);
        return;
      }
      
      // 3
      int ix = intersect(x1, y1, x2, y2, minValue);
      lineT(xo, yo, ix, minValue, x2, y2);
      return;
    }
    
    // 2
    if (y1 > maxValue) {
      // 1
      if (y2 < minValue) {
        int ix1 = intersect(x1, y1, x2, y2, maxValue);
        int ix2 = intersect(x1, y1, x2, y2, minValue);
        lineT(xo, yo, ix1, maxValue, ix2, minValue);
        return;
      }
      // 2
      if (y2 > maxValue) {
        return;
      }
      
      // 3
      int ix = intersect(x1, y1, x2, y2, maxValue);
      lineT(xo, yo, ix, maxValue, x2, y2);
      return;
    }
    
    // 3
    if (y2 < minValue) {
      int ix = intersect(x1, y1, x2, y2, minValue);
      lineT(xo, yo, x1, y1, ix, minValue);
      return;
    }
    if (y2 > maxValue) {
      int ix = intersect(x1, y1, x2, y2, maxValue);
      lineT(xo, yo, x1, y1, ix, maxValue);
      return;
    }
    
    lineT(xo, yo, x1, y1, x2, y2);
  }
  
  void setAutoResize(boolean b) {
    autoRecalcMinMax = b;
  }
  
  void normalize() {
    if (!fixedMin) {
      recalcMinValue();
    }
    if (!fixedMax) {
      recalcMaxValue();
    }
  }
  
  void setFixedMinValue(float v) {
    fixedMin = true;
    internalSetMinValue(v);
  }
  
  void unsetFixedMinValue() {
    fixedMin = false;
  }
  
  void setFixedMaxValue(float v) {
    fixedMax = true;
    internalSetMaxValue(v);
  }
  
  void unsetFixedMaxValue() {
    fixedMax = false;
  }
  
  void setClip(boolean v) {
    clip = v;
  }

  int intersect(float x1, float y1, float x2, float y2, float Y) {
    float d1 = Y - y1;
    float d2 = y2 - Y;
    float dx = x2 - x1;
    float rx = x1 + dx * d1 / (d1 + d2);
    return (int)rx;
  }
  
  void internalSetMinValue(float v) {
    minValue = v;
    minValueT = valueToY(v);
  }
  void internalSetMaxValue(float v) {
    maxValue = v;
    maxValueT = valueToY(v);
  }

  float valueToX(float value) {
    if (logarithmic) {
      return valueToX_logarithmic(value);
    } else {
      return valueToX_linear(value);
    }
  }
  
  // logarithmic
  float valueToX_logarithmic(float value) {
    
    int avail = diagramWidth - annotationY;
    
    float v = (1.0*value) / (maxNumValues-1);    // [0,1]
    v = 1-v;
    v = 1 + 99*v;           // [1,100]
    v = log(v) / L100;  // [0,1]
    v = avail*(1.0-v);
    v += annotationY;
    
    return v;
  }
  
  float valueToX_linear(float value) {
      int avail = diagramWidth - annotationY;
      float v = avail*value / (maxNumValues-1);
      return annotationY + v;
  }

  float valueToY(float value) {
    float v = (value-minValue) / (maxValue - minValue);
    int avail = diagramHeight - annotationX;
    v = avail*v;
    return avail-v;
  }
  
  void recalcMaxValue() {
    internalSetMaxValue(-Float.MAX_VALUE);
    for (int i=0; i<numValues; i++) {
      if (values[i] > maxValue) {
        internalSetMaxValue(values[i]);
      }
    }
  }

  void recalcMinValue() {
    internalSetMinValue(Float.MAX_VALUE);
    for (int i=0; i<numValues; i++) {
      if (values[i] < minValue) {
        internalSetMinValue(values[i]);
      }
    }
  }
  
  
  
  int maxNumValues, numValues, diagramWidth, diagramHeight;
  int currentPos = 0;
  float[] values;
  float maxValue = -Float.MAX_VALUE;
  float minValue =  Float.MAX_VALUE;
  float maxValueT = -Float.MAX_VALUE;
  float minValueT =  Float.MAX_VALUE;
  PFont font;
  int fontSize;
  int annotationX, annotationY;
  
  boolean fixedMin = false;          // ignore lower values
  boolean fixedMax = false;          // ignore higher values
  boolean autoRecalcMinMax = false;   // keep min/max values
  boolean clip = false;
  
  color lineColor = color(255, 255, 0);
  boolean drawBG = true;
  boolean drawBGStroke = true;
  color bgColor = color(100);
  color bgStroke = color(0);
  
  boolean drawYAxis = true;
  boolean drawYLines = true;
  
  boolean drawXAxis = false;
  
  boolean clipRightText = true;
  boolean clipUpperText = true;
  boolean clipOriginText = true;
  
  boolean logarithmic = false;
  float L100 = log(100.0);
  
  IndexValueConversion converter = null;
}

class MyConverter implements IndexValueConversion {

  // seconds
  // float K1 = -NUM_VALUES;
  // float K2 = 1;
  
  // minutes
  float K1 = -NUM_VALUES / 60;
  float K2 = 1.0/60;
  
  float indexToValue(int idx) {
    return K1 + K2*idx;
  }
  
  int valueToIndex(float v) {
    return (int)((v - K1)/K2);
  }
}
















class Sampler {
  Sampler() {
    currentPos = 0;
  }
  
  void addTicks(int n, int ms) {
    samples[currentPos*2] = n;
    samples[currentPos*2+1] = ms;
    currentPos = (currentPos+1) % SAMPLES;
  }

  // number of ticks in SAMPLE_TIME
  int getRate(int ms) {
    int startTime = ms - SAMPLE_TIME;
    int idx = (SAMPLES + currentPos-1) % SAMPLES;
    int ticks = 0;
    while (samples[idx*2+1] != 0 && samples[idx*2+1] > startTime) {
      ticks += samples[idx*2];
      idx = (idx - 1 + SAMPLES) % SAMPLES;
      if (idx == currentPos) {
        println("ERROR: Sampler.rate(): samples array too small: " + SAMPLES);
        return 17;
      }
    }
    return ticks;
  }
  
  static final int SAMPLE_TIME = 60*1000;                     // one minute
  // static final int SAMPLES = FRAME_RATE * SAMPLE_TIME + 100;  // max number of samples + some extra space
  static final int SAMPLES = UPDATE_RATE * SAMPLE_TIME + 100;  // max number of samples + some extra space
  int[] samples = new int[2*SAMPLES];
  int currentPos;
}

class Toggle {
  Toggle(String Text, char Key, boolean On, int cx, int cy, PFont font) {
    this.Text = Text;
    this.Key = Key;
    this.On = On;
    this.cx = cx;
    this.cy = cy;
    this.font = font;
  }
  void toggle() {
    On = !On;
    textAlign(CENTER);
    textFont(font, 32);
    fill(textColor);
    String state = On ? "on" : "off";
    text(Text + ": " + state, cx, cy);
  }

  String Text;
  boolean On;
  char Key;
  int cx, cy;
  PFont font;
}

interface CBMethod {
  void start();
  void stop();
}

class KeyAction {
  KeyAction(char Key, boolean Start, CBMethod function) {
    this.Key = Key;
    this.function = function;
    if (Start) {
      start();
    }
  }
  void startOrStop() {
    if (started) {
      stop();
    } else {
      start();
    }
  }
  
  private void start() {
    started = true;
    function.start();
  }
  private void stop() {
    started = false;
    function.stop();
  }

  boolean started = false;
  char Key;
  CBMethod function;
}


HashMap toggles = new HashMap();
HashMap keyActions = new HashMap();

Toggle playSoundToggle;
Toggle showRaysToggle;
Toggle showDiagramToggle;

Toggle createToggle(String Text, char Key, boolean On, int cx, int cy, PFont font) {
  Toggle t = new Toggle(Text, Key, On, cx, cy, font);
  toggles.put(Key, t);
  return t;
}

KeyAction createKeyAction(char Key, boolean start, CBMethod method) {
  KeyAction k = new KeyAction(Key, start, method);
  keyActions.put(Key, k);
  return k;
}

Minim minim;
AudioPlayer tick;

PFont fontA;
char instruct;
color backColor;
color textColor;
color helpTextColor;
color gridColor;
color rayColor;
boolean portChosen = false;
int COMPort;
int [] keyIn = new int[3];
int i, keyIndex=0;
int windowWidth = 800;
int windowHeight = 500;
int helpWidth = 310;
int helpHeight = 140;
int windowCX = windowWidth / 2;
int windowCY = windowHeight / 2;
float r = (windowWidth + windowHeight) / 10.0;

boolean showHelpScreen = false;

String outStr = new String();
int Rate_old = 0;
int Events = -1;

int drawsBetweenUpdate = 0;
int DrawsBetweenUpdate = 65;

int timeBetweenUpdate = 1000; // just a guess
int lastTime = 0;
int lastUpdate = 0;
int lastRate = 0;

Sampler sampler;

// The serial port:
Serial myPort;

LDiagram recorder;

boolean drawingScene = false;
boolean drawingRay = false;

int textHeight = 200;



class HelpMethod implements CBMethod {
    void start() {
      showHelpScreen = true;
    }
    void stop() {
      showHelpScreen = false;
    }
}

class DrawRayTask extends TimerTask  
{
  DrawRayTask(boolean playSound, boolean showRay) {
    this.playSound = playSound;
    this.showRay = showRay;
  }
  public void run() {
    drawRay(playSound, showRay);
  }
  
  private boolean playSound, showRay;
}

// draw n rays within timespan
void startDrawRays(int n,    // num rays to be drawn
                   int ms    // in this time
                   )
                   
{
  // start one TimerTask and one Timer per ray
  if (0 == n) {
    return;
  }

  for (int i=0; i<n; i++) {

    int startAt = (int)random(ms);
    Timer timer = new Timer();
    timer.schedule  ( new DrawRayTask(playSoundToggle.On, showRaysToggle.On), startAt);
  }
}

void setup()
{
  frameRate(FRAME_RATE);
  sampler = new Sampler();
  //load font
  fontA = loadFont("CourierNew36.vlw");
  
  playSoundToggle = createToggle("sound", 's', false, windowCX, windowCY, fontA);
  showRaysToggle = createToggle("rays", 'r', true, windowCX, windowCY, fontA);
  showDiagramToggle = createToggle("diagram", 'd', true, windowCX, windowCY, fontA);
  
  CBMethod method = new HelpMethod();
  createKeyAction('h', false, method);

  recorder = new LDiagram(NUM_VALUES, windowWidth, windowHeight - textHeight, fontA, 20);
  
  recorder.setFixedMinValue(0);
  // recorder.setFixedMaxValue(100);
  
  recorder.drawYAxis = true;
  recorder.drawXAxis = true;
  
  recorder.clip = true;
  
  recorder.drawBG = false;
  // dia.bgColor = color(128, 128, 128);
  
  recorder.drawBGStroke = false;
  recorder.clipUpperText = false;

  recorder.converter = new MyConverter();
  
  recorder.addValue(1);
  
  
  //setup window
  size(windowWidth, windowHeight);
  smooth();
  ellipseMode(RADIUS);

  // Set the font, its size (in units of pixels), and alignment
  //Set background color
  // backColor = color(25,0,0, 15); // ok for 60 fps
  backColor = color(25,8,8, 50);
  textColor = color(255,255,255);
  helpTextColor = color(255,0,0);
  // gridColor = color(128,128,128);
  gridColor = color(170,170,170, 20);
  rayColor = color(255,255,255);

  // List all the available serial ports, then give prompt
  String txt = "Please type in the serial COM port that your LaunchPad is connected to, then ENTER.";
  println(Serial.list());
  println(txt);
  
  background(backColor);
  stroke(textColor);
  textFont(fontA, 13);
  textAlign(LEFT);
  text(txt, 0, 20);
  for(i=0; i<Serial.list().length; i++){
    text("[" + i + "] " + Serial.list()[i], 100, 38+13*i);
  }
  
  // audio
  minim = new Minim (this);
  tick = minim.loadFile ("tick2.wav");
}

void drawRay(boolean playSound, boolean showRay) {
  
    if (playSound) {
      tick.rewind();
      tick.play();
    }
    
    if (!showRay) {
      return;
    }
    
    drawingRay = true;
    
    // draw rays for single event
    float x = random(windowWidth);      // start point of rays
    float y = random(windowHeight);
    
    // int n = 2 + (int)random(6);         // 2 to 7 rays per event - ok for fade
    int n = 1 + (int)random(3);         // 1 to 3 rays per event
    float direction = random(2*PI);     // ray direction
    
    stroke(rayColor);
    noFill();
    
    for (int i=0; i<n; i++) {

      int s1 = random(2) < 1 ? 1 : -1;
      int s2 = random(2) < 1 ? 1 : -1;
      
      r = random(windowWidth * 0.5);
      float xs = x + r*cos(direction - s1*0.5*PI);
      float ys = y + r*sin(direction - s1*0.5*PI);
      float a1 = direction + s1*0.5*PI;
      float a2 = a1 + s2*0.5*PI;
      if (a2 < a1) {
        float a = a1;
        a1 = a2;
        a2 = a;
      }
      stroke(rayColor); noFill();
      arc(xs,ys,r,r,a1,a2);
    }
    
    drawingRay = false;
}

// internal rate update
void draw()
{
  if (drawingRay) {
    return;
  }
  
  drawsBetweenUpdate++;
  if(portChosen == true) {

    int oldEvents = Events;

    if (myPort.available() > 0) {
      try{
        Thread.currentThread().sleep(10);
      } catch(InterruptedException ie){
      }
    }
    
    int ct = millis();
    
    int dEvents = 0;
    // read all available data  
    while (myPort.available() > 0) {
      
      char c = myPort.readChar();
      outStr += c;
      int l = outStr.length();
      
      // detect 10, 13 sequence -> end of transmission
      if (l > 1 && 10 == outStr.charAt(l-2) && 13 == outStr.charAt(l-1)) {
        
        timeBetweenUpdate = ct - lastTime;
        lastTime = ct;
        
        DrawsBetweenUpdate = drawsBetweenUpdate;
        drawsBetweenUpdate = 0;
        
        // save last output for comparision
        String[] s = outStr.split("\\s");
        
        boolean first = -1 == Events;
        
        Events = Integer.valueOf( s[0] ).intValue();
        if (first) {
          // oldEvents = Events - 30;               // show some rays at beginning
          oldEvents = Events;                    // no start events in counter
          startDrawRays(15, timeBetweenUpdate);  // little show at start
        }
        
        dEvents = Events - oldEvents;
        // a) rays are drawn between now and next update
        startDrawRays(dEvents, timeBetweenUpdate);
        
        // dEvents is rate
        // sampling: events / minute
        // update: every second
        
        if (dEvents > 0) {
          sampler.addTicks(dEvents, ct);
        }
        outStr = new String();
      }
    }

    int rate = lastRate;
    if (ct - lastUpdate > UPDATE_RATE*1000) {
      rate = sampler.getRate(ct);
      lastRate = rate;
      recorder.addValue(rate);
      lastUpdate = ct;
    }
    
    drawingScene = true;
    
    boolean fade = true;
    if (fade) {
      // draw a semi transparent rectangle over whole screen, let old rays fade away
      fill(backColor);
      noStroke();
      rect(0, 0, windowWidth, windowHeight);
    } else {
      background(backColor);
    }

    /*
    // b
    for (int i=0; i<dEvents; i++) {
      drawRay(playSoundToggle.On, showRaysToggle.On);
    }
    */
    

    int tx = 0;
    int ty = 50;
    // draw text
    String s = "rate       : " + rate + " / min";
    textFont(fontA, 40);
    textAlign(LEFT);
    fill(textColor);
    text(s, tx, ty);
    s = "total count: " + Events;
    text(s, tx, ty + 50);
    noFill();
    
    if (showDiagramToggle.On) {
      recorder.draw(0, textHeight);
    }
    
    if (showHelpScreen) {
      textAlign(LEFT);
      stroke(textColor);
      fill(255, 128);
      rect(0.5*(windowWidth-helpWidth), 0.5*(windowHeight-helpHeight), helpWidth, helpHeight);
      fill(helpTextColor);
      textFont(fontA, 24);
      float Y = 30;
      Y += 0.5*(windowHeight - helpHeight);
      float X = 0.5*(windowWidth - helpWidth);
      float lineHeight = 30;
      text("'h': show / hide help", X, Y);
      text("'s': sound on / off", X, Y + lineHeight);
      text("'r': rays on / off", X, Y + 2*lineHeight);
      text("'d': diagram on / off", X, Y + 3*lineHeight);
    }


    drawingScene = false;

    // c) rays are drawn without using timer, ...
    
    // d) rays are drawn as the events occur
    // needs immediate notification from HW
  }
}



//wait for key press. Once key is entered, initialize serial com port
void keyPressed() {
  
  if(portChosen == false){
    if (key != 10) { //Enter
      keyIn[keyIndex++] = key-48;
    } else {
      COMPort = 0;
      for (i = 0; i < keyIndex; i++) {
        COMPort = COMPort * 10 + keyIn[i];
      }
      println("COM Port: " + COMPort + " name: " + Serial.list()[COMPort]);

      myPort = new Serial(this,                     // PApplet
                          Serial.list()[COMPort],   // name
                          9600);                    // rate
      myPort.clear();
      portChosen = true;
      // background(200, 255, 0);
      background(255, 255, 255);
      // textFont(fontA, 60); // change font size & alignment for temp readings
      textFont(fontA, 40); // change font size & alignment for temp readings
      textAlign(LEFT);
    }
  } else {
    // toggle something ?
    
    if (toggles.containsKey(key)) {
      Toggle t = (Toggle)toggles.get(key);
      t.toggle();
    }
    if (keyActions.containsKey(key)) {
      KeyAction k = (KeyAction)keyActions.get(key);
      k.startOrStop();
    }
    if (key == 'l') {
      recorder.logarithmic = !recorder.logarithmic;
    }
  }
}



