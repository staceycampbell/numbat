// from Bob Hyatt's crafty

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

static char buffer[4096];
static char pgn_event[128];
static char pgn_date[128];
static char pgn_round[128];
static char pgn_site[128];
static char pgn_white[128];
static char pgn_white_elo[128];
static char pgn_black[128];
static char pgn_black_elo[128];
static char pgn_result[128];

/*
*******************************************************************************
*                                                                             *
*   This routine reads a move from a PGN file to build an opening book or for *
*   annotating.  It returns a 1 if a header is read, it returns a 0 if a move *
*   is read, and returns a -1 on end of file.  It counts lines and this       *
*   counter can be accessed by calling this function with a non-zero second   *
*   formal parameter.                                                         *
*                                                                             *
*******************************************************************************
*/
int
ReadPGN(FILE * input, int option)
{
	static int data = 0, lines_read = 0;
	int braces = 0, parens = 0, brackets = 0, analysis = 0, last_good_line;
	static char input_buffer[4096];
	char *eof, analysis_move[64];

/*
************************************************************
*                                                          *
*  If the line counter is being requested, return it with  *
*  no other changes being made.  If "purge" is true, clear *
*  the current input buffer.                               *
*                                                          *
************************************************************
*/
	if (!input)
	{
		lines_read = 0;
		data = 0;
		return 0;
	}
	if (option == -1)
		data = 0;
	if (option == -2)
		return lines_read;
/*
************************************************************
*                                                          *
*  If we don't have any data in the buffer, the first step *
*  is to read the next line.                               *
*                                                          *
************************************************************
*/
	while (1)
	{
		if (!data)
		{
			eof = fgets(input_buffer, 4096, input);
			if (!eof)
				return -1;
			if (strchr(input_buffer, '\n'))
				*strchr(input_buffer, '\n') = 0;
			if (strchr(input_buffer, '\r'))
				*strchr(input_buffer, '\r') = ' ';
			lines_read++;
			buffer[0] = 0;
			sscanf(input_buffer, "%s", buffer);
			if (buffer[0] == '[')
				do
				{
					char *bracket1, *bracket2, value[128];

					strcpy(buffer, input_buffer);
					bracket1 = strchr(input_buffer, '\"');
					if (bracket1 == 0)
						return 1;
					bracket2 = strchr(bracket1 + 1, '\"');
					if (bracket2 == 0)
						return 1;
					*bracket1 = 0;
					*bracket2 = 0;
					strcpy(value, bracket1 + 1);
					if (strstr(input_buffer, "Event"))
						strcpy(pgn_event, value);
					else if (strstr(input_buffer, "Site"))
						strcpy(pgn_site, value);
					else if (strstr(input_buffer, "Round"))
						strcpy(pgn_round, value);
					else if (strstr(input_buffer, "Date"))
						strcpy(pgn_date, value);
					else if (strstr(input_buffer, "WhiteElo"))
						strcpy(pgn_white_elo, value);
					else if (strstr(input_buffer, "White"))
						strcpy(pgn_white, value);
					else if (strstr(input_buffer, "BlackElo"))
						strcpy(pgn_black_elo, value);
					else if (strstr(input_buffer, "Black"))
						strcpy(pgn_black, value);
					else if (strstr(input_buffer, "Result"))
						strcpy(pgn_result, value);
					else if (strstr(input_buffer, "FEN"))
					{
						// sprintf(buffer, "setboard %s", value);
						// Option(block[0]);
						continue;
					}
					return 1;
				}
				while (0);
			data = 1;
		}
/*
************************************************************
*                                                          *
*  If we already have data in the buffer, it is just a     *
*  matter of extracting the next move and returning it to  *
*  the caller.  If the buffer is empty, another line has   *
*  to be read in.                                          *
*                                                          *
************************************************************
*/
		else
		{
			buffer[0] = 0;
			sscanf(input_buffer, "%s", buffer);
			if (strlen(buffer) == 0)
			{
				data = 0;
				continue;
			}
			else
			{
				char *skip;

				skip = strstr(input_buffer, buffer) + strlen(buffer);
				if (skip)
					memmove(input_buffer, skip, strlen(skip) + 1);
			}
/*
************************************************************
*                                                          *
*  This skips over nested {} or () characters and finds    *
*  the 'mate', before returning any more moves.  It also   *
*  stops if a PGN header is encountered, probably due to   *
*  an incorrectly bracketed analysis variation.            *
*                                                          *
************************************************************
*/
			last_good_line = lines_read;
			analysis_move[0] = 0;
			if (strchr(buffer, '{') || strchr(buffer, '('))
				while (1)
				{
					char *skip, *ch;

					analysis = 1;
					while ((ch = strpbrk(buffer, "(){}[]")))
					{
						if (*ch == '(')
						{
							*strchr(buffer, '(') = ' ';
							if (!braces)
								parens++;
						}
						if (*ch == ')')
						{
							*strchr(buffer, ')') = ' ';
							if (!braces)
								parens--;
						}
						if (*ch == '{')
						{
							*strchr(buffer, '{') = ' ';
							braces++;
						}
						if (*ch == '}')
						{
							*strchr(buffer, '}') = ' ';
							braces--;
						}
						if (*ch == '[')
						{
							*strchr(buffer, '[') = ' ';
							if (!braces)
								brackets++;
						}
						if (*ch == ']')
						{
							*strchr(buffer, ']') = ' ';
							if (!braces)
								brackets--;
						}
					}
					if (analysis && analysis_move[0] == 0)
					{
						if (strspn(buffer, " ") != strlen(buffer))
						{
							char *tmove = analysis_move;

							sscanf(buffer, "%64s", analysis_move);
							strcpy(buffer, analysis_move);
							if (strcmp(buffer, "0-0") && strcmp(buffer, "0-0-0"))
								tmove = buffer + strspn(buffer, "0123456789.");
							else
								tmove = buffer;
							if ((tmove[0] >= 'a' && tmove[0] <= 'z') ||
                                                            (tmove[0] >= 'A' && tmove[0] <= 'Z') ||
                                                            !strcmp(tmove, "0-0") || !strcmp(tmove, "0-0-0"))
								strcpy(analysis_move, buffer);
							else
								analysis_move[0] = 0;
						}
					}
					if (parens == 0 && braces == 0 && brackets == 0)
						break;
					buffer[0] = 0;
					sscanf(input_buffer, "%s", buffer);
					if (strlen(buffer) == 0)
					{
						eof = fgets(input_buffer, 4096, input);
						if (!eof)
						{
							parens = 0;
							braces = 0;
							brackets = 0;
							return -1;
						}
						if (strchr(input_buffer, '\n'))
							*strchr(input_buffer, '\n') = 0;
						if (strchr(input_buffer, '\r'))
							*strchr(input_buffer, '\r') = ' ';
						lines_read++;
						if (lines_read - last_good_line >= 100)
						{
							parens = 0;
							braces = 0;
							brackets = 0;
							fprintf(stderr, "ERROR.  comment spans over 100 lines, starting at line %d\n", last_good_line);
							break;
						}
					}
					skip = strstr(input_buffer, buffer) + strlen(buffer);
					memmove(input_buffer, skip, strlen(skip) + 1);
				}
			else
			{
				int skip;

				if ((skip = strspn(buffer, "0123456789./-")))
				{
					if (skip > 1)
						memmove(buffer, buffer + skip, strlen(buffer + skip) + 1);
				}
				if (isalpha(buffer[0]) || strchr(buffer, '-'))
				{
					char *first, *last, *percent;

					first = input_buffer + strspn(input_buffer, " ");
					if (first == 0 || *first != '{')
						return 0;
					last = strchr(input_buffer, '}');
					if (last == 0)
						return 0;
					percent = strstr(first, "play");
					if (percent == 0)
						return 0;
					return 0;
				}
			}
			if (analysis_move[0] && option == 1)
			{
				strcpy(buffer, analysis_move);
				return 2;
			}
		}
	}
}

/*
 *******************************************************************************
 *                                                                             *
 *   InputMove() is responsible for converting a move from a text string to    *
 *   the internal move format.  It allows the so-called "reduced algebraic     *
 *   move format" which makes the origin square optional unless required for   *
 *   clarity.  It also accepts as little as required to remove ambiguity from  *
 *   the move, by using GenerateMoves() to produce a set of legal moves that   *
 *   the text can be applied against to eliminate those moves not intended.    *
 *   Hopefully, only one move will remain after the elimination and legality   *
 *   checks.                                                                   *
 *                                                                             *
 *******************************************************************************
 */

static int promote;
static int ffile, frank, tfile, trank;

int
InputMove(int wtm, char *text)
{
	int current, i;
	char *goodchar, *tc;
	char movetext[128];
	static const char pro_pieces[15] = { ' ', ' ', 'P', 'p', 'N', 'n', 'B', 'b', 'R', 'r', 'Q', 'q',
		'K', 'k', '\0'
	};
/*
 ************************************************************
 *                                                          *
 *  First, we need to strip off the special characters for  *
 *  check, mate, bad move, good move, and such that might   *
 *  come from a PGN input file.                             *
 *                                                          *
 ************************************************************
 */
	if ((tc = strchr(text, '!')))
		*tc = 0;
	if ((tc = strchr(text, '?')))
		*tc = 0;
	if (strlen(text) == 0)
		return 0;
/*
 ************************************************************
 *                                                          *
 *  Initialize move structure.  If we discover a parsing    *
 *  error, this will cause us to return a move of "0" to    *
 *  indicate some sort of error was detected.               *
 *                                                          *
 ************************************************************
 */
	strcpy(movetext, text);
	frank = -1;
	ffile = -1;
	trank = -1;
	tfile = -1;
	goodchar = strchr(movetext, '#');
	if (goodchar)
		*goodchar = 0;
/*
 ************************************************************
 *                                                          *
 *  First we look for castling moves which are a special    *
 *  case with an unusual syntax compared to normal moves.   *
 *                                                          *
 ************************************************************
 */
	if (!strcmp(movetext, "o-o") || !strcmp(movetext, "o-o+")
	    || !strcmp(movetext, "O-O") || !strcmp(movetext, "O-O+") || !strcmp(movetext, "0-0") || !strcmp(movetext, "0-0+"))
	{
		if (wtm)
		{
			ffile = 4;
			frank = 0;
			tfile = 6;
			trank = 0;
		}
		else
		{
			ffile = 4;
			frank = 7;
			tfile = 6;
			trank = 7;
		}
	}
	else if (!strcmp(movetext, "o-o-o") || !strcmp(movetext, "o-o-o+")
		 || !strcmp(movetext, "O-O-O") || !strcmp(movetext, "O-O-O+") || !strcmp(movetext, "0-0-0") || !strcmp(movetext, "0-0-0+"))
	{
		if (wtm)
		{
			ffile = 4;
			frank = 0;
			tfile = 2;
			trank = 0;
		}
		else
		{
			ffile = 4;
			frank = 7;
			tfile = 2;
			trank = 7;
		}
	}
	else
	{
/*
 ************************************************************
 *                                                          *
 *  OK, it is not a castling move.  Check for two "b"       *
 *  characters which might be a piece (bishop) and a file   *
 *  (b-file).  The first "b" should be "B" but we allow     *
 *  this to make typing input simpler.                      *
 *                                                          *
 ************************************************************
 */
		if ((movetext[0] == 'b') && (movetext[1] == 'b'))
			movetext[0] = 'B';
/*
 ************************************************************
 *                                                          *
 *  Check to see if there is a "+" character which means    *
 *  that this move is a check.  We can use this to later    *
 *  eliminate all non-checking moves as possibilities.      *
 *                                                          *
 ************************************************************
 */
		if (strchr(movetext, '+'))
		{
			*strchr(movetext, '+') = 0;
		}
/*
 ************************************************************
 *                                                          *
 *  If this is a promotion, indicated by an "=" in the      *
 *  text, we can pick up the promote-to piece and save it   *
 *  to use later when eliminating moves.                    *
 *                                                          *
 ************************************************************
 */
		if (strchr(movetext, '='))
		{
			goodchar = strchr(movetext, '=');
			goodchar++;
			promote = (strchr(pro_pieces, *goodchar) - pro_pieces) >> 1;
			*strchr(movetext, '=') = 0;
		}
/*
 ************************************************************
 *                                                          *
 *  Now for a kludge.  ChessBase (and others) can't follow  *
 *  the PGN standard of bxc8=Q for promotion, and instead   *
 *  will produce "bxc8Q" omitting the PGN-standard "="      *
 *  character.  We handle that here so that we can read     *
 *  their non-standard moves.                               *
 *                                                          *
 ************************************************************
 */
		else
		{
			char *prom = strchr(pro_pieces, movetext[strlen(movetext) - 1]);

			if (prom)
			{
				promote = (prom - pro_pieces) >> 1;
				movetext[strlen(movetext) - 1] = 0;
			}
		}
/*
 ************************************************************
 *                                                          *
 *  Next we extract the last rank/file designators from the *
 *  text, since the destination is required for all valid   *
 *  non-castling moves.  Note that we might not have both a *
 *  rank and file but we must have at least one.            *
 *                                                          *
 ************************************************************
 */
		current = strlen(movetext) - 1;
		trank = movetext[current] - '1';
		if ((trank >= 0) && (trank <= 7))
			movetext[current] = 0;
		else
			trank = -1;
		current = strlen(movetext) - 1;
		tfile = movetext[current] - 'a';
		if ((tfile >= 0) && (tfile <= 7))
			movetext[current] = 0;
		else
			tfile = -1;
		if (strlen(movetext))
		{
/*
 ************************************************************
 *                                                          *
 *  The first character is the moving piece, unless it is a *
 *  pawn.  In this case, the moving piece is omitted and we *
 *  know what it has to be.                                 *
 *                                                          *
 ************************************************************
 */
			if (strchr("  PpNnBBRrQqKk", *movetext))
			{
				for (i = 0; i < (int)strlen(movetext); i++)
					movetext[i] = movetext[i + 1];
			}
/*
 ************************************************************
 *                                                          *
 *  It is also possible that this move is a capture, which  *
 *  is indicated by a "x" between either the source and     *
 *  destination squares, or between the moving piece and    *
 *  the destination.                                        *
 *                                                          *
 ************************************************************
 */
			if ((strlen(movetext)) && (movetext[strlen(movetext) - 1] == 'x'))
			{
				movetext[strlen(movetext) - 1] = 0;
			}
/*
 ************************************************************
 *                                                          *
 *  It is possible to have no source square, but we could   *
 *  have a complete algebraic square designation, or just   *
 *  rank or file, needed to disambiguate the move.          *
 *                                                          *
 ************************************************************
 */
			if (strlen(movetext))
			{
				ffile = movetext[0] - 'a';
				if ((ffile < 0) || (ffile > 7))
				{
					ffile = -1;
					frank = movetext[0] - '1';
				}
				else
				{
					if (strlen(movetext) == 2)
					{
						frank = movetext[1] - '1';
					}
				}
			}
		}
	}
	return 0;
}

int
main(int argc, char *argv[0])
{
        int i, status, wtm;
        FILE *fp;

        if ((fp = fopen("sample.pgn", "r")) == 0)
        {
                fprintf(stderr, "%s: can't read sample.pgn", argv[0]);
                exit(1);
        }

        i = 0;
	wtm = 1;
        while ((status = ReadPGN(fp, 0)) >= 0)
        {
		if (status == 0)
		{
			InputMove(wtm, buffer);
			++i;
			printf("%s (%d %d %d %d)\n", buffer, frank, ffile, trank, tfile);
			wtm = !wtm;
		}
	}

        return 0;
}
