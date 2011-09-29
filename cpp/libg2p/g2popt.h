#ifndef __G2POPT_H__
#define __G2POPT_H__

#include <string>

#include <libg2p/GRule.h>

using namespace std;

int get_all_pats_limit(const string * wordp,string::size_type from, string::size_type to, list<string> &patlist);
int fgen_rules_opt(char * g, char * pattsfile, bool use_groups, int min_kids, int max_groups, char * groupsfile, char * rulefile);
void rules_frompats_opt(char * g,map<int, map<string, map <string,int> > > &gpatts,int best, GRule* grules);
int predict(char * word, char * rulesfile, bool info, bool pnulls, bool spaces, bool gnulls, char * gnullsfile, bool usegroups, char * groupsfile);
int fpredict(char * listfile, char * rulesfile, char * outfile, bool info, bool pnulls, bool gnulls, char *gnullsfile, bool usegroups, char * groupsfile, string format );
void id_rules(char *wordsfile, char *rulesfile, char *reffile, bool usegroups, char *groupsfile, bool gnulls, char *gnullsfile, char *outfile);

#endif /* __G2POPT_H__ */
