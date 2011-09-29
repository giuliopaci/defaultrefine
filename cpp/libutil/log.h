#ifndef LOG_H_
#define LOG_H_

#ifdef __cplusplus
extern "C" {
#endif

#define DEBUG_LEVEL 1
#define INFO_LEVEL 2
#define NOTE_LEVEL 3
#define WARN_LEVEL 4
#define ERROR_LEVEL 5

int log_print(int level, const char *filename, int line, char const *fmt, ...);

#define DEBUG_(...) log_print(DEBUG_LEVEL, __FILE__, __LINE__, __VA_ARGS__)
#define INFO_(...) log_print(INFO_LEVEL, __FILE__, __LINE__, __VA_ARGS__)
#define NOTE_(...) log_print(NOTE_LEVEL, __FILE__, __LINE__, __VA_ARGS__)
#define WARN_(...) log_print(WARN_LEVEL, __FILE__, __LINE__, __VA_ARGS__)
#define ERROR_(...) log_print(ERROR_LEVEL, __FILE__, __LINE__, __VA_ARGS__)

#ifdef __cplusplus
}
#endif

#endif // LOG_H_
