#_ linux.mak

DMD=dmd
MODEL=32
S=src/med
O=obj
B=bin

DFLAGS=-g -od$O -I$S -m$(MODEL)
LDFLG=-g \
       -L~/cbx/mars/phobos/generated/linux/release/32 \
       -L~/cbx/mars/phobos/generated/linux/release/64 \


.d.o:
	$(DMD) -c $(DFLAGS) $*

all: $B/med

SRC= $S/ed.d $S/basic.d $S/buffer.d $S/display.d $S/file.d $S/fileio.d $S/line.d \
	$S/random.d $S/region.d $S/search.d $S/spawn.d $S/terminal.d \
	$S/window.d $S/word.d $S/main.d $S/more.d $S/disprev.d \
	$S/syntaxd.d $S/syntaxc.d $S/syntaxcpp.d $S/termio.d $S/xterm.d \
	$S/tcap.d $S/console.d $S/mouse.d $S/disp.d $S/url.d $S/utf.d $S/regexp.d


OBJ= $O/ed.o $O/basic.o $O/buffer.o $O/display.o $O/file.o $O/fileio.o $O/line.o \
	$O/random.o $O/region.o $O/search.o $O/spawn.o $O/terminal.o \
	$O/window.o $O/word.o $O/main.o $O/more.o $O/disprev.o \
	$O/syntaxd.o $O/syntaxc.o $O/syntaxcpp.o $O/termio.o $O/xterm.o \
	$O/tcap.o $O/console.o $O/mouse.o $O/disp.o $O/url.o $O/utf.o $O/regexp.o

SOURCE= $(SRC) win32.mak linux.mak me.html

$B/med : $(OBJ) linux.mak
	$(DMD) $(DFLAGS) -of$B/med $(OBJ)

ansicolors : $S/ansicolors.d
	$(DMD) $(DFLAGS) -of$B/ansicolors $S/ansicolors.d

$O/ed.o: $S/ed.d
	$(DMD) -c $(DFLAGS) $S/ed.d

$O/basic.o: $S/basic.d
	$(DMD) -c $(DFLAGS) $S/basic.d

$O/buffer.o: $S/buffer.d
	$(DMD) -c $(DFLAGS) $S/buffer.d

$O/console.o: $S/console.d
	$(DMD) -c $(DFLAGS) $S/console.d

$O/disp.o: $S/disp.d
	$(DMD) -c $(DFLAGS) $S/disp.d

$O/display.o: $S/display.d
	$(DMD) -c $(DFLAGS) $S/display.d

$O/file.o: $S/file.d
	$(DMD) -c $(DFLAGS) $S/file.d

$O/fileio.o: $S/fileio.d
	$(DMD) -c $(DFLAGS) $S/fileio.d

$O/line.o: $S/line.d
	$(DMD) -c $(DFLAGS) $S/line.d

$O/mouse.o: $S/mouse.d
	$(DMD) -c $(DFLAGS) $S/mouse.d

$O/random.o: $S/random.d
	$(DMD) -c $(DFLAGS) $S/random.d

$O/regexp.o: $S/regexp.d
	$(DMD) -c $(DFLAGS) $S/regexp.d

$O/region.o: $S/region.d
	$(DMD) -c $(DFLAGS) $S/region.d

$O/search.o: $S/search.d
	$(DMD) -c $(DFLAGS) $S/search.d

$O/spawn.o: $S/spawn.d
	$(DMD) -c $(DFLAGS) $S/spawn.d

$O/terminal.o: $S/terminal.d
	$(DMD) -c $(DFLAGS) $S/terminal.d

$O/termio.o: $S/termio.d
	$(DMD) -c $(DFLAGS) $S/termio.d

$O/url.o: $S/url.d
	$(DMD) -c $(DFLAGS) $S/url.d

$O/window.o: $S/window.d
	$(DMD) -c $(DFLAGS) $S/window.d

$O/word.o: $S/word.d
	$(DMD) -c $(DFLAGS) $S/word.d

$O/main.o: $S/main.d
	$(DMD) -c $(DFLAGS) $S/main.d

$O/more.o: $S/more.d
	$(DMD) -c $(DFLAGS) $S/more.d

$O/disprev.o: $S/disprev.d
	$(DMD) -c $(DFLAGS) $S/disprev.d

$O/syntaxd.o: $S/syntaxd.d
	$(DMD) -c $(DFLAGS) $S/syntaxd.d

$O/syntaxc.o: $S/syntaxc.d
	$(DMD) -c $(DFLAGS) $S/syntaxc.d

$O/syntaxcpp.o: $S/syntaxcpp.d
	$(DMD) -c $(DFLAGS) $S/syntaxcpp.d

$O/tcap.o: $S/tcap.d
	$(DMD) -c $(DFLAGS) $S/tcap.d

$O/utf.o: $S/utf.d
	$(DMD) -c $(DFLAGS) $S/utf.d

$O/xterm.o: $S/xterm.d
	$(DMD) -c $(DFLAGS) $S/xterm.d

clean:
	rm $O/*.o

detab : $(SRC)
	detab $(SRC)

zip : $(SOURCE)
	rm -f me.zip
	zip me $(SOURCE)
