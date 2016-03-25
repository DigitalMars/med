

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The routines in this file move the cursor around on the screen. They
 * compute a new value for the cursor, then adjust ".". The display code
 * always updates the cursor location, so only moves between lines, or
 * functions that adjust the top line in the window and invalidate the
 * framing, are hard.
 */

module basic;

import std.conv;

import ed;
import line;
import main;
import window;
import display;

/*********************************
 * Move the cursor to the
 * beginning of the current line.
 * Trivial.
 */

int gotobol(bool f, int n)
{	int s;

	if (curwp.w_doto == 0)
		s = backline(f, n);
	else
	{
		if (curwp.w_markp)
			curwp.w_flag |= WFMOVE;
		s = TRUE;
		curwp.w_doto = 0;
		if( n > 1 )
			s = backline(f, n-1);
	}
	curgoal = 0;
	return s;
}

/*
 * Move the cursor backwards by "n" characters. If "n" is less than zero call
 * "forwchar" to actually do the move. Otherwise compute the new cursor
 * location. Error if you try and move out of the buffer. Set the flag if the
 * line pointer for dot changes.
 */
int backchar(bool f, int n)
{
        if (n < 0)
                return (forwchar(f, -n));
	if (curwp.w_markp && n)
		curwp.w_flag |= WFMOVE;
        while (n--) {
                if (curwp.w_doto == 0) {
		        LINE   *lp;
                        if ((lp=lback(curwp.w_dotp)) == curbp.b_linep)
                                return (FALSE);
                        curwp.w_dotp  = lp;
                        curwp.w_doto  = llength(lp);
                        curwp.w_flag |= WFMOVE;
                } else
                        curwp.w_doto--;
        }
        return (TRUE);
}

/**************************************
 * Move the cursor to the end of the current line.
 * If already at the end, advance to next line.
 */

int gotoeol(bool f, int n)
{
    int s;

    s = TRUE;
    if( curwp.w_doto != llength(curwp.w_dotp) )
    {
	if (curwp.w_markp)
	    curwp.w_flag |= WFMOVE;
	n--;
    }
    if( n > 0 )
	s = forwline(f,n);
    curwp.w_doto = llength(curwp.w_dotp);
    return( s );
}

/*
 * Move the cursor forwards by "n" characters. If "n" is less than zero call
 * "backchar" to actually do the move. Otherwise compute the new cursor
 * location, and move ".". Error if you try and move off the end of the
 * buffer. Set the flag if the line pointer for dot changes.
 */
int forwchar(bool f, int n)
{
        if (n < 0)
                return (backchar(f, -n));
	if (curwp.w_markp && n)
		curwp.w_flag |= WFMOVE;
        while (n--) {
                if (curwp.w_doto == llength(curwp.w_dotp)) {
                        if (curwp.w_dotp == curbp.b_linep)
                                return (FALSE);
                        curwp.w_dotp  = lforw(curwp.w_dotp);
                        curwp.w_doto  = 0;
                        curwp.w_flag |= WFMOVE;
                } else
                        curwp.w_doto++;
        }
        return (TRUE);
}

/*
 * Goto the beginning of the buffer. Massive adjustment of dot. This is
 * considered to be hard motion; it really isn't if the original value of dot
 * is the same as the new value of dot. Normally bound to "M-<".
 */
int gotobob(bool f, int n)
{
        curwp.w_dotp  = lforw(curbp.b_linep);
        curwp.w_doto  = 0;
        curwp.w_flag |= WFHARD;
        return (TRUE);
}

/*
 * Move to the end of the buffer. Dot is always put at the end of the file
 * (ZJ). The standard screen code does most of the hard parts of update.
 * Bound to "M.".
 */
int gotoeob(bool f, int n)
{
        curwp.w_dotp  = curbp.b_linep;
        curwp.w_doto  = 0;
        curwp.w_flag |= WFHARD;
        return (TRUE);
}

/*
 * Move forward by full lines. If the number of lines to move is less than
 * zero, call the backward line function to actually do it. The last command
 * controls how the goal column is set. Bound to "C-N". No errors are
 * possible.
 */
int forwline(bool f, int n)
{
        if (n < 0)
                return (backline(f, -n));
        auto dlp = curwp.w_dotp;

	/* Reset goal if last command not backline() or forwline()	*/
        if ((lastflag&CFCPCN) == 0)
                curgoal = getcol(dlp,curwp.w_doto);
        thisflag |= CFCPCN;			/* this command was a	*/
						/* forwline or backline	*/
        while (n-- && dlp!=curbp.b_linep)
                dlp = lforw(dlp);
        curwp.w_dotp  = dlp;
        curwp.w_doto  = getgoal(dlp);
        curwp.w_flag |= WFMOVE;
        return (TRUE);
}

/*******************************
 * Proceed to beginning of next line.
 */

int basic_nextline(bool f, int n)
{
    return (curwp.w_doto == 0 || gotobol(FALSE,1)) &&
	(lastflag &= ~CFCPCN, forwline(f,n));
}

/*
 * This function is like "forwline", but goes backwards. The scheme is exactly
 * the same. Check for arguments that are less than zero and call your
 * alternate. Figure out the new line and call "movedot" to perform the
 * motion. No errors are possible. Bound to "C-P".
 */
int backline(bool f, int n)
{
        if (n < 0)
                return (forwline(f, -n));
        auto dlp = curwp.w_dotp;

	/* Reset goal if last command not backline() or forwline()	*/
        if ((lastflag&CFCPCN) == 0)
                curgoal = getcol(dlp,curwp.w_doto);
        thisflag |= CFCPCN;

        while (n-- && lback(dlp)!=curbp.b_linep)
                dlp = lback(dlp);
        curwp.w_dotp  = dlp;
        curwp.w_doto  = getgoal(dlp);
        curwp.w_flag |= WFMOVE;
        return (TRUE);
}

/**********************************
 * Goto line number.
 */

int gotoline(bool f, int n)
{	string number;

	if (mlreply("Goto line: ", null, number) == FALSE)
		return FALSE;
	try
	{
	    const num = to!(int)(number);
	    gotobob(f, n);			/* move to beginning of buffer	*/
	    return forwline(f, num - 1);
	}
	catch
	{
	}
	return FALSE;
}

/*
 * This routine, given a pointer to a LINE, and the current cursor goal
 * column, return the best choice for the offset. The offset is returned.
 * Used by forwline() and backline().
 */
int getgoal(LINE* dlp)
{
        int    c;
        int    col;
        int    newcol;
        int    dbo;

        col = 0;
        dbo = 0;
        while (dbo != llength(dlp)) {
                c = lgetc(dlp, dbo);
                newcol = col;
                if (c == '\t')
                        newcol |= 0x07;
                else if (c<0x20 || c==0x7F)
                        ++newcol;
                ++newcol;
                if (newcol > curgoal)
                        break;
                col = newcol;
                ++dbo;
        }
        return (dbo);
}

/*
 * Scroll forward by a specified number of lines, or by a full page if no
 * argument. Bound to "C-V". The "2" in the arithmetic on the window size is
 * the overlap; this value is the default overlap value in ITS EMACS. Because
 * this zaps the top line in the display window, we have to do a hard update.
 */
int forwpage(bool f, int n)
{
        if (f == FALSE) {
                n = curwp.w_ntrows - 2;        /* Default scroll.      */
                if (n <= 0)                     /* Forget the overlap   */
                        n = 1;                  /* if tiny window.      */
        } else if (n < 0)
                return (backpage(f, -n));
        else if (CVMVAS)                       /* Convert from pages   */
                n *= curwp.w_ntrows;           /* to lines.            */
        auto lp = curwp.w_linep;
        while (n-- && lp!=curbp.b_linep)
                lp = lforw(lp);
        curwp.w_linep = lp;
        curwp.w_dotp  = lp;
        curwp.w_doto  = 0;
        curwp.w_flag |= WFHARD;
        return (TRUE);
}

/*
 * This command is like "forwpage", but it goes backwards. The "2", like
 * above, is the overlap between the two windows. The value is from the ITS
 * EMACS manual. Bound to "M-V". We do a hard update for exactly the same
 * reason.
 */
int backpage(bool f, int n)
{
        if (f == FALSE) {
                n = curwp.w_ntrows - 2;        /* Default scroll.      */
                if (n <= 0)                     /* Don't blow up if the */
                        n = 1;                  /* window is tiny.      */
        } else if (n < 0)
                return (forwpage(f, -n));
        else if (CVMVAS)                       /* Convert from pages   */
                n *= curwp.w_ntrows;           /* to lines.            */
        auto lp = curwp.w_linep;
        while (n-- && lback(lp)!=curbp.b_linep)
                lp = lback(lp);
        curwp.w_linep = lp;
        curwp.w_dotp  = lp;
        curwp.w_doto  = 0;
        curwp.w_flag |= WFHARD;
        return (TRUE);
}

/*
 * Set the mark in the current window to the value of "." in the window. No
 * errors are possible. Bound to "M-.".
 */
int basic_setmark(bool f, int n)
{
	removemark(f,n);		/* delete old mark		*/
        curwp.w_markp = curwp.w_dotp;
        curwp.w_marko = curwp.w_doto;
	/* Get starting column for column regions	*/
	markcol = getcol(curwp.w_markp,curwp.w_doto);
        mlwrite("[Mark set]");
        return (TRUE);
}

/*************************
 * Remove mark from current window.
 */

int removemark(bool f, int n)
{
	if (curwp.w_markp)
	{	curwp.w_flag |= WFHARD;
		curwp.w_markp = null;
	        mlwrite("[Mark removed]");
	}
	else
		mlwrite("[No mark]");
        return (TRUE);
}

/*
 * Swap the values of "." and "mark" in the current window. This is pretty
 * easy, bacause all of the hard work gets done by the standard routine
 * that moves the mark about. The only possible error is "no mark". Bound to
 * "C-X C-X".
 */
int swapmark(bool f, int n)
{
        if (curwp.w_markp == null) {
                mlwrite("No mark in this window");
                return (FALSE);
        }
        auto odotp = curwp.w_dotp;
        auto odoto = curwp.w_doto;
        curwp.w_dotp  = curwp.w_markp;
        curwp.w_doto  = curwp.w_marko;
        curwp.w_markp = odotp;
        curwp.w_marko = odoto;
        curwp.w_flag |= WFMOVE;
        return (TRUE);
}
