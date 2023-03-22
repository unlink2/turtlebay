CC = g++
CFLAGS = -g `libpng-config --cflags`
LIBS = `libpng-config --ldflags`

LIBDIR = ./lib
IDIR = ./src/include
ODIR = ./obj
BINDIR = ./bin
SRCDIR = ./src

_DEPS = imageconverter.h util.h colour.h
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = main.o imageconverter.o util.o colour.o
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))

$(ODIR)/%.o: $(SRCDIR)/%.cpp $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

png2bin: $(OBJ)
	$(CC) -o $(BINDIR)/$@ $^ $(LIBS)

.PHONY: clean
clean:
	rm $(ODIR)/*.o
	rm $(BINDIR)/*
