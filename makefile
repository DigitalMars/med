MODEL=32

#HOST_DMD=/usr/bin/dmd
#HOST_DMD=/home/walter/dmd2.067/linux/bin64/dmd
#HOST_DMD=/home/walter/dmd2.074.1/linux/bin64/dmd
#HOST_DMD=/home/walter/dmd2.079.1/linux/bin64/dmd
HOST_DMD=/home/walter/dmd2.089.1/linux/bin64/dmd
#HOST_DMD=/home/walter/cbx/mars/dmd2

MAKE=make DMD=$(HOST_DMD) MODEL=$(MODEL) -f linux.mak

targets:
	$(MAKE)

ansicolors:
	$(MAKE) ansicolors

detab:
	$(MAKE) detab

clean:
	$(MAKE) clean

zip:
	$(MAKE) zip
