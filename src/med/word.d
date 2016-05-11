

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The routines in this file implement commands that work word at a time.
 * There are all sorts of word mode commands. If I do any sentence and/or
 * paragraph mode commands, they are likely to be put in this file.
 */

module word;

import std.ascii;

import ed;
import main;
import window;
import random;
import line;
import terminal;
import xterm;
import region;
import basic;
import display;

/* Word wrap. Back-over whatever precedes the point on the current
 * line and stop on the first word-break or the beginning of the line. If we
 * reach the beginning of the line, jump back to the end of the word and start
 * a new line.  Otherwise, break the line at the word-break, eat it, and jump
 * back to the end of the word.
 *      NOTE:  This function may leaving trailing blanks.
 * Returns true on success, false on errors.
 */
int word_wrap(bool f, int n)
{
        int cnt;
	LINE* oldp;

        oldp = curwp.w_dotp;
        cnt = -1;
        do {                            
                cnt++;
                if (! backchar(false, 1))
		    goto err;
        } while (! inword());
        if (! word_back(false, 1))
	    goto err;
	/* If still on same line (but not at the beginning)	*/
        if (oldp == curwp.w_dotp && curwp.w_doto)
	{   int i;

	    if (!random_backdel(false, 1))
		goto err;
	    if (!random_newline(false, 1))
		goto err;
	    oldp = lback(curwp.w_dotp);
	    i = 0;
	    while (1)
	    {
		auto c = lgetc(oldp,i);
		if (c != ' ' && c != '\t')
		    break;
		line_insert(1,c);
		i++;
	    }
        }
	while (inword() == true)
	    if (forwchar(false, 1) == false)
		goto err;
        return forwchar(false, cnt);

err:
	return false;
}

/****************************
 * Word wrap the current line.
 */

int word_wrap_line(bool f, int n)
{
    int i;
    int j;
    int col;
    char c;
    int inword;
    int lasti;
    LINE* oldp;
    LINE* dotpsave;
    int dotosave;

    if (n < 0)
	goto err;

    if (window_marking(curwp))
    {   REGION region;
	int s;

	if ((s = getregion(&region)) != true)
	    return s;
	dotpsave = curwp.w_dotp;
	dotosave = curwp.w_doto;
	curwp.w_dotp = region.r_linep;
	curwp.w_doto = region.r_offset;
	n = region.r_nlines;
    }

    while (n-- > 0)
    {
      L1:
	col = 0;
	lasti = 0;
	inword = 0;
	for (i = 0; i < llength(curwp.w_dotp); i++)
	{
	    c = lgetc(curwp.w_dotp, i);
	    if (c == ' ' || c == '\t')
	    {
		if (inword)
		    lasti = i;
		inword = 0;
	    }
	    else
	    {
		inword = 1;
	    }
	    col = getcol(curwp.w_dotp, i);
	    if (col >= term.t_ncol && lasti)
	    {
		if (!forwchar(0, lasti - curwp.w_doto))
		    goto err;
		if (!random_newline(0,1))
		    goto err;

		/* Remove leading whitespace from new line	*/
		while (1)
		{
		    if (!llength(curwp.w_dotp))
			break;
		    c = lgetc(curwp.w_dotp, 0);
		    if (c == ' ' || c == '\t')
		    {
			if (!random_forwdel(0, 1))
			    goto err;
		    }
		    else
			break;
		}

		/* Match indenting of original line (oldp)	*/
		oldp = lback(curwp.w_dotp);
		for (j = 0; j < llength(oldp); j++)
		{
		    c = lgetc(oldp, j);
		    if (c == ' ' || c == '\t')
		    {
			if (!line_insert(1, c))
			    goto err;
		    }
		    else
			break;
		}

		goto L1;
	    }
	}
	if (!forwline(0, 1))
	    goto err;
    }
    if (window_marking(curwp))
    {
	if (dotosave > llength(dotpsave))
	    dotosave = llength(dotpsave);
	curwp.w_dotp = dotpsave;
	curwp.w_doto = dotosave;
    }
    return true;

err:
    return false;
}

/*************************
 * Select word that the cursor is on.
 */

int word_select(bool f, int n)
{
    int inw;
    int s;

    inw = inword();
    do
	s = backchar(false, 1);
    while (s && inword() == inw);

    return s &&
	forwchar(false,1) &&
	basic_setmark(false,1) &&
	word_forw(f,n);
}

/******************************
 * Select line that the cursor is on.
 */

int word_lineselect(bool f, int n)
{
    return (curwp.w_doto == 0 || gotobol(false,1)) &&
	basic_setmark(false,1) &&
	forwline(f,n);
}

/*
 * Move the cursor backward by "n" words. All of the details of motion are
 * performed by the "backchar" and "forwchar" routines. Error if you try to
 * move beyond the buffers.
 */
int word_back(bool f, int n)
{
        if (n < 0)
                return (word_forw(f, -n));
        if (backchar(false, 1) == false)
                return (false);
        while (n--) {
	    auto inw = inword();
	    do
		if (backchar(false, 1) == false)
		    return (false);
	    while (inword() == inw);
        }
        return (forwchar(false, 1));
}

/*
 * Move the cursor forward by the specified number of words. All of the motion
 * is done by "forwchar". Error if you try and move beyond the buffer's end.
 */
int word_forw(bool f, int n)
{
        if (n < 0)
                return (word_back(f, -n));
        while (n--) {
	    auto inw = inword();
	    do
		if (forwchar(false, 1) == false)
		    return (false);
	    while (inword() == inw);
        }
        return (true);
}

/*
 * Move the cursor forward by the specified number of words. As you move,
 * convert any characters to upper case. Error if you try and move beyond the
 * end of the buffer. Bound to "M-U".
 */
int word_upper(bool f, int n)
{
    return word_setcase(f,n,0);
}

/*
 * Move the cursor forward by the specified number of words. As you move
 * convert characters to lower case. Error if you try and move over the end of
 * the buffer. Bound to "M-L".
 */
int word_lower(bool f, int n)
{
    return word_setcase(f,n,1);
}

/*************************
 * Move the cursor forward by the specified number of words. As you move
 * convert the first character of the word to upper case, and subsequent
 * characters to lower case. Error if you try and move past the end of the
 * buffer. Bound to "M-C".
 */

int capword(bool f, int n)
{
    return word_setcase(f,n,2);
}

private int word_setcase(bool f, int n, int flag)
{
    char    c;

    if (n < 0)
	return (false);
    while (n--) {
	while (inword() == false) {
	    if (forwchar(false, 1) == false)
		return (false);
	}
	if (flag == 2 && inword() != false) {
	    c = lgetc(curwp.w_dotp, curwp.w_doto);
	    if (isLower(c))
	    {   c -= 'a'-'A';
		lputc(curwp.w_dotp, curwp.w_doto, c);
		line_change(WFHARD);
	    }
	    if (forwchar(false, 1) == false)
		return (false);
	}
	while (inword() != false) {
	    c = lgetc(curwp.w_dotp, curwp.w_doto);
	    final switch (flag)
	    {   case 0:
		    if (isLower(c)) {
			c -= 'a'-'A';
			goto L1;
		    }
		    break;
		case 1:
		case 2:
		    if (isUpper(c)) {
			c += 'a'-'A';
		    L1: lputc(curwp.w_dotp, curwp.w_doto, c);
			line_change(WFHARD);
		    }
		    break;
	    }
	    if (forwchar(false, 1) == false)
		return (false);
	}
    }
    return (true);
}

/*
 * Kill forward by "n" words. Remember the location of dot. Move forward by
 * the right number of words. Put dot back where it was and issue the kill
 * command for the right number of characters. Bound to "M-D".
 */
int delfword(bool f, int n)
{
        int    size;
        LINE*  dotp;
        int    doto;

        if (n < 0)
                return (false);
        dotp = curwp.w_dotp;
        doto = curwp.w_doto;
        size = 0;
        while (n--) {
                while (inword() == false) {
                        if (forwchar(false, 1) == false)
                                return (false);
                        ++size;
                }
                while (inword() != false) {
                        if (forwchar(false, 1) == false)
                                return (false);
                        ++size;
                }
        }
        curwp.w_dotp = dotp;
        curwp.w_doto = doto;
        return (line_delete(size, true));
}

/*
 * Kill backwards by "n" words. Move backwards by the desired number of words,
 * counting the characters. When dot is finally moved to its resting place,
 * fire off the kill command. Bound to "M-Rubout" and to "M-Backspace".
 */
int delbword(bool f, int n)
{
        int    size;

        if (n < 0)
                return (false);
        if (backchar(false, 1) == false)
                return (false);
        size = 0;
        while (n--) {
                while (inword() == false) {
                        if (backchar(false, 1) == false)
                                return (false);
                        ++size;
                }
                while (inword() != false) {
                        if (backchar(false, 1) == false)
                                return (false);
                        ++size;
                }
        }
        if (forwchar(false, 1) == false)
                return false;
        return line_delete(size, true);
}

/*
 * Return true if the character at dot is a character that is considered to be
 * part of a word. The word character list is hard coded. Should be setable.
 * This routine MUST return only a 1 or a 0.
 */
bool inword()
{
        if (curwp.w_doto == llength(curwp.w_dotp))
                return false;
        auto c = lgetc(curwp.w_dotp, curwp.w_doto);
	return (isAlphaNum(c) ||
		 c=='$' || c=='_');	/* For identifiers      */
}
