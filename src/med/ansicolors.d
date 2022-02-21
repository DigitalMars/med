/*******************************************
 * Print various ANSI escape sequences to the screen.
 */

module ansicolors;

import core.stdc.stdio;

void main()
{
    // Escape sequences:
    // https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
    // https://opensource.com/article/19/9/linux-terminal-colors

    string s = "text sequence";
    foreach (i; 30 .. 37+1)
    {
        printf("\\033[%dm \033[%dm %s\n", i, i, s.ptr);
        resetColor();
    }
    foreach (i; 30 .. 37+1)
    {
        printf("\\033[1;%dm \033[1;%dm %s\n", i, i, s.ptr);
        resetColor();
    }
    foreach (i; 40 .. 47+1)
    {
        printf("\\033[%dm \033[%dm %s", i, i, s.ptr);
        resetColor();
        printf("\n");
    }
    foreach (i; 0 .. 10+1)
    {
        printf("\\033[%d;30m \033[%d;30m %s\n", i, i, s.ptr);
        resetColor();
    }
    foreach (i; 51 .. 53+1)
    {
        printf("\\033[%d;30m \033[%d;30m %s\n", i, i, s.ptr);
        resetColor();
    }
}

void resetColor()
{
    fputs("\033[m", stdout);
}

