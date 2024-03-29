
## med, Micro Emacs in D

This is my version of MicroEmacs, based on the public
domain version by Dave Conroy. I like it because it is
small, fast, easilly customizable, and it ports readilly
to whatever machine I need to use it on. It's written
in the [D programming language](https://dlang.org).

It currently works on Windows and Linux.

To edit myfile.d:
```
med myfile.d
```

Cheat Sheet
```
Command Name         Description                        Keybinding

Movement

basic_nextline       Move to next line			F5
gotobol              Move to start of line		^A
forwchar             Move forward by characters		^F, rightarrow
gotoeol              Move to end of line		^E
backchar             Move backward by characters	^B, leftarrow
forwline             Move forward by lines		^N, downarrow
backline             Move backward by lines		^P, uparrow
forwpage             Move forward by pages		^V, PgDn
backpage             Move backward by pages		Esc B, PgUp
gotobob              Move to start of buffer		Esc <, ^Home
gotoeob              Move to end of buffer		Esc >, ^End
gotoline             Move to line number		^X L
word_back            Backup by words			Esc B, ^leftarrow
word_forw            Advance by words			Esc F, ^rightarrow

Windows

window_next          Move to the next window		^X N, F6
window_prev          Move to the previous window	^X P
window_only          Make current window only one	^X 1
window_split         Split current window		^X 2
window_mvdn          Move window down			Esc N, End
window_mvup          Move window up			Esc P, Home
window_enlarge       Enlarge display window		^X Z
window_shrink        Shrink window			Esc Z
window_reposition    Reposition window			^X T
window_refresh       Refresh the screen			^L
delwind              Delete a window			^X D

Deleting

random_deblank       Delete blank lines			^X O
random_forwdel       Forward delete			^D, Del
random_backdel       Backward delete			^H, 0x7F
random_undelchar     Undelete a character		AltF Del
Ddelline             Delete a line			^J
Dundelline           Undelete a line			Esc J, AltF F2
Ddelword             Delete a word
Ddelbword            Delete a word (backwards)
Dundelword           Undelete a word			AltF ^rightarrow, AltF ^leftarrow
delfword             Delete forward word		Esc D
delbword             Delete backward word		Esc H

Cutting/Pasting

random_kill          Kill forward			^K
random_yank          Paste from kill buffer		^Y, ^X K, F10
region_kill          Cut region to kill buffer		Esc 9, F9
region_copy          Copy region to kill buffer		Esc 8, F8
basic_setmark        Set mark				F7, Esc .
removemark           Remove mark			^X .
swapmark             Swap dot and mark			Esc X
word_select          Select word			Esc W

Files

filenext             Edit next file			AltF N
fileread             Get a file, read only		AltF R
filevisit            Get a file, read write		AltF V
filewrite            Write a file			AltF W
fileunmodify         Turn off buffer changed bits	AltF U
filesave             Save current file			AltF S
filename             Adjust file name			AltF F
filemodify           Write modified files		AltF M
Dinsertfile          Insert a file at dot		AltF I

Exit

ctrlg                Abort out of things		^@, ^G
quit                 Quit				^C, AltF Q
quickexit            low keystroke style exit
normexit             Write modified files and exit	AltF X, AltX

Macros

ctlxlp               Begin macro			^X (
ctlxrp               End macro				^X )
macrotoggle          Start/End macro			F12
ctlxe                Execute macro			^X E, F11

Search

forwsearch           Search forward			^S
                     Search forward regexp              ^S^T
                     Search forward word                ^S^W
backsearch           Search backwards			^R
replacestring        Search and replace			Esc R
queryreplacestring   Query search and replace		Esc Q
Dsearch              Search				F4, AltF F4
Dsearchagain         Search for the same string		F2

D, C and C++

search_paren         Toggle over parentheses		^W, F3
random_indent        Insert CR-LF, then indent
random_incindent     increase indentation level		^X ], AltF10
random_decindent     decrease indentation level		^X [, AltF9
random_opttab        optimize tabbing in line		Esc I
Dcppcomment          convert /* */ to //		^X /

<b>Configuration</b>

display_norm_fg						AltF2
display_norm_bg						AltF1
display_mode_fg						AltF4
display_mode_bg						AltF3
display_mark_fg						AltF5
display_mark_bg						AltF6
display_eol_bg						AltF7
main_saveconfig      Save configuration			AltC

Process

spawncli             Run CLI in a subjob		^Z
spawn                Run a command in a subjob		^X !
spawn_filter         Filter buffer through program	^X #
spawn_pipe           Run program and gather output	^X @, AltZ
Dpause               Pause the program (UNIX only)

Buffers

listbuffers          Display list of buffers		AltF B
usebuffer            Switch a window to a buffer	^X B
buffer_next          Switch to next buffer		^X W, AltB
killbuffer           Make a buffer go away

Other

random_setfillcol    Set fill column			^X F
word_wrap_line       Word wrap line                     ^X A
random_showcpos      Show the cursor position		^X =
random_twiddle       Twiddle characters			^T
random_tab           Insert tab				^I, Tab
random_hardtab       Set hardware tabs			AltF T
random_newline       Insert CR-LF			^M
random_openline      Open up a blank line		^O, AltF Ins
random_quote         Insert literal			^Q, ^X Q
region_togglemode    Toggle column region mode		Esc T
toggleinsert         Toggle insert/overwrite mode	Ins
line_overwrite       Write char in overwrite mode
getcol               Get current column
misc_upper           Upper case word/region		Esc U
misc_lower           Lower case word/region		Esc L
capword              Initial capitalize word		Esc C
win32toggle43        Toggle hires mode			AltE
ibmpctoggle43        Toggle hires mode			AltE
Dignore              do nothing
Dadvance             Set into advance mode		Esc downarrow
Dbackup              Set into backup mode		Esc uparrow
Dinsertdate          File and date stamp		AltF D
scrollUnicode        Scroll through Unicode variations  ^X U
```

### Glossary

* *dot* current cursor position
* *mark* start of a region
* *minibuffer* text entry box used for entering file names
and search strings
* *region* text between "dot" and "mark"
* [Regular Expressions](https://www.digitalmars.com/ctg/regular.html)


### Notes

* ^[ also works as Esc.
* Names without a keybinding can't be accessed, but they can
be called if the keybindings in main.c are updated.
* Prefixing a command with ^U enables a count to be entered,
which executes the command count times.
* Pressing ^X, AltF, or Esc and then pausing will bring up
a menu.
* The right mouse button will bring up a menu.
* The left mouse button can be used for setting the dot,
marking regions, and adjusting window sizes.
* The minibuffer has a small history buffer, accessible with
the uparrow key.
* On Win32, by clicking on the title bar, then select [Edit],
you can access the Windows clipboard. This is very handy
for cutting/pasting text from another window or the web browser.

### Bugs

* Some of the keybindings make no sense.
* The Alt function key sequences don't work on Win32.
* The control numeric pad sequences don't work on Linux.
* The colors can't be modified on any but the DOS version.
* The process functionality is flaky.
* For some reason, the mouse in the Win32 version doesn't
work on Win2000, but does on WinNT.
