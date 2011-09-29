#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libg2p/GRule.h>

#include <iostream>
#include <fstream>
#include <sstream>

#include <libutil/StringHelper.h>


GRule::GRule(bool use, int mink, int maxg, char *groupsfile)
{
	use_groups=use;
	rules.clear();
	if (use_groups) {
		groupp = new GGroups(mink,maxg,groupsfile);
	} else {
		groupp = NULL;
	}
}

GRule::~GRule() {
}

void GRule::fwrite(char* filename) const {
	ofstream fout(filename);
	if (fout.is_open()) {
		list <rule>::const_iterator i;
		int cnt=0;
		for (i=rules.begin();i!=rules.end();i++) {
			string left,g,right;
			const string* wordp = i->patp;
			find_parts(wordp,left,g,right);
			fout << g << ";" << left << ";" << right << ";" << *(i->phonep) << ";" << cnt << ";" << i->num << endl;
			cnt++;
			//fout << *(i->patp) << ";" << *(i->phonep) << ";" << i->num << endl;
		}
	}
	fout.close();
}

vector<string> GRule::get_rules(void)
{
	vector<string> rule_strings;
	list <rule>::const_iterator i;
	int cnt=0;    
	for (i=rules.begin();i!=rules.end();i++) {
		stringstream ss;
		string left,g,right;
		const string* wordp = i->patp;
		find_parts(wordp,left,g,right);      
		ss << g << ";" << left << ";" << right << ";" << *(i->phonep) << ";" 
		   << cnt << ";" << i->num;
		string new_rule = ss.str();
		rule_strings.push_back(new_rule);
		cnt++;      
	}
	return rule_strings;
}

bool GRule::has_default(char *g,GNode* root) const {
		return (rules.front().patp->compare(*(root->get_name()))==0);
}

void GRule::add(const string *pat,const string *phone, int num) {
	rule tmprule;
	tmprule.patp = pat;
	tmprule.phonep = phone;
	tmprule.num = num;
	rules.push_back(tmprule);
}

void GRule::add_default(char* g,GNode *root) {
	rule defrule;
	defrule.patp = root->get_name();
	defrule.phonep = (rules.front()).phonep;
	defrule.num = 0;
	rules.push_front(defrule);
    cout << "g:\t[0]\t[-" << g << "-] --> " << *(defrule.phonep) << endl;
}


void GRule::add_empty(char* g,GNode *root) {
	rule defrule;
	defrule.patp = root->get_name();
	root->set_outcome("0");
	defrule.phonep = root->get_outcome();
	defrule.num = 0;
	rules.push_front(defrule);
    cout << "g:\t[0]\t[-" << g << "-] --> 0" << endl;
}

//---------------------------------------------------------------------------
