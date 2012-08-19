#_ win32.mak
# Build win32 version of microemacs
# Needs Digital Mars D compiler to build, available free from:
# http://www.digitalmars.com/d/

DMD=\cbx\mars\dmd

TARGET=med

DFLAGS=-g
LFLAGS=-L/map/co

.d.obj :
	$(DMD) -c $(DFLAGS) $*

OBJa= ed.obj basic.obj buffer.obj display.obj file.obj fileio.obj line.obj
OBJb= random.obj region.obj search.obj spawn.obj terminal.obj
OBJc= window.obj word.obj main.obj more.obj disprev.obj
OBJd= console.obj mouse.obj

ALLOBJS=$(OBJa) $(OBJb) $(OBJc) $(OBJd)

all: $(TARGET).exe

#################################################

$(TARGET).exe : $(ALLOBJS)
	$(DMD) -of$(TARGET).exe $(ALLOBJS) $(LFLAGS)

###### Source file dependencies ######

###################################

clean:
	del $(ALLOBJS) $(TARGET).map

zip:	win32.mak linux.mak
	del me.zip
	zip32 me win32.mak linux.mak me.html
	zip32 me ed.d basic.d buffer.d display.d file.d fileio.d line.d
	zip32 me random.d region.d search.d spawn.d terminal.d
	zip32 me window.d word.d main.d more.d disprev.d
	zip32 me console.d mouse.d

