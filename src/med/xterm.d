
module xterm;

version (Posix)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.sys.ioctl;

import ed;
import termio;

enum
{
    NROW    = 24,
    NCOL    = 80,
    BEL     = 0x07,
    ESC     = 0x1B,
}

/*********************************
 */

int msm_init()
{
    puts("\x1b[?1000h");
    return TRUE;
}

void msm_term()
{
    puts("\x1b[?1000l");
}

void	msm_showcursor() { }
void	msm_hidecursor() { }

struct msm_status		// current state of mouse
{
    int state;
    uint row;
    uint col;
}

__gshared msm_status mstat;

int msm_getstatus(uint *pcol,uint *prow)
{
    int c = 0;
    switch (mstat.state)
    {
	case 0:
	    *prow = mstat.row;
	    *pcol = mstat.col;
	    return 0;

	case 1:
	    *prow = mstat.row;
	    *pcol = mstat.col;
	    mstat.state++;
	    return 1;

	case 2:
	    c = ttgetc();
	    if (c == 0x1b)
	    {   c = ttgetc();
		if (c == 0x5b)
		{   c = ttgetc();
		    if (c == 0x4d)
		    {   c = ttgetc();
			if (c == 0x23)
			{   c = ttgetc();
			    if (c >= 0x21)
			    {   mstat.col = c - 0x21;
				c = ttgetc();
				if (c >= 0x21)
				    mstat.row = c - 0x21;
			    }
			}
		    }
		}
	    }
	    *prow = mstat.row;
	    *pcol = mstat.col;
	    mstat.state++;
	    return 1;

	case 3:
	    *prow = mstat.row;
	    *pcol = mstat.col;
	    mstat.state = 0;
	    return 0;

	default:
	    assert(0);
    }
}


immutable(char)*
        PC,
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
int LONGFINAL(int C) { return C & 0x80; }
int LONGCHAR(int C)  { return C & 0x7F; }

struct LONGKEY {
	ubyte key;
	union {
	  LONGKEY* ptr;
	  int keyv;
	}
}

LONGKEY *lkroot = null;

struct TERM
{
    short   t_nrow;              /* Number of rows.              */
    short   t_ncol;              /* Number of columns.           */
    bool    t_canscroll = true;

    void t_open()
    {
	// Get size of terminal
	winsize ws;
	import core.sys.posix.sys.ioctl;
	ioctl(1, TIOCGWINSZ, &ws);

	//printf("Columns: %d\tRows: %d\n", ws.ws_col, ws.ws_row);
	term.t_ncol = ws.ws_col;
	term.t_nrow = ws.ws_row;

	CD = "\x1b\x5b\x4a".ptr;
	CM = "\x1b\x5b\x25\x69\x25\x64\x3b\x25\x64\x48".ptr; // "\x1b"\x1b[%i%d;%dH"
	CE = "\x1b\x5b\x4b".ptr;
	UP = "\x1b\x5b\x41".ptr;
	VB = "\x1b\x5b\x3f\x35\x68\x1b\x5b\x3f\x35\x6c".ptr;
	KU = "\x1b\x4f\x41".ptr;
	KD = "\x1b\x4f\x42".ptr;
	KL = "\x1b\x4f\x44".ptr;
	KR = "\x1b\x4f\x43".ptr;
	K1 = "\x1b\x4f\x50".ptr;
	SO = "\x1b\x5b\x37\x6d".ptr;
	SE = "\x1b\x5b\x32\x37\x6d".ptr;
	CS = "\x1b\x5b\x25\x69\x25\x64\x3b\x25\x64\x72".ptr;
	SR = "\x1b\x4d".ptr;
	SF = "\x0a".ptr;
	DO = "\x0a".ptr;
	AL = "\x1b\x5b\x4c".ptr;
	DL = "\x1b\x5b\x4d".ptr;

	build_long_keys();

        if ( term.t_ncol < 1 || term.t_nrow < 1 )
        {
                puts("Incomplete termcap entry\n");
                exit(1);
        }

	if(AL && DL)
	{
		scroll_type = 0;
	}
	else if (CS && SR && (SF || DO))
	{
		scroll_type = 1;
		if( !SF ) SF = DO;
	}
	else
	{
		assert(0);
		//term.t_scrollup = null;
		//term.t_scrolldn = null;
	}

        ttopen();
    }

    void t_close()
    {
	if( strcmp(getenv("TERM"),"vt100") == 0 )
		fputs("\033[?7h",stdout);	/* turn on autowrap	*/
	ttclose();
	msm_term();
    }

    int t_getchar()         /* Get character from keyboard. */
    {
	int c,i;
	LONGKEY* lkp, tmpp;

	static int backlen;
	static char[16] backc;

	/*
	 * If there was a previously almost complete LONGKEY sequence
	 * that failed, then we have to send the characters as if they
	 * were pressed individually.
	 */
    start:
	/*
	 * Continue following the LONGKEY structure sequence until
	 * either there is a complete match, or there is a complete
	 * failure to match.
	 */
	lkp = lkroot;
    loop:
	if (backlen)
	    c = backc[--backlen];
	else
	    c = fgetc(stdin);
	for(i=1; i<=lkp[0].key; i++)
	{
	    if( LONGCHAR(lkp[i].key) == c )
	    {
		//static int x;
		//printf("\nmatch %d\n",++x); fflush(stdout); sleep(2);
		if( LONGFINAL(lkp[i].key) )
		{
			c = lkp[i].keyv;
			if (c == MOUSEKEY)
			{
			    if (backlen)
				c = backc[--backlen];
			    else
				c = ttgetc();
			    mstat.col = c - 0x21;
			    if (backlen)
				c = backc[--backlen];
			    else
				c = ttgetc();
			    mstat.row = c - 0x21;
			    mstat.state = 1;
			    c = MOUSEKEY;
			}
			return c;
		}
		lkp = lkp[i].ptr;
		goto loop;
	    }
	}

	version (none)
	{
	    for(i=1; i<=lkp[0].key; i++)
	    {
	      printf("\nLONGCHAR[%d] = x%02x\n",i,lkp[i].key);
	    }
	    printf("no match for x%02x of %d entries\n",c,i); fflush(stdout); sleep(10);
	}

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
	return backc[--backlen];
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
	printf("\x1b[%d;%dH", row + 1, col + 1);
        //putpad(tgoto(CM, col, row));
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


void putpad(const(char) *str)
{
	while (*str)
	{   ttputc(*str);
	    str++;
	}
        //tputs(str, 1, ttputc);
}

void putnpad(const char *str, int n)
{
	while (n--)
	    ttputc(str[n]);
        //tputs(str, n, ttputc);
}

void build_long_keys()
{
	lkroot = cast(LONGKEY *)malloc( LONGKEY.sizeof );
	lkroot.key = 0;	lkroot.ptr = null;

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
	build_one_long( "\033\x5B\x32\x34\x7E", F12KEY );


	build_one_long("\033\x62", ALTB );
	build_one_long("\033\x63", ALTC );
	build_one_long("\033\x64", ALTD );
	build_one_long("\033\x65", ALTE );
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

	build_one_long("\033\x5B\x4d\x20", MOUSEKEY );
}

void build_one_long( const(char) *s, int keyval )
{
	int i;
	LONGKEY* lkp, tmpp, tmpq;

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
			++i;
			tmpp = cast(LONGKEY *)malloc( LONGKEY.sizeof * i );
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

void tpstr( const(char) *str, int p1, int p2 )
{
	char[128] buf;
	char *pt = buf.ptr;
	int pi;

	for(pi=0; pi<128;) buf[pi++] = '\0';
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

    void dump_one_long( int offset, LONGKEY *lkp, LONGKEY *lkprev )
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

}
