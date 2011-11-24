#include <gvc.h>
#include <stdio.h>
#include <time.h>

int dot2graphic (char* type, char* input, char* output){
	/* check inputfiles and type */
	if(!type)
		return 1;
	if(!input)
		return 2;
	if(!output)
		return 3;
	GVC_t *gvc;
	graph_t *g;
	FILE *inHandler;
	gvc = gvContext();
	inHandler = fopen(input, "r");
	if(!inHandler)
		return -1;
	g = agread(inHandler);
	if(gvLayout(gvc, g, "dot"))
		return -2;
	if(gvRenderFilename(gvc, g, type, output))
		return -3;

	gvFreeLayout(gvc, g);
	agclose(g);
	return 0;
}
