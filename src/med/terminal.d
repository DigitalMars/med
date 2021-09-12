

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


version (Windows)
{
    public import console;
    public import mouse;
}

version (Posix)
{
    public import termio;
    public import xterm;
}
