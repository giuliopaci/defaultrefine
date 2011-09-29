#ifndef RNODE_H_
#define RNODE_H_

#include <vector>
#include <string>
#include <set>

#include <libg2p/GGroups.h>

using namespace std;

class RNode
{
public:
	string name;
	string outcome;
	int num;			//rule number according to extraction order
	bool groups;		//pattern contains groups if true
	set <RNode*> kids;

	RNode(string,string,int);
	virtual ~RNode();
	const string * get_outcome() const {return &outcome;};
	const string * get_name() const {return &name;};
	int get_num() const {return num;};
	bool node_subof_pat(const string &pat, GGroups *groupp) const;
};

#endif /*RNODE_H_*/
