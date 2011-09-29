#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libg2p/RTree.h>

#include <iostream>
#include <fstream>
#include <queue>
#include <set>
#include <cstdlib>
#include <errno.h>

#include <libutil/StringHelper.h>

RTree::RTree() {
  use_groups=false;
}

RTree::~RTree()
{
}

//---------------------------------------------------------------------------

void RTree::set_groups(GGroups * gp) {
  use_groups = true;
  groupp = gp;
}

//---------------------------------------------------------------------------
// Read rules from file into tree: read_rules
// Subfunctions init_root, add_rule, find_parents
//---------------------------------------------------------------------------

void RTree::read_rules(char * rulefile) {
	//Read rules from file into tree
  ifstream infile(rulefile);
  string line;
  vector<string> parts;
  if (infile.is_open()) {
    getline(infile,line);
    while (!infile.eof()) {
      //cout << "Reading " << line << endl;
      int numparts = split(line,";",parts);
      if (numparts != 6) {
        cout << "Error: wrong format of rule file " << *rulefile << endl;
        exit(0);
      }
      int num = atoi(parts[4].c_str());
      if ((parts[1].compare("")==0)&&(parts[2].compare("")==0)) {
        init_root(parts[0],parts[3],num);
        //cout << "rtree::init_root:" << parts[0] << ',' << parts[3] << ',' << num << endl;
      } else {
        string newname = parts[1] + "-" + parts[0] + "-" + parts[2];
        add_rule(parts[0],newname,parts[3],num);
        //cout << "rtree::add_rule:" << parts[0] << ',' << newname << ',' << parts[3] << ',' << num << endl;
      }
      getline(infile,line);
      //traverse();
    }
  } else {
    cout << "Error reading file: "<< *rulefile << endl;
    exit(0);
  }
}

void RTree::init_root(string rootname, string outcome, int num) {
	//Create a new root node for the rule tree for grapheme <rootname>
	//and add a default rule producing <outcome>
	//This should be the first rule (rule no 0)
  string newname = "-" + rootname + "-";
  if (num!=0) {
    cout << "Error: check why root is not first rule, but rule number " << str_cast(num) << endl;
  }
  RNode *newnode = new RNode(newname,outcome,num);
  roots.insert(make_pair(rootname,newnode));
}

void RTree::add_rule(string root, string name, string outcome, int num) {
  //Add a new rule (<name> produces <outcome>, rule number <num>) 
  //to the grapheme tree with root <root>
  
  #ifdef _DEBUG
  cout << "Adding " << name << " to tree " << root << endl;
  #endif
  
  RNode *newnode = new RNode(name,outcome,num);
  queue <RNode*> parents;
  int numfound = find_parents(root,name,parents);
  if (numfound>0) {
    while (!parents.empty()) {
      RNode * parent = parents.front();
      parents.pop();
      parent->kids.insert(newnode);
    }
  } else {
    cout << "Error: no parents found. Rule file probably corrupt." << endl;
    exit(0);
  }
}

int RTree::find_parents(string rootname, string name, queue <RNode*> &parents) {
  #ifdef _DEBUG
  cout << "Entering find_parents: " << name << endl;
  #endif
  
  queue <RNode*> nextlist;
  nextlist.push(roots[rootname]);
  while (!nextlist.empty()) {
    RNode * next = nextlist.front();
    nextlist.pop();
    if (next->kids.empty()) {
      parents.push(next);
    } else {
      set<RNode*>::iterator i;
      bool follow_kids=false;
      for (i=next->kids.begin();i!=next->kids.end();i++) {
        if ((*i)->node_subof_pat(name,groupp)) {
          //cout << "Following " << *((*i)->get_name()) << endl;
          nextlist.push(*i);
          follow_kids=true;
        }
      }
      if (!follow_kids) {
        parents.push(next);
      }
    }
  }
  return parents.size();
}

//---------------------------------------------------------------------------
// Traverse tree, printing out nodes: traverse
// Subfunctions: get_root, traverse_root
//---------------------------------------------------------------------------

void RTree::traverse() {
  map <string,RNode*>::iterator i;
  for (i=roots.begin();i!=roots.end();i++) {
    traverse_root(i->first);
  }
}

RNode * RTree::get_root(string rname) {

  map<string,RNode*>::iterator i = roots.find(rname);
  if (i==roots.end()) {
    cout << "Warning: root not found:" << rname << endl;
    return NULL;
  }
  return i->second;
}

int RTree::traverse_root(string rootname) {
  cout << "Entering traverse_root" << endl;
  set <RNode*> done;
  queue <RNode*> nodes;
  RNode *node = get_root(rootname);
  if (node == NULL) {
    return EFAULT;
  }
  nodes.push(node);
  while (!nodes.empty()) {
    RNode *n = nodes.front();
    nodes.pop();
    if (done.find(n)!=done.end()) {continue;}
    cout << *(n->get_name()) << "(" << *(n->get_outcome()) << "): ";
    set <RNode*>::const_iterator i;
    for (i=n->kids.begin();i!=n->kids.end();i++) {
      nodes.push(*i);
      cout << *((*i)->get_name()) << " ";
    }
    cout << endl;
    done.insert(n);
  }
  return 0;
}

//---------------------------------------------------------------------------
// Predict one word based on rule tree
// Subfunctions: predict_pat_first or predict_pat_last,
//               depending on how tree was built (both not used)
//---------------------------------------------------------------------------

int RTree::predict_word(string &word, vector <string> &result, vector<RNode*> &rules) {
  //Assumes boundary indicators added
  int error;
  string::size_type i;
  string left;
  string g;
  string right;
  string pat;
  string out;
  RNode *winner=NULL;
  result.clear();
  rules.clear();
  //for each letter in the word being predicted
  //find the winning rule and outcome
  for (i=1;i<word.length()-1;i++) {
    //cout << word.at(i) << endl;
    left = word.substr(0,i);
    g = word.substr(i,1);
    right = word.substr(i+1);
    pat = left + "-" + g + "-" + right;
    out = predict_pat_last(pat,g,&winner,&error);
    if (error != 0) {
        return error;
    }
    //out = predict_pat_first(pat,g,info);
    result.push_back(out);
    rules.push_back(winner);
  }
  return 0;
}

string RTree::predict_pat_first(string pat, string rootname, RNode **rule, int *error) {
  //cout << "Entering predict_pat_first: " << pat << endl;
  *error = 0;
  RNode * next = get_root(rootname);
  if (next == NULL) {
        *error = EFAULT;
        return "";
  }
  bool lead=false;
  bool busy=true;
  while (busy) {
    if (pat.compare(*(next->get_name()))==0) {
      return *next->get_outcome();
    }
    set <RNode*>::const_iterator i;
    lead=false;
    for (i=next->kids.begin();i!=next->kids.end();i++) {
      if ((*i)->node_subof_pat(pat,groupp)) {
        next = *i;
        lead = true;
        break;
      }
    }
    if (!lead) {
      busy=false;
    }
  }
  *rule=next;
  return *next->get_outcome();
}

string RTree::predict_pat_last(string pat, string rootname, RNode **rule, int *error) {
  //cout << "Entering predict_pat: " << pat << endl;
  //Better to search a few nodes twice than to keep track of all visited
  *error = 0;
  queue <RNode*> nodes;
  RNode *node;
  node = get_root(rootname);
  if (node == NULL) {
    *error = EFAULT;
    return "";
  }
  nodes.push(node);
  RNode *next;
  RNode *last=nodes.front();
  while (!nodes.empty()) {
    next = nodes.front();
    if (last->get_num()<next->get_num()) {
      last = next;
    }
    nodes.pop();
    set <RNode*>::const_iterator i;
    for (i=next->kids.begin();i!=next->kids.end();i++) {
      if ((*i)->node_subof_pat(pat,groupp)) {
        nodes.push(*i);
      }
    }
  }
  *rule = last;
  return *last->get_outcome();
}

//---------------------------------------------------------------------------
