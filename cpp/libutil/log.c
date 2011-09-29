#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <errno.h>

#include <libutil/log.h>

#define MAX_TIME_SIZE 40
#define MAX_CONTEXT_SIZE 80
#define MAX_MSG_SIZE 2560

#define LOG_PATH "g2p.log"

#ifdef _WIN32
	#define snprintf _snprintf
#endif

int g_is_first_call = 1;

int make_time_buf(char *buf)
{
    int n;
    const struct tm *tm;
    time_t now;

    now = time(NULL);
    tm = localtime(&now);
    n = strftime(buf, MAX_TIME_SIZE, "%m/%d/%Y %H:%M:%S", tm);
    if (n < 0 || n >= MAX_TIME_SIZE) {
        return EIO;
    }
    return 0;
}

int make_context_buf(char *buf, int level, const char *filename, int line)
{
    int n;
    const char *levelp;

    switch (level) {
        case DEBUG_LEVEL:
            levelp = "DEBUG";
            break;
        case INFO_LEVEL:
            levelp = "INFO";
            break;
        case NOTE_LEVEL:
            levelp = "NOTE";
            break;
        case WARN_LEVEL:
            levelp = "WARN";
            break;
        case ERROR_LEVEL:
            levelp = "ERROR";
            break;
        default:
            return EINVAL;
    }
	n = snprintf(buf, MAX_CONTEXT_SIZE, "[%s] (%s:%d)", levelp, filename, line);
	if (n < 0 || n >= MAX_CONTEXT_SIZE) {
		printf("ERROR: snprintf returned %d\n", n);
        return EIO;
    }
    return 0;
}

int log_print(int level, const char *filename, int line, char const *fmt, ...)
{
    int n, result;
    FILE *fh;
	va_list ap;
    char time[MAX_TIME_SIZE];
    char context[MAX_CONTEXT_SIZE];
    char msg[MAX_MSG_SIZE];

	if (g_is_first_call != 0) {
        g_is_first_call = 0;
        log_print(INFO_LEVEL, __FILE__, __LINE__, "Logger started");
    }
	result = make_time_buf(time);
    if (result != 0) {
        return EIO;
    }
	result = make_context_buf(context, level, filename, line);
    if (result != 0) {
        return EIO;
    }
	va_start(ap, fmt);
	n = vsnprintf(msg, MAX_MSG_SIZE, fmt, ap);
    if (n < 0 || n >= MAX_MSG_SIZE) {
		return EINVAL;
    }
	va_end(ap);
	printf("%s %s %s\n", time, context, msg);
    fh = fopen(LOG_PATH, "a+");
    if (fh <= 0) {
        return EIO;
    }
    fprintf(fh, "%s %s %s\n", time, context, msg);
    fclose(fh);
    return 0;
}
