#ifndef PNG_CONVERTER_H
#define PNG_CONVERTER_H

#include<png++/png.hpp>
#include<cstdint>
#include"util.h"

namespace Image {
  class ImageConverter {
  private:
    png::image<png::rgb_pixel> *image;

    unsigned int *converted; // converted image for each pixel

    Settings *settings;
  public:
    ImageConverter(Settings *settings);

    ~ImageConverter();

    void convertPixels();

    void writePixels();
  };
}

#endif
