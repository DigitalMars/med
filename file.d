

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

import std.stdio;
import std.path;
import std.string;
import std.c.stdlib;

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
	int s,nline;
	WINDOW *wp;
	string fname;
	string line;

	if (mlreply("Insert file: ", null, fname) == FALSE)
		return FALSE;

	s = ffropen(fname);		/* open file for reading	*/
	switch (s)
	{
	    case FIOFNF:
		mlwrite("File not found");
	    case FIOERR:
		return FALSE;
	}
	mlwrite("[Reading file]");
	nline = 0;
	while ((s = ffgetline(line)) == FIOSUC)
	{
		foreach(c; line)
		{
		    if (line_insert(1,c) == FALSE)
			return FALSE;
		}
		if (random_newline(FALSE,1) == FALSE)
		    return FALSE;
		++nline;
	}
	ffclose();
        if (s == FIOEOF) {                      /* Don't zap message!   */
                if (nline == 1)
                        mlwrite("[Read 1 line]");
                else
                        mlwrite(format("[Read %d lines]", nline));
        }
        for (wp=wheadp; wp!=null; wp=wp.w_wndp) {
                if (wp.w_bufp == curbp) {
                        wp.w_flag |= WFMODE|WFHARD;
                }
        }
	return s != FIOERR;
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
    BUFFER *bp;
    WINDOW *wp;
    LINE   *lp;
    int    i;
    int    s;
    string bname;

    /* If there is an existing buffer with the same file name, simply	*/
    /* switch to it instead of reading the file again.			*/
    for (bp=bheadp; bp!=null; bp=bp.b_bufp)
    {
	/* Always redo temporary buffers, check for filename match.	*/
	if ((bp.b_flag&BFTEMP)==0 && fnmatch(bp.b_fname, fname))
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
		for (wp = wheadp; wp != null; wp = wp.w_wndp)
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
int readin(string fname)
{
        LINE   *lp1;
        LINE   *lp2;
        int    i;
        WINDOW *wp;
        BUFFER *bp;
        int    s;
        int    nline;
        string line;

        bp = curbp;                             /* Cheap.               */
        if ((s=buffer_clear(bp)) != TRUE)             /* Might be old.        */
                return (s);
        bp.b_flag &= ~(BFTEMP|BFCHG);
        bp.b_fname = fname;

	/* Determine if file is read-only	*/
	if (ffreadonly(fname))			/* is file read-only?	*/
		bp.b_flag |= BFRDONLY;
	else
		bp.b_flag &= ~BFRDONLY;
        if ((s=ffropen(fname)) == FIOERR)       /* Hard file open.      */
	{	mlwrite("[Bad file]");
                goto Lout;
	}
        if (s == FIOFNF) {                      /* File not found.      */
                mlwrite("[New file]");
                goto Lout;
        }
        mlwrite("[Reading file]");

        nline = 0;
        while ((s=ffgetline(line)) == FIOSUC) {
                if ((lp1=line_realloc(null,line.length)) == null) {
                        s = FIOERR;             /* Keep message on the  */
                        break;                  /* display.             */
                }
                lp2 = lback(curbp.b_linep);
                lp2.l_fp = lp1;
                lp1.l_fp = curbp.b_linep;
                lp1.l_bp = lp2;
                curbp.b_linep.l_bp = lp1;
		lp1.l_text[] = line[];
                ++nline;
        }
        ffclose();                              /* Ignore errors.       */
        if (s == FIOEOF) {                      /* Don't zap message!   */
                if (nline == 1)
                        mlwrite("[Read 1 line]");
                else
                        mlwrite(format("[Read %d lines]", nline));
        }
Lout:
        for (wp=wheadp; wp!=null; wp=wp.w_wndp) {
                if (wp.w_bufp == curbp) {
                        wp.w_linep = lforw(curbp.b_linep);
                        wp.w_dotp  = lforw(curbp.b_linep);
                        wp.w_doto  = 0;
                        wp.w_markp = null;
                        wp.w_marko = 0;
                        wp.w_flag |= WFMODE|WFHARD;
                }
        }
	return s != FIOERR;			/* FALSE if error	*/
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
    WINDOW *wp;

    curbp.b_flag &= ~BFCHG;

    /* Update mode lines.   */
    for (wp = wheadp; wp != null; wp = wp.w_wndp)
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
        if (curbp.b_fname[0] == 0) {           /* Must have a name.    */
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
        WINDOW *wp;
	int s = TRUE;
	BUFFER *oldbp;

	oldbp = curbp;
	for (curbp = bheadp; curbp != null; curbp = curbp.b_bufp)
	{
		if((curbp.b_flag&BFCHG) == 0 || /* if no changes	*/
		   curbp.b_flag & BFTEMP ||	/* if temporary		*/
		   curbp.b_fname[0] == 0)	/* Must have a name	*/
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
int writeout(string fn)
{
        int    s;
        LINE   *lp;
        int    nline;

	string backupname;
	/*
	 * This code has been added to supply backups
	 * when writing files.
	 */
version (Windows)
{
	backupname = std.path.addExt(fn, "bak");
}
else
{
	backupname = join(dirname(fn), ".B" ~ basename(fn));
}
	ffunlink( backupname );			/* Remove old backup file */
	if( ffrename( fn, backupname ) != FIOSUC )
		return( FALSE );		/* Make new backup file */

        if ((s=ffwopen(fn)) != FIOSUC)          /* Open writes message. */
                return (FALSE);
	if ( ffchmod( fn, backupname ) != FIOSUC ) /* Set protection	*/
		return( FALSE );

        lp = lforw(curbp.b_linep);             /* First line.          */
        nline = 0;                              /* Number of lines.     */
        while (lp != curbp.b_linep) {
                if ((s=ffputline(lp.l_text[0 .. llength(lp)])) != FIOSUC)
                        break;
                ++nline;
                lp = lforw(lp);
        }
	return file_finish(s,nline);
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
        auto wp = wheadp;                         /* Update mode lines.   */
        while (wp != null) {
                if (wp.w_bufp == curbp)
                        wp.w_flag |= WFMODE;
                wp = wp.w_wndp;
        }
        return (TRUE);
}

/*******************************
 * Write region out to file.
 */

int file_writeregion(string filename, REGION* region)
{   int s;
    LINE   *lp;
    int    nline;
    int size;
    int loffs;

    if ((s=ffwopen(filename)) != FIOSUC)	/* open writes message	*/
	return (FALSE);

    lp = region.r_linep;		/* First line.          */
    loffs = region.r_offset;
    size = region.r_size;
    nline = 0;				/* Number of lines.     */
    while (size > 0)
    {	int nchars;

	nchars = llength(lp) - loffs;
	if (nchars > size)		/* if last line is not a full line */
	    nchars = size;
	if ((s=ffputline(lp.l_text[loffs .. loffs + nchars])) != FIOSUC)
	    break;
	size -= nchars + 1;
	++nline;
	lp = lforw(lp);
	loffs = 0;
    }
    return file_finish(s,nline);
}

/************************
 * Finish writing file.
 */

static int file_finish(int s, int nline)
{
    if (s == FIOSUC) {                      /* No write error.      */
	    s = ffclose();
	    if (s == FIOSUC) {              /* No close error.      */
		    if (nline == 1)
			    mlwrite("[Wrote 1 line]");
		    else
			    mlwrite(format("[Wrote %d lines]", nline));
	    }
    } else                                  /* Ignore close error   */
	    ffclose();                      /* if a write error.    */
    return s == FIOSUC;			/* TRUE if success	*/
}
