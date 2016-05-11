

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The routines in this file provide support for computers with
 * WIN32 console I/O support.
 */

module console;

version (Windows)
{

import std.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.windows;
import core.sys.windows.winuser;

import ed;
import disp;


enum BEL = 0x07;                    /* BEL character.               */
enum ESC = 0x1B;                    /* ESC character.               */


static HANDLE hStdin;			// console input handle
static DWORD fdwSaveOldMode;

static INPUT_RECORD lookaheadir;
static int lookahead;			// !=0 if data in lookaheadir

/*
 * Standard terminal interface dispatch table. Most of the fields point into
 * "termio" code.
 */



struct TERM
{
    int   t_nrow;              /* Number of rows.              */
    int   t_ncol;              /* Number of columns.           */

    void t_open()             /* Open terminal at the start.  */
    {
	hStdin  = GetStdHandle(STD_INPUT_HANDLE);
	if (hStdin == INVALID_HANDLE_VALUE)
	{   printf("getstdhandle\n");
	    exit(EXIT_FAILURE);
	}

	if (!GetConsoleMode(hStdin,&fdwSaveOldMode))
	{   printf("getconsolemode\n");
	    exit(EXIT_FAILURE);
	}

	if (!SetConsoleMode(hStdin,ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT))
	{   printf("setconsolemode\n");
	    exit(EXIT_FAILURE);
	}

	disp_open();
	disp_setcursortype(DISP_CURSORBLOCK);
	t_ncol = disp_state.numcols;
	t_nrow = disp_state.numrows;
    }

    void t_close()            /* Close terminal at end.       */
    {
	disp_close();

	if (!SetConsoleMode(hStdin,fdwSaveOldMode))
	{   printf("restore console mode\n");
	    exit(EXIT_FAILURE);
	}
    }

    int t_getchar()          /* Get character from keyboard. */
    {
	INPUT_RECORD buf;
	DWORD cNumRead;
	int c;

	while (1)
	{
	    if (lookahead)
	    {   buf = lookaheadir;
		lookahead = 0;
	    }
	    else if (!ReadConsoleInputW(hStdin,&buf,1,&cNumRead))
	    {   c = 3;				// ^C
		goto Lret;
	    }

	    switch (buf.EventType)
	    {
		case MOUSE_EVENT:
		    mstat_update(&buf.MouseEvent);
		    continue;

		default:
		    continue;			// ignore

		case KEY_EVENT:
		    c = win32_keytran(&buf.KeyEvent);
		    if (!c)
			continue;
		    goto Lret;
	    }
	}

    Lret:
	return c;
    }

    void t_putchar(int c)          /* Put character to display.    */
    {
	disp_putc(c);
    }

    void t_flush()            /* Flush output buffers.        */
    {
	disp_flush();
    }

    void t_move(int row, int col)         /* Move the cursor, origin 0.   */
    {
	disp_move(row, col);
    }

    void t_eeol()             /* Erase to end of line.        */
    {
	disp_eeol();
    }

    void t_eeop()             /* Erase to end of page.        */
    {
	disp_eeop();
    }

    void t_beep()             /* Beep.                        */
    {
	disp_putc(BEL);
    }

    void t_standout()         /* Start standout mode          */
    {
	disp_startstand();
    }

    void t_standend()         /* End standout mode            */
    {
	disp_endstand();
    }

    void t_scrollup()         /* Scroll the screen up         */
    {
    }

    void t_scrolldn()         /* Scroll the screen down       */
				 /* Note: scrolling routines do  */
				 /*  not save cursor position.   */
    {
    }

    void t_setcursor(int insertmode)
    {
	disp_setcursortype(insertmode ? DISP_CURSORBLOCK : DISP_CURSORUL);
    }
}

TERM term;

/********************************************
 */

void updateline(int row,attchar_t[] buffer,attchar_t[] physical)
{
    int col;
    int numcols;
    CHAR_INFO *psb;
    CHAR_INFO[256] sbbuf;
    CHAR_INFO *sb;
    COORD sbsize;
    static COORD sbcoord;
    SMALL_RECT sdrect;

    sbsize.X = cast(short)disp_state.numcols;
    sbsize.Y = 1;
    sbcoord.X = 0;
    sbcoord.Y = 0;
    sdrect.Left = 0;
    sdrect.Top = cast(short)row;
    sdrect.Right = cast(short)(disp_state.numcols - 1);
    sdrect.Bottom = cast(short)row;
    numcols = disp_state.numcols;
    sb = sbbuf.ptr;
    if (numcols > sbbuf.length)
    {
	sb = cast(CHAR_INFO *)alloca(numcols * CHAR_INFO.sizeof);
    }
    for (col = 0; col < numcols; col++)
    {
	auto c = buffer[col].chr;
	sb[col].UnicodeChar = cast(WCHAR)c;
	sb[col].Attributes = buffer[col].attr;
	if (c >= 0x10000)
	{
	    /* Calculate surrogate pairs, but don't know yet how they
	     * work, if at all, with WriteConsoleOutput()
	     */
	    auto c0 = cast(wchar)((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
	    auto c1 = cast(wchar)(((c - 0x10000) & 0x3FF) + 0xDC00);
	}
	//printf("col = %2d, x%2x, '%c'\n",col,sb[col].AsciiChar,sb[col].AsciiChar);
    }
    if (!WriteConsoleOutputW(cast(HANDLE)disp_state.handle,sb,sbsize,sbcoord,&sdrect))
    {
	// error
    }
    physical[] = buffer[];
}

/*********************************
 */

extern (C) int msm_init()
{
    return GetSystemMetrics(SM_MOUSEPRESENT);
}

extern (C)
{
    void	msm_term() { }
    void	msm_showcursor() { }
    void	msm_hidecursor() { }
}

struct msm_status		// current state of mouse
{
    uint row;
    uint col;
    int buttons;
}

msm_status mstat;

/*************************
 * Fold MOUSE_EVENT into mstat.
 */

static void mstat_update(MOUSE_EVENT_RECORD *pme)
{
    mstat.row = pme.dwMousePosition.Y;
    mstat.col = pme.dwMousePosition.X;
    mstat.buttons = pme.dwButtonState & 3;
}

extern (C) int msm_getstatus(uint *pcol,uint *prow)
{
    INPUT_RECORD buf;
    DWORD cNumRead;

    if (lookahead)
    {	buf = lookaheadir;
	cNumRead = 1;
    }
    else if (!PeekConsoleInputA(hStdin,&buf,1,&cNumRead))
	goto Lret;

    if (cNumRead)
	switch (buf.EventType)
	{
	    case MOUSE_EVENT:
		mstat_update(&buf.MouseEvent);
	    default:
	    Ldiscard:
		if (lookahead)
		    lookahead = 0;
		else
		    ReadConsoleInputA(hStdin,&buf,1,&cNumRead);	// discard
		break;

	    case KEY_EVENT:
		if (mstat.buttons & 3)
		    goto Ldiscard;
		break;
	}

Lret:
    *prow = mstat.row;
    *pcol = mstat.col;
    return mstat.buttons;
}

/*************************************
 * Translate key from WIN32 to IBM PC style.
 * Returns:
 *	0 if ignore it
 */

static uint win32_keytran(KEY_EVENT_RECORD *pkey)
{   uint c;

    c = 0;
    if (!pkey.bKeyDown)
	goto Lret;				// ignore button up events
    c = pkey.UnicodeChar;
    if (c == 0)
    {
	switch (pkey.wVirtualScanCode)
	{
	    case 0x1D:				// Ctrl
	    case 0x38:				// Alt
	    case 0x2A:				// Left Shift
	    case 0x36:				// Right Shift
		break;				// ignore
	    default:
		c = (pkey.wVirtualScanCode << 8) & 0xFF00;
		if (pkey.dwControlKeyState & (RIGHT_CTRL_PRESSED | LEFT_CTRL_PRESSED))
		{
		    final switch (c)
		    {   case 0x4700:	c = 0x7700;	break;	// Home
			case 0x4F00:	c = 0x7500;	break;	// End
			case 0x4900:	c = 0x8400;	break;	// PgUp
			case 0x5100:	c = 0x7600;	break;	// PgDn
		    }
		}
		break;
	}
    }
    else if (pkey.dwControlKeyState & (RIGHT_ALT_PRESSED | LEFT_ALT_PRESSED))
    {
	c = (pkey.wVirtualScanCode << 8) & 0xFF00;
    }
Lret:
    return c;
}

/*************************************
 * Wait for any input (yield to other processes).
 */

void ttyield()
{
    if (!lookahead)
    {
	DWORD cNumRead;

	if (!ReadConsoleInputA(hStdin,&lookaheadir,1,&cNumRead))
	{   printf("readconsoleinput\n");
	    goto Lret;
	}
    }
    lookahead = 1;
Lret: ;
}

/*************************************
 */

int ttkeysininput()
{
    INPUT_RECORD buf;
    DWORD cNumRead;

    if (lookahead)
    {	buf = lookaheadir;
	cNumRead = 1;
    }
    else if (!PeekConsoleInputA(hStdin,&buf,1,&cNumRead))
	goto Lret;

    if (cNumRead)
    {
	switch (buf.EventType)
	{
	    case MOUSE_EVENT:
		mstat_update(&buf.MouseEvent);
	    default:
	    Ldiscard:
		if (lookahead)
		    lookahead = 0;
		else
		    ReadConsoleInputA(hStdin,&buf,1,&cNumRead);	// discard
		cNumRead = 0;
		break;

	    case KEY_EVENT:
		if (!win32_keytran(&buf.KeyEvent))
		    goto Ldiscard;
		break;
	}
    }

Lret:
    return cNumRead != 0;
}

extern (C) void popen() { assert(0); }

void setClipboard(const(char)[] s)
{
    if (OpenClipboard(null))
    {
	EmptyClipboard();

	HGLOBAL hmem = GlobalAlloc(GMEM_MOVEABLE, (s.length + 1) * char.sizeof);
	if (hmem)
	{
	    auto p = cast(char*)GlobalLock(hmem);
	    memcpy(p, s.ptr, s.length * char.sizeof);
	    p[s.length] = 0;
	    GlobalUnlock(hmem);

	    SetClipboardData(CF_TEXT, hmem);
	}
	CloseClipboard();
    }
}

char[] getClipboard()
{
    char[] s = null;
    if (IsClipboardFormatAvailable(CF_TEXT) &&
        OpenClipboard(null))
    { 
	HANDLE h = GetClipboardData(CF_TEXT);	// CF_UNICODETEXT is UTF-16
	if (h)
	{   
	    auto p = cast(char*)GlobalLock(h); 
	    if (p)
	    {
		size_t length = strlen(p);
		s = p[0 .. length].dup;
	    }
	    GlobalUnlock(h);
	} 
	CloseClipboard();
    }
    return s; 
}

/***********************
 * Open browser on help file.
 */

int help(bool f, int n)
{
    printf("\nhelp \n");
    char[MAX_PATH + 1] resolved_name = void;
    if (GetModuleFileNameA(NULL, resolved_name.ptr, MAX_PATH + 1))
    {
	size_t len = strlen(resolved_name.ptr);
	size_t i;
	for (i = len; i; --i)
	{
	    if (resolved_name[i] == '/' ||
		resolved_name[i] == '\\' ||
		resolved_name[i] == ':')
	    {
		++i;
		break;
	    }
	}
	immutable(char)[7] doc = "me.html";
	if (i + doc.sizeof <= MAX_PATH)
	{
	    import std.process;
	    memcpy(resolved_name.ptr + i, doc.ptr, doc.sizeof);
    printf("\nhelp2 '%.*s'\n", cast(int)(i + doc.sizeof), resolved_name.ptr);
	    browse(cast(string)resolved_name[0 .. i + doc.sizeof]);
	}
    }
    return ed.FALSE;
}

}

