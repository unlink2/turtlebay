#ifndef UTIL_H
#define UTIL_H

#include <vector>
#include<iostream>
#include<cstdint>

// this struct holds program settings
struct Settings {
  unsigned int minorVersion;
  unsigned int majorVersion;
  unsigned int patch;
  std::string appname;
  std::string dev;
  std::string github;
  std::string email;

  std::string appmode; // mode the app is in (sprite is the only one right now!)
  std::string outputBase;
  std::string inputfile;
  std::string outfile;
  uint32_t *colours; // pointer to as many colours are the user input
  unsigned short coloursLen;
  bool verbose;
};

extern Settings globalsettings;

/*
This function inits the program and settings struct
*/
void init();

/*
This function parses CLI arguments based on criteria
*/
void parseArgs(int argc, char **argv);

/*
This is just a helper function to make my life easier
*/
unsigned int hexStringToInt(const std::string &hexstr);

/*
This function determines if the arguments needed
are still covered by an array with size n
*/
bool extraArgumentsNeeded(int needed, int argc, int index);

/*
This function splits a string at a specific char and
returns an std::vector of all split elements
*/
std::vector<std::string> splitStr(const std::string &text, char sep);

int setBit(int num, unsigned int bit);

int unsetBit(int num, unsigned int bit);

int readBit(int num, unsigned int bit);

int toggleBit(int num, unsigned int bit);

#endif
