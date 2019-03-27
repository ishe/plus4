#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "wingetopt.h"

void usage(void)
{
	printf("\nAppend a binary ROM to a rompack file for FPGATED use");
	printf("\n\nUsage: addrom -t romtype -p romposition -v romversion outputfile inputfile ");
	printf("\n\n-t\tROM type. Valid values are");
	printf("\n\tInt\tInternal ROM location (Kernal or Basic)");
	printf("\n\tFunc\tFunction ROM location");
	printf("\n\tC1\tCartridge1 ROM location");
	printf("\n\tC2\tCartridge2 ROM location");
	printf("\n\n-p\tROM position. Valid values are Low or High based on ROM position");
	printf("\n\n-v\tAlternative ROM version. Valid values are from 0-15.");
	printf("\n\tIt is used for storing different ROM versions of the same ROM type.");
	printf("\n\tDefault value is 0 which is the ROM accessed at device power on.\n");
	printf("\nVersion 1.0\n\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	char romtype=0;
	char optflag = 0;
	short romsize=0;
	int c;
	int i;
	FILE *outfile, *infile;

	opterr = 0;

	// identifying options
	
	while ((c = getopt(argc, argv, "t:p:v:")) != -1)
	{
		switch (c) {
		case 't':
			if (!strcmp(optarg, "int") || !strcmp(optarg, "Int"))
				romtype = romtype & 0xFC;
			else if (!strcmp(optarg, "func") || !strcmp(optarg, "Func"))
				romtype = (romtype & 0xFC) | 0x01;
			else if (!strcmp(optarg, "c1") || !strcmp(optarg, "C1"))
				romtype = (romtype & 0xFC) | 0x02;
			else if (!strcmp(optarg, "c2") || !strcmp(optarg, "C2"))
				romtype = (romtype & 0xFC) | 0x03;
			else usage();
			optflag = optflag|0x01;
			break;
		case 'p':
			if (!strcmp(optarg, "low") || !strcmp(optarg, "Low"))
				romtype = romtype & 0xBF;
			else if (!strcmp(optarg, "high") || !strcmp(optarg, "High"))
				romtype = (romtype & 0xBF) | 0x40;
			else usage();
			optflag = optflag | 0x02;
			break;
		case 'v':
			if (atoi(optarg) < 16)
				romtype = (romtype & 0xC3) | (atoi(optarg) << 2);
			else usage();
			optflag = optflag | 0x04;
			break;
		}
	}

	if (!(optflag & 0x01))
	{
		printf("ROM type parameter is missing!\n");
		usage();
	}
	else if (!(optflag & 0x02))
	{
		printf("ROM position parameter is missing!\n");
		usage();
	}
	else if (!(optflag & 0x04))
	{
		printf("ROM image version parameter is missing!\n");
		usage();
	}

	// checking filename parameters

	if (argv[optind] == NULL || argv[optind + 1] == NULL) {
		printf("Input or Output file name is missing!\n");
		exit(-1);
	}

	// opening files for read and write

	if ((infile = fopen(argv[optind + 1], "rb")) == NULL)
	{
		printf("Error: %s", strerror(errno));
		exit(-1);
	}
	else if ((outfile = fopen(argv[optind], "r+b")) == NULL)
	{
		if ((outfile = fopen(argv[optind], "ab")) == NULL)
		{
			printf("Error: %s", strerror(errno));
			fclose(infile);
			exit(-1);
		}
	}
	else 	fseek(outfile, -1L, SEEK_END);	// if output file already contains a rom image, seek back one byte to remove the rom stream closing byte
	
	// get input file size
	fseek(infile, 0L, SEEK_END);
	if ((romsize = ftell(infile)-1) > 16383)
	{
		printf("Error: ROM size must not be larger than 16Kbyte;");
		fclose(infile);
		fclose(outfile);
		exit(-1);
	}

	fseek(infile, 0L, SEEK_SET);

// writing new ROM's header to rompack file

	fputc(romtype, outfile);									// write 1 byte romtype
	fwrite(&romsize, sizeof(romsize), 1, outfile);				// write 2 bytes romsize

	while ((c = fgetc(infile)) != EOF)
	{
		fputc(c, outfile);
	}

	fputc(0x80, outfile);
	printf("\nNew ROM image is added to file %s.\n%d bytes have been written.", argv[optind], romsize);
	printf("\nRomtype byte is:%X", romtype);
	fclose(infile);
	fclose(outfile);
	return 0;
}
