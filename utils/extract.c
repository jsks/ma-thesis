// extract.c
//
// ./extract [-h] [-n <nlines>] -s <regex> <FILE>...
//
// Simple program that extracts parameters from a Stan posterior output file(s)
// and concatenates the result to stdout.
//
// example: ./extract -s '^alpha|^beta' -n 10 samples-chain_*.csv
//
// Fair warning: there's a lot of shortcuts in this program. Memory is not
// freed and file descriptors are not closed with the assumption that the OS
// will take of it when we exit. Plus, it's assumed that the posterior csv
// files are comma deliminated with no quotes around columns names.

#define _GNU_SOURCE

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <regex.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#define BUF_SIZE 1024 * 1024 * 8

typedef struct bitarray {
    size_t capacity;
    uint64_t *data;
} bitarray;

static char buf[BUF_SIZE];
static size_t bufsize = BUF_SIZE,
              offset = 0;

void usage(void) {
    printf("Usage: %s [-h] [-n nlines] -s <regex> <file>...\n",
            program_invocation_short_name);
}

void help(void) {
    usage();
    printf("\n");
    printf("Extracts given parameters from stan posterior csv file(s) based on regex expression.\n");
    printf("\n");
    printf("Options:\n");
    printf("\t-h Useless help message\n");
    printf("\t-n Maximum number of lines to read per file [Default: 1000]\n");
    printf("\t-s Target parameter regex\n");
}

bitarray *create_bitarray(size_t len) {
    bitarray *x;
    if (!(x = malloc(sizeof(bitarray))))
        err(EXIT_FAILURE, NULL);

    if (!(x->data = calloc(len, sizeof(uint64_t))))
        err(EXIT_FAILURE, NULL);

    x->capacity = len;
    return x;
}

void resize_bitarray(bitarray *x) {
    size_t old_size= x->capacity;
    x->capacity *= 2;

    if (!(x->data = reallocarray(x->data, x->capacity, sizeof(uint64_t))))
        err(EXIT_FAILURE, NULL);

    memset(x->data + old_size, 0, (x->capacity - old_size) * sizeof(uint64_t));
}

void set_bitarray(bitarray *x, uint64_t v) {
    uint64_t k = v / 64;
    if (k + 1 > x->capacity)
        resize_bitarray(x);

    x->data[k] |= UINT64_C(1) << (v % 64);
}

bool check_bitarray(bitarray *x, uint64_t v) {
    uint64_t k = v / 64;
    if (k + 1 > x->capacity)
        return false;

    return (x->data[k] & (UINT64_C(1) << (v % 64))) != 0;
}

bool is_empty_bitarray(bitarray *x) {
    for (size_t i = 0; i < x->capacity; i++) {
        if (x->data[i] != 0)
            return false;
    }

    return true;
}

void destroy_bitarray (bitarray **x) {
    free((*x)->data);
    free(*x);

    *x = NULL;
}

void write2(int fd, void *buf, size_t count) {
    ssize_t rv;
    for (size_t w_offset = 0; w_offset < count; w_offset += rv) {
        if ((rv = write(fd, buf + w_offset, count - w_offset)) < 1)
            err(EXIT_FAILURE, "stdout write");
    }
}

// To avoid the overhead of calling write for every field, buffer output into
// chunks using the global variable 'buf'.
void output(char *s, size_t len, bool add_comma) {
    // Sanity check
    if (len + add_comma > bufsize)
        errx(EXIT_FAILURE, "Token size too large for buffer");

    if (offset == bufsize) {
        write2(STDOUT_FILENO, buf, bufsize);
        offset = 0;
    }

    if (add_comma)
        buf[offset++] = ',';

    if (offset + len >  bufsize) {
        size_t partial_len = bufsize - offset;

        // Fill up the buffer as much as possible and drain
        memcpy(&buf[offset], s, partial_len);
        write2(STDOUT_FILENO, buf, bufsize);

        // Copy remaining bytes from field
        offset = len - partial_len;
        memcpy(buf, &s[partial_len], offset);
    } else {
        memcpy(&buf[offset], s, len);
        offset += len;
    }
}

void flush(void) {
    if (offset > 0)
        write2(STDOUT_FILENO, buf, offset);
}

ssize_t next_line(char **line, size_t *n, FILE *fp) {
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
        err(EXIT_FAILURE, NULL);

    return nr;
}

int main(int argc, char *argv[]) {
    regex_t re;
    bool compiled = false;
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
                    err(EXIT_FAILURE, NULL);
                break;
            case 's':
                if ((ret = regcomp(&re, optarg, REG_EXTENDED)) != 0)
                    errx(EXIT_FAILURE, "Unable to compile regex argument");
                compiled = true;
                break;
            default:
                usage();
                exit(EXIT_FAILURE);
        }
    }

    if (!argv[optind]) {
        usage();
        errx(EXIT_FAILURE, "Missing file argument");
    }

    if (!compiled) {
        usage();
        errx(EXIT_FAILURE, "Missing parameter argument");
    }

    int num_files = argc - optind;
    FILE *files[num_files];
    for (int i = optind; i < argc; i++) {
        if (!(files[i - optind] = fopen(argv[i], "r")))
            err(EXIT_FAILURE, "%s", argv[i]);

        if ((posix_fadvise(fileno(files[i - optind]), 0, 0, POSIX_FADV_SEQUENTIAL)) != 0)
            err(EXIT_FAILURE, "posix_fadvise");
    }

    bitarray *columns = create_bitarray(10);    // Array tracking matching columns
    char *line = NULL,                          // next_line/getline line buffer
         *delim = NULL,                         // Pointer to first delim, ','
         *p,                                    // Token iterator (points to next char after delim)
         *token;                                // Header token from strsep
    size_t n = 0,                               // Size of next_line/getline buffer
           len;                                 // Token length for each parsed field
    ssize_t nr;                                 // Number of bytes read by getline/next_line
    bool first = true;                          // Handle output of commas
    regmatch_t pmatch;                          // Regex match struct

    // Find matching columns based on the header for the first file
    nr = next_line(&line, &n, files[0]);

    // Don't lose track of pointer to start of 'line' since we re-use the
    // buffer for every next_line call, so use p to iterate past each token
    p = line;

    for (unsigned int i = 0;; i++) {
        if (!(token = strsep(&p, ",")))
            break;

        if ((ret = regexec(&re, token, 1, &pmatch, 0)) == 0) {
            output(token, strlen(token), !first);
            first = false;
            set_bitarray(columns, i);
        }
    }

    // If we haven't found any column names matching our regexes,
    // simply quit without writing to stdout
    if (is_empty_bitarray(columns))
        goto cleanup;

    output("\n", 1, false);

    // Filter remaining rows for each input file based on matched columns
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

    goto cleanup;

cleanup:
#ifdef DEBUG
    destroy_bitarray(&columns);
    regfree(&re);
    free(line);

    for (int i = 0; i < num_files; i++)
        fclose(files[i]);
#endif

    flush();
}
