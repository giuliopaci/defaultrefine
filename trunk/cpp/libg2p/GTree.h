#ifndef GTREE_H_
#define GTREE_H_

#include <string>
#include <list>
#include <set>
#include <queue>
#include <libg2p/GNode.h>
#include <libg2p/GGroups.h>

using namespace std;

class GTree
{
	GNode* root;
	int best;
	bool use_groups;
	GGroups *groupp;

	int get_best() const {return best;}
	GNode* find_node(const string*) const;

	int add_pattern_info(const string *, list<string> &, map<string,int> &);

	void remove_linked_rule(GNode*,const string*);
	void update_info_for_tree(GNode*, list<GNode*>&, list<GNode*>&);
	void update_order(GNode*,int,int);
	void delete_order(GNode*);
	void clear_flags();
	int  update_best();
	void get_pats_of_size(const string *name, const string *pat, int length, set<GNode*> &patlist);

public:
	vector <set<GNode*>*> order;
	GTree(string,int);
	void set_use_groups(GGroups *);
	virtual ~GTree();

	GNode* get_root() const {return root;};
	void get_leaves(GNode*,queue<GNode*>&) const;
	GNode* get_winning_rule() const;
	void traverse() const;

	void build_tree(map<int, map<string, map <string,int> > > &gpatts);
	void remove_rule(GNode*);
	bool get_equiv(GNode *winner,set<GNode*> &equivlist);
};


#endif /*GTREE_H_*/

//---------------------------------------------------------------------------
