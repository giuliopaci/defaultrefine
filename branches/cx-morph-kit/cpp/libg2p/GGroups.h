#ifndef GGROUPS_H_
#define GGROUPS_H_

#include <set>
#include <map>
#include <string>
#include <list>

#include <libg2p/GNode.h>

using namespace std;

class GGroups
{
	void remove_name(string);

public:
	int minimum_kids;
	int max_groups;
	map <char,set<char> > groups;		// groups: 		group_id => set of characters in group
	map <char,set<char> > members;		// members: 	char => set of group_ids relevant to char
	map <char,set<char> > superset;		// superset:	group_id => set of group_ids that are contained in key

	set <string> tmpnames;
	map <string, map <string, int> > tmpcnt;
	map <string, map <string, int> > tmpkids;
	map <string, set <GNode*> > tmpnodes;

	GGroups(int,int,char*);
	virtual ~GGroups();

	void create_group(string &line);
	void create_members();

	void insert_name(string);
	void insert_outcome(string,string);
	void create_possible_group_pats(const string* patp, list <string> &newgroups);
	void show_groups(string);
	int less_groups(const string *,const string *);
	int numgroups(string);
	bool maxgroups(string&);
	void add_valid_groups(int len, vector <set<GNode*>*> &order);
	bool has_member(char setid,char candidate);		//true if the set identified by <setid> has member <candidate>
	bool contains(char masterid,char childid);		//true if the <masterid> set contains <childid> set
};

#endif /*GGROUPS_H_*/
