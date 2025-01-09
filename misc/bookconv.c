#include <stdio.h>

int
main(void)
{
	int c;
	
	printf("static const unsigned char book_data[] = {\n");
	while ((c = fgetc(stdin)) != EOF)
		printf("%d,\n", c);
	printf("};\n");

	return 0;
}
	
