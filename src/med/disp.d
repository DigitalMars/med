

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/* D interface to Digital Mars C/C++ disp package.
 * Windows only.
 * http://www.digitalmars.com/rtl/disp.html
 */

module disp;

version (Windows)
{

extern (C)
{

struct disp_t
{ align(1):
    uint numrows;
    uint numcols;
    uint cursorrow;
    uint cursorcol;
    ubyte mono;
    ubyte snowycga;
    ubyte mode;
    ubyte inited;
    ubyte ega;
    ubyte[3] reserved;
    short nowrap;

    union
    {
	ushort *base;
	struct
	{   uint offset;
	    ushort basep;
	}
    }
    void *handle;
}

extern __gshared disp_t disp_state;

int	disp_printf(char *,...);
int	disp_getmode();
int	disp_getattr();
int	disp_putc(int);
void	disp_levelblockpoke(int,int,int,int,uint,uint *,uint,uint *,uint);
void	disp_open();
void	disp_puts(const char *);
void	disp_box(int,int,uint,uint,uint,uint);
void	disp_close();
void	disp_move(int,int);
void	disp_flush();
void	disp_eeol();
void	disp_eeop();
void	disp_startstand();
void	disp_endstand();
void	disp_setattr(int);
void	disp_setcursortype(int);
void	disp_pokew(int,int,ushort);
void	disp_scroll(int,uint,uint,uint,uint,uint);
void	disp_setmode(ubyte);
void	disp_peekbox(ushort *,uint,uint,uint,uint);
void	disp_pokebox(ushort *,uint,uint,uint,uint);
void	disp_fillbox(uint,uint,uint,uint,uint);
void	disp_hidecursor();
void	disp_showcursor();
ushort	disp_peekw(int,int);

enum
{
    DISP_REVERSEVIDEO       = 0x70,
    DISP_NORMAL             = 0x07,
    DISP_UNDERLINE          = 0x01,
    DISP_NONDISPLAY         = 0x00,

    DISP_INTENSITY          = 0x08,
    DISP_BLINK              = 0x80,

    DISP_CURSORBLOCK	    = 100,
    DISP_CURSORHALF	    = 50,
    DISP_CURSORUL	    = 20,
}

}

}
