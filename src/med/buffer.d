

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * Buffer management.
 * Some of the functions are internal,
 * and some are actually attached to user
 * keys. Like everyone else, they set hints
 * for the display system.
 */

module buffer;

import std.stdio;
import std.path;

import ed;
import line;
import display;
import main;
import window;


/*
 * Text is kept in buffers. A buffer header, described below, exists for every
 * buffer in the system. The buffers are kept in a big list, so that commands
 * that search for a buffer by name can find the buffer header. There is a
 * safe store for the dot and mark in the header, but this is only valid if
 * the buffer is not being displayed (that is, if "b_nwnd" is 0). The text for
 * the buffer is kept in a circularly linked list of lines, with a pointer to
 * the header line in "b_linep".
 */
struct  BUFFER {
        LINE*   b_dotp;                // Link to "." LINE structure
        uint   b_doto;                 // Offset of "." in above LINE
        LINE*   b_markp;               // The same as the above two,
        uint   b_marko;                // but for the "mark"
        LINE*   b_linep;               // Link to the header LINE
        uint    b_nwnd;                // Count of windows on buffer
        ubyte    b_flag;               // Flags
        string  b_fname;              // File name
        string  b_bname;               // Buffer name
}

enum
{
    BFTEMP   = 0x01,                   // Internal temporary buffer
    BFCHG    = 0x02,                   // Changed since last write
    BFRDONLY = 0x04,                   // Buffer is read only
    BFNOCR   = 0x08,                   // last line in buffer has no
                                       // trailing CR
}

__gshared BUFFER*[] buffers;

/*
 * Attach a buffer to a window. The
 * values of dot and mark come from the buffer
 * if the use count is 0. Otherwise, they come
 * from some other window.
 */
int usebuffer(bool f, int n)
{
    string bufn;

    auto s = mlreply("Use buffer: ", null, bufn);
    if (s != TRUE)
	return (s);
    auto bp = buffer_find(bufn, TRUE, 0);
    if (bp == null)
	return (FALSE);
    return buffer_switch(bp);
}

/*********************************
 * Make next buffer in list the current one.
 * Put it into the current window if it isn't displayed.
 */

int buffer_next(bool f, int n)
{
    foreach (i, bp; buffers)
    {
	if (bp == curbp)
	{
	    i = i + 1;
	    if (i == buffers.length)
		i = 0;
	    return buffer_switch(buffers[i]);
	}
    }
    return FALSE;
}

/***************************
 * Switch to buffer bp.
 * Returns:
 *	TRUE or FALSE
 */

int buffer_switch(BUFFER* bp)
{
    if (--curbp.b_nwnd == 0) {             /* Last use.            */
	curbp.b_dotp  = curwp.w_dotp;
	curbp.b_doto  = curwp.w_doto;
	curbp.b_markp = curwp.w_markp;
	curbp.b_marko = curwp.w_marko;
    }
    curbp = bp;                             /* Switch.              */
    curwp.w_bufp  = bp;
    curwp.w_linep = bp.b_linep;           /* For macros, ignored. */
    curwp.w_flag |= WFMODE|WFFORCE|WFHARD; /* Quite nasty.         */
    if (bp.b_nwnd++ == 0) {                /* First use.           */
	curwp.w_dotp  = bp.b_dotp;
	curwp.w_doto  = bp.b_doto;
	curwp.w_markp = bp.b_markp;
	curwp.w_marko = bp.b_marko;
	return (TRUE);
    }
    else
    {
	/* Look for the existing window onto buffer bp			*/
	foreach (wp; windows)
	{
	    if (wp!=curwp && wp.w_bufp==bp)
	    {
		curwp.w_dotp  = wp.w_dotp;
		curwp.w_doto  = wp.w_doto;
		curwp.w_markp = wp.w_markp;
		curwp.w_marko = wp.w_marko;
		break;
	    }
	}
    }
    return TRUE;
}

/*
 * Dispose of a buffer, by name.
 * Ask for the name. Look it up (don't get too
 * upset if it isn't there at all!). Get quite upset
 * if the buffer is being displayed. Clear the buffer (ask
 * if the buffer has been changed). Then free the header
 * line and the buffer header. Bound to "C-X K".
 */
int killbuffer(bool f, int n)
{
	BUFFER *bp;
        int    s;
        string bufn;

        if ((s=mlreply("Kill buffer: ", null, bufn)) != TRUE)
                return (s);
        if ((bp=buffer_find(bufn, FALSE, 0)) == null) /* Easy if unknown.     */
                return (TRUE);
	return buffer_remove(bp);
}

/**********************
 * Remove buffer bp.
 * Returns:
 *	0	failed
 *	!=0	succeeded
 */

int buffer_remove(BUFFER* bp)
{
        if (bp.b_nwnd != 0) {                  /* Error if on screen.  */
                mlwrite("Buffer is being displayed");
                return (FALSE);
        }
        if (!buffer_clear(bp))			/* Blow text away	*/
	    return FALSE;
        delete bp.b_linep;                     /* Release header line. */

	foreach (i, b; buffers)
	{
	    if (b == bp)
	    {
		buffers[i .. $ - 1] = buffers[i + 1 .. $];
		buffers = buffers[0 .. $ - 1];
		break;
	    }
	}
        delete bp;                      /* Release buffer block */
        return (TRUE);
}

/*
 * List all of the active
 * buffers. First update the special
 * buffer that holds the list. Next make
 * sure at least 1 window is displaying the
 * buffer list, splitting the screen if this
 * is what it takes. Lastly, repaint all of
 * the windows that are displaying the
 * list. Bound to "C-X C-B".
 */
int listbuffers(bool f, int n)
{
        BUFFER *bp;
        int    s;

        if ((s=makelist()) != TRUE)
                return (s);
        if (blistp.b_nwnd == 0) {              /* Not on screen yet.   */
	        WINDOW *wp;
                if ((wp=wpopup()) == null)
                        return (FALSE);
                bp = wp.w_bufp;
                if (--bp.b_nwnd == 0) {
                        bp.b_dotp  = wp.w_dotp;
                        bp.b_doto  = wp.w_doto;
                        bp.b_markp = wp.w_markp;
                        bp.b_marko = wp.w_marko;
                }
                wp.w_bufp  = blistp;
                ++blistp.b_nwnd;
        }
	foreach (wp; windows)
	{
                if (wp.w_bufp == blistp) {
                        wp.w_linep = lforw(blistp.b_linep);
                        wp.w_dotp  = lforw(blistp.b_linep);
                        wp.w_doto  = 0;
                        wp.w_markp = null;
                        wp.w_marko = 0;
                        wp.w_flag |= WFMODE|WFHARD;
                }
        }
        return (TRUE);
}

/*
 * This routine rebuilds the
 * text in the special secret buffer
 * that holds the buffer list. It is called
 * by the list buffers command. Return TRUE
 * if everything works. Return FALSE if there
 * is an error (if there is no memory).
 */
int makelist()
{
        LINE   *lp;
        int    nbytes;
        int    s;
        int    type;
        char[6+1] b;
        char[128] line;

        blistp.b_flag &= ~BFCHG;               /* Don't complain!      */
        if ((s=buffer_clear(blistp)) != TRUE)         /* Blow old text away   */
                return (s);
        blistp.b_fname = null;
        if (addline("C   Size Buffer           File") == FALSE
        ||  addline("-   ---- ------           ----") == FALSE)
                return (FALSE);
	/* For all buffers      */
	foreach (bp; buffers)
	{
                if ((bp.b_flag&BFTEMP) != 0) { /* Skip magic ones.     */
                        continue;
                }
                int i = 0;                 /* Start at left edge   */
                if ((bp.b_flag&BFCHG) != 0)    /* "*" if changed       */
                        line[i++] = '*';
                else
                        line[i++] = ' ';
                line[i++] = ' ';                /* Gap.                 */
                nbytes = 0;                     /* Count bytes in buf.  */
                lp = lforw(bp.b_linep);
                while (lp != bp.b_linep) {
                        nbytes += llength(lp)+1;
                        lp = lforw(lp);
                }
                buffer_itoa(b, 6, nbytes);             /* 6 digit buffer size. */
		line[i .. i + b.length] = b;
		i += b.length;
                line[i++] = ' ';                /* Gap.                 */
		line[i .. i + bp.b_bname.length] = bp.b_bname;	// buffer name
		i += bp.b_bname.length;
                if (bp.b_fname.length)
		{
                        while (i < 25)
                                line[i++] = ' ';
			line[i++] = ' ';
			foreach (c; bp.b_bname)
			{
			    if (i < line.length)
				line[i++] = c;
                        }
                }
                                       /* Add to the buffer.   */
                if (addline(line[0 .. i].idup) == FALSE)
                        return (FALSE);
        }
        return (TRUE);                          /* All done             */
}

void buffer_itoa(char[] buf, int width, int num)
{
        buf[width] = 0;                         /* End of string.       */
        while (num >= 10) {                     /* Conditional digits.  */
                buf[--width] = cast(char)((num%10) + '0');
                num /= 10;
        }
        buf[--width] = cast(char)(num + '0');               // Always 1 digit.
        while (width != 0)                      /* Pad with blanks.     */
                buf[--width] = ' ';
}

/*
 * The argument "text" points to
 * a string. Append this line to the
 * buffer list buffer. Handcraft the EOL
 * on the end. Return TRUE if it worked and
 * FALSE if you ran out of room.
 */
int addline(string text)
{
        LINE   *lp;

        if ((lp=line_realloc(null, cast(int)text.length)) == null)
                return (FALSE);
        for (int i=0; i<text.length; ++i)
                lputc(lp, i, text[i]);
        blistp.b_linep.l_bp.l_fp = lp;       /* Hook onto the end    */
        lp.l_bp = blistp.b_linep.l_bp;
        blistp.b_linep.l_bp = lp;
        lp.l_fp = blistp.b_linep;
        if (blistp.b_dotp == blistp.b_linep)  /* If "." is at the end */
                blistp.b_dotp = lp;            /* move it to new line  */
        return (TRUE);
}

/*
 * Look through the list of
 * buffers. Return TRUE if there
 * are any changed buffers. Buffers
 * that hold magic internal stuff are
 * not considered; who cares if the
 * list of buffer names is hacked.
 * Return FALSE if no buffers
 * have been changed.
 */
int anycb()
{
    foreach (bp; buffers)
    {
	if ((bp.b_flag & (BFTEMP | BFCHG)) == BFCHG)
	    return TRUE;
    }
    return FALSE;
}

/********************************
 * Find a buffer, by name. Return a pointer
 * to the BUFFER structure associated with it. If
 * the named buffer is found, but is a TEMP buffer (like
 * the buffer list) complain. If the buffer is not found
 * and the "cflag" is TRUE, create it. The "bflag" is
 * the settings for the flags in in buffer.
 * If bflag specifies a TEMP buffer, then a TEMP buffer can be selected.
 */

BUFFER *buffer_find(string bname, int cflag, int bflag)
{
    foreach (bp; buffers)
    {
	if (globMatch(bname, bp.b_bname))
	{   
	    if ((bflag & BFTEMP) == 0 && (bp.b_flag & BFTEMP) != 0)
	    {
		mlwrite("Cannot select builtin buffer");
		return (null);
	    }
	    return (bp);
	}
    }
    if (cflag != FALSE)
    {
	auto lp = new LINE;
	auto bp = new BUFFER;
	buffers ~= bp;
	bp.b_dotp  = lp;
	bp.b_flag  = cast(ubyte)bflag;
	bp.b_linep = lp;
	bp.b_fname = "";
	bp.b_bname = bname;
	lp.l_fp = lp;
	lp.l_bp = lp;
	return bp;
    }
    return null;
}

/*
 * This routine blows away all of the text
 * in a buffer. If the buffer is marked as changed
 * then we ask if it is ok to blow it away; this is
 * to save the user the grief of losing text. The
 * window chain is nearly always wrong if this gets
 * called; the caller must arrange for the updates
 * that are required. Return TRUE if everything
 * looks good.
 */
int buffer_clear(BUFFER* bp)
{
        LINE   *lp;
        int    s;

	/*if (bp.b_flag & BFRDONLY)
	    return FALSE;*/
        if ((bp.b_flag&BFTEMP) == 0            /* Not scratch buffer.  */
        && (bp.b_flag&BFCHG) != 0              /* Something changed    */
        && (s=mlyesno("Discard changes [y/n]? ")) != TRUE)
                return (s);
        bp.b_flag  &= ~BFCHG;                  /* Not changed          */
        while ((lp=lforw(bp.b_linep)) != bp.b_linep)
                line_free(lp);
        bp.b_dotp  = bp.b_linep;              /* Fix "."              */
        bp.b_doto  = 0;
        bp.b_markp = null;                     /* Invalidate "mark"    */
        bp.b_marko = 0;
        return (TRUE);
}
