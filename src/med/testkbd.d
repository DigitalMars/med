
module testkbd;

version (Posix)
{

import core.stdc.stdio;
import core.sys.posix.termios;
import core.sys.posix.sys.ioctl;

import ed;

extern (C) void cfmakeraw(in termios*);


termios  ostate;                 /* saved tty state */
termios  nstate;                 /* values for editor mode */


/*
 * This function is called once to set up the terminal device streams.
 * On VMS, it translates SYS$INPUT until it finds the terminal, then assigns
 * a channel to it and sets it raw. On CPM it is a no-op.
 */
void ttopen()
{
        /* Adjust output channel        */
        tcgetattr(1, &ostate);                       /* save old state */
        tcgetattr(1, &nstate);                       /* get base of new state */
        cfmakeraw(&nstate);
        tcsetattr(1, TCSADRAIN, &nstate);      /* set mode */
}

/*
 * This function gets called just before we go back home to the command
 * interpreter. On VMS it puts the terminal back in a reasonable state.
 * Another no-operation on CPM.
 */
void ttclose()
{
        tcsetattr(1, TCSADRAIN, &ostate);       // return to original mode
}

/*
 * Write a character to the display. On VMS, terminal output is buffered, and
 * we just put the characters in the big array, after checking for overflow.
 * On CPM terminal I/O unbuffered, so we just write the byte out. Ditto on
 * MS-DOS (use the very very raw console output routine).
 */
void ttputc(char c)
{
        fputc(c, stdout);
}

/*
 * Flush terminal buffer. Does real work where the terminal output is buffered
 * up. A no-operation on systems where byte at a time terminal I/O is done.
 */
void ttflush()
{
        fflush(stdout);
}

/*
 * Read a character from the terminal, performing no editing and doing no echo
 * at all. More complex in VMS that almost anyplace else, which figures. Very
 * simple on CPM, because the system can do exactly what you want.
 */
int ttgetc()
{
        return fgetc(stdin);
}

/**************************
 * Return TRUE if there are unread chars ready in the input.
 */

int ttkeysininput()
{
        int n;
        ioctl(0, FIONREAD, &n);
        return n != 0;
}

/**************************
 * Return when there are unread chars ready in the input.
 */

void ttwaitkeys()
{
    import core.sys.posix.sys.select;
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(0, &readfds);
    select(1, &readfds, null, null, null);
}

/******************************
 */

void ttyield()
{
}

int msm_init()
{
    puts("\x1b[?1000h");
    return true;
}

void msm_term()
{
    puts("\x1b[?1000l");
}

}

int main()
{
    printf("type 'x' to exit\n");
    ttopen();
    msm_init();
    while (1)
    {
        int c = ttgetc();
        if (c > ' ' && c <= '~')
            printf("c = '%c'\n\r", c);
        else
            printf("c = x%02x\n\r", c);
        if (c == 'x')
            break;
    }
    msm_term();
    ttclose();
    return 0;
}
