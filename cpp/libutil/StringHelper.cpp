#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libutil/StringHelper.h>

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdlib>

bool find_parts(const string* wordp,string &left,string &g,string &right) {
  string::size_type mark = wordp->find('-');
  if (mark==wordp->npos) {
    cout << "Error: format error in find_parts" << endl;
    return false;
  }
  //if (mark==0) {
  //  left.clear();
  //} else {
    left = wordp->substr(0,mark);
  //}
  //cout << "HERE: " << left.size() << endl;
  g = wordp->substr(mark+1,1);
  mark = wordp->find('-',mark+1);
  if (mark==wordp->npos) {
    cout << "Error: format error in find_parts" << endl;
    return false;
  }
  //if (mark+1==string::npos) {
  //  right.clear();
  //} else {
    right = wordp->substr(mark+1);
  //}
  return true;
}

int get_sym(const string* patp) {
  string left,g,right;
  find_parts(patp,left,g,right);
  int symcnt = (int) (right.length()-left.length());
  return abs(symcnt);
}

int right_first(const string* patp) {
  string left,g,right;
  find_parts(patp,left,g,right);
  return (right.length()>left.length());
}

string itostr(int i)
{
  stringstream intstr;
  intstr << i;
  return intstr.str();
}

string ftostr(float f)
{
  stringstream s;
  s << f;
  return s.str();
}

string str_cast(int i)
{
  return itostr(i);
}

int split(string &pat, const char *delim, vector<string> &parts) {
  //cout << "Entering split" << endl;
  parts.clear();
  string::size_type from = 0;
  string::size_type mark = pat.find(*delim);
  while (mark!=pat.npos) {
    parts.push_back(pat.substr(from,mark-from));
    from = mark+1;
    mark = pat.find(*delim,from);
  }

  if (from!=pat.npos) {
    parts.push_back(pat.substr(from));
  }
  //for (string::size_type i=0;i<parts.size();i++) {
  //  cout << parts[i] << endl;
  //}
  //cout << "Exiting split" << endl;
  return parts.size();
}
//---------------------------------------------------------------------------
