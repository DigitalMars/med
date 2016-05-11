

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The routines in this file
 * handle the reading and writing of
 * disk files. All of details about the
 * reading and writing of the disk are
 * in "fileio.c".
 */

module file;

import core.stdc.stdlib;

import std.stdio;
import std.path;
import std.string;
import std.file;
import std.utf;

import ed;
import main;
import region;
import window;
import fileio;
import line;
import buffer;
import display;
import random;

/**********************************
 * Save current file. Get next file and read it into the
 * current buffer. Next file is either:
 *	o next argument from command line
 *	o input from the user
 */

int filenext(bool f, int n)
{	int s;

	if (filesave(f,n) == FALSE)	/* save current file		*/
		return FALSE;
	if (gargi < gargs.length)	/* if more files on command line */
	{
		s = readin(gargs[gargi]);
		gargi++;
	}
	else				/* get file name from user	*/
		s = fileread(f,n);
	curbp.b_bname = makename(curbp.b_fname);
	return s;
}

/**********************************
 * Insert a file into the current buffer.
 */

int Dinsertfile(bool f, int n)
{
    string fnamed;

    if (mlreply("Insert file: ", null, fnamed) == FALSE)
	    return FALSE;

    string fname = toUTF8(fnamed);
    try
    {
	fname = std.path.expandTilde(fname);
	auto fp = File(fname);
	mlwrite("[Reading file]");
	int nline = 0;
	char[] line;
	size_t s;
	while ((s = fp.readln(line)) != 0)
	{
	    foreach(char c; line)
	    {
		if (c == '\r' || c == '\n')
		    break;
		if (line_insert(1,c) == FALSE)
		    return FALSE;
	    }
	    if (random_newline(FALSE,1) == FALSE)
		return FALSE;
	    ++nline;
	}
	fp.close();
	if (nline == 1)
	    mlwrite("[Read 1 line]");
	else
	    mlwrite(format("[Read %d lines]", nline));
	return TRUE;
    }
    catch (Exception e)
    {
	mlwrite(e.toString());
	return FALSE;
    }
    finally
    {
	foreach (wp; windows)
	{
	    if (wp.w_bufp == curbp) {
		wp.w_flag |= WFMODE|WFHARD;
	    }
        }
    }
}

/*
 * Read a file into the current
 * buffer. This is really easy; all you do it
 * find the name of the file, and call the standard
 * "read a file into the current buffer" code.
 * Bound to "C-X C-R".
 */
int fileread(bool f, int n)
{
        int    s;
        string fname;

        if ((s=mlreply("Read file: ", null, fname)) != TRUE)
                return (s);
        return (readin(fname));
}

/*
 * Select a file for editing.
 * Look around to see if you can find the
 * file in another buffer; if you can find it
 * just switch to the buffer. If you cannot find
 * the file, create a new buffer, read in the
 * text, and switch to the new buffer.
 * Bound to GOLD E.
 */
int filevisit(bool f, int n)
{
        string fname;

        return	mlreply("Visit file: ", null, fname) &&
		window_split(f,n) &&
		file_readin(fname);
}

int file_readin(string fname)
{
    LINE   *lp;
    int    i;
    int    s;
    string bname;

    /* If there is an existing buffer with the same file name, simply	*/
    /* switch to it instead of reading the file again.			*/
    foreach (bp; buffers)
    {
	/* Always redo temporary buffers, check for filename match.	*/
	if ((bp.b_flag&BFTEMP)==0 && globMatch(bp.b_fname, fname))
	{
	    /* If the current buffer now becomes undisplayed		*/
	    if (--curbp.b_nwnd == 0)
	    {
		curbp.b_dotp  = curwp.w_dotp;
		curbp.b_doto  = curwp.w_doto;
		curbp.b_markp = curwp.w_markp;
		curbp.b_marko = curwp.w_marko;
	    }
	    curbp = bp;
	    curwp.w_bufp  = bp;
	    if (bp.b_nwnd++ == 0)	/* if buffer not already displayed */
	    {
		curwp.w_dotp  = bp.b_dotp;
		curwp.w_doto  = bp.b_doto;
		curwp.w_markp = bp.b_markp;
		curwp.w_marko = bp.b_marko;
	    }
	    else
	    {
		/* Set dot to be at place where other window has it	*/
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

	    /* Adjust frame so dot is at center	*/
	    lp = curwp.w_dotp;
	    i = curwp.w_ntrows/2;
	    while (i-- && lback(lp)!=curbp.b_linep)
		lp = lback(lp);
	    curwp.w_linep = lp;

	    curwp.w_flag |= WFMODE|WFHARD;
	    mlwrite("[Old buffer]");
	    return TRUE;
	}
    }

    bname = makename(fname);                 /* New buffer name.     */
    BUFFER* bp;
    while ((bp=buffer_find(bname, FALSE, 0)) != null)
    {
	s = mlreply("Buffer name: ", null, bname);
	if (s == ABORT)                 /* ^G to just quit      */
	    return (s);
	if (s == FALSE) {               /* CR to clobber it     */
	    bname = makename(fname);
	    break;
	}
    }
    if (bp==null && (bp=buffer_find(bname, TRUE, 0))==null)
    {	mlwrite("Cannot create buffer");
	return (FALSE);
    }
    if (--curbp.b_nwnd == 0)			/* Undisplay		*/
    {	curbp.b_dotp = curwp.w_dotp;
	curbp.b_doto = curwp.w_doto;
	curbp.b_markp = curwp.w_markp;
	curbp.b_marko = curwp.w_marko;
    }
    curbp = bp;                             /* Switch to it.        */
    curwp.w_bufp = bp;
    curbp.b_nwnd++;
    return (readin(fname));                 /* Read it in.          */
}

/*
 * Read file "fname" into the current
 * buffer, blowing away any text found there. Called
 * by both the read and visit commands. Return the final
 * status of the read. Also called by the mainline,
 * to read in a file specified on the command line as
 * an argument.
 */
int readin(string dfname)
{
    auto bp = curbp;                            // Cheap.
    auto b = buffer_clear(bp);  		// Might be old.
    if (b != TRUE)
	    return b;
    bp.b_flag &= ~(BFTEMP|BFCHG);
    bp.b_fname = dfname;

    /* Determine if file is read-only	*/
    auto fname = std.path.expandTilde(toUTF8(dfname));
    if (ffreadonly(fname))			/* is file read-only?	*/
	    bp.b_flag |= BFRDONLY;
    else
	    bp.b_flag &= ~BFRDONLY;

    try
    {
	if (!std.file.exists(fname))
	{
	    mlwrite("[New file]");
	    return TRUE;
	}
	auto fp = File(fname);
	mlwrite("[Reading file]");
	int nline = 0;
	char[] line;
	size_t s;
	bool first = true;
	while ((s = fp.readln(line)) != 0)
	{
	    if (line.length && line[$ - 1] == '\n')
		line = line[0 .. $ - 1];
	    if (line.length && line[$ - 1] == '\r')
		line = line[0 .. $ - 1];

	    LINE   *lp1;
	    LINE   *lp2;

	    if ((lp1=line_realloc(null,0)) == null) {
		    s = FIOERR;             /* Keep message on the  */
		    break;                  /* display.             */
	    }
	    lp2 = lback(curbp.b_linep);
	    lp2.l_fp = lp1;
	    lp1.l_fp = curbp.b_linep;
	    lp1.l_bp = lp2;
	    curbp.b_linep.l_bp = lp1;
	    if (first && line.length >= 3 && line[0] == 0xEF && line[1] == 0xBB && line[2] == 0xBF)
		line = line[3..$];	// skip BOM
	    lp1.l_text = line[].dup;

	    first = false;
	    ++nline;
	}
	fp.close();
	if (nline == 1)
	    mlwrite("[Read 1 line]");
	else
	    mlwrite(format("[Read %d lines]", nline));
	return TRUE;
    }
    catch (Exception e)
    {
	mlwrite(e.toString());
	return FALSE;
    }
    finally
    {
	foreach (wp; windows)
	{
                if (wp.w_bufp == curbp) {
                        wp.w_linep = lforw(curbp.b_linep);
                        wp.w_dotp  = lforw(curbp.b_linep);
                        wp.w_doto  = 0;
                        wp.w_markp = null;
                        wp.w_marko = 0;
                        wp.w_flag |= WFMODE|WFHARD;
                }
        }
    }
}

/*
 * Take a file name, and from it
 * fabricate a buffer name. This routine knows
 * about the syntax of file names on the target system.
 * I suppose that this information could be put in
 * a better place than a line of code.
 */
string makename(string fname)
{
	return fname;
}

/*
 * Ask for a file name, and write the
 * contents of the current buffer or region to that file.
 * Update the remembered file name and clear the
 * buffer changed flag. This handling of file names
 * is different from the earlier versions, and
 * is more compatible with Gosling EMACS than
 * with ITS EMACS. Bound to "C-X C-W".
 */
int filewrite(bool f, int n)
{
    int    s;
    string fname;

    if ((s=mlreply("Write file: ", null, fname)) != TRUE)
	return (s);
    if (curwp.w_markp)		/* if marking a region	*/
    {   REGION region;

	if (!getregion(&region))
	    return FALSE;
	return file_writeregion(fname,&region);
    }
    else
    {
        if ((s=writeout(fname)) == TRUE) {
	    curbp.b_fname = fname;
	    fileunmodify(f,n);
        }
    }
    return (s);
}

/****************************
 * Mark a file as being unmodified.
 */

int fileunmodify(bool f, int n)
{
    curbp.b_flag &= ~BFCHG;

    /* Update mode lines.   */
    foreach (wp; windows)
    {
	if (wp.w_bufp == curbp)
	    wp.w_flag |= WFMODE;
    }
    return TRUE;
}

/*
 * Save the contents of the current
 * buffer in its associated file. No nothing
 * if nothing has changed (this may be a bug, not a
 * feature). Error if there is no remembered file
 * name for the buffer. Bound to "C-X C-S". May
 * get called by "C-Z".
 */
int filesave(bool f, int n)
{
        WINDOW *wp;
        int    s;

        if ((curbp.b_flag&BFCHG) == 0)         /* Return, no changes.  */
                return (TRUE);
        if (curbp.b_fname.length == 0) {       /* Must have a name.    */
                mlwrite("No file name");
                return (FALSE);
        }
        if ((s=writeout(curbp.b_fname)) == TRUE) {
		fileunmodify(f,n);
        }
        return (s);
}

/*
 * Save the contents of each and every modified
 * buffer.  Does nothing if the buffer is temporary
 * or has no filename.
 */
int filemodify(bool f, int n)
{
	int s = TRUE;

	auto oldbp = curbp;
	foreach (bp; buffers)
	{
		curbp = bp;
		if((curbp.b_flag&BFCHG) == 0 || /* if no changes	*/
		   curbp.b_flag & BFTEMP ||	/* if temporary		*/
		   curbp.b_fname.length == 0)	/* Must have a name	*/
			continue;
		if((s&=writeout(curbp.b_fname)) == TRUE )
			fileunmodify(f,n);
	}
	curbp = oldbp;
	return( s );
}

/*
 * This function performs the details of file
 * writing. Uses the file management routines in the
 * "fileio.c" package. The number of lines written is
 * displayed. Sadly, it looks inside a LINE; provide
 * a macro for this. Most of the grief is error
 * checking of some sort.
 */
int writeout(string dfn)
{
    auto fn = std.path.expandTilde(toUTF8(dfn));
    /*
     * Supply backups when writing files.
     */
    version (Windows)
    {
	auto backupname = std.path.setExtension(fn, "bak");
    }
    else
    {
	auto backupname = buildPath(dirName(fn), ".B" ~ baseName(fn));
    }

    try
    {
	std.file.remove(backupname);	// Remove old backup file
    }
    catch
    {
    }

    if (ffrename(fn, backupname) != FIOSUC)
	    return FALSE;		// Make new backup file

    try
    {
	auto f = File(fn, "w");

	if ( ffchmod( fn, backupname ) != FIOSUC ) /* Set protection	*/
	{	f.close();
		return( FALSE );
	}

        auto lp = lforw(curbp.b_linep);             // First line.
        int nline = 0;                         // Number of lines.
        while (lp != curbp.b_linep) {
                f.writeln(toUTF8(lp.l_text[0 .. llength(lp)]));
                ++nline;
                lp = lforw(lp);
        }

	f.close();
	if (nline == 1)
	    mlwrite("[Wrote 1 line]");
	else
	    mlwrite(format("[Wrote %d lines]", nline));
	return TRUE;
    }
    catch (Exception e)
    {
	mlwrite(e.toString());
	return FALSE;
    }
}

/*
 * The command allows the user
 * to modify the file name associated with
 * the current buffer. It is like the "f" command
 * in UNIX "ed". The operation is simple; just zap
 * the name in the BUFFER structure, and mark the windows
 * as needing an update. You can type a blank line at the
 * prompt if you wish.
 */
int filename(bool f, int n)
{
        int    s;
        string fname;

        if ((s=mlreply("New File Name: ", null, fname)) == ABORT)
                return (s);
        if (s == FALSE)
                curbp.b_fname = null;
        else
                curbp.b_fname = fname;
	foreach (wp; windows)
        {       // Update mode lines.
                if (wp.w_bufp == curbp)
                        wp.w_flag |= WFMODE;
        }
        return (TRUE);
}

/*******************************
 * Write region out to file.
 */

int file_writeregion(string dfilename, REGION* region)
{
    auto lp = region.r_linep;		/* First line.          */
    auto loffs = region.r_offset;
    auto size = region.r_size;
    int nline = 0;				/* Number of lines.     */

    try
    {
	auto filename = std.path.expandTilde(toUTF8(dfilename));
	auto f = File(filename, "w");
	while (size > 0)
	{
	    auto nchars = llength(lp) - loffs;
	    if (nchars > size)		/* if last line is not a full line */
		nchars = size;
	    f.writeln(toUTF8(lp.l_text[loffs .. loffs + nchars]));
	    size -= nchars + 1;
	    ++nline;
	    lp = lforw(lp);
	    loffs = 0;
	}
	f.close();
	if (nline == 1)
	    mlwrite("[Wrote 1 line]");
	else
	    mlwrite(format("[Wrote %d lines]", nline));
	return TRUE;
    }
    catch (Exception e)
    {
	mlwrite(e.toString());
	return FALSE;
    }
}
