#ifndef GRULE_H_
#define GRULE_H_

#include <string>
#include <list>
#include <set>
#include <vector>
#include <libg2p/GNode.h>
#include <libg2p/GGroups.h>

using namespace std;

class GRule
{
	bool use_groups;
	struct rule {
		const string* patp;
		const string* phonep;
		int num;
	};
	list<rule> rules;

public:
	GGroups *groupp;

	GRule(bool,int,int,char*);
	virtual ~GRule();

	bool get_use_groups() const {return use_groups;};
	void add(const string*,const string*,int);
	bool has_default(GNode*) const;

	void add_default(char*,GNode*);
	void add_empty(char*,GNode*);
	vector<string>	get_rules(void);
	void fwrite(char*) const;
};

#endif /*GRULE_H_*/

//---------------------------------------------------------------------------
