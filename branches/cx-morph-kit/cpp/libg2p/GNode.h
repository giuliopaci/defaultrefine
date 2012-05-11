#ifndef GNODE_H_
#define GNODE_H_


#include <iostream>
#include <list>
#include <map>
#include <string>
#include <vector>
#include <set>

using namespace std;

class GNode
{
	int max;
	bool active;	//All nodes start as active. Marked as inactive once node used to generate a rule.
	bool done;		//Only applicable to word nodes. Indicates whether correctly predicted by current rule set or not.
					//Status changes as rules are added.
	bool flag;		//All nodes typically unflagged. Used to flag completed nodes during "update_info_for_tree".
					//Cleared afterwards.
	bool grouprule;	//True if this is a grouped rule, false otherwise

public:
	string name;
	int length;
	string outcome;
	vector <GNode*> parents;
	vector <GNode*> kids;
	set <GNode*> grouplinks;

	GNode(const string,bool);
	virtual ~GNode();

	const string* get_name()const {return &name;}
	int get_max() const {return max;}
	const string* get_outcome() const {return &outcome;}
	bool get_done() const {return done;}
	bool get_flag() const {return flag;}
	bool get_active() const {return active;}
	int get_length() const {return length;}
	bool has_kids() const {return (!kids.empty());}
	bool node_subof_pat(const string* patp) const {return (patp->find(name)!=patp->npos);}
	bool pat_subof_node(const string* patp)const  {return (name.find(*patp)!=name.npos);}
	bool is_group() const {return grouprule;};

	void set_max(int num) {max=num;}
	void set_outcome(string p) {outcome=p;}
	void set_done() {done=1;}
	void clear_done() {done=0;}
	void set_flag() {flag=1;}
	void clear_flag() {flag=0;}
	void set_active() {active=1;}
	void clear_active() {active=0;}
	void set_length(int len) {length=len;}

	string countstr() const;

	void add_parent(GNode*);
	void add_kid(GNode*);
	int inc_all(int num) {max=max+num; return max;}
	int update_max();
	void add_grouplinks(set <GNode*> &);
};


#endif /*GNODE_H_*/

//---------------------------------------------------------------------------
