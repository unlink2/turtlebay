#include"include/imageconverter.h"
#include"include/colour.h"
#include <exception>
#include <string>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <fstream>
#include <bitset>

using namespace Colour;

namespace Image {
  ImageConverter::ImageConverter(Settings *settings) {
    this->settings = settings;
    try {
      this->image = new png::image<png::rgb_pixel>(settings->inputfile);
    } catch(std::exception &e) {
      std::cerr << red << "[FATAL] " << def << e.what() << std::endl;
      exit(-1);
    }

    if(settings->verbose) {
      std::cout << "Creating array of size: (" << image->get_width() << "/" << image->get_height() << ")" << std::endl;
    }

    /*
    init converted array
    this array contains every pixel -> access like this:
    x * width + y
    This simulates a 2d array with less of a memory mess
    */
  }

  ImageConverter::~ImageConverter() {
    // TODO error when freeing

    if(this->image) {
      delete this->image;
    }
  }

  void ImageConverter::convertPixels() {
    if(settings->verbose) {
      std::cout << "Converting pixels" << std::endl;
    }
    converted.clear();
    for(int h = 0; h < this->image->get_height(); h++) {
      converted.emplace_back(std::vector<unsigned int>());
      for(int w = 0; w < this->image->get_width(); w++) {
        png::rgb_pixel pixel = image->get_pixel(w, h);

        // converted pixel
        int pixelConverted = 0;

        // write pixel into file if it is in pallette

        // convert colour to hex string just like the user input would specify
        std::stringstream stream;
        stream << std::hex << std::setw(2) << std::setfill('0') << (short)pixel.red;
        std::string hexColour = "#" + stream.str();

        // reset stream for next int
        stream.str("");
        stream << std::hex << std::setw(2) << std::setfill('0') << (short)pixel.green;
        hexColour = hexColour + stream.str();

        stream.str("");
        stream << std::hex << std::setw(2) << std::setfill('0') << (short)pixel.blue;
        hexColour = hexColour + stream.str();

        bool colourFound = false;
        for(int i = 0; i < settings->coloursLen; i++) {
          std::string colourCheck = "#";
          stream.str("");
          stream << std::hex << std::setw(6) << settings->colours[i];
          colourCheck = colourCheck + stream.str();

          // if colour is not in there default to 0 and output a warning
          if(colourCheck == hexColour) {
            if(settings->verbose) {
              std::cout << "Pixel (" << w << "/" << h << ") "
              << "Colour found for " << hexColour << ". Converted int: " << i << std::endl;
            }
            pixelConverted = i;
            colourFound = true;
            break;
          }
        }

        if(!colourFound) {
          std::cerr << "Pixel (" << w << "/" << h << ") "
          << red << "[WARNING] " << def << "Colour " << hexColour << " not found in list. Defaulting to 0 "
          << std::endl;

          colourFound = 0;
        }

        if(settings->verbose) {
          std::cout << "Pixel (" << w << "/" << h << ") "
          << std::setw(2) << std::setfill('0')
          << (short)pixel.red << " " << std::setw(2) << std::setfill('0') <<
          (short)pixel.green << " " << std::setw(2) << std::setfill('0')
          << (short)pixel.blue
          << " " << hexColour << std::endl;
        }
        converted[h].emplace_back(pixelConverted);
        if(settings->verbose) {
          std::cout << "Set " << converted[w][h] << "(" <<
          w * image->get_width() + h << "th element)\n\n";
        }
      }
    }
  }

  void ImageConverter::writePixels() {
    std::ofstream outfile;
    outfile.open(settings->outfile);

    // outputting to file
    outfile << "; Sprite of " << settings->inputfile << std::endl;
    for(int x = 0; x < image->get_height(); x++) {
      outfile << ".byte \%";
      // pf0 is inverted!
      if(settings->outputBase == "p0") {
        for(int y = image->get_width(); y >= 0; y--) {
          outfile << converted[x][y];
        }
      } else {
        for(int y = 0; y < image->get_width(); y++) {
          outfile << converted[x][y];
        }
      }
      outfile << std::endl;
    }
    outfile << std::endl;

    outfile.close();
  }
}
