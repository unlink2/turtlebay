#include"include/imageconverter.h"
#include"include/colour.h"
#include <exception>
#include<string>
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
    this->converted = new unsigned int[image->get_width() * image->get_height()];
    if(!this->converted) {
      std::cerr << red << "[FATAL] " << def
      << "Unable to allocate enough memory for converted image!" << std::endl;
      exit(-1);
    }
  }

  ImageConverter::~ImageConverter() {
    // TODO error when freeing
    if(this->converted) {
      delete[] this->converted;
    }

    if(this->image) {
      delete this->image;
    }
  }

  void ImageConverter::convertPixels() {
    if(settings->verbose) {
      std::cout << "Converting pixels" << std::endl;
    }

    for(int w = 0; w < this->image->get_width(); w++) {
      for(int h = 0; h < this->image->get_height(); h++) {
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
        }

        if(settings->verbose) {
          std::cout << "Pixel (" << w << "/" << h << ") "
          << std::setw(2) << std::setfill('0')
          << (short)pixel.red << " " << std::setw(2) << std::setfill('0') <<
          (short)pixel.green << " " << std::setw(2) << std::setfill('0')
          << (short)pixel.blue
          << " " << hexColour << std::endl;
        }
        this->converted[w * image->get_width() + h] = pixelConverted;
        if(settings->verbose) {
          std::cout << "Set " << this->converted[w * image->get_width() + h] << "(" <<
          w * image->get_width() + h << "th element)\n\n";
        }
      }
    }
  }

  void ImageConverter::writePixels() {
    std::ofstream outfile;

    outfile.open(settings->outfile);
    if(settings->outputBase == "detailed") {
      if(settings->verbose) std::cout << "Outputting sprite in detailed mode!\n";

      // outputting to file
      unsigned short stepCounter = image->get_width() / 8;
      for(int sc = 0; sc < stepCounter; sc++) {
        // each of these loops will write 8 by 8 pixels at most so we loop N times to get all arrays
        outfile << "; Sprite of " << settings->inputfile << " Part " << sc << "/" << stepCounter << std::endl;
        for(int x = 0; x < image->get_width(); x++) {
          outfile << ".byte ";

          for(int y = stepCounter * 8 - 8; y < 8 * stepCounter; y++) {
            if(y < image->get_width()) {
              outfile << converted[x * image->get_width() + y];
            } else {
              outfile << 0;
            }
          }
          outfile << std::endl;
        }
        outfile << std::endl;
      }

      outfile << std::endl << std::endl;
    }
    outfile.close();
  }
}
