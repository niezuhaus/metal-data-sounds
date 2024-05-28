class Section {
  int sum;
  PVector corner;
  PVector center;
  PImage plan;

  Section(int _sum, PVector _corner, PImage _plan) {
    sum = _sum;
    corner = _corner;
    plan = _plan;
    plan.loadPixels();

    center = averagePosition();
  }

  int getWidth() {
    return plan.width;
  }

  int getHeight() {
    return plan.height;
  }

  void savePlan() {
    plan.save(sum + ".png");
  }

  color getPixel(PVector globalPos) {
    if (globalPos.x < corner.x || globalPos.x > corner.x + plan.width || globalPos.y < corner.y || globalPos.y > corner.y + plan.height) {
      return color(0, 0);
    }
    return pixel(plan, (int)(globalPos.x - corner.x), (int)(globalPos.y - corner.y));
  }

  boolean isInside(PVector globalPos) {
    if (globalPos.x < corner.x || globalPos.x > corner.x + plan.width || globalPos.y < corner.y || globalPos.y > corner.y + plan.height) {
      return false;
    } else if(pixel(plan, (int)(globalPos.x - corner.x), (int)(globalPos.y - corner.y)) == color(0, 0)){
      return false;
    } else {
      return true;
    }
  }
}
