/****************************************************************************/
/*                                                                          */
/* License:                                                                 */
/*                                                                          */
/*   Copyright (c) 2008, 2009, 2010 The Department of Arts and Culture,     */
/*   The Government of the Republic of South Africa.                        */
/*                                                                          */
/*   All rights reserved.                                                   */
/*                                                                          */
/*   Contributors:  CSIR, South Africa                                      */
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

#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <list>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#ifdef _WIN32
    #include <windows.h>
#endif

#include <libg2p/RTree.h>
#include <libutil/log.h>
#include <libg2p/g2popt.h>
#include <libutil/StringHelper.h>
#include <libg2p/g2p_pattern.h>

#ifndef _WIN32
    #define __declspec(...)
#endif

using namespace std;

char g_grapheme;
vector<Pattern> g_patterns;
RTree g_rtree;

#ifdef _WIN32
// DLL entry function (called on load, unload, ...)
BOOL APIENTRY DllMain(HANDLE hModule, DWORD dwReason, LPVOID lpReserved)
{
	return TRUE;
}
#endif

// Set the grapheme for prediction rule generation.
extern "C" __declspec(dllexport) void set_grapheme(char g)
{
    DEBUG_("Setting grapheme to '%c'", g);
	g_grapheme = g;
}

// Add pattern to list of patterns for prediction rule generation.
extern "C" __declspec(dllexport) void add_pattern(int id, char *phoneme, wchar_t *context)
{
    //DEBUG_("Adding pattern id=%d, phoneme='%s', context='%S'", id, 
    //       phoneme, context);
	string phoneme_str = string(phoneme);
	wstring context_str = wstring(context);
	g_patterns.push_back(Pattern(id, phoneme_str, context_str));
}

// Returns list of rules for given grapheme and patterns.
extern "C" __declspec(dllexport) char** generate_rules(void)
{
    DEBUG_("Generating rules");
	bool use_groups = 0;
	int min_kids = 1;
	int max_groups = 0;
	char *groups_file = "";  
	map<int, map<string, map <string,int> > > gpatts;
	list<string> patlist;
	int best=0;
	
	vector<Pattern>::iterator it;
	for ( it=g_patterns.begin(); it < g_patterns.end(); it++ ) {
		patlist.clear();        
        // TODO: Add wide character support to get_all_pats_limit.
        wstring w_context = it->get_context();
        string ascii_context(w_context.begin(), w_context.end());
        //DEBUG_("Calling get_all_pats_limit('%s')", ascii_context.c_str());
		get_all_pats_limit((const string*)&ascii_context,1,1000,patlist);
		list<string>::iterator i;
		for (i=patlist.begin();i!=patlist.end();i++) {
            //DEBUG_("Adding pattern: '%s'", i->c_str());
			int len = (int)i->length()-2;
			gpatts[len][*i][it->get_phoneme()]++;
			if (gpatts[len][*i][it->get_phoneme()]>best) {
				best=gpatts[len][*i][it->get_phoneme()];
			}
		}
	}

	GRule* grules = new GRule(use_groups, min_kids, max_groups, groups_file);  
    //DEBUG_("Calling rules_frompats_opt('%c')", g_grapheme);
	rules_frompats_opt(&g_grapheme, gpatts, best, grules);
	vector<string> rules_v = grules->get_rules();
	vector<string>::iterator rules_iter;
	char **rules = (char **)malloc(sizeof(char*) * (rules_v.size() + 1));
	int count = 0;
	for (rules_iter=rules_v.begin(); rules_iter < rules_v.end(); rules_iter++) {
		int rule_len = rules_iter->length();
		rules[count] = (char *)malloc(sizeof(char) * (rule_len + 1));
		strncpy(rules[count], rules_iter->c_str(), rule_len + 1);
		count ++;
	}
	rules[count] = NULL;
	return rules;
}

extern "C" __declspec(dllexport) void clear_patterns(void)
{
    DEBUG_("Clearing patterns");
	g_patterns.clear();
}

extern "C" __declspec(dllexport) void set_rules(char **rules, int count)
{
    DEBUG_("Setting rules");

    for (int i=0; i<count; i++) {
        //DEBUG_("Adding rule:'%s'", rules[i]);
        vector<string> parts;
        string rule_str = rules[i];
        int numparts = split(rule_str,";",parts);
        if (numparts != 6) {
            ERROR_("Invalid rule format.  Part count exceeds six: '%s'", rules[i]);
            exit(0);
        }
        int num = atoi(parts[4].c_str());
        if ((parts[1].compare("")==0)&&(parts[2].compare("")==0)) {
            g_rtree.init_root(parts[0],parts[3],num);
        } else {
            string newname = parts[1] + "-" + parts[0] + "-" + parts[2];
            g_rtree.add_rule(parts[0],newname,parts[3],num);
        }
    }
}

extern "C" __declspec(dllexport) wchar_t* predict_pronunciation(wchar_t *wc_wordp)
{
    int errno;
    string result_str = "";
    vector <string> result;
    vector <RNode*> rules;
    wchar_t *resultp;

    wstring w_word(wc_wordp);
    string word_str(w_word.begin(), w_word.end());

    word_str = " " + word_str + " ";
    errno = g_rtree.predict_word(word_str, result, rules);
    if (errno != 0) {
        return NULL;
    }
    vector <string>::iterator i;
    for (i=result.begin();i!=result.end();i++) {
        if ((*i).compare("0")!=0){
            result_str += *i;
        }
    }
    size_t len = result_str.length();
    resultp = (wchar_t*)malloc(sizeof(wchar_t) * (len + 1));
    mbstowcs( resultp, result_str.c_str(), result_str.size() + 1 );
    return resultp;
}
