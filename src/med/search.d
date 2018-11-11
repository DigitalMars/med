

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The functions in this file implement commands that search in the forward
 * and backward directions. There are no special characters in the search
 * strings. Probably should have a regular expression search, or something
 * like that.
 *
 * REVISION HISTORY:
 *
 * ?    Steve Wilhite, 1-Dec-85
 *      - massive cleanup on code.
 */

module search;

import core.stdc.stdio;
import core.stdc.ctype;
import std.string;
import std.ascii;
import std.uni;

import ed;
import line;
import display;
import window;
import main;
import buffer;
import basic;
import terminal;

enum CASESENSITIVE = true;	/* TRUE means case sensitive		*/
enum WORDPREFIX = 'D' & 0x1F;	// prefix to trigger word search

int Dnoask_search;

/* Returns:
 *	true if word character
 */
bool isWordChar(char c)
{
    return isalnum(c) || c == '_';
}

/*
 * Search forward. Get a search string from the user, and search, beginning at
 * ".", for the string. If found, reset the "." to be just after the match
 * string, and [perhaps] repaint the display. Bound to "C-S".
 */
int forwsearch(bool f, int n)
{
    int s;
    if ((s = readpattern("Search: ",pat)) != TRUE)
        return (s);

    static bool notFound()
    {
	mlwrite("Not found");
	return FALSE;
    }

    bool word;
    string pattern = pat;	// pattern to match
    if (pattern.length == 0)
	return notFound();
    word = pattern[0] == WORDPREFIX;  // ^D means only match words
    if (word)
    {
	pattern = pattern[1 .. $];
	if (pattern.length == 0)
	    return notFound();
    }

    char p0 = pattern[0];		// first char to match

    LINE* clp = curwp.w_dotp;		/* get pointer to current line	*/
    int cbo = curwp.w_doto;		/* and offset into that line	*/

    char lastc;

again:
    while (!empty(clp, cbo))		/* while not end of buffer	*/
    {
	int c = front(clp, cbo);
	popFront(clp, cbo);
	if (!eq(c, p0))
	{
	    lastc = cast(char)c;
	    continue;
	}
	if (word && lastc != lastc.init && isWordChar(lastc))
	    continue;
	lastc = cast(char)c;

	{
            LINE* tlp = clp;
            int tbo = cbo;			/* remember where start of pattern */

	    foreach (pc; pattern[1 .. $])
	    {
		if (empty(tlp, tbo))
		    continue again;
		c = front(tlp, tbo);
		popFront(tlp, tbo);

		lastc = cast(char)c;

                if (!eq(c, pc))
                    continue again;
	    }

	    if (word && !empty(tlp, tbo) && isWordChar(cast(char)front(tlp, tbo)))
	    {
		continue again;
	    }

	    /* We've found it. It starts at clp,cbo and ends before tlp,tbo */
            curwp.w_dotp  = tlp;
            curwp.w_doto  = tbo;
            curwp.w_flag |= WFMOVE;
            return (TRUE);
	}
    }

    return notFound();
}

/*
 * Reverse search. Get a search string from the user, and search, starting at
 * "." and proceeding toward the front of the buffer. If found "." is left
 * pointing at the first character of the pattern [the last character that was
 * matched]. Bound to "C-R".
 */
int backsearch(bool f, int n)
{
    int s;
    if ((s = readpattern("Reverse search: ",pat)) != TRUE)
        return (s);

    static bool notFound()
    {
	mlwrite("Not found");
	return FALSE;
    }

    bool word;
    string pattern = pat;	// pattern to match
    if (pattern.length == 0)
	return notFound();
    word = pattern[0] == WORDPREFIX;  // ^D means only match words
    if (word)
    {
	pattern = pattern[1 .. $];
	if (pattern.length == 0)
	    return notFound();
    }

    immutable(char)* epp = &pattern[$ - 1];

    LINE* clp = curwp.w_dotp;
    int cbo = curwp.w_doto;

again:
    for (;;)
    {
	if (atFront(clp, cbo))
	    return notFound();

        if (word && !empty(clp, cbo) && isWordChar(cast(char)front(clp, cbo)))
	{
	    popBack(clp, cbo);
	    continue;
	}

	popBack(clp, cbo);
	int c = front(clp, cbo);

        if (eq(c, *epp))
	{
            LINE* tlp = clp;
            int tbo = cbo;
            auto pp  = epp;

            while (pp != &pattern[0])
	    {
		if (atFront(tlp, tbo))
		    continue again;
		popBack(tlp, tbo);
		c = front(tlp, tbo);

                if (!eq(c, *--pp))
                    continue again;
	    }

	    if (word && !atFront(tlp, tbo) && isWordChar(cast(char)peekBack(tlp, tbo)))
	    {
		continue again;
	    }

            curwp.w_dotp  = tlp;
            curwp.w_doto  = tbo;
            curwp.w_flag |= WFMOVE;
            return (TRUE);
	}
    }
    assert(0);
}

/*
 * Compare two characters. The "bc" comes from the buffer. It has it's case
 * folded out. The "pc" is from the pattern.
 */

bool eq(int bc, int pc)
{
    if (CASESENSITIVE)
	return bc == pc;

    if (bc>='a' && bc<='z')
        bc -= 0x20;

    if (pc>='a' && pc<='z')
        pc -= 0x20;

    return (bc == pc);
}

/*********************************
 * Replace occurrences of pat with withpat.
 */

int replacestring(bool f, int n)
{
	return replace(FALSE);
}

/********************************
 */

int queryreplacestring(bool f, int n)
{
	return replace(TRUE);
}

/*************************
 * Do the replacements.
 * Input:
 *	query	if TRUE then it's a query-search-replace
 */

private int replace(bool query)
{
    LINE * clp;
    int    cbo;
    LINE * tlp;
    int    tbo;
    int    c;
    int    s;
    int    numreplacements;
    int    retval;
    LINE*  dotpsave;
    int dotosave;
    string withpat;
    int stop;

    if ((s = readpattern("Replace: ", pat)) != TRUE)
	return (s);			/* must have search pattern	*/

    bool word;
    string pattern = pat;	// pattern to match
    if (pattern.length == 0)
	return FALSE;
    word = pattern[0] == WORDPREFIX;  // ^D means only match words
    if (word)
    {
	pattern = pattern[1 .. $];
	if (pattern.length == 0)
	    return FALSE;
    }

    readpattern ("With: ", withpat);	/* replacement pattern can be null */

    stop = FALSE;
    retval = TRUE;
    numreplacements = 0;
    dotpsave = curwp.w_dotp;
    dotosave = curwp.w_doto;		/* save original position	*/
    clp = curwp.w_dotp;			/* get pointer to current line	 */
    cbo = curwp.w_doto;			/* and offset into that line	 */

    auto p0 = pattern[0];

    char lastc;

again:
    while (!empty(clp, cbo))		/* while not end of buffer	 */
    {
	/* Compute c, the character at the current position		 */
	c = front(clp, cbo);
	popFront(clp, cbo);

	if (!eq(c, p0))
	{
	    lastc = cast(char)c;
	    continue;
	}
	if (word && lastc != lastc.init && isWordChar(lastc))
	    continue;
	lastc = cast(char)c;

	{
	    tlp = clp;
	    tbo = cbo;			/* remember where start of pattern */
	    int i = 1;

	    foreach (pc; pattern[1 .. $])
	    {
		if (empty(tlp, tbo))
		    continue again;
		c = front(tlp, tbo);
		popFront(tlp, tbo);

		lastc = cast(char)c;

		if (!eq(c, pc))
		    continue again;
		i++;
	    }

	    if (word && !empty(tlp, tbo) && isWordChar(cast(char)front(tlp, tbo)))
	    {
		continue again;
	    }

	    /* We've found it. It starts before clp,cbo and ends	*/
	    /* before tlp,tbo						*/

	    /* If query, get user input about this			*/
	    if (query)
	    {
		curwp.w_dotp= clp;
		curwp.w_doto = cbo;
		backchar(FALSE,1);
		mlwrite("' ' change 'n' continue '!' change rest '.' change and stop ^G abort");
		curwp.w_flag |= WFMOVE;
	      tryagain:
		update();
		switch (getkey())
		{
		    case 'n':		/* don't change, but continue	*/
			continue again;

		    /*case 'R':*/	/* enter recursive edit		*/
		    case '!':		/* change rest w/o asking	*/
			query = FALSE;
			goto case;

		    case ' ':		/* change and continue to next	*/
			break;
		    case '.':		/* change and stop		*/
			stop = TRUE;
			break;
		    case 'G' & 0x1F:	/* abort			*/
			goto abortreplace;
		    default:		/* illegal command		*/
			term.t_beep();
			goto tryagain;
		}
	    }

	    /* Delete the pattern by setting the current position to	*/
	    /* the start of the pattern, and deleting 'n' characters	*/
	    curwp.w_flag |= WFHARD;
	    curwp.w_dotp= clp;
	    curwp.w_doto = cbo;
	    if (backchar(FALSE,1) == FALSE ||
		line_delete(i,FALSE) == FALSE)
		goto L1;

	    /* 'Yank' the replacement pattern back in at dot (also	*/
	    /* moving cursor past end of replacement pattern to prevent	*/
	    /* recursive replaces).					*/
	    foreach (wc; withpat)
		if (line_insert(1, wc) == FALSE)
		{
		    goto L1;
		}

	    /* Take care of case where line_insert() reallocated the line	*/
	    if (dotpsave == clp)
		dotpsave = curwp.w_dotp;
	    clp = curwp.w_dotp;
	    cbo = curwp.w_doto;		/* continue from end of with text */
	    numreplacements++;
	    if (stop)
		break;
	}
    }

abortreplace:
    curwp.w_dotp = dotpsave;
    curwp.w_doto = dotosave;		/* back to original position	*/
    curwp.w_flag |= WFMOVE;
    mlwrite("%d replacements done", numreplacements);
    return retval;

L1:
    if (dotpsave == clp)
	dotpsave = curwp.w_dotp;
    retval = FALSE;
    goto abortreplace;
}

/*
 * Read a pattern. Stash it in the external variable "pat". The "pat" is not
 * updated if the user types in an empty line. If the user typed an empty line,
 * and there is no old pattern, it is an error. Display the old pattern, in the
 * style of Jeff Lomicka. There is some do-it-yourself control expansion.
 */
private int readpattern(string prompt, ref string pat)
{
    if( Dnoask_search )
	return( pat.length != 0 );
    auto tpat = pat;
    auto s = mlreply(prompt, pat, tpat);

    if (s == TRUE)                      /* Specified */
        pat = tpat;
    else if (s == FALSE && pat.length != 0)         /* CR, but old one */
        s = TRUE;

    return (s);
}

/*********************************
 * Examine line at '.'.
 * Returns:
 *	HASH_xxx
 *	0	anything else
 */

enum
{
	HASH_IF		= 1,
	HASH_ELIF	= 2,
	HASH_ELSE	= 3,
	HASH_ENDIF	= 4,
}

static int ifhash(LINE* clp)
{
    int len;
    int i;
    static string[] hash = ["if","elif","else","endif"];

    len = cast(int)clp.l_text.length;
    if (len < 3 || lgetc(clp,0) != '#')
	goto ret0;
    for (i = 1; ; i++)
    {
	if (i >= len)
	    goto ret0;
	if (!isSpace(clp.l_text[i]))
	    break;
    }
    for (int h = 0; h < hash.length; h++)
	if (len - i >= hash[h].length &&
	    clp.l_text[i .. i + hash[h].length] == hash[h])
	    return h + 1;
ret0:
    return 0;
}

/*********************************
 * Search for the next occurence of the character at '.'.
 * If character is a (){}[]<>, search for matching bracket.
 * If '.' is on #if, #elif, or #else search for next #elif, #else or #endif.
 * If '.' is on #endif, search backwards for corresponding #if.
 */

int search_paren(bool f, int n)
{
    LINE* clp;
    int cbo;
    int len;
    int i;
    char chinc,chdec,ch;
    int count;
    int forward;
    int h;
    static char[2][] bracket = [['(',')'],['<','>'],['[',']'],['{','}']];

    clp = curwp.w_dotp;		/* get pointer to current line	*/
    cbo = curwp.w_doto;		/* and offset into that line	*/
    count = 0;

    len = llength(clp);
    if (cbo >= len)
	chinc = '\n';
    else
	chinc = lgetc(clp,cbo);

    if (cbo == 0 && (h = ifhash(clp)) != 0)
    {	forward = h != HASH_ENDIF;
    }
    else
    {
	forward = TRUE;			/* forward			*/
	h = 0;
	chdec = chinc;
	for (i = 0; i < bracket.length; i++)
	    if (bracket[i][0] == chinc)
	    {	chdec = bracket[i][1];
		break;
	    }
	for (i = 0; i < bracket.length; i++)
	    if (bracket[i][1] == chinc)
	    {	chdec = bracket[i][0];
		forward = FALSE;	/* search backwards		*/
		break;
	    }
    }

    while (1)				/* while not end of buffer	*/
    {
	if (forward)
	{
	    if (h || cbo >= len)
	    {
		clp = lforw(clp);
		if (clp == curbp.b_linep)	/* if end of buffer	*/
		    break;
		len = llength(clp);
		cbo = 0;
	    }
	    else
		cbo++;
	}
	else /* backward */
	{
	    if (h || cbo == 0)
            {
		clp = lback(clp);
		if (clp == curbp.b_linep)
		    break;
		len = llength(clp);
		cbo = len;
            }
	    else
		--cbo;
	}

	if (h)
	{   int h2;

	    cbo = 0;
	    h2 = ifhash(clp);
	    if (h2)
	    {	if (h == HASH_ENDIF)
		{
		    if (h2 == HASH_ENDIF)
			count++;
		    else if (h2 == HASH_IF)
		    {	if (count-- == 0)
			    goto found;
		    }
		}
		else
		{   if (h2 == HASH_IF)
			count++;
		    else
		    {	if (count == 0)
			    goto found;
			if (h2 == HASH_ENDIF)
			    count--;
		    }
		}
	    }
	}
	else
	{
	    ch = (cbo < len) ? lgetc(clp,cbo) : '\n';
	    if (eq(ch,chdec))
	    {   if (count-- == 0)
		{
		    /* We've found it	*/
		found:
		    curwp.w_dotp  = clp;
		    curwp.w_doto  = cbo;
		    curwp.w_flag |= WFMOVE;
		    return (TRUE);
		}
	    }
	    else if (eq(ch,chinc))
		count++;
	}
    }
    mlwrite("Not found");
    return (FALSE);
}
