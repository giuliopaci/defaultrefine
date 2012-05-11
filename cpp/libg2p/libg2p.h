#ifndef __LIBG2P_H__
#define __LIBG2P_H__

#include <libg2p/g2pexports.h>

#ifdef __cplusplus
extern "C" {
#endif

// Set the grapheme for prediction rule generation.
LIBG2P_EXTERN void set_grapheme(char *g);
// Add pattern to list of patterns for prediction rule generation.
LIBG2P_EXTERN void add_pattern(int id, char *phoneme, wchar_t *context);
// Returns list of rules for given grapheme and patterns.
LIBG2P_EXTERN char** generate_rules(void);
LIBG2P_EXTERN void clear_patterns(void);
LIBG2P_EXTERN void set_rules(char **rules, int count);
LIBG2P_EXTERN char* predict_pronunciation(wchar_t *wc_wordp);

#ifdef __cplusplus
}
#endif

#endif /* __LIBG2P_H__ */
