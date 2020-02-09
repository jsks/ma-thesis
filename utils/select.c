// select.c
//
// ./select [-h] [-n <nlines>] -s <parameter>... <FILE>...
//
// Simple program that extracts specified parameters from a Stan posterior
// output file(s) and prints the result to stdout. 
//
// example: ./select -s '^alpha|^beta' -n 10 samples-chain_*.csv
//
// Fair warning: there's a lot of shortcuts in this program. Memory is not
// freed and file descriptors are not closed with the assumption that the OS
// will take of it when we exit. 

#define _GNU_SOURCE

#include <errno.h>
#include <regex.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#define BUF_SIZE 1024 * 1024
#define die(msg)                       \
    do {                               \
        fprintf(stderr, "%s\n", msg);  \
        exit(EXIT_FAILURE);            \
    } while (0);

typedef struct bitarray {
    size_t capacity;
    uint64_t *data;
} bitarray;

static char buf[BUF_SIZE];
static size_t bufsize = BUF_SIZE;
static int offset = 0;

void usage(void) {
    printf("Usage: %s [-h] [-n nlines] -s <parameter>... <file>...\n",
            program_invocation_short_name);
}

void help(void) {
    usage();
    printf("\n");
    printf("Extracts given parameters from stan posterior csv file(s) based on strict matching.\n");
    printf("\n");
    printf("Options:\n");
    printf("\t-h Useless help message\n");
    printf("\t-n Optional number of lines to read per file [Default: 1000]\n");
    printf("\t-s Target parameters. Can be specified multiple times.\n");
}

bitarray *create_bitarray(size_t len) {
    bitarray *x;
    if (!(x = malloc(sizeof(bitarray))))
        die(strerror(errno));

    if (!(x->data = calloc(len, sizeof(uint64_t))))
        die(strerror(errno));

    x->capacity = len;
    return x;
}

void resize_bitarray(bitarray *x) {
    size_t old_size = x->capacity * sizeof(uint64_t);
    x->capacity *= 2;

    x->data = reallocarray(x->data, x->capacity, sizeof(uint64_t));
    if (!x->data)
        die(strerror(errno));

    memset(x->data, 0, (x->capacity * sizeof(uint64_t)) - old_size);
}

void set_bitarray(bitarray *x, uint64_t v) {
    uint64_t k = v / 64;
    if (k > x->capacity)
        resize_bitarray(x);

    x->data[k] |= UINT64_C(1) << (v % 64);
}

bool check_bitarray(bitarray *x, uint64_t v) {
    uint64_t k = v / 64;
    if (k > x->capacity)
        return false;

    return (x->data[k] & (UINT64_C(1) << (v % 64))) != 0;
}

void destroy_bitarray (bitarray **x) {
    free((*x)->data);
    free(*x);

    *x = NULL;
}

// To avoid the overhead of calling fwrite for every field, buffer output into
// 1MB chunks using the global variable 'buf'. Since we're already buffering
// here, turn off stdio buffering for stdout.
void output(char *s, size_t len, bool add_comma) {
    size_t total_len = len + add_comma;

    // Sanity check
    if (total_len > bufsize)
        die("Token size too large for buffer");

    if (offset + total_len > bufsize) {
        fwrite(buf, 1, offset, stdout);
        offset = 0;
    }

    char *p = &buf[offset];
    size_t i;

    if (add_comma)
        p[0] = ',';

    for (i = 0; i < total_len; i++)
        p[(add_comma) ? i + 1 : i] = s[i];

    offset += i;
}

void flush(void) {
    fwrite(buf, 1, offset, stdout);
}

size_t next_line(char **line, size_t *n, FILE *fp) {
    ssize_t nr;
    while ((nr = getline(line, n, fp)) > 0) {
        // Stan output files have a bunch of info/diagnostic lines beginning
        // with '#'.
        if ((*line)[0] == '#')
            continue;

        // Remove trailing newline
        (*line)[nr - 1] = '\0';
        break;
    }

    if (nr == -1 && !feof(fp))
        die(strerror(errno));

    return nr;
}

int main(int argc, char *argv[]) {
    setvbuf(stdout, NULL, _IONBF, 0);

    regex_t re;
    int max_lines = 1000, opt, ret;
    while ((opt = getopt(argc, argv, "hn:s:")) != -1) {
        switch (opt) {
            case 'h':
                help();
                exit(EXIT_SUCCESS);
            case 'n':
                errno = 0;
                max_lines = (int) strtol(optarg, NULL, 10);
                if (errno == ERANGE)
                    die(strerror(errno));
                break;
            case 's': 
                if ((ret = regcomp(&re, optarg, REG_EXTENDED)) != 0)
                    die("Unable to compile parameter regex.");
                break;
            default:
                usage();
                exit(EXIT_FAILURE);
        }
    }

    if (!argv[optind]) {
        usage();
        die("Missing file argument(s)");
    }

    int num_files = argc - optind;
    FILE *files[num_files];
    for (int i = optind; i < argc; i++) {
        if (!(files[i - optind] = fopen(argv[i], "r")))
            die(strerror(errno));
    }

    bitarray *columns = create_bitarray(2048);  // Array tracking matching columns
    char *line = NULL,                          // next_line/getline line buffer
         *delim = NULL,                         // Pointer to first delim, ','
         *p;                                    // Token iterator (points to next char after delim)
    size_t n = 0,                               // Size of next_line/getline buffer
           len;                                 // Token length for each parsed field
    ssize_t nr;                                 // Number of bytes read by getline/next_line
    bool first = true;                          // Handle output of commas
    regmatch_t pmatch;                          // Regex match struct

    // Find matching columns
    while ((nr = next_line(&line, &n, files[0])) > 0) { 
        // Don't lose track of pointer to start of line since we re-use the
        // buffer for every next_line call, so use p to iterate past each token
        p = line;

        // Search for tokens using strchrnul. Unlike strsep, we don't replace
        // each occurence of ',' with '\0', so instead keep track of the length
        // of a token with len.
        for (int i = 0;; i++) { 
            delim = strchrnul(p, ','); 
            len = delim - p;

            // Match regex pattern based on length rather than '\0'
            pmatch.rm_so = 0;
            pmatch.rm_eo = len;

            if ((ret  = regexec(&re, p, 1, &pmatch, REG_STARTEND)) == 0) {
                output(p, len, !first);
                first = false;
                set_bitarray(columns, i);
            }

            // strchrnul returns pointer to end of line ('\0') if ',' not found
            if (*delim == '\0')
                break;
            else
                p = delim + 1;
        }

        output("\n", 1, false);
        break;
    }


    // Filter remaining rows based on matched columns for each input file
    for (int i = 0; i < num_files; i++) {
        // Remove header for remaining files
        if (i > 0) {
            if ((nr = next_line(&line, &n, files[i])) <= 0)
                break;
        }

        // Read only n lines per file as set by max_lines
        int nlines = 0;
        while ((nr = next_line(&line, &n, files[i])) > 0 && nlines++ < max_lines) {
            p = line;
            first = true;

            for (int i = 0;; i++) {
                delim = strchrnul(p, ',');

                if (check_bitarray(columns, i)) {
                    len = delim - p;
                    output(p, len, !first);
                    first = false;
                }

                if (*delim == '\0')
                    break;
                else
                    p = delim + 1;
            }

            output("\n", 1, false);
        }
    }

#ifdef DEBUG
    regfree(&re);
    destroy_bitarray(&columns);
    free(line);

    for (int i = 0; i < num_files; i++)
        fclose(files[i]);
#endif

    flush();
}
