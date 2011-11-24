#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

#include "config.h"

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#include "nftrack_stat.h"
#include "nftrack_rrd.h"

#define STATFILE "ports.stat"

#define NUMPORTS 65536

typedef struct stat_header_s {
	uint16_t	version;
	int			av_num;
	time_t		last;
} stat_header_t;

typedef struct topN_vector_s {
	uint16_t	port;
	uint64_t	count;
} topN_vector_t;

static stat_header_t	stat_header;
static data_row			*stat_record;
static char				statfile[1024];
static char				dbpath[1024];
static int				dirty;

/* prototypes */
static void ReadStat(void);
static void heapSort(topN_vector_t *vector, int array_size, int topN);
static void siftDown(topN_vector_t *vector, int root, int bottom);

int InitStat(char *path) {
int len;
	stat_header.version = 0;
	stat_record = NULL;

	len = snprintf(dbpath, 1024, "%s", path);
	len = snprintf(statfile, 1024, "%s/%s", path, STATFILE);
	if ( len >= 1024 ) {
		fprintf(stderr, "String overflow: statfile name\n");
		statfile[0] = 0;
		return 0;
	}
	dirty = 0;

	return 1;

} // End of InitStat

int InitStatFile(time_t when, int av_num) {
ssize_t	num;
int		fd;

	if ( statfile[0] == 0 )
		return 0;

	stat_record = (data_row *)calloc(NUMPORTS, sizeof(data_row));
	if ( !stat_record ) {
		fprintf(stderr, "Can't allocate stat buffer:  %s\n", strerror(errno));
		return 0;
	}

	memset((void *)stat_record, 0, NUMPORTS * sizeof(data_row));
	
	fd = open(statfile, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH );
	if ( fd < 0 ) {
		fprintf(stderr, "Can't open stat file '%s': %s\n", statfile, strerror(errno));
		free(stat_record);
		return 0;
	}

	stat_header.version = 1;
	stat_header.av_num	= av_num;
	stat_header.last	= when;

	num = write(fd, &stat_header, sizeof(stat_header));
	num = write(fd, stat_record, NUMPORTS * sizeof(data_row));
	if ( num < 0 ) {
		fprintf(stderr, "Can't write stat record: %s\n", strerror(errno));
		stat_header.version = 0;
		free(stat_record);
		close(fd);
		return 0;
	}
	
	close(fd);

	return 1;

} // End of InitStatFile

data_row *GetStat(void) {

	if ( !stat_record ) 
		ReadStat();

	return stat_record;

} // End of GetStat

int CloseStat(void) {
int 	fd;
ssize_t	num;

	if ( statfile[0] == 0 || !dirty )
		return 1;

	fd = open(statfile, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH );
	if ( fd < 0 ) {
		fprintf(stderr, "Can't open stat file '%s': %s\n", statfile, strerror(errno));
		return 0;
	}

	num = write(fd, (void *)&stat_header, sizeof(stat_header));
	if ( num < 0 ) {
		fprintf(stderr, "Can't write stat record: %s\n", strerror(errno));
		close(fd);
		return 0;
	}

	num = write(fd, stat_record, NUMPORTS * sizeof(data_row));
	if ( num < 0 ) {
		fprintf(stderr, "Can't read stat record: %s\n", strerror(errno));
		return 0;
	}

	free(stat_record);
	stat_record = NULL;
	stat_header.version = 0;
	close(fd);
	
	return 1;

} // End of CloseStat

static void ReadStat(void) {
int 	fd;
ssize_t	num;

	if ( statfile[0] == 0 )
		return;

	stat_record = (data_row *)calloc(NUMPORTS, sizeof(data_row));
	if ( !stat_record ) {
		fprintf(stderr, "Can't allocate stat buffer:  %s\n", strerror(errno));
		return;
	}

	fd = open(statfile, O_RDONLY );
	if ( fd < 0 ) {
		fprintf(stderr, "Can't open stat file '%s': %s\n", statfile, strerror(errno));
		free(stat_record);
		stat_record = NULL;
		return;
	}

	num = read(fd, (void *)&stat_header, sizeof(stat_header));
	if ( num < 0 ) {
		fprintf(stderr, "Can't read stat record: %s\n", strerror(errno));
		free(stat_record);
		stat_record = NULL;
		close(fd);
		return;
	}

	if ( stat_header.version != 1 ) {
		fprintf(stderr, "Version error stat file. Found version: %d expected: 1\n", stat_header.version);
		free(stat_record);
		stat_record = NULL;
		stat_header.version = 0;
		close(fd);
		return;
	}

	num = read(fd, stat_record, NUMPORTS * sizeof(data_row));
	if ( num < 0 ) {
		fprintf(stderr, "Can't read stat record: %s\n", strerror(errno));
		free(stat_record);
		stat_record = NULL;
		stat_header.version = 0;
		close(fd);
	}
	
} // End of ReadStat

int UpdateStat(data_row *row, time_t when) {
data_row	*oldrow;
int pnum, p, t;
time_t	tslot;

	if ( !stat_record ) {
		ReadStat();
		if ( !stat_record )
			return 0;
	}

	// Add new slot
	for(pnum=0; pnum<NUMPORTS; pnum++ ) {
		for (p=0; p<2; p++) {
			for (t=0; t<3; t++) {
				stat_record[pnum].proto[p].type[t] += row[pnum].proto[p].type[t];
			}
		}
	}

	if ( (when - stat_header.last ) > 1800 ) {
		// last update too far away
		// pretend last update was max half an hour ago, otherwise it takes too long
		stat_header.last = when - 300;
	}
	// Subtract old slots
	for ( tslot = stat_header.last - (stat_header.av_num * 300); tslot < when - (stat_header.av_num * 300); tslot += 300 ) {
		oldrow = RRD_GetDataRow(dbpath, tslot);
		fprintf(stderr, "Remove stat line %s\n", ctime(&tslot));
		for(pnum=0; pnum<NUMPORTS; pnum++ ) {
			for (p=0; p<2; p++) {
				for (t=0; t<3; t++) {
					stat_record[pnum].proto[p].type[t] -= oldrow[pnum].proto[p].type[t];
				}
			}
		}
	}
	stat_header.last = when;
	dirty = 1;

	return 1;

} // End of UpdateStat

void Generate_TopN(data_row *row, int n, int scale, time_t when, int output_mode, char *wfile) {
int 		i, p, t, pnum;
FILE		*wfd;
topN_vector_t	*topN_vector;
static const char *proto[] = { "TCP", "UDP" };
static const char *type[]  = { "Flows", "Packets", "Bytes" };

	if ( wfile ) {
		wfd = strcmp(wfile, "-") == 0 ? stdout : 
                fopen(wfile, "w");
		if ( wfd == NULL ) {
			perror("Can't open output file for writing");
			return;
		}
	} else 
		wfd = stdout;

	topN_vector = (topN_vector_t *)malloc((NUMPORTS+1) * sizeof(struct topN_vector_s));
	if ( !topN_vector ) {
		perror("Memory error");
		exit(255);
	}

	// Add new slot
	if ( when == 0 ) 
		when = stat_header.last;
	if ( output_mode != 0 ) 
		fprintf(wfd, "%i\n", (int)when);
	for (p=0; p<2; p++) {
		for (t=0; t<3; t++) {
			for(pnum=0; pnum<NUMPORTS; pnum++ ) {
				topN_vector[pnum].port = pnum;
				topN_vector[pnum].count = row[pnum].proto[p].type[t] / scale;
			}
			heapSort(topN_vector, NUMPORTS, n);
			if ( output_mode == 0 ) {
				fprintf(wfd, "Top %i %s Proto %s\n", n, type[t], proto[p]);
				for (i = NUMPORTS-1; i > ( NUMPORTS-n-1 ); i--)
					fprintf(wfd, "%u %llu\n", topN_vector[i].port, (long long unsigned)topN_vector[i].count);
				fprintf(wfd, "\n");
			} else {
				fprintf(wfd, "%i %i %i\n", n, t, p);
				for (i = NUMPORTS-1; i > ( NUMPORTS-n-1 ); i--)
					fprintf(wfd, "%u ", topN_vector[i].port);
				fprintf(wfd, "\n");
				for (i = NUMPORTS-1; i > ( NUMPORTS-n-1 ); i--)
					fprintf(wfd, "%llu ", (long long unsigned)topN_vector[i].count);
				fprintf(wfd, "\n");
			}
		}
	}

	if ( wfile )
		fclose(wfd);

} // End of TopN

static void heapSort(topN_vector_t *vector, int array_size, int topN) {
topN_vector_t	temp;
int32_t i, top_count;

	for (i = (array_size / 2)-1; i >= 0; i--)
		siftDown(vector, i, array_size);

	top_count = 1;

	for (i = array_size-1; i >= 1; i--) {
		temp = vector[0];
		vector[0] = vector[i];
		vector[i] = temp;
		siftDown(vector, 0, i-1);
		if ( top_count == topN )
			return;
		top_count++;
	}

} // End of heapSort


static void siftDown(topN_vector_t *vector, int root, int bottom) {
uint32_t done, maxChild;
topN_vector_t	temp;

	done = 0;
	while ((root*2 <= bottom) && (!done)) {
		if (root*2 == bottom)
			maxChild = root * 2;
		else if (vector[root * 2].count > vector[root * 2 + 1].count)
			maxChild = root * 2;
		else
			maxChild = root * 2 + 1;

		if (vector[root].count < vector[maxChild].count ) {
			temp = vector[root];
			vector[root] = vector[maxChild];
			vector[maxChild] = temp;
			root = maxChild;
		} else
			done = 1;
	}
} // End of siftDown

int Lister(data_row *row) {
int pnum, p, t;

	if ( !row ) {
		fprintf(stderr, "Lister: Empty row!\n");
		return 0;
	}
	for(pnum=0; pnum<NUMPORTS; pnum++ ) {
		for (p=0; p<2; p++) {
			for (t=0; t<3; t++) {
				if ( row[pnum].proto[p].type[t] ) {
					fprintf(stderr, "%d %d %d: %llu\n", pnum, p, t, (long long unsigned)row[pnum].proto[p].type[t]);
				}
			}
		}
	}
	return 1;
} // List


