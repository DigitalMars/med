#_ linux.mak

DMD=dmd
MODEL=
S=src/med
O=obj
B=bin

DFLAGS=-g -od$O -I$S -d $(MODEL)
LDFLG=-g \
       -L~/cbx/mars/phobos/generated/linux/release/32 \
       -L~/cbx/mars/phobos/generated/linux/release/64 \


.d.o:
	$(DMD) -c $(DFLAGS) $*

all: $B/med

SRC= $S/ed.d $S/basic.d $S/buffer.d $S/display.d $S/file.d $S/fileio.d $S/line.d \
	$S/random.d $S/region.d $S/search.d $S/spawn.d $S/terminal.d \
	$S/window.d $S/word.d $S/main.d $S/more.d $S/disprev.d \
	$S/tcap.d \
	$S/console.d $S/mouse.d


OBJ= $O/ed.o $O/basic.o $O/buffer.o $O/display.o $O/file.o $O/fileio.o $O/line.o \
	$O/random.o $O/region.o $O/search.o $O/spawn.o $O/terminal.o \
	$O/window.o $O/word.o $O/main.o $O/more.o $O/disprev.o $O/tcap.o

SOURCE= $(SRC) win32.mak linux.mak me.html

$B/med : $(OBJ) linux.mak
#	gcc $(LDFLG) -o $B/med $(OBJ) -ltermcap
#	cc $(LDFLG)  -o $B/med $(OBJ) -l :libncurses.so.5 -l phobos2 -l pthread -l m
#	gcc $(LDFLG)  -o $B/med $(OBJ) -l :libncurses.so.5 -l libphobos2.a -l pthread -l m -l rt
	$(DMD) $(DFLAGS) -of$B/med $(OBJ) -Lncurses

$O/ed.o: $S/ed.d
	$(DMD) -c $(DFLAGS) $S/ed.d

$O/basic.o: $S/basic.d
	$(DMD) -c $(DFLAGS) $S/basic.d

$O/buffer.o: $S/buffer.d
	$(DMD) -c $(DFLAGS) $S/buffer.d

$O/display.o: $S/display.d
	$(DMD) -c $(DFLAGS) $S/display.d

$O/file.o: $S/file.d
	$(DMD) -c $(DFLAGS) $S/file.d

$O/fileio.o: $S/fileio.d
	$(DMD) -c $(DFLAGS) $S/fileio.d

$O/line.o: $S/line.d
	$(DMD) -c $(DFLAGS) $S/line.d

$O/random.o: $S/random.d
	$(DMD) -c $(DFLAGS) $S/random.d

$O/region.o: $S/region.d
	$(DMD) -c $(DFLAGS) $S/region.d

$O/search.o: $S/search.d
	$(DMD) -c $(DFLAGS) $S/search.d

$O/spawn.o: $S/spawn.d
	$(DMD) -c $(DFLAGS) $S/spawn.d

$O/terminal.o: $S/terminal.d
	$(DMD) -c $(DFLAGS) $S/terminal.d

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

$O/tcap.o: $S/tcap.d
	$(DMD) -c $(DFLAGS) $S/tcap.d

clean:
	rm $O/*.o

zip : $(SOURCE)
	rm -f me.zip
	zip me $(SOURCE)
