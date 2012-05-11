#ifndef STRINGHELPER_H_
#define STRINGHELPER_H_


#include <string>
#include <vector>

using namespace std;

bool find_parts(const string* wordp,string &left,string &g,string &right);
int get_sym(const string* pat);
int right_first(const string* pat);
string str_cast(int);
string ftostr(float f);
string itostr(int i);
int split(string &pat, const char *delim, vector<string> &parts);

#endif /*STRINGHELPER_H_*/

//---------------------------------------------------------------------------
