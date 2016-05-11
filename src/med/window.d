

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


/*
 * Window management. Some of the functions are internal, and some are
 * attached to keys that the user actually types.
 */

module window;

import std.string;

import ed;
import buffer;
import line;
import main;
import terminal;
import xterm;
import display;

/*
 * There is a window structure allocated for every active display window. The
 * windows are kept in a big list, in top to bottom screen order, with the
 * listhead at "wheadp". Each window contains its own values of dot and mark.
 * The flag field contains some bits that are set by commands to guide
 * redisplay; although this is a bit of a compromise in terms of decoupling,
 * the full blown redisplay is just too expensive to run for every input
 * character. 
 */
struct  WINDOW {
        BUFFER* w_bufp;           /* Buffer displayed in window   */
        LINE*   w_linep;          /* Top line in the window       */
        LINE*   w_dotp;           /* Line containing "."          */
        int     w_doto;           /* Byte offset for "."          */
        LINE*   w_markp;          /* Line containing "mark"       */
        int     w_marko;          /* Byte offset for "mark"       */
        int     w_toprow;         /* Origin 0 top row of window   */
        int     w_ntrows;         /* # of rows of text in window  */
        int     w_force;          /* If NZ, forcing row.          */
        ubyte   w_flag;           /* Flags.                       */
        int     w_startcol;       /* starting column              */
}

enum
{
    WFFORCE = 0x01,                    /* Window needs forced reframe  */
    WFMOVE  = 0x02,                    /* Movement from line to line   */
    WFEDIT  = 0x04,                    /* Editing within a line        */
    WFHARD  = 0x08,                    /* Better do a full display     */
    WFMODE  = 0x10,                    /* Update mode line.            */
}

__gshared WINDOW*[] windows;

/* !=0 means marking    */
bool window_marking(WINDOW* wp) { return wp.w_markp != null; }


/*************************************
 * Reposition dot in the current window to line "n". If the argument is
 * positive, it is that line. If it is negative it is that line from the
 * bottom. If it is 0 the window is centered (this is what the standard
 * redisplay code does). With no argument it defaults to 1. Bound to M-!.
 * Because of the default, it works like in Gosling.
 */

int window_reposition(bool f, int n)
{
    curwp.w_force = n;
    curwp.w_flag |= WFFORCE;
    return (TRUE);
}

/*
 * Refresh the screen. With no argument, it just does the refresh. With an
 * argument it recenters "." in the current window. Bound to "C-L".
 */
int window_refresh(bool f, int n)
{
    if (f == FALSE)
        sgarbf = TRUE;
    else
        {
        curwp.w_force = 0;             /* Center dot. */
        curwp.w_flag |= WFFORCE;
        }

    return (TRUE);
}

/*
 * The command make the next window (next => down the screen) the current
 * window. There are no real errors, although the command does nothing if
 * there is only 1 window on the screen. Bound to "C-X C-N".
 */
int window_next(bool f, int n)
{
    foreach (i, wp; windows)
    {
	if (wp == curwp)
	{
	    i = i + 1;
	    if (i == windows.length)
		i = 0;
	    curwp = windows[i];
	    curbp = curwp.w_bufp;
	    return TRUE;
	}
    }
    return FALSE;
}

/*
 * This command makes the previous window (previous => up the screen) the
 * current window. There arn't any errors, although the command does not do a
 * lot if there is 1 window.
 */
int window_prev(bool f, int n)
{
    foreach (i, wp; windows)
    {
	if (wp == curwp)
	{
	    if (i == 0)
		i = windows.length;
	    i--;
	    curwp = windows[i];
	    curbp = curwp.w_bufp;
	    return TRUE;
	}
    }
    return FALSE;
}

/*
 * This command moves the current window down by "arg" lines. Recompute the
 * top line in the window. The move up and move down code is almost completely
 * the same; most of the work has to do with reframing the window, and picking
 * a new dot. We share the code by having "move down" just be an interface to
 * "move up". Magic. Bound to "C-X C-N".
 */
int window_mvdn(bool f, int n)
{
    return window_mvup(f, -n);
}

/*
 * Move the current window up by "arg" lines. Recompute the new top line of
 * the window. Look to see if "." is still on the screen. If it is, you win.
 * If it isn't, then move "." to center it in the new framing of the window
 * (this command does not really move "."; it moves the frame). Bound to
 * "C-X C-P".
 */
int window_mvup(bool f, int n)
{
    LINE *lp;
    int i;

    lp = curwp.w_linep;

    if (n < 0)
        {
        while (n++ && lp!=curbp.b_linep)
            lp = lforw(lp);
        }
    else
        {
        while (n-- && lback(lp)!=curbp.b_linep)
            lp = lback(lp);
        }

    curwp.w_linep = lp;		/* new top line of window	*/
    curwp.w_flag |= WFHARD;            /* Mode line is OK. */

    for (i = 0; i < curwp.w_ntrows; ++i)
        {
        if (lp == curwp.w_dotp)
            return (TRUE);
        if (lp == curbp.b_linep)
            break;
        lp = lforw(lp);
        }

    lp = curwp.w_linep;
    i  = curwp.w_ntrows/2;

    while (i-- && lp != curbp.b_linep)
        lp = lforw(lp);

    curwp.w_dotp  = lp;
    curwp.w_doto  = 0;
    return (TRUE);
}

/*
 * This command makes the current window the only window on the screen. Bound
 * to "C-X 1". Try to set the framing so that "." does not have to move on the
 * display. Some care has to be taken to keep the values of dot and mark in
 * the buffer structures right if the destruction of a window makes a buffer
 * become undisplayed.
 */
int window_only(bool f, int n)
{
	foreach (wp; windows)
	{
	    if (wp != curwp)
	    {
                if (--wp.w_bufp.b_nwnd == 0) {
                        wp.w_bufp.b_dotp  = wp.w_dotp;
                        wp.w_bufp.b_doto  = wp.w_doto;
                        wp.w_bufp.b_markp = wp.w_markp;
                        wp.w_bufp.b_marko = wp.w_marko;
                }
                delete wp;
	    }
	}
	windows = windows[0 .. 1];
	windows[0] = curwp;

        auto lp = curwp.w_linep;
        auto i  = curwp.w_toprow;
        while (i!=0 && lback(lp)!=curbp.b_linep) {
                --i;
                lp = lback(lp);
        }
        curwp.w_toprow = 0;
        curwp.w_ntrows = term.t_nrow - 2;
        curwp.w_linep  = lp;
        curwp.w_flag  |= WFMODE|WFHARD;
        return (TRUE);
}

/*
 * Split the current window. A window smaller than 3 lines cannot be split.
 * The only other error that is possible is a "malloc" failure allocating the
 * structure for the new window. Bound to "C-X 2".
 */
int window_split(bool f, int n)
{
        LINE   *lp;
        int    ntru;
        int    ntrl;
        int    ntrd;
        WINDOW *wp1;
        WINDOW *wp2;

        if (curwp.w_ntrows < 3) {
                mlwrite(format("Cannot split a %d line window", curwp.w_ntrows));
                return (FALSE);
        }
	auto wp = new WINDOW;
        ++curbp.b_nwnd;                        /* Displayed twice.     */
        wp.w_bufp  = curbp;
        wp.w_dotp  = curwp.w_dotp;
        wp.w_doto  = curwp.w_doto;
        wp.w_markp = curwp.w_markp;
        wp.w_marko = curwp.w_marko;
        ntru = (curwp.w_ntrows-1) / 2;         /* Upper size           */
        ntrl = (curwp.w_ntrows-1) - ntru;      /* Lower size           */
        lp = curwp.w_linep;
        ntrd = 0;
        while (lp != curwp.w_dotp) {
                ++ntrd;
                lp = lforw(lp);
        }
        lp = curwp.w_linep;
        if (ntrd <= ntru) {                     /* Old is upper window. */
                if (ntrd == ntru)               /* Hit mode line.       */
                        lp = lforw(lp);
                curwp.w_ntrows = ntru;
		// Insert wp after curwp
		foreach (i, w; windows)
		{   if (w == curwp)
		    {
			windows = windows[0 .. i + 1] ~ wp ~ windows[i + 1 .. $];
			break;
		    }
		}
                wp.w_toprow = curwp.w_toprow+ntru+1;
                wp.w_ntrows = ntrl;
        } else {                                /* Old is lower window  */
		// Insert wp before curwp
		foreach (i, w; windows)
		{   if (w == curwp)
		    {
			windows = windows[0 .. i] ~ wp ~ windows[i .. $];
			break;
		    }
		}

                wp.w_toprow = curwp.w_toprow;
                wp.w_ntrows = ntru;
                ++ntru;                         /* Mode line.           */
                curwp.w_toprow += ntru;
                curwp.w_ntrows  = ntrl;
                while (ntru--)
                        lp = lforw(lp);
        }
        curwp.w_linep = lp;                    /* Adjust the top lines */
        wp.w_linep = lp;                       /* if necessary.        */
        curwp.w_flag |= WFMODE|WFHARD;
        wp.w_flag |= WFMODE|WFHARD;
        return (TRUE);
}

/*
 * Enlarge the current window. Find the window that loses space. Make sure it
 * is big enough. If so, hack the window descriptions, and ask redisplay to do
 * all the hard work. You don't just set "force reframe" because dot would
 * move. Bound to "C-X Z".
 */
int window_enlarge(bool f, int n)
{
        WINDOW *adjwp;
        LINE   *lp;
	bool prev;

        if (n < 0)
                return (window_shrink(f, -n));

        if (windows.length == 1) {
                mlwrite("Only one window");
                return (FALSE);
        }

	foreach (i, wp; windows)
	{
	    if (wp == curwp)
	    {
		if (i == windows.length - 1)
		{
		    adjwp = windows[i - 1];
		    prev = true;
		}
		else
		{
		    adjwp = windows[i + 1];
		    prev = false;
		}
		break;
	    }
	}

        if (adjwp.w_ntrows <= n) {
                mlwrite("Impossible enlarge change");
                return (FALSE);
        }
        if (!prev) {           // Shrink below.
                lp = adjwp.w_linep;
                for (int i=0; i<n && lp!=adjwp.w_bufp.b_linep; ++i)
                        lp = lforw(lp);
                adjwp.w_linep  = lp;
                adjwp.w_toprow += n;
        } else {                                /* Shrink above.        */
                lp = curwp.w_linep;
                for (int i=0; i<n && lback(lp)!=curbp.b_linep; ++i)
                        lp = lback(lp);
                curwp.w_linep  = lp;
                curwp.w_toprow -= n;
        }
        curwp.w_ntrows += n;
        adjwp.w_ntrows -= n;
        curwp.w_flag |= WFMODE|WFHARD;
        adjwp.w_flag |= WFMODE|WFHARD;
        return (TRUE);
}

/*
 * Shrink the current window. Find the window that gains space. Hack at the
 * window descriptions. Ask the redisplay to do all the hard work. Bound to
 * "C-X C-Z".
 */
int window_shrink(bool f, int n)
{
        WINDOW *adjwp;
        LINE   *lp;
	bool prev;

        if (n < 0)
                return (window_enlarge(f, -n));
        if (windows.length == 1) {
                mlwrite("Only one window");
                return (FALSE);
        }

	foreach (i, wp; windows)
	{
	    if (wp == curwp)
	    {
		if (i == windows.length - 1)
		{
		    adjwp = windows[i - 1];
		    prev = true;
		}
		else
		{
		    adjwp = windows[i + 1];
		    prev = false;
		}
		break;
	    }
	}

        if (curwp.w_ntrows <= n) {
                mlwrite("Impossible shrink change");
                return (FALSE);
        }
        if (!prev) {           // Grow below.
                lp = adjwp.w_linep;
                for (int i=0; i<n && lback(lp)!=adjwp.w_bufp.b_linep; ++i)
                        lp = lback(lp);
                adjwp.w_linep  = lp;
                adjwp.w_toprow -= n;
        } else {                                /* Grow above.          */
                lp = curwp.w_linep;
                for (int i=0; i<n && lp!=curbp.b_linep; ++i)
                        lp = lforw(lp);
                curwp.w_linep  = lp;
                curwp.w_toprow += n;
        }
        curwp.w_ntrows -= n;
        adjwp.w_ntrows += n;
        curwp.w_flag |= WFMODE|WFHARD;
        adjwp.w_flag |= WFMODE|WFHARD;
        return (TRUE);
}

/*
 * Pick a window for a pop-up. Split the screen if there is only one window.
 * Pick the uppermost window that isn't the current window. An LRU algorithm
 * might be better. Return a pointer, or null on error.
 */
WINDOW  *wpopup()
{
        if (windows.length == 1              // Only 1 window
        && window_split(FALSE, 0) == FALSE)        // and it won't split
                return null;
        auto wp = windows[0];                            // Find window to use
	if (wp == curwp)
	    wp = windows[1];
        return wp;
}

/*
 * Delete the current window. Does nothing if this window is last the
 * one on the screen.  Otherwise, it moves to the next window and
 * deletes the previous one.
 */
int delwind(bool f, int n)
{
	if (windows.length == 1)
	    return TRUE;	// Only 1 window

	auto delwp = curwp;
	if (windows[0] == delwp)		// Pick which window to be in next
	{
		curwp = windows[1];
		windows = windows[1 .. $];
		curbp = curwp.w_bufp;
		auto lp = curwp.w_linep;
		int i  = curwp.w_toprow;
		while( i!=0 && lback(lp)!=curbp.b_linep )
		{
			i--;
			lp = lback(lp);
		}
		curwp.w_toprow = delwp.w_toprow;
	}
	else
	{
		foreach (i, wp; windows)
		{
		    if (wp == delwp)
		    {
			curwp = windows[i - 1];
			windows = windows[0 .. i] ~ windows[i + 1 .. $];
			break;
		    }
		}
		curbp = curwp.w_bufp;
	}

	curwp.w_ntrows += delwp.w_ntrows+1;
	curwp.w_flag |= WFMODE|WFHARD;

	delwp.w_bufp.b_dotp  = delwp.w_dotp;
	delwp.w_bufp.b_doto  = delwp.w_doto;
	delwp.w_bufp.b_markp = delwp.w_markp;
	delwp.w_bufp.b_marko = delwp.w_marko;
	delwp.w_bufp.b_nwnd--;

	delete delwp;

	return( TRUE );
}
