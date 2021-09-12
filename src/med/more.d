

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


/*
 * Due to my (Bjorn Benson) laziness, the functions will all
 * work with a positive argument, but may or may not with
 * a negative.
 */

module more;

import core.stdc.stdio;

import std.ascii;
import std.uni;
import std.process;

import ed;
import main;
import window;
import buffer;
import line;
import search;
import random;
import region;
import word;
import basic;
import terminal;
import display;
import url;
import utf;

version (Posix)
{
    import core.sys.posix.signal;
    import core.sys.posix.unistd;
}

/*
 * The multiple delete buffers
 */
enum
{
	DK_CUT,
	DK_LINE,
	DK_WORD,
	DK_CHAR,
}

void SETMARK()
{
    curwp.w_markp = curwp.w_dotp;
    curwp.w_marko = curwp.w_doto;
}

/*
 * Current direction that things happen in
 */
enum
{
	ADVANCE,
	BACKUP,
}

int Dcur_direction = ADVANCE;

int Dsearch(bool f, int n)
{
	if( Dcur_direction == ADVANCE )
		return( forwsearch(f, n) );
	else	return( backsearch(f, n) );
}

int Dsearchagain(bool f, int n)
{
	int s;
	Dnoask_search = true;
	scope(exit) Dnoask_search = false;
	if( Dcur_direction == ADVANCE )
		s = forwsearch(f, n);
	else	s = backsearch(f, n);
	return s;
}

int Ddelline(bool f, int n)
{
	int s = true;

	kill_setbuffer(DK_LINE);
	kill_freebuffer();
	while( n-- > 0 && s )
	{   curwp.w_doto = 0;
	    s &= line_delete(llength(curwp.w_dotp) + 1, true);
	}
	kill_setbuffer(DK_CUT);
	return s;
}

int Dundelline(bool f, int n)
{
	int s = true;

	kill_setbuffer(DK_LINE);
	while( n-- > 0 && s )
	{
		curwp.w_doto = 0;
		s = random_yank(true, 1);
		backline(false, 1);
		curwp.w_doto = 0;
	}
	kill_setbuffer(DK_CUT);
	return s;
}

int Ddelword(bool f, int n)
{
	int s = true;

	kill_setbuffer(DK_WORD);
	kill_freebuffer();
	while( n-- > 0 && s )
	{
		SETMARK();
		s = word_forw(false, 1);
		if( !s ) break;
		s = region_kill(false, 1);
	}
	kill_setbuffer(DK_CUT);
	return s;
}

int Ddelbword(bool f, int n)
{
	int s = true;

	kill_setbuffer(DK_WORD);
	kill_freebuffer();
	while( n-- > 0 && s )
	{
		SETMARK;
		s = word_back(false, 1);
		if( !s ) break;
		s = region_kill(false, 1);
	}
	kill_setbuffer(DK_CUT);
	return s;
}

int Dundelword(bool f, int n)
{
	int s = true;

	kill_setbuffer(DK_WORD);
	while( n-- > 0 && s )
		s &= random_yank(true, 1);
	kill_setbuffer(DK_CUT);
	return s;
}

int Dadvance(bool f, int n)
{
	Dcur_direction = ADVANCE;
	return true;
}

int Dbackup(bool f, int n)
{
	Dcur_direction = BACKUP;
	return true;
}

int Dignore(bool f, int n)
{
	/* Ignore this command. Useful for ^S and ^Q flow control	*/
	/* sent out by some terminals.					*/
	return true;
}

int Dpause(bool f, int n)
{
    version (Posix)
    {
	term.t_move( term.t_nrow - 1, 0 );
	term.t_eeop();
	term.t_flush();
	term.t_close();
	killpg(getpgid(0), 18);	/* SIGTSTP -- stop the current program */
	term.t_open();
	sgarbf = true;
	window_refresh(false, 1);
    }
    return true;
}

/*********************************
 * Decide whether to uppercase a word or a region.
 */

int misc_upper(bool f, int n)
{
    if (curwp.w_markp)
	return region_upper(f,n);
    else
	return word_upper(f,n);
}

/*********************************
 * Decide whether to lowercase a word or a region.
 */

int misc_lower(bool f, int n)
{
    if (curwp.w_markp)
	return region_lower(f,n);
    else
	return word_lower(f,n);
}

/*********************************
 * Insert file name and date at top of file.
 */

int Dinsertdate(bool f, int n)
{	return false;
}

/***********************************
 * Remove trailing whitespace from line.
 */

void deblank()
{   int len;
    int n;
    int c;
    int i;

    len = llength(curwp.w_dotp);
    for (i = len - 1; i >= 0; i--)
    {
	c = lgetc(curwp.w_dotp, i);
	if (!isSpace(c))
	    break;
    }
    n = (len - 1) - i;
    if (n)
    {
	curwp.w_doto = i + 1;
	line_delete(n,false);
    }
}

/*********************************
 * Convert C comment to C++ comment.
 */

int Dcppcomment(bool f, int n)
{
        int    c;
        int    i;
	LINE *dotpsave;
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
        while (n--)
	{   int len;

	    deblank();
	    len = llength(curwp.w_dotp);
	    if (len)
	    {
		for (i = 0; i + 3 < len; i++)
		{
		    c = lgetc(curwp.w_dotp, i);
		    if (c == '/' && lgetc(curwp.w_dotp, i + 1) == '*')
		    {
			if (lgetc(curwp.w_dotp, len - 2) == '*' &&
			    lgetc(curwp.w_dotp, len - 1) == '/')
			{
			    curwp.w_doto = i + 1;
			    line_delete(1,false);
			    line_insert(1,'/');
			    curwp.w_doto = len - 2;
			    line_delete(2,false);
			    deblank();
			    break;
			}
		    }
                }
		curwp.w_doto = 0;	/* move to beginning of line	*/
	    }
	    if (forwline(false,1) == false)
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

/************************************
 * Open browser on URL.
 */
int openBrowser(bool f, int n)
{
    LINE* dotp = curwp.w_dotp;
    auto s = getURL(dotp.l_text[0 .. llength(dotp)], curwp.w_doto);
    if (s)
    {
	browse(cast(string)s);
	return TRUE;
    }
    return FALSE;
}

/***************************
 * Look up current character in the replacement table,
 * and replace it with the next character in the table.
 * Returns:
 *	TRUE = success
 *	FALSE = failure
 */

int scrollUnicode(bool f, int n)
{
    /* Mapping table of one character to the next in each entry
     */
    __gshared immutable string[] table =
    [
	"a\&auml;\&agrave;\&aacute;\&acirc;\&atilde;\&aring;\&aelig;\&alpha;\&ordf;",
	"e\&egrave;\&eacute;\&ecirc;\&euml;\&epsilon;\&eta;",
        "i\&igrave;\&iacute;\&icirc;\&iuml;\&iota;",
        "o\&ograve;\&oacute;\&ocirc;\&otilde;\&ouml;\&oslash;\&omicron;\&oelig;",
        "u\&ugrave;\&uacute;\&ucirc;\&uuml;\&mu;\&upsilon;",

	"A\&Agrave;\&Aacute;\&Acirc;\&Atilde;\&Auml;\&Aring;\&AElig;\&Alpha;\&forall;",
	"E\&Egrave;\&Eacute;\&Ecirc;\&Euml;\&Epsilon;\&exist;\&isin;\&notin;\&ni;",
	"I\&Igrave;\&Iacute;\&Icirc;\&Iuml;\&Iota;\&int;",
	"O\&Ograve;\&Oacute;\&Ocirc;\&Ouml;\&Omicron;",
	"U\&Ugrave;\&Uacute;\&Ucirc;\&Uuml;\&cap;\&cup;\&sub;\&sup;\&nsub;",

	"c\&ccedil;\&copy;",
	"C\&Ccedil;",

	"$\&euro;\&cent;\&pound;\&curren;\&yen;",
	"\"\&ldquo;\&rdquo;\&bdquo;\&laquo;\&raquo;",
	"'\&lsquo;\&rsquo;\&sbquo;\&acute;",
	"-\&ndash;\&mdash;\&macr;\&oline;\&minus;",
	"~\&tilde;\&sim;\&cong;\&asymp;",
	"!\&iexcl;",
    ];

    LINE* dotp = curwp.w_dotp;
    auto s = dotp.l_text[0 .. llength(dotp)];
    size_t index = curwp.w_doto;

    size_t i = index;
    dchar dc = decodeUTF8(s, i);
    foreach (entry; table)
    {
	for (size_t j = 0; j < entry.length; )
	{
	    dchar dr = decodeUTF8(entry, j);
	    if (dr == dc)
	    {
		if (j == entry.length)
		    j = 0;
		size_t k = j;
		decodeUTF8(entry, k);

		/* Replace s[index .. i] with entry[j .. k]
		 */
		line_delete(i - index, FALSE);
		foreach (char c; entry[j .. k])
		    line_insert(1, c);
		backchar(f, k - j);
		line_change(WFEDIT);

		return TRUE;
	    }
	}
    }
    return FALSE;
}

