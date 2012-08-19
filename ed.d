

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


/*
 * This file is the general header file for all parts of the MicroEMACS
 * display editor. It contains definitions used by everyone, and it contains
 * the stuff you have to edit to create a version of the editor for a specific
 * operating system and terminal.
 */

module ed;

alias ushort attchar_t;

enum
{
    CVMVAS  = 1,                       /* C-V, M-V arg. in screens.    */

    HUGE    = 1000,                    /* Huge number                  */

    AGRAVE  = 0x60,                    /* M- prefix,   Grave (LK201)   */
    METACH  = 0x1B,                    /* M- prefix,   Control-[, ESC  */
    CTMECH  = 0x1C,                    /* C-M- prefix, Control-\       */
    EXITCH  = 0x1D,                    /* Exit level,  Control-]       */
    CTRLCH  = 0x1E,                    /* C- prefix,   Control-^       */
    HELPCH  = 0x1F,                    /* Help key,    Control-_       */
}


enum
{
    UPKEY           = 0x4800,          /* Up arrow key                 */
    DNKEY           = 0x5000,          /* Down arrow key               */
    RTKEY           = 0x4D00,          /* Right arrow key              */
    LTKEY           = 0x4B00,          /* Left arrow key               */
    F1KEY           = 0x3B00,
    F2KEY           = 0x3C00,
    F3KEY           = 0x3D00,
    F4KEY           = 0x3E00,
    F5KEY           = 0x3F00,
    F6KEY           = 0x4000,
    F7KEY           = 0x4100,
    F8KEY           = 0x4200,
    F9KEY           = 0x4300,
    F10KEY          = 0x4400,
    F11KEY          = 0x5700,
    F12KEY          = 0x5800,
    AltF1KEY        = 0x6800,
    AltF2KEY        = 0x6900,
    AltF3KEY        = 0x6A00,
    AltF4KEY        = 0x6B00,
    AltF5KEY        = 0x6C00,
    AltF6KEY        = 0x6D00,
    AltF7KEY        = 0x6E00,
    AltF8KEY        = 0x6F00,
    AltF9KEY        = 0x7000,
    AltF10KEY       = 0x7100,
    ALTB            = 0x3000,
    ALTC            = 0x2E00,
    ALTD            = 0x2000,
    ALTE            = 0x1200,
    ALTF            = 0x2100,
    ALTH            = 0x2300,
    ALTM            = 0x3200,
    ALTX            = 0x2D00,
    ALTZ            = 0x2C00,
    InsKEY          = 0x5200,
    CtrlHome        = 0x7700,
    CtrlEnd         = 0x7500,
    DelKEY          = 0x5300,
    CtrlRTKEY       = 0x7400,
    CtrlLFKEY       = 0x7300,
    HOMEKEY         = 0x4700,
    ENDKEY          = 0x4F00,
    PgUpKEY         = 0x4900,
    PgDnKEY         = 0x5100,

    GOLDKEY         = ALTF,
    MENU_BUTTON     = ALTH,
}


char CTRL(char c) { return c & 0x1F; }  /* Control flag, or'ed in       */

enum
{
    META    = METACH,                  /* Meta flag, or'ed in          */
    CTLX    = CTRL('X'),               /* ^X flag, or'ed in            */
    GOLD    = GOLDKEY,                 /* Another Meta flag, or'ed in  */
}

enum
{
    FALSE   = 0,                       /* False, no, bad, etc.         */
    TRUE    = 1,                       /* True, yes, good, etc.        */
    ABORT   = 2,                       /* Death, ^G, abort, etc.       */
}

enum
{
    CFCPCN  = 0x0001,                  /* Last command was C-P, C-N    */
    CFKILL  = 0x0002,                  /* Last command was a kill      */
}

/*
 * Seperate kbufp[] buffers for cut, word, line and char deletes...
 */
enum
{   DCUTBUF,
    DLINEBUF,
    DWORDBUF,
    DCHARBUF,
    DSPECBUF,      /* maximum number of temp buffers */
}

/********************************
 * All configuration parameters are stored in this struct.
 */

struct CONFIG
{
    uint modeattr;          /* for mode line                */
    uint normattr;          /* for normal text              */
    uint eolattr;           /* for end of line              */
    uint markattr;          /* for selected text            */
    uint tabchar;           /* char to use for tab display  */
}

/**************
 * George M. Jones      {cbosgd,ihnp4}!osu-eddie!george
 * Work Phone:          george@ohio-state.csnet
 * (614) 457-8600       CompuServe: 70003,2443
 */

