

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */


module mouse;

import disp;
import core.stdc.time;

import ed;
import window;
import line;
import main;
import terminal;
import display;
import xterm;
import word;

//#include	<msmouse.h>

static int clicks = 0;		/* number of clicks we've seen		*/
static clock_t lastclick;	/* time of last click			*/

/*********************************
 * Call this routine in the main command loop.
 * It handles any mouse commands.
 * Returns:
 *	0	no mouse input
 *	!=0	value is a keystroke
 */

int mouse_command()
{   uint x,y;
    WINDOW *wp;
    LINE *lp;
    int status;

    if (!hasmouse)			/* if no mouse installed	*/
	return 0;
    status = msm_getstatus(&x,&y);	/* read button status		*/
    mouse_tocursor(&x,&y);		/* collect real cursor coords	*/
    if (status & 1)			/* if left button is down	*/
    {	int doto;

	mouse_findpos(x,y,&wp,&lp,&doto);
	if (wp && lp)
	{   markcol = wp.w_startcol + x;
	    mouse_markdrag(wp,lp,doto);
	}
	else
	{   if (wp)
	    {
		curbp = wp.w_bufp;
		curwp = wp;
		/* Examine window action buttons	*/
		switch (x)
		{   case 0:
			window_only(FALSE,1);
			goto L2;
		    case 1:
			window_split(FALSE,1);
			goto L2;
		    case 2:
			delwind(FALSE,1);
		    L2:	update();
			goto L1;
		    case 3:
			do
			{   window_mvup(FALSE,1);
			    update();
			} while (mouse_leftisdown());
			break;
		    case 4:
			do
			{   window_mvdn(FALSE,1);
			    update();
			} while (mouse_leftisdown());
			break;
		    default:
			mouse_windrag(wp);
			break;
		}
		update();
	    }
	    else
	    L1:
		while (mouse_leftisdown())	/* wait till button goes up */
		{ }
	    clicks = 0;
	}
    }
    else if (status & 2)		/* if right button is down	*/
    {
	//return memenu_mouse(y,x);
    }
    return 0;
}

/*******************************
 * Convert from Microsoft coordinates to proper cursor coordinates.
 */

static void mouse_tocursor(uint* px, uint* py)
{
}

/***************************
 * Set cursor at row,col.
 */

static void mouse_findpos(uint col, uint row, WINDOW** p_wp, LINE** p_lp, int* p_doto)
{   int r;
    int i;
    LINE *lp;

    *p_wp = null;
    *p_lp = null;
    *p_doto = 0;			/* default cases		*/
    r = 0;				/* starting row for window	*/
    foreach (wp; windows)
    {
	if (row <= r + wp.w_ntrows)
	{
	    *p_wp = wp;
	    if (row == r + wp.w_ntrows)
		return;
	    for (lp = wp.w_linep; lp != wp.w_bufp.b_linep; lp = lforw(lp))
	    {	if (row == r)
		    break;
		r++;
	    }
	    *p_lp = lp;
	    /* Determine offset into line corresponding to col		*/
	    *p_doto = coltodoto(lp,wp.w_startcol + col);
	    return;
	}
	r += wp.w_ntrows + 1;
    }
}

/*****************************
 * Given an initial position, drag the mouse, marking
 * text as we go.
 */

static void mouse_markdrag(WINDOW* wp, LINE* lp, int doto)
{   uint x,y;

    curbp = wp.w_bufp;
    curwp = wp;
    if (lp != wp.w_dotp)	/* if on different line		*/
    {   wp.w_dotp = lp;
	wp.w_flag |= WFMOVE;
    }
    wp.w_doto = doto;
    wp.w_markp = lp;
    wp.w_marko = doto;		/* set new mark			*/
    curwp.w_flag |= WFHARD;
    update();

    /* Continue marking until button goes up			*/
    while (msm_getstatus(&x,&y) & 1)
    {
	mouse_tocursor(&x,&y);	/* collect real cursor coords	*/
	mouse_findpos(x,y,&wp,&lp,&doto);
	if (wp && wp == curwp && lp)
	{
	    if (wp.w_markp || lp != wp.w_dotp) /* if on different line */
	    {
		wp.w_dotp = lp;
		wp.w_flag |= WFMOVE;
	    }
	    wp.w_doto = doto;
	}
	else if (!wp ||
	    wp != curwp && wp.w_toprow > curwp.w_toprow ||
	    wp == curwp && !lp)
		window_mvdn(FALSE,1);
	else
		window_mvup(FALSE,1);
	curgoal = curwp.w_startcol + x;
	lastflag |= CFCPCN;	/* behave as if forwline() or backline() */
	update();
    }
    /* If mark start and mark end match, then no mark		*/
    if (wp.w_markp == wp.w_dotp &&
	wp.w_marko == wp.w_doto)
    {	clock_t thisclick;

	wp.w_markp = null;
	thisclick = clock();
	if (clicks)
	{   if (thisclick - lastclick > 500) //CLOCKS_PER_SEC / 2)
		clicks = 0;
	}
	clicks++;
	lastclick = thisclick;

	switch (clicks)
	{   case 1:
		break;
	    case 2:
		word_select(FALSE,1);
		goto L1;
	    case 3:
		word_lineselect(FALSE,1);
	    L1:
		mlerase();
		update();
		break;
	    default:
		clicks = 0;
		break;
	}
    }
    else
	clicks = 0;
}

/*****************************
 * Given an initial position, drag the border of the window around.
 */

static void mouse_windrag(WINDOW* wp)
{   uint x,y;
    LINE *lp;
    int doto;

    /* Continue dragging window until button goes up			*/
    while (msm_getstatus(&x,&y) & 1)
    {
	mouse_tocursor(&x,&y);		/* collect real cursor coords	*/
	mouse_findpos(x,y,&wp,&lp,&doto);
	if (wp && wp == curwp && lp ||
	    wp != curwp && wp && wp.w_toprow < curwp.w_toprow)
	    window_shrink(FALSE,1);
	else if (!wp ||
	    wp != curwp && wp.w_toprow > curwp.w_toprow)
	    window_enlarge(FALSE,1);
	update();
    }
}

/*****************************
 * Return !=0 if left button is down.
 */

static int mouse_leftisdown()
{   uint x,y;

    return msm_getstatus(&x,&y) & 1;
}
