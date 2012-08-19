#_ win32.mak
# Build win32 version of microemacs
# Needs Digital Mars D compiler to build, available free from:
# http://www.digitalmars.com/d/

#DMD=\cbx\mars\dmd
DMD=\dmd2\windows\bin\dmd
DEL=del

TARGET=med

DFLAGS=-g
LFLAGS=-L/map/co
#DFLAGS=
#LFLAGS=

.d.obj :
	$(DMD) -c $(DFLAGS) $*

SRC=\
	win32.mak linux.mak me.html \
	ed.d basic.d buffer.d display.d file.d fileio.d line.d \
	random.d region.d search.d spawn.d terminal.d \
	window.d word.d main.d more.d disprev.d \
	console.d mouse.d tcap.d disp.d

OBJa= ed.obj basic.obj buffer.obj display.obj file.obj fileio.obj line.obj
OBJb= random.obj region.obj search.obj spawn.obj terminal.obj
OBJc= window.obj word.obj main.obj more.obj disprev.obj
OBJd= console.obj mouse.obj

ALLOBJS=$(OBJa) $(OBJb) $(OBJc) $(OBJd)

all: $(TARGET).exe

#################################################

$(TARGET).exe : $(ALLOBJS)
	$(DMD) -of$(TARGET).exe $(ALLOBJS) $(LFLAGS)

###################################

clean:
	del $(ALLOBJS) $(TARGET).map


tolf:
	tolf $(SRC)


zip: tolf win32.mak
	$(DEL) med.zip
	zip32 med $(SRC)


git: tolf win32.mak
	\putty\pscp -i c:\.ssh\colossus.ppk $(SRC) walter@mercury:dm/med

