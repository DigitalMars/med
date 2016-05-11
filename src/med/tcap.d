

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


module tcap;

version (none)
{
import ed;

import std.c.stdio;
import core.stdc.stdlib;
import std.c.string;
import std.c.time;
import core.sys.posix.termios;

extern (C) void cfmakeraw(in termios*);

termios  ostate;                 /* saved tty state */
termios  nstate;                 /* values for editor mode */


/* Termcap library functions
 * See: http://www.gnu.org/software/termutils/manual/termcap-1.3/html_node/termcap_toc.html
 */

extern (C)
{
    int tgetent(char *buffer, const char *termtype);
    int tgetnum (const char *name);
    int tgetflag (const char *name);
    const(char) *tgetstr (const char *name, const(char) **area);
    const(char) *tgoto (const(char) *cstring, int hpos, int vpos);
    const(char) *tparam (const(char) *ctlstring, char *buffer, int size, int parm1,...);
    char PC;
    short ospeed;
    int tputs (const(char) *string, int nlines, int function(int) outfun);
}

enum
{
    NROW    = 24,
    NCOL    = 80,
    BEL     = 0x07,
    ESC     = 0x1B,
}

char[2048] tcapbuf;
static const(char) *p;	/* roving pointer into tcapbuf[]	*/
const(char)*
	CM,
        CL,
        CE,
        UP,
        CD,
	KU,	/* up arrow key */
	KD,	/* down arrow key */
	KL,	/* left arrow key */
	KR,	/* right arrow key */
	K1,	/* second meta key */
	SO,	/* start standout mode */
	SE,	/* end standout mode */
	VB,	/* visible bell */
	CS,	/* scrolling region */
	SR,	/* scroll reverse */
	SF,	/* scroll forward */
	DO,	/* move down (alt for scroll forward) */
	AL,	/* add a line */
	DL;	/* delete a line */

/*
 * The LONGKEY structures are used to map the keys that produce
 * escape sequences to single return values.  Each LONGKEY element
 * is allocated as an array of LONGKEY structures.  lk[0].key is
 * the number of structure-1, lk[0].ptr is a backpointer.  lk[1] is
 * the first entry, etc.  These structures are dynamcially allocated
 * and linked at initialize time.  See tcapgetc() to see how they
 * are used.
 */

int LONGFINAL(char C) { return C & 0x80; }
int LONGCHAR(char C)  { return C & 0x7F; }

struct LONGKEY
{
	char key;
	union {
	  LONGKEY *ptr;
	  int keyv;
	}
}
LONGKEY *lkroot = null;

struct TERM
{
    short   t_nrow;              /* Number of rows.              */
    short   t_ncol;              /* Number of columns.           */
    bool    t_canscroll = true;

    void t_open()            /* Open terminal at the start.  */
    {
        auto tv_stype = getenv("TERM");
        if (tv_stype == null)
        {
	    puts("environment variable TERM not defined\n");
	    exit(1);
        }

        char[2048] tcbuf = void;
        auto success = tgetent(tcbuf.ptr, tv_stype);
        if (success < 0)
        {
	    printf("cannot access termcap database\n");
	    exit(1);
        }
        if (success == 0)
        {
	    printf("unknown terminal type %s\n", tv_stype);
	    exit(1);
        }

        p = tcapbuf.ptr;
        auto t = tgetstr("pc", &p);
        if (t)
	    PC = *t;	// set "padding capabilities"

	term.t_ncol = cast(short)tgetnum("co");
	term.t_nrow = cast(short)tgetnum("li");
        CD = tgetstr("cd", &p);
        CM = tgetstr("cm", &p);
        CE = tgetstr("ce", &p);
        UP = tgetstr("up", &p);
	//printf("UP=%p,%02x,%02x,%02x '%s'\n\n\n\n",UP,*UP,UP[1],UP[2],UP); fflush(stdout); sleep(1);
	VB = tgetstr("vb", &p);
	KU = tgetstr("ku", &p);
	//printf("KU=%p,%02x,%02x,%02x '%s'\n\n\n\n",KU,*KU,KU[1],KU[2],KU); fflush(stdout); sleep(3);
	KD = tgetstr("kd", &p);
	KL = tgetstr("kl", &p);
	KR = tgetstr("kr", &p);
	K1 = tgetstr("k1", &p);
	SO = tgetstr("so", &p);
	SE = tgetstr("se", &p);
	CS = tgetstr("cs", &p);
	SR = tgetstr("sr", &p);
	SF = tgetstr("sf", &p);
	DO = tgetstr("do", &p);
	AL = tgetstr("al", &p);
	DL = tgetstr("dl", &p);
	build_long_keys( tv_stype );

        if (CD == null || CM == null || CE == null || UP == null
	 || term.t_ncol < 1 || term.t_nrow < 1 )
        {
	    puts("Incomplete termcap entry\n");
	    exit(1);
        }

        if (p >= tcapbuf.ptr + tcapbuf.length)
        {
	    puts("Terminal description too big!\n");
	    exit(1);
        }

	if (AL && DL)
	{
	    scroll_type = 0;
	}
	else if (CS && SR && (SF || DO))
	{
	    scroll_type = 1;
	    if (!SF)
		SF = DO;
	}
	else
	{
	    t_canscroll = false;
	}

        /* Adjust output channel        */
        tcgetattr(1, &ostate);                       /* save old state */
        tcgetattr(1, &nstate);                       /* get base of new state */
	cfmakeraw(&nstate);
        tcsetattr(1, TCSADRAIN, &nstate);      /* set mode */

	if( strcmp(tv_stype,"vt100") == 0 )
		fputs("\033=",stdout);	/* turn on the keypad	*/
    }

    void t_close()            /* Close terminal at end.       */
    {
	if( strcmp(getenv("TERM"),"vt100") == 0 )
	    fputs("\033[?7h",stdout);	/* turn on autowrap	*/

        tcsetattr(1, TCSADRAIN, &ostate);	// return to original mode
    }

    int t_getchar()         /* Get character from keyboard. */
    {
	int c,i;
	LONGKEY* lkp,tmpp;

	static int backlen;
	static char[16] backc;

	/*
	 * If there was a previously almost complete LONGKEY sequence
	 * that failed, then we have to send the characters as if they
	 * were pressed individually.
	 */
    start:
	if( backlen )
		return( backc[--backlen] );

	/*
	 * Continue following the LONGKEY structure sequence until
	 * either there is a complete match, or there is a complete
	 * failure to match.
	 */
	lkp = lkroot;
    loop:
	c = fgetc(stdin);
	for(i=1; i<=lkp[0].key; i++)
	{
	    if( LONGCHAR(lkp[i].key) == c )
	    {
		//static int x;
		//printf("\nmatch %d\n",++x); fflush(stdout); sleep(2);
		if( LONGFINAL(lkp[i].key) )
		    return( lkp[i].keyv );
		lkp = lkp[i].ptr;
		goto loop;
	    }
	}

	/+
	for(i=1; i<=lkp[0].key; i++)
	{
	  printf("\nLONGCHAR[%d] = x%02x\n",i,lkp[i].key);
	}
	printf("no match for x%02x of %d entries\n",c,i); fflush(stdout); sleep(10);
	+/

	/*
	 * Upon a complete failure to match, we fill up the backc[]
	 * array with the ASCII characters that have been entered
	 * so that future calls to tcapgetc() can return these
	 * characters is the correct order.
	 */
	backc[backlen++] = cast(char)c;
	while( lkp[0].ptr != null )
	{
		tmpp = lkp;
		lkp = lkp[0].ptr;
		for(i=1; i<=lkp[0].key; i++)
			if( lkp[i].ptr == tmpp ) break;
		backc[backlen++] = lkp[i].key;
	}
	goto start;
    }

    extern (C) static int t_putchar(int c)   /* Put character to display.    */
    {
	return fputc(c, stdout);
    }

    void t_flush()           /* Flush output buffers.        */
    {
	fflush(stdout);
    }

    void t_move(int row, int col)  /* Move the cursor, origin 0.   */
    {
        putpad(tgoto(CM, col, row));
    }

    void t_eeol()            /* Erase to end of line.        */
    {
        putpad(CE);
    }

    void t_eeop()            /* Erase to end of page.        */
    {
        putpad(CD);
    }

    void t_beep()            /* Beep.                        */
    {
	if (VB)
	    putpad(VB);
	else
	    t_putchar(BEL);
    }

    void t_standout()        /* Start standout mode          */
    {
	if (SO)
	    putpad( SO );
    }

    void t_standend()        /* End standout mode            */
    {
	if (SE)
	    putpad( SE );
    }

    void t_scrollup(int first, int last)   /* Scroll the screen up         */
    {
	if (scroll_type)
	{
	    tpstr( CS, first, last );
	    t_move( last, 0 );
	    putpad( SF );
	    tpstr( CS, 0, term.t_nrow - 1 );
	    t_move( last, 0 );
	}
	else
	{
	    t_move( first, 0 );
	    putpad( DL );
	    t_move( last, 0 );
	    putpad( AL );
	}
    }

    void t_scrolldn(int first, int last)  /* Scroll the screen down       */
					  /* Note: scrolling routines do  */
					  /*  not save cursor position.   */
    {
	if (scroll_type)
	{
	    tpstr( CS, first, last );
	    t_move( first, 0 );
	    putpad( SR );
	    tpstr( CS, 0, term.t_nrow - 1 );
	    t_move( first, 0 );
	}
	else
	{
	    t_move( last, 0 );
	    putpad( DL );
	    t_move( first, 0 );
	    putpad( AL );
	}
    }

    void t_setcursor(int insertmode)
    {
    }
}


TERM term;

static int scroll_type;	/* type of scrolling region (used in tcapscr{up|dn}) */


void putpad(const(char)* str)
{
        tputs(str, 1, &TERM.t_putchar);
}

void putnpad(const(char)* str, int n)
{
        tputs(str, n, &TERM.t_putchar);
}

static void build_long_keys(const(char)* term )
{
    lkroot = cast(LONGKEY *)malloc(LONGKEY.sizeof);
    lkroot.key = 0;
    lkroot.ptr = null;

    version (linux)
    {
        build_one_long("\033[A", UPKEY);
	build_one_long("\033[B", DNKEY);
	build_one_long("\033[C", RTKEY);
	build_one_long("\033[D", LTKEY);
	build_one_long( "\033\x4F\x50", F1KEY );
	build_one_long( "\033\x4F\x51", F2KEY );
	build_one_long( "\033\x4F\x52", F3KEY );
	build_one_long( "\033\x4F\x53", F4KEY );
	build_one_long( "\033\x5B\x31\x31\x7E", F1KEY );
	build_one_long( "\033\x5B\x31\x32\x7E", F2KEY );
	build_one_long( "\033\x5B\x31\x33\x7E", F3KEY );
	build_one_long( "\033\x5B\x31\x34\x7E", F4KEY );
	build_one_long( "\033\x5B\x31\x35\x7E", F5KEY );
	build_one_long( "\033\x5B\x31\x37\x7E", F6KEY );
	build_one_long( "\033\x5B\x31\x38\x7E", F7KEY );
	build_one_long( "\033\x5B\x31\x39\x7E", F8KEY );
	build_one_long( "\033\x5B\x32\x30\x7E", F9KEY );
	build_one_long( "\033\x5B\x32\x31\x7E", F10KEY );


	build_one_long("\033\x62", ALTB );
	build_one_long("\033\x63", ALTC );
	build_one_long("\033\x64", ALTD );
	build_one_long("\033\x64", ALTE );
	build_one_long("\033\x66", ALTF );
	build_one_long("\033\x68", ALTH );
	build_one_long("\033\x6D", ALTM );
	build_one_long("\033\x78", ALTX );
	build_one_long("\033\x7A", ALTZ );

	build_one_long("\033\x5B\x32\x7E", InsKEY );
	build_one_long("\033\x5B\x33\x7E", DelKEY );
	build_one_long("\033\x5B\x31\x7E", HOMEKEY );
	build_one_long("\033\x5B\x34\x7E", ENDKEY );
	build_one_long("\033\x5B\x35\x7E", PgUpKEY );
	build_one_long("\033\x5B\x36\x7E", PgDnKEY );
    }
    else
    {
	build_one_long( KU, UPKEY );
	build_one_long( KD, DNKEY );
	build_one_long( KR, RTKEY );
	build_one_long( KL, LTKEY );
	build_one_long( K1, GOLDKEY );
	build_one_long( tgetstr("kR",&p), SCROLLUPKEY ); /* scroll back */
	build_one_long( tgetstr("kF",&p), SCROLLDNKEY ); /* scroll forw */
	build_one_long( tgetstr("kP",&p), PAGEUPKEY ); /* prev page */
	build_one_long( tgetstr("kN",&p), PAGEDNKEY ); /* next page */
	if( strcmp(term,"vt100") == 0 )
	{
		build_one_long( "\033OQ", PF2KEY );
		build_one_long( "\033OR", PF3KEY );
		build_one_long( "\033OS", PF4KEY );
		build_one_long( "\033Op", F0KEY );
		build_one_long( "\033Oq", F1KEY );
		build_one_long( "\033Or", F2KEY );
		build_one_long( "\033Os", F3KEY );
		build_one_long( "\033Ot", F4KEY );
		build_one_long( "\033Ou", F5KEY );
		build_one_long( "\033Ov", F6KEY );
		build_one_long( "\033Ow", F7KEY );
		build_one_long( "\033Ox", F8KEY );
		build_one_long( "\033Oy", F9KEY );
		build_one_long( "\033Om", FMINUSKEY );
		build_one_long( "\033Ol", FCOMMAKEY );
		build_one_long( "\033On", FDOTKEY );
		build_one_long( "\033OM", FENTERKEY );
	}
	else
	{
		build_one_long( tgetstr("k2",&p), PF2KEY );
		build_one_long( tgetstr("k3",&p), PF3KEY );
		build_one_long( tgetstr("k4",&p), PF4KEY );
		build_one_long( tgetstr("k5",&p), F5KEY );
		build_one_long( tgetstr("k6",&p), F6KEY );
		build_one_long( tgetstr("k7",&p), F7KEY );
		build_one_long( tgetstr("k8",&p), F8KEY );
		build_one_long( tgetstr("k9",&p), F9KEY );
		build_one_long( "\033Op", F0KEY );
		build_one_long( "\033Oq", F1KEY );
		build_one_long( "\033Or", F2KEY );
		build_one_long( "\033Os", F3KEY );
		build_one_long( "\033Ot", F4KEY );
		build_one_long( "\033Om", FMINUSKEY );
		build_one_long( "\033[229z", FCOMMAKEY );
		build_one_long( "\033Ol", FCOMMAKEY );
		build_one_long( "\033OM", FENTERKEY );
	}
    }
}

static void build_one_long(const(char)* s, int keyval)
{
	int i;
	LONGKEY* lkp,tmpp,tmpq;

	if (!s)
		return;
	lkp = lkroot;
	while( *s )
	{
		for(i=1; i<=lkp[0].key; i++)
			if( lkp[i].key == *s ) break;
		if( i != lkp[0].key+1 )
		{
			lkp = lkp[i].ptr;
			s++;
		}
		else
		{
			tmpp = cast(LONGKEY *)malloc(
				LONGKEY.sizeof * ++i );
			while( i-- )
			{
				tmpp[i].key = lkp[i].key;
				tmpp[i].ptr = lkp[i].ptr;
			}
			if( lkp[0].ptr )
			{
				tmpq = lkp[0].ptr;
				for(i=1; i<=tmpq[0].key; i++)
					if( tmpq[i].ptr == lkp )
						tmpq[i].ptr = tmpp;
			}
			else
				lkroot = tmpp;
			free( lkp );
			lkp = tmpp;
			for(i=1; i<=lkp[0].key; i++)
				if( !LONGFINAL(lkp[i].key) )
					lkp[i].ptr.ptr = lkp;
			lkp[0].key++;
			lkp[lkp[0].key].key = *s++;
			if( !*s )
			{
				lkp[lkp[0].key].keyv = keyval;
				lkp[lkp[0].key].key |= 0x80;
			}
			else
			{
				tmpp = lkp;
				lkp = lkp[lkp[0].key].ptr = cast(LONGKEY *)
					malloc( LONGKEY.sizeof );
				lkp[0].key = 0;
				lkp[0].ptr = tmpp;
			}
		}
	}
}

void tpstr(const(char)* str, int p1, int p2)
{
	char[128] buf = '\0';
	char* pt = buf.ptr;
	int pi;

	pi = p1;
	while( *str >= '0' && *str <= '9' ) *pt++ = *str++;
	if( *str == '*' ) *pt++ = *str++;
	while( *str )
	{
		if( *str == '%' )
		{	str++;
			switch( *str++ )
			{
			  case 'd':
				sprintf(pt,"%d",pi);
				pi = p2; break;
			  case '2':
				sprintf(pt,"%2d",pi);
				pi = p2; break;
			  case '3':
				sprintf(pt,"%3d",pi);
				pi = p2; break;
			  case '.':
				sprintf(pt,"%c",pi);
				pi = p2; break;
			  case 'r':
				pi = p2;
				p2 = p1;
				p1 = pi;
				break;
			  case 'i':
				p1++; p2++; pi++; break;
			  case '%':
				*pt++ = '%'; break;
			  default:
				strcpy(pt,"\nTERMCAP Error\n");
				break;
			}
			pt = buf.ptr + strlen(buf.ptr);
		}
		else
			*pt++ = *str++;
	}
	*pt = '\0';
	putpad( buf.ptr );
}

debug
{
    void dump_longs()
    {
	printf("__dump__\n");
	dump_one_long( 0, lkroot, null );
	printf("________\n");
    }

    int backcheck = 0;

    void dump_one_long( int offset, LONGKEY* lkp, LONGKEY* lkprev )
    {
	int i,j;
	if( backcheck )
	{
		for(j=0; j<offset; j++) printf(" ");
		printf( (lkprev == lkp[0].ptr) ? "TRUE\n" : "FALSE\n" );
	}
	for(i=1; i<=lkp[0].key; i++)
	{
		for(j=0; j<offset; j++) printf(" ");
		printf("%d (%c)      ",
			LONGCHAR(lkp[i].key), LONGCHAR(lkp[i].key));
		if( LONGFINAL(lkp[i].key) )
			printf("return( %d )\n", lkp[i].keyv );
		else
		{	printf("\n");
			dump_one_long( offset+1, lkp[i].ptr, lkp );
		}
	}
    }
}

/**************************
 * Return true if there are unread chars ready in the input.
 */

bool ttkeysininput()
{
    return false;
}

/******************************
 */

void ttyield()
{
}

/******************************
 */

int msm_init()
{
    return FALSE;	// no mouse support
}

int mouse_command()
{
    return 0;		// no mouse input
}
}
