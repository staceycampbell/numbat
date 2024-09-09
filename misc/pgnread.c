#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
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
							if ((tmove[0] >= 'a' && tmove[0] <= 'z') || (tmove[0] >= 'A' &&
												     tmove[0] <= 'Z') || !strcmp(tmove, "0-0") || !strcmp(tmove, "0-0-0"))
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

int
main(void)
{
}
