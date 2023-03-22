#include"include/util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include"include/colour.h"
#include<string>

Settings globalsettings;

using namespace Colour;

void init() {
  // init settings struct with default values
  globalsettings.appname = "png2bin";
  globalsettings.dev = "Lukas Krickl";
  globalsettings.email = "lukaskrickl@gmail.com";
  globalsettings.minorVersion = 0;
  globalsettings.majorVersion = 0;
  globalsettings.patch = 1;
  globalsettings.github = "https://github.com/unlink2/png2bin";

  // set default options
  globalsettings.appmode = "sprite";
  globalsettings.outputBase = "default";
  globalsettings.colours = (uint32_t*)malloc(5 * sizeof(uint32_t));

  // set default colour pallette
  globalsettings.colours[0] = 0xFFFFFF;
  globalsettings.colours[1] = 0x000000;

  globalsettings.coloursLen = 2;

  globalsettings.outfile = "./out.sprite";

  globalsettings.verbose = false;
}

void parseArgs(int argc, char **argv) {
  if(argc <= 1) {
    std::cout << globalsettings.appname << ": No arguments given! Use -h for help!\n";
  }
  for(int index = 0; index < argc; index++) {
    std::string arg = argv[index]; // convert to std::string for ease of use

    // simple version info
    if(arg == "version" || arg == "-v") {
      std::cout << globalsettings.appname << " Version: " <<
      globalsettings.majorVersion << "." << globalsettings.minorVersion <<
      "." << globalsettings.patch << ". Developed by: " << globalsettings.dev << " (" <<
      globalsettings.email << ") Github: " << globalsettings.github << std::endl;
    } else if(arg == "-h") {
      std::cout << globalsettings.appname << " help page. Use man " << globalsettings.appname <<
      " for more information!\n\n" <<
      "Arguments:\n" <<
      "-h\t(optional) Outputs this menu\n" <<
      "-v\t(optional) Outputs version information\n" <<
      "-f ./example.png\t(required) Set the file that is to be converted\n" <<
      "-o ./output\t(optional) Set the output file and directory\n" <<
      "-b p0/default\t(optional) Set the base to output the data in (defaults to detailed)\n" <<
      "verbose\t(optional) Verbose mode.";
    } else if(arg == "-f") {
      if(extraArgumentsNeeded(1, argc, index)) {
        index++;
        globalsettings.inputfile = argv[index];
      } else {
        std::cerr << red << "[FATAL]" << def << " Insufficent arguments: Use -h for syntax!" << std::endl;
        exit(-1);
      }
    } else if(arg == "-o") {
      if(extraArgumentsNeeded(1, argc, index)) {
        index++;
        globalsettings.outfile = argv[index] + '\0';
      } else {
        std::cerr << red << "[FATAL]" << def << " Insufficent arguments: Use -h for syntax!" << std::endl;
        exit(-1);
      }
    } else if(arg == "-b") {
      if(extraArgumentsNeeded(1, argc, index)) {
        index++;
        globalsettings.outputBase = argv[index];
      } else {
        std::cerr << red << "[FATAL]" << def << " Insufficent arguments: Use -h for syntax!" << std::endl;
        exit(-1);
      }
    } else if(arg == "verbose") {
      globalsettings.verbose = true;
    }
  }
}

unsigned int hexStringToInt(const std::string &hexstr) {
  return std::stoul(hexstr, nullptr, 16);
}

bool extraArgumentsNeeded(int needed, int argc, int index) {
  if(index + needed >= argc) {
    return false;
  }

  return true;
}

std::vector<std::string> splitStr(const std::string &text, char sep) {
  std::vector<std::string> tokens;
  std::size_t start = 0, end = 0;
  while ((end = text.find(sep, start)) != std::string::npos) {
    tokens.push_back(text.substr(start, end - start));
    start = end + 1;
  }
  tokens.push_back(text.substr(start));
  return tokens;
}

int setBit(int num, unsigned int bit) {
  return num | 1u << bit;
}

int unsetBit(int num, unsigned int bit) {
  return num & ~(1u << bit);
}

int readBit(int num, unsigned int bit) {
  int mask =  1 << bit;
  int masked_n = num & mask;
  int thebit = masked_n >> bit;
  return thebit;
}

int toggleBit(int num, unsigned int bit) {
  return num ^ (1u << bit);
}
