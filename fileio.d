

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * The routines in this file read and write ASCII files from the disk. All of
 * the knowledge about files are here. A better message writing scheme should
 * be used.
 */

module fileio;

import std.file;
import std.path;
import std.string;
import std.stdio;
import std.c.stdio;
import std.c.stdlib;

version (Windows)
{
    import std.c.windows.windows;
}

version (linux)
{
    import std.c.linux.linux;
}

import ed;
import display;

enum ENOENT = 2;

enum
{
    FIOSUC = 0,                      /* File I/O, success.           */
    FIOFNF = 1,                      /* File I/O, file not found.    */
    FIOEOF = 2,                      /* File I/O, end of file.       */
    FIOERR = 3,                      /* File I/O, error.             */
}

FILE    *ffp;                           /* File pointer, all functions. */

/*
 * Open a file for reading.
 */
int ffropen(string fn)
{
	fn = std.path.expandTilde(fn);
        if ((ffp=fopen(toStringz(fn), "r")) == null)
	    return (getErrno() == ENOENT) ? FIOFNF : FIOERR;
        return (FIOSUC);
}

/*
 * Open a file for writing. Return TRUE if all is well, and FALSE on error
 * (cannot create).
 */
int ffwopen(string fn)
{
        if ((ffp=fopen(toStringz(fn), "w")) == null) {
                mlwrite("Cannot open file for writing");
                return (FIOERR);
        }
        return (FIOSUC);
}

/*
 * Close a file. Should look at the status in all systems.
 */
int ffclose()
{
        if (fclose(ffp) != ed.FALSE) {
                mlwrite("Error closing file");
                return(FIOERR);
        }
        return(FIOSUC);
}

/*
 * Write a line to the already opened file. The "buf" points to the buffer,
 * and the "nbuf" is its length, less the free newline. Return the status.
 * Check only at the newline.
 */
int ffputline(char[] buf)
{
	fwrite(buf.ptr,1,buf.length,ffp);

        fputc('\n', ffp);
        if (ferror(ffp)) {
                mlwrite("Write I/O error");
                return (FIOERR);
        }

        return (FIOSUC);
}

/*
 * Read a line from a file, and store the bytes in a buffer.
 * Complain about lines
 * at the end of the file that don't have a newline present. Check for I/O
 * errors too. Return status.
 * *pbuf gets a pointer to the buffer.
 * *pnbytes gets the # of chars read into the buffer.
 */
int ffgetline(out string pbuf)
{
    string buf;

    try
    {
	buf = std.stdio.readln(ffp, '\n');
    }
    catch (StdioException e)
    {
	mlwrite("File read error");
	return (FIOERR);
    }
    if (buf.length == 0)
	return FIOEOF;

    // Trim trailing CR and LF
    if (buf[length - 1] == '\n')
	buf = buf[0 .. length - 1];
    if (buf.length && buf[length - 1] == '\r')
	buf = buf[0 .. length - 1];

    pbuf = buf;
    return FIOSUC;
}

/***************************
 * Determine if file is read-only.
 */

bool ffreadonly(string name)
{
    uint a;
    try
    {
	a = std.file.getAttributes(name);
    }
    catch (Object o)
    {
    }

    version (Win32)
    {
	return (a & FILE_ATTRIBUTE_READONLY) != 0;
    }
    else
    {
	return (a & S_IWRITE) == 0;
    }
}

/*
 * Delete a file
 */
void ffunlink(string fn)
{
    try
    {
	fn = std.path.expandTilde(fn);
	remove( fn );
    }
    catch (Object o)
    {
    }
}

/*
 * Rename a file
 */
int ffrename(string from, string to)
{
    try
    {
	from = std.path.expandTilde(from);
	to = std.path.expandTilde(to);
	version (linux)
	{
	    struct_stat buf;
	    if( stat( toStringz(from), &buf ) != -1
	     && !(buf.st_uid == getuid() && (buf.st_mode & 0200))
	     && !(buf.st_gid == getgid() && (buf.st_mode & 0020))
	     && !(                          (buf.st_mode & 0002)) )
	    {
		    mlwrite("Cannot open file for writing.");
		    /* Note the above message is a lie, but because this	*/
		    /* routine is only called by the backup file creation	*/
		    /* code, the message will look right to the user.	*/
		    return( FIOERR );
	    }
	}
	rename( from, to );
    }
    catch (Object o)
    {
    }
    return( FIOSUC );
}


/*
 * Change the protection on a file <subject> to match that on file <image>
 */
int ffchmod(string subject, string image)
{
    version (linux)
    {
	subject = std.path.expandTilde(subject);
	image = std.path.expandTilde(image);

	uint attr;
	try
	{
	    attr = std.file.getAttributes(image);
	}
	catch (FileException fe)
	{
		return( FIOSUC );
		/* Note that this won't work in all cases, but because	*/
		/* this is only called from the backup file creator, it	*/
		/* will work.  UGLY!!					*/
	}
	if (chmod( toStringz(subject), attr ) == -1 )
	{
		mlwrite("Cannot open file for writing.");
		/* Note the above message is a lie, but because this	*/
		/* routine is only called by the backup file creation	*/
		/* code, the message will look right to the user.	*/
		return( FIOERR );
	}
    }
    return( FIOSUC );
}

