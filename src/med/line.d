

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The functions in this file are a general set of line management utilities.
 * They are the only routines that touch the text. They also touch the buffer
 * and window structures, to make sure that the necessary updating gets done.
 * There are routines in this file that handle the kill buffer too. It isn't
 * here for any good reason.
 *
 * Note that this code only updates the dot and mark values in the window list.
 * Since all the code acts on the current window, the buffer that we are
 * editing must be being displayed, which means that "b_nwnd" is non zero,
 * which means that the dot and mark values in the buffer headers are nonsense.
 */

module line;

import core.stdc.string;

import std.utf;

import ed;
import buffer;
import window;
import main;
import display;
import random;

/*
 * All text is kept in circularly linked lists of "LINE" structures. These
 * begin at the header line (which is the blank line beyond the end of the
 * buffer). This line is pointed to by the "BUFFER". Each line contains the
 * number of bytes in the line (the "used" size), the size of the text array,
 * and the text. The end of line is not stored as a byte; it's implied. Future
 * additions will include update hints, and a list of marks into the line.
 */
struct  LINE {
        LINE *l_fp;              /* Link to the next line              */
        LINE *l_bp;              /* Link to the previous line          */
	    SyntaxState syntaxState; /* state at the beginning of the line */
        char[] l_text;           /* A bunch of characters.             */
}

LINE* lforw(LINE* lp) { return lp.l_fp; }
LINE* lback(LINE* lp) { return lp.l_bp; }
char lputc(LINE* lp, int n, char c) { return lp.l_text[n] = c; }
int llength(LINE* lp) { return cast(int)lp.l_text.length; }
char lgetc(LINE* lp, int n) { return lp.l_text[n]; }

bool empty(LINE* lp, int n) { return lp == curbp.b_linep; }
int  front(LINE* lp, int n) { return n == llength(lp) ? '\n' : lgetc(lp, n); }

void popFront(ref LINE* lp, ref int n)
{
    if (n < llength(lp))
        n += 1;
    else
    {
	lp = lforw(lp);
	n = 0;
    }
}

bool atFront(LINE* lp, int n) { return n == 0 && lback(lp) == curbp.b_linep; }

void popBack(ref LINE* lp, ref int n)
{
    if (n)
	n -= 1;
    else
    {
	lp = lback(lp);
	n = llength(lp);
    }
}

int peekBack(LINE* lp, int n)
{
    popBack(lp, n);
    return front(lp, n);
}

/*
 * This routine allocates a block of memory large enough to hold a LINE
 * containing "used" characters. The block is always rounded up a bit. Return
 * a pointer to the new block, or null if there isn't any memory left. Print a
 * message in the message line if no space.
 */

LINE* line_realloc(LINE* lpold, int used)
{
	if (!lpold)
	    lpold = new LINE;
	lpold.l_text.length = used;
        return lpold;
}

/*
 * Delete line "lp". Fix all of the links that might point at it (they are
 * moved to offset 0 of the next line). Unlink the line from whatever buffer it
 * might be in. Release the memory. The buffers are updated too; the magic
 * conditions described in the above comments don't hold here.
 */
void line_free(LINE* lp)
{
	foreach (wp; windows)
	{
	    if (wp.w_linep == lp)
		wp.w_linep = lp.l_fp;
	    if (wp.w_dotp  == lp) {
		wp.w_dotp  = lp.l_fp;
		wp.w_doto  = 0;
	    }
	    if (wp.w_markp == lp) {
		wp.w_markp = lp.l_fp;
		wp.w_marko = 0;
	    }
	}
	foreach (bp; buffers)
	{
assert(bp);
	    /* If there are windows on this buffer, the dot and mark	*/
	    /* values are nonsense.					*/
	    if (bp.b_nwnd == 0)	/* if no windows on this buffer	*/
	    {
		/* update dot or mark in the buffer	*/
		if (bp.b_dotp  == lp) {
			bp.b_dotp = lp.l_fp;
			bp.b_doto = 0;
		}
		if (bp.b_markp == lp) {
			bp.b_markp = lp.l_fp;
			bp.b_marko = 0;
		}
	    }
        }
        lp.l_bp.l_fp = lp.l_fp;
        lp.l_fp.l_bp = lp.l_bp;
        delete lp;
}

/*
 * This routine gets called when a character is changed in place in the current
 * buffer. It updates all of the required flags in the buffer and window
 * system. The flag used is passed as an argument; if the buffer is being
 * displayed in more than 1 window we change EDIT to HARD. Set MODE if the
 * mode line needs to be updated (the "*" has to be set).
 */
void line_change(int flag)
{
	if (curwp.w_markp)			/* if marking		*/
	    curwp.w_flag |= WFMOVE;		/* so highlighting is updated */
        if ((curbp.b_flag&(BFCHG|BFRDONLY)) == 0) /* First change, so     */
	{   flag |= WFMODE;			/* update mode lines	*/
	    curbp.b_flag |= BFCHG;
        }
	foreach (wp; windows)
	{
                if (wp.w_bufp == curbp)
		{
		    wp.w_flag |= flag;
		    if (wp != curwp)
			wp.w_flag |= WFHARD;
		}
        }
}

/*
 * Insert "n" copies of the character "c" at the current location of dot. In
 * the easy case all that happens is the text is stored in the line. In the
 * hard case, the line has to be reallocated. When the window list is updated,
 * take special care; I screwed it up once. You always update dot in the
 * current window. You update mark, and a dot in another window, if it is
 * greater than the place where you did the insert. Return TRUE if all is
 * well, and FALSE on errors.
 */
int line_insert(int n, char c)
{
        LINE   *lp1;
        LINE   *lp2;
        LINE   *lp3;
        int    doto;

	if (curbp.b_flag & BFRDONLY)		/* if buffer is read-only */
	    return FALSE;			/* error		*/
        line_change(WFEDIT);
        lp1 = curwp.w_dotp;                    /* Current line         */
        if (lp1 == curbp.b_linep) {            /* At the end: special  */
                if (curwp.w_doto != 0) {
                        mlwrite("bug: line_insert");
                        return (FALSE);
                }
		lp2 = line_realloc(null, n);	/* Allocate new line    */
                lp3 = lp1.l_bp;                /* Previous line        */
                lp3.l_fp = lp2;                /* Link in              */
                lp2.l_fp = lp1;
                lp1.l_bp = lp2;
                lp2.l_bp = lp3;
		lp2.l_text[0 .. n] = c;
                curwp.w_dotp = lp2;
                curwp.w_doto = n;
                return (TRUE);
        }
        doto = curwp.w_doto;                   /* Save for later.      */
	lp2 = lp1;
	lp2.l_text.length = lp2.l_text.length + n;

	memmove(lp2.l_text.ptr + doto + n,
		lp2.l_text.ptr + doto,
		(lp2.l_text.length - n - doto) * char.sizeof);
	if (n == 1)
	    lp2.l_text[doto] = c;
	else
	    lp2.l_text[doto .. doto + n] = c;

	/* Update windows       */
	foreach (wp; windows)
	{   if (wp.w_linep == lp1)
		    wp.w_linep = lp2;
	    if (wp.w_dotp == lp1) {
		    wp.w_dotp = lp2;
		    if (wp==curwp || wp.w_doto>doto)
			    wp.w_doto += n;
	    }
	    if (wp.w_markp == lp1) {
		    wp.w_markp = lp2;
		    if (wp.w_marko > doto)
			    wp.w_marko += n;
	    }
	}

        return (TRUE);
}

/***************************
 * Same as line_insert(), but for overwrite mode.
 */

int line_overwrite(int n, char c)
{   int status = true;

    while (n-- > 0)
    {	if (curwp.w_doto < llength(curwp.w_dotp))
	    status = random_forwdel(FALSE,1);
	if (status)
	    status = line_insert(1,c);
	if (!status)
	    break;
    }
    return status;
}

/********************************************
 * Insert a newline into the buffer at the current location of dot in the
 * current window. The funny ass-backwards way it does things is not a botch;
 * it just makes the last line in the file not a special case. Return TRUE if
 * everything works out and FALSE on error (memory allocation failure). The
 * update of dot and mark is a bit easier then in the above case, because the
 * split forces more updating.
 */
int line_newline()
{
        LINE   *lp1;
        LINE   *lp2;
        int    doto;

	if (curbp.b_flag & BFRDONLY)		/* if buffer is read-only */
	    return FALSE;			/* error		*/
        lp1  = curwp.w_dotp;                   /* Get the address and  */
        doto = curwp.w_doto;                   /* offset of "."        */
	lp2 = line_realloc(null,doto);		/* New first half line  */
	lp2.l_text[0 .. doto] = lp1.l_text[0 .. doto];
	memmove(lp1.l_text.ptr, lp1.l_text.ptr + doto, (lp1.l_text.length - doto) * char.sizeof);
	lp1.l_text.length = lp1.l_text.length - doto;

        lp2.l_bp = lp1.l_bp;
        lp1.l_bp = lp2;
        lp2.l_bp.l_fp = lp2;
        lp2.l_fp = lp1;

	foreach (wp; windows)
	{
                if (wp.w_linep == lp1)
                        wp.w_linep = lp2;
                if (wp.w_dotp == lp1) {
                        if (wp.w_doto < doto)
                                wp.w_dotp = lp2;
                        else
                                wp.w_doto -= doto;
                }
                if (wp.w_markp == lp1) {
                        if (wp.w_marko < doto)
                                wp.w_markp = lp2;
                        else
                                wp.w_marko -= doto;
                }
        }       
        line_change(WFHARD);
        return (TRUE);
}

/*
 * This function deletes "n" bytes, starting at dot. It understands how do deal
 * with end of lines, etc. It returns TRUE if all of the characters were
 * deleted, and FALSE if they were not (because dot ran into the end of the
 * buffer). The "kflag" is TRUE if the text should be put in the kill buffer.
 */
bool line_delete(int n, bool kflag)
{
        LINE*  dotp;
        int    doto;
        int    chunk;

	if (curbp.b_flag & BFRDONLY)		/* if buffer is read-only */
	    return FALSE;			/* error		*/
        while (n != 0) {
                dotp = curwp.w_dotp;
                doto = curwp.w_doto;
                if (dotp == curbp.b_linep)     /* Hit end of buffer.   */
                        return (FALSE);
                chunk = cast(int)dotp.l_text.length - doto;   /* Size of chunk.       */
                if (chunk > n)
                        chunk = n;
                if (chunk == 0) {               /* End of line, merge.  */
                        line_change(WFHARD);
                        if (line_delnewline() == FALSE
                        || (kflag!=FALSE && kill_appendchar('\n')==FALSE))
                                return (FALSE);
                        --n;
                        continue;
                }
                line_change(WFEDIT);
                if (kflag != FALSE) {           /* Kill?                */
		    if (!kill_appendstring(dotp.l_text[doto .. doto + chunk]))
			return FALSE;
                }
		memmove(dotp.l_text.ptr + doto,
			dotp.l_text.ptr + doto + chunk,
			(dotp.l_text.length - chunk - doto) * char.sizeof);
		dotp.l_text.length = dotp.l_text.length - chunk;

		foreach (wp; windows)
		{
                        if (wp.w_dotp==dotp && wp.w_doto>=doto) {
                                wp.w_doto -= chunk;
                                if (wp.w_doto < doto)
                                        wp.w_doto = doto;
                        }       
                        if (wp.w_markp==dotp && wp.w_marko>=doto) {
                                wp.w_marko -= chunk;
                                if (wp.w_marko < doto)
                                        wp.w_marko = doto;
                        }
                }
                n -= chunk;
        }
        return (TRUE);
}

/*
 * Delete a newline. Join the current line with the next line. If the next line
 * is the magic header line always return TRUE; merging the last line with the
 * header line can be thought of as always being a successful operation, even
 * if nothing is done, and this makes the kill buffer work "right". Easy cases
 * can be done by shuffling data around. Hard cases require that lines be moved
 * about in memory. Return FALSE on error and TRUE if all looks ok. Called by
 * "line_delete" only.
 */
bool line_delnewline()
{
        LINE   *lp1;
        LINE   *lp2;
        LINE   *lp3;
	int	lp1used;

	if (curbp.b_flag & BFRDONLY)		/* if buffer is read-only */
	    return FALSE;			/* error		*/
        lp1 = curwp.w_dotp;
        lp2 = lp1.l_fp;
	lp1used = cast(int)lp1.l_text.length;
        if (lp2 == curbp.b_linep) {            /* At the buffer end.   */
                if (lp1used == 0)               /* Blank line.          */
                        line_free(lp1);
                return (TRUE);
        }
	lp3 = line_realloc(lp1, lp1used + cast(int)lp2.l_text.length);
	lp3.l_bp.l_fp = lp3;

	memmove(lp3.l_text.ptr + lp1used, lp2.l_text.ptr, lp2.l_text.length * char.sizeof);
        lp3.l_fp = lp2.l_fp;
        lp3.l_fp.l_bp = lp3;

	foreach (wp; windows)
	{
                if (wp.w_linep==lp1 || wp.w_linep==lp2)
                        wp.w_linep = lp3;
                if (wp.w_dotp == lp1)
                        wp.w_dotp  = lp3;
                else if (wp.w_dotp == lp2) {
                        wp.w_dotp  = lp3;
                        wp.w_doto += lp1used;
                }
                if (wp.w_markp == lp1)
                        wp.w_markp  = lp3;
                else if (wp.w_markp == lp2) {
                        wp.w_markp  = lp3;
                        wp.w_marko += lp1used;
                }
        }

	delete lp2.l_text;
	delete lp2;

        return (TRUE);
}


/********************** KILL BUFFER STUFF *********************/

struct killbuf_t
{
    char[] buf;
}

__gshared killbuf_t[4] killbuffer;
__gshared killbuf_t *kbp = &killbuffer[0];	/* current kill buffer	*/

/************************************
 * Set the current kill buffer to i.
 */

void kill_setbuffer(int i)
{
    kbp = &killbuffer[i];
}

void kill_toClipboard()
{
    version (Windows)
    {
	import console;

	if (kbp == &killbuffer[0])
	    setClipboard(kbp.buf);
    }
}

/*
 * Delete all of the text saved in the kill buffer. Called by commands when a
 * new kill context is being created. The kill buffer array is released, just
 * in case the buffer has grown to immense size. No errors.
 */
void kill_freebuffer()
{
    delete kbp.buf;
}

void kill_fromClipboard()
{
    version (Windows)
    {
	import console;

	if (kbp == &killbuffer[0])
	{
	    auto s = getClipboard();
	    if (s)
	    {
		kill_freebuffer();
		kbp.buf = s;
	    }
	}
    }
}

/*
 * Append a character to the kill buffer, enlarging the buffer if there isn't
 * any room. Always grow the buffer in chunks, on the assumption that if you
 * put something in the kill buffer you are going to put more stuff there too
 * later. Return TRUE if all is well, and FALSE on errors.
 */
bool kill_appendchar(char c)
{
    kbp.buf ~= c;
    return (TRUE);
}

/********************************
 * Append string to kill buffer.
 */

bool kill_appendstring(const char[] s)
{
    kbp.buf ~= s;
    return (TRUE);
}

/*
 * This function gets characters from the kill buffer. If the character index
 * "n" is off the end, it returns "-1". This lets the caller just scan along
 * until it gets a "-1" back.
 */
int kill_remove(int n)
{
	return (n >= kbp.buf.length) ? -1 : kbp.buf[n];
}

/********************************
 * We're going to use at least size bytes, so make room for it.
 * Returns:
 *	FALSE	out of memory
 */

int kill_setsize(int size)
{
    auto oldlength = kbp.buf.length;
    kbp.buf.length = size;
    kbp.buf.length = oldlength;
    return TRUE;
}
