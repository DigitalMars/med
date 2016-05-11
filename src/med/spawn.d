

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


/*
 * The routines in this file are called to create a subjob running a command
 * interpreter.
 */

module spawn;

import core.stdc.stdlib;
import core.stdc.time;

import std.conv;
import std.stdio;
import std.file;
import std.process;
import std.string;
import std.utf;

version(linux)
{
    import core.sys.posix.unistd;
}

import ed;
import buffer;
import window;
import display;
import main;
import file;
import terminal;
import xterm;



/*
 * Create a subjob with a copy of the command intrepreter in it. When the
 * command interpreter exits, mark the screen as garbage so that you do a full
 * repaint. Bound to "C-C". The message at the start in VMS puts out a newline.
 * Under some (unknown) condition, you don't get one free when DCL starts up.
 */
int spawncli(bool f, int n)
{
    movecursor(term.t_nrow-1, 0);             /* Seek to last line.   */
    version (Windows)
    {
        term.t_flush();
        auto comspec = core.stdc.stdlib.getenv("COMSPEC");
	string[] args;
	args ~= to!string(comspec);
	args ~= "COMMAND.COM";
        spawnProcess(args);
    }
    version (linux)
    {
        term.t_flush();
        term.t_close();                             /* stty to old settings */
        auto cp = core.stdc.stdlib.getenv("SHELL");
        if (cp && *cp != '\0')
	    core.stdc.stdlib.system(cp);
        else
	    core.stdc.stdlib.system("exec /bin/sh");
        sleep(2);
        term.t_open();
    }
    sgarbf = TRUE;
    return(TRUE);
}

/*
 * Run a one-liner in a subjob. When the command returns, wait for a single
 * character to be typed, then mark the screen as garbage so a full repaint is
 * done. Bound to "C-X !".
 */
int spawn(bool f, int n)
{
    int    s;
    string line;
    version (Windows)
    {
        if ((s=mlreply("MS-DOS command: ", null, line)) != TRUE)
                return (s);
        core.stdc.stdlib.system(toUTF8(line).toStringz());
        while (term.t_getchar() != '\r')     /* Pause.               */
        {
	}
        sgarbf = TRUE;
        return (TRUE);
    }
    version (linux)
    {
        if ((s=mlreply("! ", null, line)) != TRUE)
                return (s);
        term.t_putchar('\n');                /* Already have '\r'    */
        term.t_flush();
        term.t_close();                              /* stty to old modes    */
        core.stdc.stdlib.system(toUTF8(line).toStringz());
        import core.sys.posix.unistd;
        sleep(2);
        term.t_open();
        printf("[End]");                        /* Pause.               */
        term.t_flush();
        while ((s = term.t_getchar()) != '\r' && s != ' ')
        {
	}
        sgarbf = TRUE;
        return (TRUE);
    }
}

/*
 * Pipe a one line command into a window
 * Bound to ^X @
 */
int spawn_pipe(bool f, int n)
{
    int    s; 	       /* return status from CLI */
    WINDOW *wp;        /* pointer to new window */
    BUFFER *bp;        /* pointer to buffer to zot */
    static string bname = "[DOS]";

    static string filnam = "DOS.TMP";
    string line; /* command line sent to shell */
    string sline;

    /* get the command to pipe in */
    if ((s = mlreply("DOS:", null, line)) != TRUE)
        return s;

    /* get rid of the command output buffer if it exists */
    if ((bp=buffer_find(bname, FALSE, BFTEMP)) != null) /* if buffer exists */
    {
        /* If buffer is displayed, try to move it off screen            */
        /* (can't remove an on-screen buffer)                           */
        if (bp.b_nwnd)                 /* if buffer is displayed       */
        {   if (bp == curbp)            /* if it's the current window   */
                window_next(FALSE,1);   /* make another window current  */
            window_only(FALSE, 1);

            if (buffer_remove(bp) != TRUE)
                goto fail;
        }
    }

    /* split the current window to make room for the command output */
    if (window_split(FALSE, 1) == FALSE)
        goto fail;

    sline = toUTF8(line) ~ ">" ~ filnam;

version (Windows)
{
    movecursor(term.t_nrow - 2, 0);
    core.stdc.stdlib.system(sline.toStringz());
    sgarbf = TRUE;
    if (std.file.exists(filnam) && std.file.isFile(filnam))
	return FALSE;
}
version (linux)
{
    term.t_putchar('\n');                /* Already have '\r'    */
    term.t_flush();
    term.t_close();                              /* stty to old modes    */
    core.stdc.stdlib.system(sline.toStringz());
    term.t_open();
    term.t_flush();
    sgarbf = TRUE;
}

    /* and read the stuff in */
    if (file_readin(filnam) == FALSE)
        return(FALSE);

    /* and get rid of the temporary file */
    remove(filnam);
    return(TRUE);

fail:
    return FALSE;
}

/*
 * filter a buffer through an external DOS program
 * Bound to ^X #
 */
int spawn_filter(bool f, int n)
{
        int    s;      /* return status from CLI */
        BUFFER *bp;    /* pointer to buffer to zot */
        string line;      /* command line to send to shell */
        string tmpnam;    /* place to store real file name */
        string bname1 = "fltinp";

        string filnam1 = "fltinp";
        string filnam2 = "fltout";

        if (curbp.b_flag & BFRDONLY)   /* if buffer is read-only       */
            return FALSE;               /* fail                         */

        /* get the filter name and its args */
        if ((s=mlreply("Filter:", null, line)) != TRUE)
                return(s);

        /* setup the proper file names */
        bp = curbp;
        tmpnam = bp.b_fname;    /* save the original name */
        bp.b_fname = bname1;    /* set it to our new one */

        /* write it out, checking for errors */
        if (writeout(filnam1) != TRUE) {
                mlwrite("[Cannot write filter file]");
                bp.b_fname = tmpnam;
                return(FALSE);
        }

        line ~= " <fltinp >fltout";
    version (Windows)
    {
        movecursor(term.t_nrow - 2, 0);
        core.stdc.stdlib.system(toUTF8(line).toStringz());
    }
    version (linux)
    {
        term.t_putchar('\n');                /* Already have '\r'    */
        term.t_flush();
        term.t_close();                              /* stty to old modes    */
        core.stdc.stdlib.system(toUTF8(line).toStringz());
        term.t_open();
        term.t_flush();
    }

        sgarbf = TRUE;
        s = TRUE;

        /* on failure, escape gracefully */
        if (s != TRUE || ((s = readin(filnam2)) == FALSE)) {
                mlwrite("[Execution failed]");
                bp.b_fname = tmpnam;
                goto ret;
        }

        /* reset file name */
        bp.b_fname = tmpnam;           /* restore name */
        bp.b_flag |= BFCHG;            /* flag it as changed */
        s = TRUE;

ret:
        /* and get rid of the temporary file */
        remove(toUTF8(filnam1));
        remove(toUTF8(filnam2));
        return s;
}
