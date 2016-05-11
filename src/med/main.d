

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/*
 * This program is in public domain; written by Dave G. Conroy.
 * This file contains the main driving routine, and some keyboard processing
 * code, for the MicroEMACS screen editor.
 *
 * REVISION HISTORY:
 *
 * 1.0  Steve Wilhite, 30-Nov-85
 *      - Removed the old LK201 and VT100 logic. Added code to support the
 *        DEC Rainbow keyboard (which is a LK201 layout) using the the Level
 *        1 Console In ROM INT. See "rainbow.h" for the function key definitions.
 *
 * 2.0  George Jones, 12-Dec-85
 *      - Ported to Amiga.
 *
 * Later versions - Walter Bright, Bjorn Benson
 *	- Ported to linux
 *	- Ported to Win32 (compile with Digital Mars C compiler, www.digitalmars.com)
 *	- Ported to DOS32
 *
 * The D programming language version
 *	- translated to D by Walter Bright on 14-Feb-2008
 *	- drops 16 bit versions, all versions other than Windows and Linux
 */

module main;

import core.stdc.time;
import core.stdc.stdlib;

import std.string;
import std.stdio;
import std.utf;

import ed;
import file;
import buffer;
import window;
import basic;
import random;
import more;
import search;
import region;
import word;
import spawn;
import display;
import terminal;
import termio;
import xterm;
import console;
import line;
import mouse;

int     currow;                         /* Working cursor row           */
int     fillcol;                        /* Current fill column          */
int     thisflag;                       /* Flags, this command          */
int     lastflag;                       /* Flags, last command          */
int     curgoal;                        /* Goal column                  */
int     markcol;                        /* starting column for column cut */
int     hasmouse;                       /* TRUE if we have a mouse      */
BUFFER  *curbp;                         /* Current buffer               */
WINDOW  *curwp;                         /* Current window               */
BUFFER  *bheadp;                        /* BUFFER listhead              */
BUFFER  *blistp;                        /* Buffer list BUFFER           */
dchar[256] kbdm = [CTLX|')'];         /* Macro                        */
dchar   *kbdmip;                        /* Input  for above             */
dchar   *kbdmop;                        /* Output for above             */
string  pat;                            /* search pattern               */
ubyte   insertmode = 1;                 /* insert/overwrite mode        */
string  progname;                       /* this program name            */

/+
int     basic_nextline();       /* Move to next line            */
int     basic_setmark();        /* Set mark                     */

int     random_setfillcol();    /* Set fill column.             */
int     random_showcpos();      /* Show the cursor position     */
int     random_twiddle();       /* Twiddle characters           */
int     random_tab();           /* Insert tab                   */
int     random_hardtab();       // Set hardware tabs
int     random_newline();       /* Insert CR-LF                 */
int     random_indent();        /* Insert CR-LF, then indent    */
int     random_incindent();     /* increase indentation level   */
int     random_decindent();     /* decrease indentation level   */
int     random_opttab();        /* optimize tabbing in line     */
int     random_openline();      /* Open up a blank line         */
int     random_deblank();       /* Delete blank lines           */
int     random_quote();         /* Insert literal               */
int     random_forwdel();       /* Forward delete               */
int     random_backdel();       /* Backward delete              */
int     random_kill();          /* Kill forward                 */
int     random_yank();          /* Yank back from killbuffer.   */
int     random_undelchar();     /* Undelete a character         */

int     region_togglemode();    /* Toggle column region mode    */
int     region_kill();          /* Kill region.                 */
int     region_copy();          /* Copy region to kill buffer.  */

int     window_next();          /* Move to the next window      */
int     window_prev();          /* Move to the previous window  */
int     window_only();          /* Make current window only one */
int     window_split();         /* Split current window         */
int     window_mvdn();          /* Move window down             */
int     window_mvup();          /* Move window up               */
int     window_enlarge();       /* Enlarge display window       */
int     window_shrink();        /* Shrink window                */
int     window_reposition();    /* Reposition window            */
int     window_refresh();       /* Refresh the screen           */

int     toggleinsert();         /* Toggle insert/overwrite mode */
int     line_overwrite();       /* Write char in overwrite mode */
int     ctrlg();                /* Abort out of things          */
int     quit();                 /* Quit                         */
int     main_saveconfig();      /* Save configuration           */
int     ctlxlp();               /* Begin macro                  */
int     ctlxrp();               /* End macro                    */
int     macrotoggle();          /* Start/End macro		*/
int     ctlxe();                /* Execute macro                */
int     filenext();             /* Edit next file               */
int     fileread();             /* Get a file, read only        */
int     filevisit();            /* Get a file, read write       */
int     filewrite();            /* Write a file                 */
int     fileunmodify();         /* Turn off buffer changed bits */
int     filesave();             /* Save current file            */
int     filename();             /* Adjust file name             */
int     getcol();               /* Get current column           */
int     gotobol();              /* Move to start of line        */
int     forwchar();             /* Move forward by characters   */
int     gotoeol();              /* Move to end of line          */
int     backchar();             /* Move backward by characters  */
int     forwline();             /* Move forward by lines        */
int     backline();             /* Move backward by lines       */
int     forwpage();             /* Move forward by pages        */
int     backpage();             /* Move backward by pages       */
int     gotobob();              /* Move to start of buffer      */
int     gotoeob();              /* Move to end of buffer        */
int     gotoline();             /* Move to line number          */
int     removemark();           /* Remove mark                  */
int     swapmark();             /* Swap "." and mark            */
int     forwsearch();           /* Search forward               */
int     backsearch();           /* Search backwards             */
int     search_paren();         /* Toggle over parentheses      */
int     listbuffers();          /* Display list of buffers      */
int     usebuffer();            /* Switch a window to a buffer  */
int     buffer_next();          /* Switch to next buffer        */
int     killbuffer();           /* Make a buffer go away.       */
int	word_wrap_line();	/* Word wrap current line	*/
int     word_select();          /* Select word                  */
int     word_back();            /* Backup by words              */
int     word_forw();            /* Advance by words             */
int     misc_upper();           /* Upper case word/region       */
int     misc_lower();           /* Lower case word/region       */
int     capword();              /* Initial capitalize word.     */
int     delfword();             /* Delete forward word.         */
int     delbword();             /* Delete backward word.        */
int     spawncli();             /* Run CLI in a subjob.         */
int     spawn();                /* Run a command in a subjob.   */
int     spawn_filter();         /* Filter buffer through program */
int     spawn_pipe();           /* Run program and gather output */
int     quickexit();            /* low keystroke style exit.    */
int     delwind();              /* Delete a window              */
int     filemodify();           /* Write modified files         */
int     normexit();             /* Write modified files and exit*/
int     replacestring();        /* Search and replace           */
int     queryreplacestring();   /* Query search and replace     */
int     win32toggle43();	/* Toggle 43 line mode          */
int     ibmpctoggle43();        /* Toggle 43 line mode          */
int     display_norm_fg();
int     display_norm_bg();
int     display_mode_fg();
int     display_mode_bg();
int     display_mark_fg();
int     display_mark_bg();
int     display_eol_bg();
int     Dignore();              /* do nothing                   */
int     Dsearch();              /* Search                       */
int     Dsearchagain();         /* Search for the same string   */
int     Ddelline();             /* Delete a line                */
int     Dundelline();           /* Undelete a line              */
int     Ddelword();             /* Delete a word                */
int     Ddelbword();            /* Delete a word (backwards)    */
int     Dundelword();           /* Undelete a word              */
int     Dadvance();             /* Set into advance mode        */
int     Dbackup();              /* Set into backup mode         */
int     Dpause();               /* Pause the program (UNIX only)*/
int     Dinsertdate();          /* File and date stamp          */
int     Dcppcomment();		/* convert to // comment	*/
int     Dinsertfile();          /* Insert a file                */
+/

/*
 * Command table.
 * This table  is *roughly* in ASCII order, left to right across the
 * characters of the command. This expains the funny location of the
 * control-X commands.
 */

enum CMD_ENDMACRO = 0x8005;

struct KEYTAB {
    int k_code;                   /* Key code                     */
    int function(bool, int) k_fp; /* Routine to handle it         */
}

version(Windows)
{
immutable KEYTAB[]  keytab =
[
        /* Definitions common to all versions   */
       { CTRL('@'),              &ctrlg}, /*basic_setmark*/
       { CTRL('A'),              &gotobol},
       { CTRL('B'),              &backchar},
       { CTRL('C'),              &quit},
       { CTRL('D'),              &random_forwdel},
       { CTRL('E'),              &gotoeol},
       { CTRL('F'),              &forwchar},
       { CTRL('G'),              &ctrlg},
       { CTRL('H'),              &random_backdel},
       { CTRL('I'),              &random_tab},
       { CTRL('J'),              &Ddelline},
       { CTRL('K'),              &random_kill},
       { CTRL('L'),              &window_refresh},
       { CTRL('M'),              &random_newline},
       { CTRL('N'),              &forwline},
       { CTRL('O'),              &random_openline},
       { CTRL('P'),              &backline},
       { CTRL('Q'),              &random_quote},   /* Often unreachable    */
       { CTRL('R'),              &backsearch},
       { CTRL('S'),              &forwsearch},     /* Often unreachable    */
       { CTRL('T'),              &random_twiddle},
       { CTRL('V'),              &forwpage},
       { CTRL('W'),              &search_paren},
       { CTRL('Y'),              &random_yank},
       { 0x7F,                   &random_backdel},
/+
        /* Unused definitions from original microEMACS */
       { CTRL('C'),              &spawncli},       /* Run CLI in subjob.   */
       { CTRL('J'),              &random_indent},
       { CTRL('W'),              &region_kill},
       { CTRL('Z'),              &quickexit},      /* quick save and exit  */
+/
       { CTRL('Z'),              &spawncli},      /* Run CLI in subjob.   */
       { F2KEY,                  &Dsearchagain},
       { F3KEY,                  &search_paren},
       { F4KEY,                  &Dsearch},
       { F5KEY,                  &basic_nextline},
       { F6KEY,                  &window_next},
       { F7KEY,                  &basic_setmark},
       { F8KEY,                  &region_copy},
       { F9KEY,                  &region_kill},
       { F10KEY,                 &random_yank},
	{F11KEY,		 &ctlxe},
	{F12KEY,		 &macrotoggle},
        {AltF1KEY,               &display_norm_bg},
        {AltF2KEY,               &display_norm_fg},
        {AltF3KEY,               &display_mode_bg},
        {AltF5KEY,               &display_mark_fg},
        {AltF6KEY,               &display_mark_bg},
        {AltF4KEY,               &display_mode_fg},
        {AltF7KEY,               &display_eol_bg},
        {AltF9KEY,               &random_decindent},
        {AltF10KEY,              &random_incindent},
        {ALTB,                   &buffer_next},
        {ALTC,                   &main_saveconfig},
	{ALTX,			 &normexit},
        {ALTZ,                   &spawn_pipe},
        {RTKEY,                  &forwchar},
        {LTKEY,                  &backchar},
        {DNKEY,                  &forwline},
        {UPKEY,                  &backline},
        {InsKEY,                 &toggleinsert},
        {DelKEY,                 &random_forwdel},
        {PgUpKEY,                &backpage},
        {PgDnKEY,                &forwpage},
        {HOMEKEY,                &window_mvup},
        {ENDKEY,                 &window_mvdn},
        {CtrlRTKEY,              &word_forw},
        {CtrlLFKEY,              &word_back},
        {CtrlHome,               &gotobob},
        {CtrlEnd,                &gotoeob},

        /* Commands with a special key value    */
        {0x8001,         &spawn_pipe},
        {0x8002,         &spawn_filter},
        {0x8003,         &random_showcpos},
        {0x8004,         &ctlxlp},
        {CMD_ENDMACRO,   &ctlxrp},
        {0x8006,         &random_decindent},
        {0x8007,         &random_incindent},
        {0x8008,         &window_only},
        {0x8009,         &removemark},
        {0x800A,         &spawn.spawn},         /* Run 1 command.       */
        {0x800B,         &window_split},
        {0x800C,         &usebuffer},
        {0x800D,         &delwind},
        {0x800E,         &ctlxe},
        {0x800F,         &random_setfillcol},
        {0x8010,         &buffer.killbuffer},
        {0x8011,         &window_next},
        {0x8012,         &window_prev},
        {0x8013,         &random_quote},
        {0x8014,         &buffer_next},
        {0x8015,         &window_enlarge},
        {0x8016,         &listbuffers},
        {0x8017,         &filename},
        {0x8018,         &filemodify},
        {0x8019,         &window_mvdn},
        {0x801A,         &random_deblank},
        {0x801B,         &window_mvup},
        {0x801C,         &fileread},
        {0x801D,         &filesave},       /* Often unreachable    */
        {0x801E,         &window_reposition},
        {0x801F,         &filevisit},
        {0x8020,         &filewrite},
        {0x8021,         &swapmark},
        {0x8022,         &window_shrink},

        {0x8023,         &delbword},
        {0x8024,         &random_opttab},
        {0x8025,         &basic_setmark},
        {0x8026,         &gotoeob},
        {0x8027,         &gotobob},
        {0x8028,         &region_copy},
        {0x8029,         &region_kill},
        {0x802A,         &word_back},
        {0x802B,         &capword},
        {0x802C,         &delfword},
        {0x802D,         &word_forw},
        {0x802E,         &misc_lower},
        {0x802F,         &queryreplacestring},
        {0x8030,         &replacestring},
        {0x8031,         &misc_upper},
        {0x8032,         &backpage},
        {0x8033,         &word_select},
        {0x8034,         &Dadvance},
        {0x8035,         &Dbackup},
        {0x8036,         &random_deblank},

        {0x8037,         &Dinsertdate},
        {0x8038,         &Dinsertfile},
        {0x8039,         &gotoline},
        {0x803A,         &fileunmodify},
        {0x803B,         &filenext},
        {0x803C,         &quit},
        {0x803D,         &normexit},
        {0x803E,         &Dundelline},
        {0x803F,         &Dsearch},
        {0x8040,         &Dundelword},
        {0x8041,         &random_undelchar},
        {0x8042,         &random_openline},
        {0x8043,         &random_kill},
        {0x8044,         &region_togglemode},
	{0x8045,	 &Dcppcomment},
	{0x8046,	 &random_hardtab},
	{0x8047,	 &word_wrap_line},
	{0x8048,         &help},
	{0x8049,         &openBrowser},
];
} else {
immutable KEYTAB[]  keytab =
[
        /* Definitions common to all versions   */
       { CTRL('@'),              &ctrlg}, /*basic_setmark*/
       { CTRL('A'),              &gotobol},
       { CTRL('B'),              &backchar},
       { CTRL('C'),              &quit},
       { CTRL('D'),              &random_forwdel},
       { CTRL('E'),              &gotoeol},
       { CTRL('F'),              &forwchar},
       { CTRL('G'),              &ctrlg},
       { CTRL('H'),              &random_backdel},
       { CTRL('I'),              &random_tab},
       { CTRL('J'),              &Ddelline},
       { CTRL('K'),              &random_kill},
       { CTRL('L'),              &window_refresh},
       { CTRL('M'),              &random_newline},
       { CTRL('N'),              &forwline},
       { CTRL('O'),              &random_openline},
       { CTRL('P'),              &backline},
       { CTRL('Q'),              &random_quote},   /* Often unreachable    */
       { CTRL('R'),              &backsearch},
       { CTRL('S'),              &forwsearch},     /* Often unreachable    */
       { CTRL('T'),              &random_twiddle},
       { CTRL('V'),              &forwpage},
       { CTRL('W'),              &search_paren},
       { CTRL('Y'),              &random_yank},
       { 0x7F,                   &random_backdel},
/+
        /* Unused definitions from original microEMACS */
       { CTRL('C'),              &spawncli},       /* Run CLI in subjob.   */
       { CTRL('J'),              &random_indent},
       { CTRL('W'),              &region_kill},
       { CTRL('Z'),              &quickexit},      /* quick save and exit  */
+/
       { CTRL('Z'),              &spawncli},      /* Run CLI in subjob.   */
       { F2KEY,                  &Dsearchagain},
       { F3KEY,                  &search_paren},
       { F4KEY,                  &Dsearch},
       { F5KEY,                  &basic_nextline},
       { F6KEY,                  &window_next},
       { F7KEY,                  &basic_setmark},
       { F8KEY,                  &region_copy},
       { F9KEY,                  &region_kill},
       { F10KEY,                 &random_yank},
	{F11KEY,		 &ctlxe},
	{F12KEY,		 &macrotoggle},
        {AltF1KEY,               &display_norm_bg},
        {AltF2KEY,               &display_norm_fg},
        {AltF3KEY,               &display_mode_bg},
        {AltF5KEY,               &display_mark_fg},
        {AltF6KEY,               &display_mark_bg},
        {AltF4KEY,               &display_mode_fg},
        {AltF7KEY,               &display_eol_bg},
        {AltF9KEY,               &random_decindent},
        {AltF10KEY,              &random_incindent},
        {ALTB,                   &buffer_next},
        {ALTC,                   &main_saveconfig},
	{ALTX,			 &normexit},
        {ALTZ,                   &spawn_pipe},
        {RTKEY,                  &forwchar},
        {LTKEY,                  &backchar},
        {DNKEY,                  &forwline},
        {UPKEY,                  &backline},
        {InsKEY,                 &toggleinsert},
        {DelKEY,                 &random_forwdel},
        {PgUpKEY,                &backpage},
        {PgDnKEY,                &forwpage},
        {HOMEKEY,                &window_mvup},
        {ENDKEY,                 &window_mvdn},
        {CtrlRTKEY,              &word_forw},
        {CtrlLFKEY,              &word_back},
        {CtrlHome,               &gotobob},
        {CtrlEnd,                &gotoeob},

        /* Commands with a special key value    */
        {0x8001,         &spawn_pipe},
        {0x8002,         &spawn_filter},
        {0x8003,         &random_showcpos},
        {0x8004,         &ctlxlp},
        {CMD_ENDMACRO,   &ctlxrp},
        {0x8006,         &random_decindent},
        {0x8007,         &random_incindent},
        {0x8008,         &window_only},
        {0x8009,         &removemark},
        {0x800A,         &spawn.spawn},         /* Run 1 command.       */
        {0x800B,         &window_split},
        {0x800C,         &usebuffer},
        {0x800D,         &delwind},
        {0x800E,         &ctlxe},
        {0x800F,         &random_setfillcol},
        {0x8010,         &buffer.killbuffer},
        {0x8011,         &window_next},
        {0x8012,         &window_prev},
        {0x8013,         &random_quote},
        {0x8014,         &buffer_next},
        {0x8015,         &window_enlarge},
        {0x8016,         &listbuffers},
        {0x8017,         &filename},
        {0x8018,         &filemodify},
        {0x8019,         &window_mvdn},
        {0x801A,         &random_deblank},
        {0x801B,         &window_mvup},
        {0x801C,         &fileread},
        {0x801D,         &filesave},       /* Often unreachable    */
        {0x801E,         &window_reposition},
        {0x801F,         &filevisit},
        {0x8020,         &filewrite},
        {0x8021,         &swapmark},
        {0x8022,         &window_shrink},

        {0x8023,         &delbword},
        {0x8024,         &random_opttab},
        {0x8025,         &basic_setmark},
        {0x8026,         &gotoeob},
        {0x8027,         &gotobob},
        {0x8028,         &region_copy},
        {0x8029,         &region_kill},
        {0x802A,         &word_back},
        {0x802B,         &capword},
        {0x802C,         &delfword},
        {0x802D,         &word_forw},
        {0x802E,         &misc_lower},
        {0x802F,         &queryreplacestring},
        {0x8030,         &replacestring},
        {0x8031,         &misc_upper},
        {0x8032,         &backpage},
        {0x8033,         &word_select},
        {0x8034,         &Dadvance},
        {0x8035,         &Dbackup},
        {0x8036,         &random_deblank},

        {0x8037,         &Dinsertdate},
        {0x8038,         &Dinsertfile},
        {0x8039,         &gotoline},
        {0x803A,         &fileunmodify},
        {0x803B,         &filenext},
        {0x803C,         &quit},
        {0x803D,         &normexit},
        {0x803E,         &Dundelline},
        {0x803F,         &Dsearch},
        {0x8040,         &Dundelword},
        {0x8041,         &random_undelchar},
        {0x8042,         &random_openline},
        {0x8043,         &random_kill},
        {0x8044,         &region_togglemode},
	{0x8045,	 &Dcppcomment},
	{0x8046,	 &random_hardtab},
	{0x8047,	 &word_wrap_line},
	{0x8049,         &openBrowser},
];
}

/* Translation table from 2 key sequence to single value        */
immutable ushort[2][] altf_tab =
[
        ['B',            0x8016],         /* listbuffers          */
        ['D',            0x8037],         /* Dinsertdate          */
        ['F',            0x8017],         /* filename             */
        ['I',            0x8038],         /* Dinsertfile          */
        ['M',            0x8018],         /* filemodify           */
        ['N',            0x803B],         /* filenext             */
        ['Q',            0x803C],         /* quit                 */
        ['R',            0x801C],         /* fileread             */
        ['S',            0x801D],         /* filesave             */
	['T',		 0x8046],	  // random_hardtab
        ['U',            0x803A],         /* fileunmodify         */
        ['V',            0x801F],         /* filevisit            */
        ['W',            0x8020],         /* filewrite            */
        ['X',            0x803D],         /* normexit             */
        [F2KEY,          0x803E],         /* Dundelline           */
        [F4KEY,          0x803F],         /* Dsearch              */
        [CtrlRTKEY,      0x8040],         /* Dundelword           */
        [CtrlLFKEY,      0x8040],         /* Dundelword           */
        [DelKEY,         0x8041],         /* random_undelchar     */
        [InsKEY,         0x8042],         /* random_openline      */
];

version (Windows) {
immutable ushort[2][] esc_tab =
[
        ['.',            0x8025],         /* basic_setmark        */
        ['>',            0x8026],         /* gotoeob              */
        [ENDKEY,         0x8026],         /* gotoeob              */
        ['<',            0x8027],         /* gotobob              */
        [HOMEKEY,        0x8027],         /* gotobob              */
        ['8',            0x8028],         /* region_copy          */
        ['9',            0x8029],         /* region_kill          */
        ['B',            0x802A],         /* word_back            */
        ['C',            0x802B],         /* capword              */
        ['D',            0x802C],         /* delfword             */
        ['E',            0x8049],         // openBrowser
        ['F',            0x802D],         /* word_forw            */
        ['H',            0x8023],         /* delbword             */
        ['I',            0x8024],         /* random_opttab        */
	['J',		 0x803E],		// Dundelline
        ['L',            0x802E],         /* misc_lower           */
        ['M',            0x8048],         // help
        ['N',            0x8019],         /* window_mvdn          */
        ['P',            0x801B],         /* window_mvup          */
        ['Q',            0x802F],         /* queryreplacestring   */
        ['R',            0x8030],         /* replacestring        */
        ['T',            0x8044],         /* region_togglemode    */
        ['U',            0x8031],         /* misc_upper           */
        ['V',            0x8032],         /* backpage             */
        ['W',            0x8033],         /* word_select          */
        ['X',            0x8021],         /* swapmark             */
        ['Z',            0x8022],         /* window_shrink        */
        [DNKEY,          0x8034],         // Dadvance
        [UPKEY,          0x8035],         // Dbackup
];
} else {
  immutable ushort[2][] esc_tab =
[
        ['.',            0x8025],         /* basic_setmark        */
        ['>',            0x8026],         /* gotoeob              */
        [ENDKEY,         0x8026],         /* gotoeob              */
        ['<',            0x8027],         /* gotobob              */
        [HOMEKEY,        0x8027],         /* gotobob              */
        ['8',            0x8028],         /* region_copy          */
        ['9',            0x8029],         /* region_kill          */
        ['B',            0x802A],         /* word_back            */
        ['C',            0x802B],         /* capword              */
        ['D',            0x802C],         /* delfword             */
        ['E',            0x8049],         // openBrowser
        ['F',            0x802D],         /* word_forw            */
        ['H',            0x8023],         /* delbword             */
        ['I',            0x8024],         /* random_opttab        */
	['J',		 0x803E],		// Dundelline
        ['L',            0x802E],         /* misc_lower           */
        ['N',            0x8019],         /* window_mvdn          */
        ['P',            0x801B],         /* window_mvup          */
        ['Q',            0x802F],         /* queryreplacestring   */
        ['R',            0x8030],         /* replacestring        */
        ['T',            0x8044],         /* region_togglemode    */
        ['U',            0x8031],         /* misc_upper           */
        ['V',            0x8032],         /* backpage             */
        ['W',            0x8033],         /* word_select          */
        ['X',            0x8021],         /* swapmark             */
        ['Z',            0x8022],         /* window_shrink        */
        [DNKEY,          0x8034],         // Dadvance
        [UPKEY,          0x8035],         // Dbackup
];
}

immutable ushort[2][] ctlx_tab =
[
        ['@',            0x8001],	// spawn_pipe
        ['#',            0x8002],	// spawn_filter
        ['=',            0x8003],	// random_showcpos
        ['(',            0x8004],	// ctlxlp
        [')',            0x8005],	// ctlxrp
        ['[',            0x8006],	// random_decindent
        [']',            0x8007],	// random_incindent
        ['.',            0x8009],	// removemark
        ['!',            0x800A],	// spawn
        ['1',            0x8008],	// window_only
        ['2',            0x800B],	// window_split
	['A',		 0x8047],	// word_wrap_line
        ['B',            0x800C],	// usebuffer
        ['D',            0x800D],	// delwind
        ['E',            0x800E],	// ctlxe
        ['F',            0x800F],	// random_setfillcol
        ['K',            0x8010],	// killbuffer
        ['L',            0x8039],       // gotoline
        ['N',            0x8011],	// window_next
        ['O',            0x801A],       // random_deblank
        ['P',            0x8012],	// window_prev
        ['Q',            0x8013],	// random_quote
        ['T',            0x801E],       // window_reposition
        ['W',            0x8014],	// buffer_next
        ['Z',            0x8015],	// window_enlarge
	['/',		 0x8045],	// Dcppcomment
];

struct CMDTAB
{   ushort    ktprefix;           /* prefix key value                     */
    immutable ushort[2][]  kt;    /* which translation table              */
};

CMDTAB[] cmdtab =
[
    {   CTLX,   ctlx_tab },
    {   META,   esc_tab  },
    {   GOLD,   altf_tab },
];


string[] gargs;
int gargi;

int c;

int main(string[] args)
{
    bool   f;
    int    n;
    string bname;

    hasmouse = msm_init();                  /* initialize mouse     */
    progname = args[0];                     /* remember program name */
    bname = "main";                         /* Work out the name of */
    if (args.length > 1)                    /* the default buffer.  */
	    bname = makename(args[1]);
    vtinit();                               /* Displays.            */
    edinit(bname);                          /* Buffers, windows.    */
    if (args.length > 1) {
	    update();                       /* You have to update   */
	    readin(args[1]);                /* in case "[New file]" */
    }
    else
	mlwrite("[No file]");
    gargi = 2;
    gargs = args;
    lastflag = 0;                           /* Fake last flags.     */
    while (1)
    {
        update();                               /* Fix up the screen    */
        c = getkey();
        if (mpresf != FALSE)            /* if there is stuff in message line */
        {   mlerase();                  /* erase it                     */
            update();
        }
        f = FALSE;
        n = 1;
        if (c == CTRL('U'))                     /* ^U, start argument   */
        {   f = TRUE;
            n = getarg();
        }
        if (kbdmip != null) {                   /* Save macro strokes.  */
                if (c!=CMD_ENDMACRO && kbdmip>&kbdm[$-6]) {
                        ctrlg(FALSE, 0);
                        continue;
                }
                if (f != FALSE) {
                        *kbdmip++ = CTRL('U');
                        *kbdmip++ = n;
                }
                *kbdmip++ = c;
        }
        execute(0, c, f, n);                       /* Do it.               */
    }
}

/******************************
 * Get and return numeric argument.
 */

int getarg()
{
    int n;
    int mflag;

    n = 4;                          /* with argument of 4 */
    mflag = 0;                      /* that can be discarded. */
    mlwrite("Arg: 4");
    while ((c=getkey()) >='0' && c<='9' || c==CTRL('U') || c=='-'){
        if (c == CTRL('U'))
            n = n*4;
        /*
         * If dash, and start of argument string, set arg.
         * to -1.  Otherwise, insert it.
         */
        else if (c == '-') {
            if (mflag)
                break;
            n = 0;
            mflag = -1;
        }
        /*
         * If first digit entered, replace previous argument
         * with digit and set sign.  Otherwise, append to arg.
         */
        else {
            if (!mflag) {
                n = 0;
                mflag = 1;
            }
            n = 10*n + c - '0';
        }
        mlwrite(format("Arg: %d", (mflag >=0) ? n : (n ? -n : -1)));
    }
    /*
     * Make arguments preceded by a minus sign negative and change
     * the special argument "^U -" to an effective "^U -1".
     */
    if (mflag == -1) {
        if (n == 0)
            n++;
        n = -n;
    }
    return n;
}

/*
 * Initialize all of the buffers and windows. The buffer name is passed down
 * as an argument, because the main routine may have been told to read in a
 * file by default, and we want the buffer name to be right.
 */
void edinit(string bname)
{
        auto bp = buffer_find(bname, TRUE, 0);             /* First buffer         */
        blistp = buffer_find("[List]", TRUE, BFTEMP); /* Buffer list buffer   */
        auto wp = new WINDOW;                              // First window
        if (bp==null || wp==null || blistp==null)
        {       vttidy();
                exit(1);
        }
        bp.b_nwnd  = 1;                        /* Displayed.           */
        curbp  = bp;                            /* Make this current    */
        windows ~= wp;
        curwp  = wp;
        wp.w_bufp  = bp;
        wp.w_linep = bp.b_linep;
        wp.w_dotp  = bp.b_linep;
        wp.w_ntrows = term.t_nrow-2;           /* -1 for mode line, -1 for minibuffer  */
        wp.w_flag  = WFMODE|WFHARD;            /* Full.                */
}

/*
 * This is the general command execution routine. It handles the fake binding
 * of all the keys to "self-insert". It also clears out the "thisflag" word,
 * and arranges to move it to the "lastflag", so that the next command can
 * look at it. Return the status of command.
 */
int execute(int prefix, int c, bool f, int n)
{
    int    status;

     /* Look in key table.   */
    foreach (ktp; keytab)
    {   if (ktp.k_code == c)
        {   thisflag = 0;
            status   = (*ktp.k_fp)(f, n);
            lastflag = thisflag;
            return (status);
        }
    }

    /*
     * If a space was typed, fill column is defined, the argument is non-
     * negative, and we are now past fill column, perform word wrap.
     */
    if (c == ' ' && fillcol > 0 && n>=0 &&
	getcol(curwp.w_dotp,curwp.w_doto) > fillcol)
	    word_wrap(false, 0);

    if ((c>=0x20 && c<=0x7E)                /* Self inserting.      */
    ||  (c>=0xA0 && c<=0xFE)) {
	    if (n <= 0) {                   /* Fenceposts.          */
		    lastflag = 0;
		    return (n<0 ? FALSE : TRUE);
	    }
	    thisflag = 0;                   /* For the future.      */
	    status   = insertmode ? line_insert(n, cast(char)c) : line_overwrite(n, cast(char)c);
	    lastflag = thisflag;
	    return (status);
    }

    /*
     * Beep if an illegal key is typed
     */
    term.t_beep();
    lastflag = 0;                           /* Fake last flags.     */
    return (FALSE);
}

/*
 * Read in a key.
 * Do the standard keyboard preprocessing. Convert the keys to the internal
 * character set.
 */
int getkey()
{
    int    c;

    ttyield();
    while (hasmouse && !ttkeysininput())
    {   c = mouse_command();
	if (c)
	    return c;
	ttyield();
    }
    c = term.t_getchar();
    switch (c)
    {
/+
            case MENU_BUTTON:
                c = memenu_button();
                break;
+/
            case META:
            case GOLD:
            case CTLX:
                c = get2nd(c);
                break;

	    default:
		break;
    }

    return (c);
}

/************************
 * Get second key of two key command.
 * Input:
 *      the first key value
 */

static int get2nd(int flag)
{
    int c;
    int i,j;

/+
    auto starttime = clock();
    while (!ttkeysininput())
        if (clock() > starttime + CLK_TCK)
        {   switch (flag)
            {   case CTLX:
                    return cast(ushort) memenu_ctlx(1,disp_cursorrow,disp_cursorcol);
                case GOLD:
                    return cast(ushort) memenu_gold(1,disp_cursorrow,disp_cursorcol);
                case META:
                    return cast(ushort) memenu_meta(1,disp_cursorrow,disp_cursorcol);
            }
        }
+/
    c = term.t_getchar();

    /* Treat control characters and lowercase the same as upper case */
    if (c>='a' && c<='z')                   /* Force to upper       */
        c -= 0x20;
    else if (c >= CTRL('A') && c <= CTRL('Z'))
        c += 0x40;

    /* Translate to special keycode     */
    for (i = 0; 1; i++)
        if (cmdtab[i].ktprefix == flag)
            break;
    for (j = 0; 1; j++)
    {
        if (j == cmdtab[i].kt.length)
        {   c = 0;
            break;
        }
        if (cmdtab[i].kt[j][0] == c)
        {   c = cmdtab[i].kt[j][1];
            break;
        }
    }
    return c;
}

/*
 * An even better exit command.  Writes all modified files and then
 * exits.
 */
int normexit(bool f, int n)
{
    filemodify(f, n);                // write all modified files
    update();    	             // make the screen look nice
    quit(f, n);
    return false;
}

/*
 * Quit command. If an argument, always quit. Otherwise confirm if a buffer
 * has been changed and not written out. Normally bound to "C-X C-C".
 */
int quit(bool f, int n)
{
        if (f != FALSE                          /* Argument forces it.  */
        || anycb() == FALSE                     /* All buffers clean.   */
        || (mlyesno("Quit [y/n]? ")))           /* User says it's OK.   */
        {   vttidy();
            exit(0);
        }
        return FALSE;
}

/*
 * Begin a keyboard macro.
 * Error if not at the top level in keyboard processing. Set up variables and
 * return.
 */
int ctlxlp(bool f, int n)
{
        if (kbdmip!=null) {
                mlwrite("Not now: recording");
                return (FALSE);
        }
        if (kbdmop!=null) {
                mlwrite("Not now: executing");
                return (FALSE);
        }
        mlwrite("[Start macro]");
        kbdmip = kbdm.ptr;

	foreach (wp; windows)
	    wp.w_flag |= WFMODE;	/* so highlighting is updated */

        return (TRUE);
}

/*
 * End keyboard macro. Check for the same limit conditions as the above
 * routine. Set up the variables and return to the caller.
 */
int ctlxrp(bool f, int n)
{
        if (kbdmip == null) {
                mlwrite("Not recording");
                return (FALSE);
        }
        mlwrite("[End macro]");
        kbdmip = null;

	foreach (wp; windows)
	    wp.w_flag |= WFMODE;	/* so highlighting is updated */

        return (TRUE);
}

/*
 * If in a macro
 * 	end macro
 * Else
 *	start macro
 */

int macrotoggle(bool f, int n)
{
        if (kbdmip)
	    return ctlxrp(f, n);
	else
	    return ctlxlp(f, n);
}

/*
 * Execute a macro.
 * The command argument is the number of times to loop. Quit as soon as a
 * command gets an error. Return TRUE if all ok, else FALSE.
 */
int ctlxe(bool f, int n)
{
        int    c;
        bool   af;
        int    an;
        int    s;

        if (kbdmip!=null || kbdmop!=null) {
                /* Can't execute macro if defining a macro or if        */
                /* in the middle of executing one.                      */
                mlwrite("Not now");
                return (FALSE);
        }
        if (n <= 0)
                /* Execute macro 0 or fewer (!) times   */
                return (TRUE);
        do {
                kbdmop = &kbdm[0];
                do {
                        af = FALSE;
                        an = 1;
                        if ((c = *kbdmop++) == CTRL('U')) {
                                af = TRUE;
                                an = *kbdmop++;
                                c  = *kbdmop++;
                        }
                        s = TRUE;
                } while (c!=CMD_ENDMACRO && (s=execute(0, c, af, an))==TRUE);
                kbdmop = null;
        } while (s==TRUE && --n);
        return (s);
}

/*
 * Abort.
 * Beep the beeper. Kill off any keyboard macro, etc., that is in progress.
 * Sometimes called as a routine, to do general aborting of stuff.
 */
int ctrlg(bool f, int n)
{
        term.t_beep();
        if (kbdmip != null) {
                kbdm[0] = CMD_ENDMACRO;
                kbdmip  = null;
        }
        return ABORT;
}

version (Windows)
{
    CONFIG config =
    {	// mode, norm, eol, mark, tab
	//0x74,0x02,0x07,0x24,
	//0x34,0x7F,0x78,0x3B,
	//0x34,0x0E,0x0E,0x3B,
	//0x34,0x70,0x70,0x3B,
	0x34,0xF0,0xF0,0x3B,
        ' '/*0xAF*/,
	0xF9,
    };
}
else
{
    enum STANDATTR = 0x80;	/* Standout mode bit flag, or'ed in */
    CONFIG config = {STANDATTR,0,0,STANDATTR,' '};
}


/********************************
 * Save configuration.
 */

int main_saveconfig(bool f, int n)
{
    return FALSE;
}

int toggleinsert(bool f, int n)
{
    insertmode ^= 1;
    term.t_setcursor(insertmode);
    return true;
}
