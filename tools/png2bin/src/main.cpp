#include<iostream>
#include<stdlib.h>
#include<stdio.h>
#include<png++/png.hpp>
#include"include/imageconverter.h"
#include"include/util.h"

int main(int argc, char **argv) {
  init();
  parseArgs(argc, argv);

  // start conversion
  Image::ImageConverter converter(&globalsettings);
  converter.convertPixels();
  converter.writePixels();
}
