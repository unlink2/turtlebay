#include <ostream>
#include"include/colour.h"
namespace Colour {
  // global colours
  Modifier red(Colour::FG_RED);
  Modifier def(Colour::FG_DEFAULT);

  // class definition

  Modifier::Modifier(Code pCode): code(pCode) {

  }
}
