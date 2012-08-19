#_ linux.mak

DMD=~/cbx/mars/dmd

DFLAGS=-g
LDFLG=-g

.d.o:
	$(DMD) -c $(DFLAGS) $*

all: med

SRC= ed.d basic.d buffer.d display.d file.d fileio.d line.d \
	random.d region.d search.d spawn.d terminal.d \
	window.d word.d main.d more.d disprev.d \
	tcap.d

OBJ= ed.o basic.o buffer.o display.o file.o fileio.o line.o \
	random.o region.o search.o spawn.o terminal.o \
	window.o word.o main.o more.o disprev.o \
	tcap.o

SOURCE= $(SRC) win32.mak linux.mak me.html console.d mouse.d

med : $(OBJ) linux.mak
#	gcc $(LDFLG) -o med $(OBJ) -ltermcap
	cc $(LDFLG)  -o med $(OBJ) -l :libncurses.so.5 -l phobos2 -l pthread -l m

ed.o: ed.d
	$(DMD) -c $(DFLAGS) $*

basic.o: basic.d
	$(DMD) -c $(DFLAGS) $*

buffer.o: buffer.d
	$(DMD) -c $(DFLAGS) $*

display.o: display.d
	$(DMD) -c $(DFLAGS) $*

file.o: file.d
	$(DMD) -c $(DFLAGS) $*

fileio.o: fileio.d
	$(DMD) -c $(DFLAGS) $*

line.o: line.d
	$(DMD) -c $(DFLAGS) $*

random.o: random.d
	$(DMD) -c $(DFLAGS) $*

region.o: region.d
	$(DMD) -c $(DFLAGS) $*

search.o: search.d
	$(DMD) -c $(DFLAGS) $*

spawn.o: spawn.d
	$(DMD) -c $(DFLAGS) $*

terminal.o: terminal.d
	$(DMD) -c $(DFLAGS) $*

window.o: window.d
	$(DMD) -c $(DFLAGS) $*

word.o: word.d
	$(DMD) -c $(DFLAGS) $*

main.o: main.d
	$(DMD) -c $(DFLAGS) $*

more.o: more.d
	$(DMD) -c $(DFLAGS) $*

disprev.o: disprev.d
	$(DMD) -c $(DFLAGS) $*

tcap.o: tcap.d
	$(DMD) -c $(DFLAGS) $*

clean:
	rm $(OBJ)

zip : $(SOURCE)
	rm -f me.zip
	zip me $(SOURCE)






