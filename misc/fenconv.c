#include <stdio.h>

int
main(void)
{
	char buffer[4096];


	printf("FEN: ");
	while (fgets(buffer, sizeof(buffer), stdin))
	{
		printf("%s", buffer);
		printf("FEN: ");
	}

	return 0;
}
