#_ win32.mak
# Build win32 version of microemacs
# Needs Digital Mars D compiler to build, available free from:
# http://www.digitalmars.com/d/

DMD=dmd
DEL=del
S=src\med
O=obj
B=bin

TARGET=med

//DFLAGS=-g -Isrc/med $(CONF)
DFLAGS=-O -Isrc/med $(CONF)
LFLAGS=-L/map/co
#DFLAGS=
#LFLAGS=

.d.obj :
	$(DMD) -c $(DFLAGS) $*

SRC= $S\ed.d $S\basic.d $S\buffer.d $S\display.d $S\file.d $S\fileio.d $S\line.d \
	$S\random.d $S\region.d $S\search.d $S\spawn.d $S\terminal.d \
	$S\window.d $S\word.d $S\main.d $S\more.d $S\disprev.d \
	$S\termio.d $S\xterm.d $S\syntaxd.d $S\syntaxc.d $S\syntaxcpp.d \
	$S\tcap.d $S\console.d $S\mouse.d $S\disp.d $S\url.d $S\utf.d $S\regexp.d


OBJ= $O\ed.obj $O\basic.obj $O\buffer.obj $O\display.obj $O\file.obj $O\fileio.obj $O\line.obj \
	$O\random.obj $O\region.obj $O\search.obj $O\spawn.obj $O\terminal.obj \
	$O\window.obj $O\word.obj $O\main.obj $O\more.obj $O\disprev.obj \
	$O\termio.obj $O\xterm.obj $O\syntaxd.obj $O\syntaxc.obj $O\syntaxcpp.obj \
	$O\tcap.obj $O\console.obj $O\mouse.obj $O\disp.obj $O\url.obj $O\utf.obj $O\regexp.obj

SOURCE= $(SRC) win32.mak linux.mak me.html README.md

all: $B\$(TARGET).exe

#################################################

$B\$(TARGET).exe : $(OBJ)
	$(DMD) -of$B\$(TARGET).exe $(OBJ) $(LFLAGS)

$O\ed.obj: $S\ed.d
	$(DMD) -c $(DFLAGS) -od$O $S\ed.d

$O\basic.obj: $S\basic.d
	$(DMD) -c $(DFLAGS) -od$O $S\basic.d

$O\buffer.obj: $S\buffer.d
	$(DMD) -c $(DFLAGS) -od$O $S\buffer.d

$O\console.obj: $S\console.d
	$(DMD) -c $(DFLAGS) -od$O $S\console.d

$O\disp.obj: $S\disp.d
	$(DMD) -c $(DFLAGS) -od$O $S\disp.d

$O\display.obj: $S\display.d
	$(DMD) -c $(DFLAGS) -od$O $S\display.d

$O\file.obj: $S\file.d
	$(DMD) -c $(DFLAGS) -od$O $S\file.d

$O\fileio.obj: $S\fileio.d
	$(DMD) -c $(DFLAGS) -od$O $S\fileio.d

$O\line.obj: $S\line.d
	$(DMD) -c $(DFLAGS) -od$O $S\line.d

$O\mouse.obj: $S\mouse.d
	$(DMD) -c $(DFLAGS) -od$O $S\mouse.d

$O\random.obj: $S\random.d
	$(DMD) -c $(DFLAGS) -od$O $S\random.d

$O\regexp.obj: $S\regexp.d
	$(DMD) -c $(DFLAGS) -od$O $S\regexp.d

$O\region.obj: $S\region.d
	$(DMD) -c $(DFLAGS) -od$O $S\region.d

$O\search.obj: $S\search.d
	$(DMD) -c $(DFLAGS) -od$O $S\search.d

$O\spawn.obj: $S\spawn.d
	$(DMD) -c $(DFLAGS) -od$O $S\spawn.d

$O\syntaxd.obj: $S\syntaxd.d
	$(DMD) -c $(DFLAGS) -od$O $S\syntaxd.d

$O\syntaxc.obj: $S\syntaxc.d
	$(DMD) -c $(DFLAGS) -od$O $S\syntaxc.d

$O\syntaxcpp.obj: $S\syntaxcpp.d
	$(DMD) -c $(DFLAGS) -od$O $S\syntaxcpp.d

$O\terminal.obj: $S\terminal.d
	$(DMD) -c $(DFLAGS) -od$O $S\terminal.d

$O\termio.obj: $S\termio.d
	$(DMD) -c $(DFLAGS) -od$O $S\termio.d

$O\url.obj: $S\url.d
	$(DMD) -c $(DFLAGS) -od$O $S\url.d

$O\utf.obj: $S\utf.d
	$(DMD) -c $(DFLAGS) -od$O $S\utf.d

$O\window.obj: $S\window.d
	$(DMD) -c $(DFLAGS) -od$O $S\window.d

$O\word.obj: $S\word.d
	$(DMD) -c $(DFLAGS) -od$O $S\word.d

$O\main.obj: $S\main.d
	$(DMD) -c $(DFLAGS) -od$O $S\main.d

$O\more.obj: $S\more.d
	$(DMD) -c $(DFLAGS) -od$O $S\more.d

$O\disprev.obj: $S\disprev.d
	$(DMD) -c $(DFLAGS) -od$O $S\disprev.d

$O\tcap.obj: $S\tcap.d
	$(DMD) -c $(DFLAGS) -od$O $S\tcap.d

$O\xterm.obj: $S\xterm.d
	$(DMD) -c $(DFLAGS) -od$O $S\xterm.d

###################################

clean:
	del $(OBJ) $B\$(TARGET).map


tolf:
	tolf $(SOURCE)


detab:
	detab $(SRC)


zip: tolf detab
	$(DEL) me.zip
	zip32 me $(SOURCE)


git: tolf detab win32.mak
	\putty\pscp -i c:\.ssh\colossus.ppk $(SRC) walter@mercury:dm/med/src/med
	\putty\pscp -i c:\.ssh\colossus.ppk win32.mak linux.mak me.html README.md walter@mercury:dm/med/

