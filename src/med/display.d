

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


/*
 * The functions in this file handle redisplay. There are two halves, the
 * ones that update the virtual display screen, and the ones that make the
 * physical display screen the same as the virtual display screen. These
 * functions use hints that are left in the windows by the commands.
 *
 * REVISION HISTORY:
 *
 * ?    Steve Wilhite, 1-Dec-85
 *      - massive cleanup on code.
 */

module display;

import core.stdc.stdio;
import core.stdc.string;

import std.format;
import std.path;

import ed;
import line;
import window;
import main;
import buffer;
import disprev;
import console;
import termio;
import terminal;
import xterm;
import url;
import utf;

int max(int a, int b) { return a > b ? a : b; }

enum SHOWCONTROL = 1;

char column_mode = FALSE;

// debug=WFDEBUG                       /* Window flag debug. */
attchar_t[] blnk_ln;

version (Windows)
    alias ushort vchar;
else
    alias char vchar;

ubyte[] vrowflags;
enum VFCHG = 0x0001;                  /* Changed. */

int display_recalc()
{
    foreach (wp; windows)
	wp.w_flag |= WFHARD | WFMODE;
    return TRUE;
}

version (Windows)
{
int display_eol_bg(bool f, int n)
{
    config.eolattr += 0x10;
    return display_recalc();
}

int display_norm_bg(bool f, int n)
{
    config.normattr += 0x10;
    return display_recalc();
}

int display_norm_fg(bool f, int n)
{
    config.normattr = (config.normattr & 0xF0) + ((config.normattr + 1) & 0xF);
    return display_recalc();
}

int display_mode_bg(bool f, int n)
{
    config.modeattr += 0x10;
    return display_recalc();
}

int display_mode_fg(bool f, int n)
{
    config.modeattr = (config.modeattr & 0xF0) + ((config.modeattr + 1) & 0xF);
    return display_recalc();
}

int display_mark_bg(bool f, int n)
{
    config.markattr += 0x10;
    return display_recalc();
}

int display_mark_fg(bool f, int n)
{
    config.markattr = (config.markattr & 0xF0) + ((config.markattr + 1) & 0xF);
    return display_recalc();
}
}
else
{
int display_eol_bg(bool f, int n)
{
    return FALSE;
}

int display_norm_bg(bool f, int n)
{
    return FALSE;
}

int display_norm_fg(bool f, int n)
{
    return FALSE;
}

int display_mode_bg(bool f, int n)
{
    return FALSE;
}

int display_mode_fg(bool f, int n)
{
    return FALSE;
}

int display_mark_bg(bool f, int n)
{
    return FALSE;
}

int display_mark_fg(bool f, int n)
{
    return FALSE;
}
}

int	sgarbf	= TRUE;			/* TRUE if screen is garbage */
int	mpresf	= FALSE;		/* TRUE if message in last line */
int	vtrow	= 0;			/* Row location of SW cursor */
int	vtcol	= 0;			/* Column location of SW cursor */
int	ttrow	= HUGE;			/* Row location of HW cursor */
int	ttcol	= HUGE;			/* Column location of HW cursor */
attr_t	attr;				/* Attribute for chars to vtputc() */
int	hardtabsize = 8;		// hardware tab size

attchar_t[][] vscreen;                      /* Virtual screen. */
attchar_t[][] pscreen;                      /* Physical screen. */

/*
 * Initialize the data structures used by the display code. The edge vectors
 * used to access the screens are set up. The operating system's terminal I/O
 * channel is set up. All the other things get initialized at compile time.
 * The original window has "WFCHG" set, so that it will get completely
 * redrawn on the first call to "update".
 */
void vtinit()
{
    term.t_open();
    vscreen = new attchar_t[][term.t_nrow];
    pscreen = new attchar_t[][term.t_nrow];
    vrowflags = new ubyte[term.t_nrow];

    version (linux)
    {
	blnk_ln = new attchar_t[term.t_ncol];
    }

    foreach (i; 0 .. term.t_nrow)
    {
	vscreen[i] = new attchar_t[term.t_ncol];
	pscreen[i] = new attchar_t[term.t_ncol];
    }
}

/*
 * Clean up the virtual terminal system, in anticipation for a return to the
 * operating system. Move down to the last line and clear it out (the next
 * system prompt will be written in the line). Shut down the channel to the
 * terminal.
 */
void vttidy()
{
    foreach (i; 0 .. term.t_nrow)
    {
	delete vscreen[i];
	delete pscreen[i];
    }
    delete vscreen;
    delete pscreen;

    version (Windows)
    {
	movecursor(term.t_nrow - 1, 0);
	term.t_close();
	printf("\n");			/* scroll up one line		*/
    }
    else
    {
	movecursor(term.t_nrow - 1, 0);
	term.t_putchar('\n');		/* scroll up one line		*/
	term.t_close();
    }
}

/*
 * Set the virtual cursor to the specified row and column on the virtual
 * screen. There is no checking for nonsense values; this might be a good
 * idea during the early stages.
 */
void vtmove(int row, int col)
{
    vtrow = row;
    vtcol = col;
}

/*
 * Write a character to the virtual screen. The virtual row and column are
 * updated. If the line is too long put a "+" in the last column. This routine
 * only puts printing characters into the virtual terminal buffers. Only
 * column overflow is checked.
 * Startcol is the starting column on the screen.
 */
void vtputc(dchar c, int startcol, int tabbase = 0)
{
    vtputc(c, startcol, tabbase, attr);
}

void vtputc(dchar c, int startcol, int tabbase, attr_t attr)
{
    auto vp = vscreen[vtrow];

    if (vtcol - startcol >= term.t_ncol)
    {
	vp[term.t_ncol - 1].chr = '+';
	vp[term.t_ncol - 1].attr = config.modeattr;
    }
    else if (c == '\t')
    {
	auto i = hardtabsize - ((vtcol - tabbase) % hardtabsize);
	do
            vtputc(config.tabchar, startcol, tabbase, attr);
	while (--i);
    }
    else if (SHOWCONTROL && (c < 0x20 || c == 0x7F))
    {
        vtputc('^',startcol, tabbase, attr);
        vtputc(c ^ 0x40,startcol, tabbase, attr);
    }
    else
    {
	if (vtcol - startcol == 0 && startcol != 0)
	{
            vp[0].chr = '+';
            vp[0].attr = config.modeattr;
	}
	else if (vtcol - startcol >= 0)
	{
	    vp[vtcol - startcol].chr = c;
	    vp[vtcol - startcol].attr = attr;
	}
	vtcol++;
    }
}

/****************************
 * Compute column number of line given index into that line.
 */

int getcol(LINE *dotp, int doto)
{
    return getcol2(dotp.l_text, doto);
}

int getcol2(const(char)[] dotp, int doto)
{
    int curcol = 0;
    size_t i = 0;
    while (i < doto)
    {
	const c = decodeUTF8(dotp, i);

	if (c == '\t')
	{
	    if (hardtabsize == 8)
		curcol |= 7;
	    else
	    {
		curcol = ((curcol + hardtabsize) / hardtabsize) * hardtabsize - 1;
	    }
	}
	else if (SHOWCONTROL && (c < 0x20 || c == 0x7F))
	    ++curcol;
	++curcol;
    }
    return curcol;
}

/******************************************
 * Inverse of getcol(), i.e. find offset into line that is closest
 * to or past column col.
 */

int coltodoto(LINE* lp, int col)
{
    size_t len = llength(lp);
    int i = 0;
    while (i < len)
    {
	if (getcol(lp, i) >= col)
	    return i;
	ulong j = i;
	decodeUTF8(lp.l_text, j);
    }
    return i;
}

/***********************
 * Write a string to vtputc().
 */

static void vtputs(const char[] s, int startcol, int tabbase = 0)
{
    for (size_t i = 0; i < s.length; )
    {
	dchar c = decodeUTF8(s, i);
	vtputc(c, startcol, tabbase);
    }
}

/*
 * Erase from the end of the software cursor to the end of the line on which
 * the software cursor is located.
 */
void vteeol(int startcol)
{
    const col = max(vtcol - startcol, 0);
    vscreen[vtrow][col .. term.t_ncol] = attchar_t(' ', config.eolattr);
    vtcol = startcol + term.t_ncol;
}

/*
 * Make sure that the display is right. This is a three part process. First,
 * scan through all of the windows looking for dirty ones. Check the framing,
 * and refresh the screen. Second, make sure that "currow" and "curcol" are
 * correct for the current window. Third, make the virtual and physical
 * screens the same.
 */

void update()
{
    LINE *lp;
    int k;
    int l_first,l_last;
    int scroll_done_flag;
    int wcol;
    int curcol;				/* cursor column from left of text */
    char inmark;			/* if column marking, and in region */
version (MOUSE)
    char hidden;

    if (ttkeysininput())		/* if more user input		*/
	return;				/* skip updating till caught up	*/

    curcol = getcol(curwp.w_dotp,curwp.w_doto);
    if ((lastflag&CFCPCN) == 0)		/* Reset goal if last		*/
	curgoal = curcol;		/* not backline() or forwline()	*/

    /* If cursor is off left or right side, set update bit so it'll scroll */
    if (curwp.w_startcol && curcol <= curwp.w_startcol ||
	curcol > curwp.w_startcol + term.t_ncol - 2)
	curwp.w_flag |= WFHARD;

    foreach (wp; windows)		// for each window
    {
        /* Look at any window with update flags set on. */
        if (wp.w_flag != 0)
	{   char marking = wp.w_markp != null;
	    int col_left,col_right;		/* for column marking	*/

            /* If not force reframe, check the framing. */
            if ((wp.w_flag & WFFORCE) == 0)
	    {
                lp = wp.w_linep;	/* top line on screen		*/

                for (int i = 0; 1; ++i)
		{
		    /* if not on screen	*/
		    if (i == wp.w_ntrows)
		    {   if (lp == wp.w_dotp ||
			    wp.w_dotp == wp.w_bufp.b_linep)
			    wp.w_force = -1;	/* one up from bottom	*/
			else if (wp.w_dotp == lback(wp.w_linep))
			    wp.w_force = 1;	/* one before top	*/
			break;
		    }

                    if (lp == wp.w_dotp)	/* if dot is on screen	*/
                        goto Lout;		/* no reframe necessary	*/

                    if (lp == wp.w_bufp.b_linep)
                        break;			/* reached end of buffer */

                    lp = lforw(lp);
		}

            } /* if not force reframe */

	    /* A reframe is necessary.
             * Compute a new value for the line at the
             * top of the window. Then set the "WFHARD" flag to force full
             * redraw.
             */
	    {
            int i = wp.w_force;

            if (i > 0)		/* if set dot to be on ith window line	*/
	    {
                --i;

                if (i >= wp.w_ntrows)
                  i = wp.w_ntrows-1;	/* clip i to size of window	*/
	    }
            else if (i < 0)	/* if set dot to be -ith line from bottom */
	    {
                i += wp.w_ntrows;

                if (i < 0)
                    i = 0;	/* clip to top of screen		*/
	    }
            else		/* set to center of screen		*/
                i = wp.w_ntrows/2;

            lp = wp.w_dotp;
            while (i != 0 && lback(lp) != wp.w_bufp.b_linep)
	    {
                --i;
                lp = lback(lp);
	    }
	    }

            wp.w_linep = lp;
            wp.w_flag |= WFHARD;       /* Force full. */

Lout:
	    /* Determine cursor column. If cursor is off the left or the  */
	    /* right, readjust starting column and do a WFHARD update	  */
	    wcol = getcol(wp.w_dotp,wp.w_doto);
	    if (wp.w_startcol && wcol <= wp.w_startcol)
	    {	wp.w_startcol = wcol ? wcol - 1 : 0;
		wp.w_flag |= WFHARD;
	    }
	    else if (wp.w_startcol < wcol - term.t_ncol + 2)
	    {	wp.w_startcol = wcol - term.t_ncol + 2;
		wp.w_flag |= WFHARD;
	    }

	    /* Determine if we should start out with a standout		  */
	    /* attribute or not, depends on if mark is before the window. */
	    attr = config.normattr;
	    if (marking)
	    {
		inmark = FALSE;
		for (lp = lforw(wp.w_bufp.b_linep);
		     lp != wp.w_linep;
		     lp = lforw(lp))
			if (lp == wp.w_markp)
			{   inmark = TRUE;
			    break;
			}
		if (column_mode)
		{
		    /* Calculate left and right column numbers of region */
		    col_right = markcol;/*getcol(wp.w_markp,wp.w_marko);*/
		    if (curgoal <= col_right)
			col_left = curgoal;
		    else
		    {	col_left = col_right;
			col_right = curgoal;
		    }
		}
		else
		{   if (inmark)
		    {	attr = config.markattr;
			inmark = FALSE;
		    }
		}
	    }

	    /* The window is framed properly now.
             * Try to use reduced update. Mode line update has its own special
             * flag. The fast update is used if the only thing to do is within
             * the line editing.
             */
            lp = wp.w_linep;		/* line of top of window	  */
            int i = wp.w_toprow;	/* display row # of top of window */

	    if ((wp.w_flag & (WFFORCE | WFEDIT | WFHARD | WFMOVE)) == WFEDIT)
            {	/* Only need to update the line that the cursor is on	*/

		/* Determine row number and line pointer for cursor line */
                while (lp != wp.w_dotp)
                {   ++i;
                    lp = lforw(lp);
                }

                vrowflags[i] |= VFCHG;	/* assume this line will change */
                vtmove(i, 0);			/* start at beg of line	*/

		for (size_t j = 0; j < llength(lp); )
		{
		    auto b = inURL(lp.l_text[], j);
		    dchar c = decodeUTF8(lp.l_text, j);
		    if (attr == config.normattr && b)
			vtputc(c, wp.w_startcol, 0, config.urlattr);
		    else
			vtputc(c, wp.w_startcol);
		}

                vteeol(wp.w_startcol);		/* clear remainder of line */
             }
             else if ((wp.w_flag & (WFEDIT | WFHARD)) != 0 ||
		      marking && wp.w_flag & WFMOVE)
	     {	/* update every line in the window	*/
                while (i < wp.w_toprow+wp.w_ntrows)
                {
                    vrowflags[i] |= VFCHG;
                    vtmove(i, 0);
                    if (lp != wp.w_bufp.b_linep) /* if not end of buffer */
                    {
			if (marking && column_mode)
			{   if (wp.w_markp == lp)
				inmark++;
			    if (wp.w_dotp == lp)
				inmark++;
			    attr = config.normattr;
			}

                        for (size_t j = 0; 1; )
			{   if (marking)
			    {	if (column_mode)
				{
				    if (inmark && col_left <= vtcol)
					attr = config.markattr;
				    if (col_right <= vtcol)
					attr = config.normattr;
				}
				else
				{
				    if (wp.w_markp == lp && wp.w_marko == j)
					attr ^= config.normattr ^ config.markattr;
				    if (wp.w_dotp == lp && wp.w_doto == j)
					attr ^= config.normattr ^ config.markattr;
				}
			    }
			    if (j >= llength(lp))
				break;

			    auto b = inURL(lp.l_text[], j);
			    dchar c = decodeUTF8(lp.l_text, j);
			    if (attr == config.normattr && b)
				vtputc(c, wp.w_startcol, 0, config.urlattr);
			    else
				vtputc(c, wp.w_startcol);
			}
			if (inmark == 2)
			    inmark = 0;
                        lp = lforw(lp);
                    }
                    vteeol(wp.w_startcol);
                    ++i;
                }
            }
debug (WFDEBUG)
{
}
else
{
            if ((wp.w_flag&WFMODE) != 0)	/* if mode line is modified */
                modeline(wp);
            wp.w_flag  = 0;
            wp.w_force = 0;
}
        } /* if any update flags on */
debug (WFDEBUG)
{
        modeline(wp);
        wp.w_flag =  0;
        wp.w_force = 0;
}
    } /* for each window */

    /* Always recompute the row and column number of the hardware cursor. This
     * is the only update for simple moves.
     */
    lp = curwp.w_linep;
    currow = curwp.w_toprow;

    while (lp != curwp.w_dotp)
    {
        ++currow;
        lp = lforw(lp);
    }

    /* Special hacking if the screen is garbage. Clear the hardware screen,
     * and update your copy to agree with it. Set all the virtual screen
     * change bits, to force a full update.
     */
version (MOUSE)
    hidden = 0;

    if (sgarbf != FALSE)
    {
        for (int i = 0; i < term.t_nrow; ++i)
	{
            vrowflags[i] |= VFCHG;
	    for (int j = 0; j < term.t_ncol; j++)
	    {
		pscreen[i][j].chr = ' ';
		pscreen[i][j].attr = config.normattr;
	    }
	}

version (MOUSE)
{
	if (!hidden && mouse)
	{   msm_hidecursor();
	    hidden++;
	}
}
	ttrow = HUGE;
	ttcol = HUGE;			// don't know where they are
        movecursor(0, 0);               /* Erase the screen. */
        term.t_eeop();
        sgarbf = FALSE;                 /* Erase-page clears */
        mpresf = FALSE;                 /* the message area. */
    }

version (linux)
{
    /* Here we check to see if we can scroll any of the lines.
     * This silly routine just checks for possibilites of scrolling
     * lines one line in either direction, but not multiple lines.
     */
    if( !term.t_canscroll ) goto no_scroll_possible;
    scroll_done_flag = 0;
    for (int i = 0; i < term.t_nrow; i++)
    {
	if( vrowflags[i] & VFCHG )
	{
		/* if not first line					*/
		/* and current line is identical to previous line	*/
		/* and previous line is not blank			*/
		if( i > 0
		&& vrowflags[i - 1] & VFCHG
		&& vscreen[i] == pscreen[i-1]
		&& pscreen[i-1] != blnk_ln )
		{
			/* Scroll screen down	*/
			l_first = i-1;	/* first line of scrolling region */
			while( i<term.t_nrow
			&& vrowflags[i - 1] & VFCHG
			&& vscreen[i] == pscreen[i-1] )
				i++;
			l_last = i-1;	/* last line of scrolling region */
			term.t_scrolldn( l_first, l_last );
			scroll_done_flag++;
			for (int j = l_first+1; j < l_last+1; j++ )
				vrowflags[j] &= ~VFCHG;
			for (int j = l_last; j > l_first; j-- )
				pscreen[j][] = pscreen[j - 1][];
			pscreen[l_first][] = attchar_t.init;

			/* Set change flag on last line to get rid of	*/
			/* bug that caused lines to 'vanish'.		*/
			vrowflags[l_first] |= VFCHG;
		}
		else if( i < term.t_nrow-1
		&& vrowflags[i + 1] & VFCHG
		&& vscreen[i] == pscreen[i+1]
		&& pscreen[i+1] != blnk_ln )
		{
			l_first = i;
			while( i<term.t_nrow-1
			&& vrowflags[i + 1] & VFCHG
			&& vscreen[i] == pscreen[i+1] )
				i++;
			l_last = i;
			term.t_scrollup( l_first, l_last );
			scroll_done_flag++;
			for (int j = l_first; j < l_last; j++ )
				vrowflags[j] &= ~VFCHG;
			for (int j = l_first; j < l_last; j++ )
				pscreen[j][] = pscreen[j + 1];
			pscreen[l_last][] = attchar_t.init;

			/* Set change flag on last line to get rid of	*/
			/* bug that caused lines to 'vanish'.		*/
			vrowflags[l_last] |= VFCHG;
		}
	}
    }
    if( scroll_done_flag )
    {
	ttrow = ttrow-1;	/* force a change */
	movecursor(currow, curcol - curwp.w_startcol);
    }

  no_scroll_possible:
    ;
}
    /* Make sure that the physical and virtual displays agree. Unlike before,
     * the "updateline" code is only called with a line that has been updated
     * for sure.
     */
    for (int i = 0; i < term.t_nrow; ++i)
    {
        if (vrowflags[i] & VFCHG)
	{
version (MOUSE)
{
	    if (!hidden && mouse)
	    {	msm_hidecursor();
		hidden++;
	    }
}
            vrowflags[i] &= ~VFCHG;
	    updateline(i, vscreen[i], pscreen[i]);
	}
    }

    /* Finally, update the hardware cursor and flush out buffers. */

version (Windows)
{
    term.t_move(currow,curcol - curwp.w_startcol);	/* putline() trashed the cursor pos */
    ttrow = currow;
    ttcol = curcol - curwp.w_startcol;
}
else
{
    movecursor(currow, curcol - curwp.w_startcol);
}
    term.t_flush();
version (MOUSE)
{
    if (hidden && mouse)
	msm_showcursor();
}
}

/*
 * Update a single line. This does not know how to use insert or delete
 * character sequences; we are using VT52 functionality. Update the physical
 * row and column variables. It does try an exploit erase to end of line. The
 * RAINBOW version of this routine uses fast video.
 */
version (linux)
{
void updateline(int row, attchar_t[] vline, attchar_t[] pline)
{
    attchar_t *cp3;
    attchar_t *cp4;
    attchar_t *cp5;
    int nbflag;
    static int tstand = FALSE;		/* TRUE if standout mode is active */

    auto cp1 = &vline[0];                    /* Compute left match.  */
    auto cp2 = &pline[0];

    while (cp1 != vline.ptr + term.t_ncol && cp1[0] == cp2[0])
    {
        ++cp1;
        ++cp2;
    }

    /* This can still happen, even though we only call this routine on changed
     * lines. A hard update is always done when a line splits, a massive
     * change is done, or a buffer is displayed twice. This optimizes out most
     * of the excess updating. A lot of computes are used, but these tend to
     * be hard operations that do a lot of update, so I don't really care.
     */
    if (cp1 == vline.ptr + term.t_ncol)             /* All equal. */
        return;

    nbflag = FALSE;
    cp3 = vline.ptr + term.t_ncol;          /* Compute right match. */
    cp4 = pline.ptr + term.t_ncol;

    while (cp3[-1] == cp4[-1])
        {
        --cp3;
        --cp4;
        if (cp3.chr != ' ' || cp3.attr)     /* Note if any nonblank */
            nbflag = TRUE;              /* in right match. */
        }

    cp5 = cp3;

    if (nbflag == FALSE)                /* Erase to EOL ? */
        {
        while (cp5!=cp1 && cp5[-1].chr==' ' && cp5[-1].attr == 0)
            --cp5;

        if (cp3-cp5 <= 3)               /* Use only if erase is */
            cp5 = cp3;                  /* fewer characters. */
        }

    movecursor(row, cast(int)(cp1-&vline[0]));     /* Go to start of line. */

    while (cp1 != cp5)                  /* Ordinary. */
    {
	if( cp1.attr & STANDATTR )
	{	if( !tstand ) {	term.t_standout(); tstand = TRUE;	} }
	else
	{	if(  tstand ) {	term.t_standend(); tstand = FALSE;	} }
        term.t_putchar(cp1.chr);
        ++ttcol;
        *cp2++ = *cp1++;
    }

    if (cp5 != cp3)                     /* Erase. */
        {
        term.t_eeol();
        while (cp1 != cp3)
            *cp2++ = *cp1++;
        }
	if( tstand )
	{	term.t_standend();
		tstand = FALSE;
	}
}
}

/*
 * Redisplay the mode line for the window pointed to by the "wp". This is the
 * only routine that has any idea of how the modeline is formatted. You can
 * change the modeline format by hacking at this routine. Called by "update"
 * any time there is a dirty window.
 */
void modeline(WINDOW* wp)
{
    char *cp;
    int c;
    int n;
    BUFFER *bp;

    n = wp.w_toprow+wp.w_ntrows;              /* Location. */
    vrowflags[n] |= VFCHG;                /* Redraw next time. */
    vtmove(n, 0);                               /* Seek to right line. */
    attr = config.modeattr;
    bp = wp.w_bufp;

    if (bp.b_flag & BFRDONLY)
	vtputc('R',0);
    else if ((bp.b_flag&BFCHG) != 0)                /* "*" if changed. */
        vtputc('*',0);
    else
        vtputc('-',0);

    if (kbdmip)
        vtputc('M',0);
    else
        vtputc(' ',0);

    vtputs(EMACSREV,0);
    vtputc(' ', 0);

    if (globMatch(bp.b_bname,bp.b_fname) == 0)
    {	vtputs("-- Buffer: "c,0);
	vtputs(bp.b_bname,0);
	vtputc(' ',0);
    }
    if (bp.b_fname.length)            /* File name. */
    {
	vtputs("-- File: "c,0);
	vtputs(bp.b_fname,0);
        vtputc(' ',0);
    }

debug (WFDEBUG)
{
    vtputc('-',0);
    vtputc((wp.w_flag&WFMODE)!=0  ? 'M' : '-',0);
    vtputc((wp.w_flag&WFHARD)!=0  ? 'H' : '-',0);
    vtputc((wp.w_flag&WFEDIT)!=0  ? 'E' : '-',0);
    vtputc((wp.w_flag&WFMOVE)!=0  ? 'V' : '-',0);
    vtputc((wp.w_flag&WFFORCE)!=0 ? 'F' : '-',0);
}

    while (vtcol < term.t_ncol)             /* Pad to full width. */
        vtputc('-',0);
}

/*
 * Send a command to the terminal to move the hardware cursor to row "row"
 * and column "col". The row and column arguments are origin 0. Optimize out
 * random calls. Update "ttrow" and "ttcol".
 */
void movecursor(int row, int col)
{
    if (row != ttrow || col != ttcol)
    {
        ttrow = row;
        ttcol = col;
        term.t_move(row, col);
    }
}


/*
 * Erase the message line. This is a special routine because the message line
 * is not considered to be part of the virtual screen. It always works
 * immediately; the terminal buffer is flushed via a call to the flusher.
 */
void mlerase()
{
    auto vp = vscreen[term.t_nrow - 1];
    foreach (ref c; vp[0 .. term.t_ncol])
	c = attchar_t(' ', config.eolattr);
    vrowflags[term.t_nrow - 1] |= VFCHG;
    mpresf = FALSE;
}

/*
 * Ask a yes or no question in the message line. Return either TRUE, FALSE, or
 * ABORT. The ABORT status is returned if the user bumps out of the question
 * with a ^G. Used any time a confirmation is required.
 */
int mlyesno(string prompt)
{
    string buf;

    for (;;)
    {
        auto s = mlreply(prompt, null, buf);

        if (s == ABORT)
            return (ABORT);

        if (s != FALSE)
            {
            if (buf[0]=='y' || buf[0]=='Y')
                return (TRUE);

            if (buf[0]=='n' || buf[0]=='N')
                return (FALSE);
            }
    }
}


/***********************************
 * Simple circular history buffer for message line.
 */

const HISTORY_MAX = 10;
string[HISTORY_MAX] history;
int history_top;

int HDEC(int hi)	{ return (hi == 0) ? HISTORY_MAX - 1 : hi - 1; }
int HINC(int hi)	{ return (hi == HISTORY_MAX - 1) ? 0 : hi + 1; }

/*
 * Write a prompt into the message line, then read back a response. Keep
 * track of the physical position of the cursor. If we are in a keyboard
 * macro throw the prompt away, and return the remembered response. This
 * lets macros run at full speed. The reply is always terminated by a carriage
 * return. Handle erase, kill, and abort keys.
 */
int mlreply(string prompt, string init, out string result)
{
    int dot;		// insertion point in buffer
    int buflen;		// number of characters in buffer
    int startcol;
    int changes;
    int hi;

    int i;
    int c;

    if (kbdmop != null)
    {
	int len;
	while ((cast(char*)kbdmop)[len])
	    ++len;
	result = (cast(char*)kbdmop)[0 .. len].idup;
	kbdmop = cast(dchar*)(cast(char*)kbdmop + len + 1);
	return (len != 0);
    }

    hi = history_top;
    startcol = 0;
    attr = config.normattr;
    changes = 1;

    mpresf = TRUE;

    char[] buf;
    auto promptlen = cast(int)prompt.length;
    buf = init.dup;
    buflen = cast(int)buf.length;
    dot = buflen;

    for (;;)
    {
	if (changes)
	{
	    auto col = promptlen + getcol2(buf, dot);
	    if (col >= startcol + term.t_ncol - 2)
		startcol = col - term.t_ncol + 2;
	    if (col < startcol + promptlen)
		startcol = col - promptlen;

	    vtmove(term.t_nrow - 1, 0);
	    vtputs(prompt,startcol);
	    vtputs(buf, startcol, promptlen);
	    vteeol(startcol);
	    mlchange();
	    update();
	    attr = config.normattr;
	    vtmove(term.t_nrow - 1, col);

	    changes = 0;
	}

	movecursor(vtrow, vtcol - startcol);
	term.t_flush();
        c = term.t_getchar();

        switch (c)
	{   case 0x0D:                  /* Return, end of line */
                if (kbdmip != null)
		{
                    if (kbdmip + buflen + 1 > &kbdm[$-3])
			goto err;	/* error	*/

		    memcpy(kbdmip, buf.ptr, buflen * buf[0].sizeof);
		    (cast(char*)kbdmip)[buflen] = 0;
		    (*cast(char**)&kbdmip) += buflen + 1;
		}
		if (buflen != 0)
		{
		    hi = HDEC(history_top);
		    if (!history[hi] || buf != history[hi])
		    {
			// Store in history buffer
			history[history_top] = buf.idup;
			history_top = HINC(history_top);
			if (history[history_top])
			    delete history[history_top];
		    }
		    result = cast(immutable)buf;
		    return 1;
		}
		return 0;

            case 0x07:                  /* Bell, abort */
                vtputc(7, startcol);
		mlchange();
		goto err;		/* error	*/

	    case 0x01:			// ^A, beginning of line
	    case HOMEKEY:
                if (dot != 0)
		{
		    dot = 0;
		    startcol = 0;
		    changes = 1;
		}
                break;

	    case 0x05:			// ^E, beginning of line
	    case ENDKEY:
                if (dot != buflen)
		{
		    dot = buflen;
		    changes = 1;
		}
                break;

	    case 0x0B:			// ^K, delete to end of line
		if (dot != buflen)
		{
		    buflen = dot;
		    buf = buf[0 .. buflen];
		    changes = 1;
		}
		break;

            case 0x7F:                  /* Rubout, erase */
            case 0x08:                  /* Backspace, erase */
                if (dot != 0)
		{
		    memmove(buf.ptr + dot - 1, buf.ptr + dot, (buflen - dot) * buf[0].sizeof);
		    --dot;
		    --buflen;
		    buf = buf[0 .. buflen];
		    changes = 1;
		}
                break;

	    case DelKEY:
                if (dot < buflen)
		{
		    memmove(buf.ptr + dot, buf.ptr + dot + 1, (buflen - dot - 1) * buf[0].sizeof);
		    --buflen;
		    buf = buf[0 .. buflen];
		    changes = 1;
		}
                break;


            case 0x15:                  // ^U means delete line
		dot = 0;
		buflen = 0;
		buf = buf[0 .. buflen];
		startcol = 0;
		changes = 1;
                break;

	    case 'Y' - 0x40:		/* ^Y means yank		*/
		{   int n;

		    for (n = 0; (c = kill_remove(n)) != -1; n++)
		    {
			buf.length = buf.length + 1;
			memmove(buf.ptr + dot + 1, buf.ptr + dot, (buflen - dot) * buf[0].sizeof);
			buflen++;
			buf[dot++] = cast(char)c;
		    }
		    changes = 1;
		}
		break;

	    case LTKEY:
		if (dot != 0)
		{
		    dot--;
		    changes = 1;
		}
                break;

	    case RTKEY:
		if (dot < buflen)
		{
		    dot++;
		    changes = 1;
		}
                break;

	    case UPKEY:
		i = HDEC(hi);
		if (hi == history_top && history[i] && buf == history[i])
		    i = HDEC(i);
		goto L1;

	    case DNKEY:
		i = HINC(hi);
	    L1:
		if (history[i])
		{
		    buf = history[i].dup;
		    buflen = cast(int)buf.length;
		    dot = buflen;
		    startcol = 0;
		    changes = 1;
		    hi = i;
		}
		else
		    ctrlg(FALSE, 0);
		break;

	    //case InsKEY:
	    case 0x11:			/* ^Q, quote next		*/
	        c = term.t_getchar();
	        goto default;
	    default:
		if (c < 0 || c >= 0x7F)
		{   // Error
		    ctrlg(FALSE, 0);
		}
                else
		{
		    buf.length = buf.length + 1;
		    memmove(buf.ptr + dot + 1, buf.ptr + dot, (buflen - dot) * buf[0].sizeof);
		    buflen++;
                    buf[dot++] = cast(char)c;
		    changes = 1;
		}
		break;
            }
    }

err:
    ctrlg(FALSE, 0);
    return (ABORT);
}

/*
 * Write a message into the message line. Keep track of the physical cursor
 * position.
 * Set the "message line" flag TRUE.
 */
void mlwrite(string buffer)
{
    int savecol;

    vtmove(term.t_nrow - 1, 0);
    attr = config.normattr;
    vtputs(buffer,0);

    savecol = vtcol;
    vteeol(0);
    vtcol = savecol;
    mlchange();
    mpresf = TRUE;
}


void mlchange()
{
    vrowflags[term.t_nrow - 1] |= VFCHG;
}
