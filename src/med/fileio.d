

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

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.errno;

import std.file;
import std.path;
import std.string;
import std.stdio;
import std.conv;

version (Windows)
{
    import core.sys.windows.windows;
}

version (linux)
{
    import core.sys.posix.unistd;
    import core.sys.posix.sys.stat;
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

/***************************
 * Determine if file is read-only.
 */

bool ffreadonly(string name)
{
    uint a;
    bool exists = true;
    try
    {
	a = std.file.getAttributes(name);
    }
    catch (Throwable o)
    {
	exists = false;
    }

    version (Win32)
    {
	return (a & FILE_ATTRIBUTE_READONLY) != 0;
    }
    else
    {
      import core.sys.posix.sys.stat;
	return exists && (a & S_IWUSR) == 0;
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
	    stat_t buf;
	    if( stat( toStringz(from), &buf ) != -1
	     && !(buf.st_uid == getuid() && (buf.st_mode & octal!200))
	     && !(buf.st_gid == getgid() && (buf.st_mode & octal!20))
	     && !(                          (buf.st_mode & octal!2)) )
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
    catch (Throwable o)
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

