/****************************************************************************/
/*                                                                          */
/* License:                                                                 */
/*                                                                          */
/*   Copyright (c) 2012 The Department of Arts and Culture,                 */
/*   The Government of the Republic of South Africa.                        */
/*                                                                          */
/*   All rights reserved.                                                   */
/*                                                                          */
/*   Contributors:  CTexT, South Africa                                     */
/*                                                                          */
/*   Redistribution and use in source and binary forms, with or without     */
/*   modification, are permitted provided that the following conditions are */
/*   met:                                                                   */
/*                                                                          */
/*     * Redistributions of source code must retain the above copyright     */
/*       notice, this list of conditions and the following disclaimer.      */
/*                                                                          */
/*     * Redistributions in binary form must reproduce the above copyright  */
/*       notice, this list of conditions and the following disclaimer in    */
/*       the documentation and/or other materials provided with the         */
/*       distribution.                                                      */
/*                                                                          */
/*     * Neither the name of the Department of Arts and Culture nor the     */
/*       names  of its contributors may be used to endorse or promote       */
/*       products derived from this software without specific prior written */
/*       permission.                                                        */
/*                                                                          */
/*   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    */
/*   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      */
/*   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  */
/*   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/*   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  */
/*   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       */
/*   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  */
/*   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  */
/*   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    */
/*   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  */
/*   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   */
/*                                                                          */
/****************************************************************************/

#if defined(__WIN32__)
# define WINVER 0x501
# define WIN32_LEAN_AND_MEAN    /* Tell windows.h to skip much */
# include <windows.h>
//#include <tchar.h>
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <libg2p/libg2p.h>
#include "SVWChar.h"

// Allocate a char** that will be freed by the garbage collection.
char **
alloc_string_list(pTHX_ int items)
{
    SV *s;
    int len = 0;

    if (items <= 0)
        return NULL;

    // Null terminate just in case.
    len = sizeof(char *) * (items + 1);
    s = sv_2mortal(NEWSV(0, len));
    memset(SvPVX(s), 0, len);
    
    return (char **)SvPVX(s);
}

MODULE = G2P::Core        PACKAGE = G2P::Core        

PROTOTYPES: DISABLE

void
set_grapheme(g)
    char *g
  CODE:
    set_grapheme(g);


void
add_pattern(id, phoneme, context)
    int id
    char *phoneme
    wchar_t *context
  CODE:
    add_pattern(id, phoneme, context);


void
generate_rules()
  PREINIT:
    char **rules;
  PPCODE:
    rules = (char **)generate_rules();
    
    if (rules != NULL) {
        int i = 0;
        
        while (rules[i] != NULL) {
            //XPUSHs(wstr_to_sv(aTHX_ rules[i++]));
            XPUSHs(sv_2mortal(newSVpv(rules[i], 0))); i++;
        }
        
        // FIXME: Need to free it library side, as allocators differ
        //free_rules(rules);
    }


void
clear_patterns()
  CODE:
    clear_patterns();


void
set_rules(...)
  PREINIT:
    char **rules;
	int i;
  CODE:
    if (items > 0 ) {
        rules = alloc_string_list(aTHX_ items);
        if (rules == NULL) {
            warn("Failed to allocate character list");
            return;
        }
        
        for (i = 0; i < items; i++) {
            rules[i] = (char *)SvPV_nolen(ST(i));
        }
        
        set_rules(rules, items);
    }


char *
predict_pronunciation(word)
    wchar_t *word
  CODE:
    RETVAL = (char *)predict_pronunciation(word);

  OUTPUT:
    RETVAL
