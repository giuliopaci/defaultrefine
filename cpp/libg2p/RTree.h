#ifndef RTREE_H_
#define RTREE_H_

#include <libg2p/RNode.h>
#include <string>
#include <map>
#include <queue>
#include <vector>
#include <libg2p/GGroups.h>

class RTree
{
  map <string,RNode*> roots;
  bool use_groups;
  GGroups *groupp;
  
  int find_parents(string root, string name, queue <RNode*> &parents);
  int traverse_root(string rootname);
  string predict_pat_first(string pat, string rootname, RNode **rule, int *error);
  string predict_pat_last(string pat, string rootname, RNode **rule, int *error);

public:
  RTree();
  virtual ~RTree();

  RNode * get_root(string rname);
  void read_rules(char * rulefile);
  void add_rule(string root, string name, string outcome, int num);
  void init_root(string root, string outcome, int num);
  void traverse();
  int predict_word(string &word, vector <string> &result, vector<RNode*> &rules);
  void set_groups(GGroups * groupp);
};

#endif /*RTREE_H_*/
