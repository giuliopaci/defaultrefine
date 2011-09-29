#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <iostream>
#include <fstream>
#include <list>
#include <cstdlib>

#include <libg2p/GGroups.h>
#include <libutil/StringHelper.h>

GGroups::GGroups(int mink, int maxg, char *groupsfile)
{
	minimum_kids = mink;
	max_groups = maxg;
	ifstream ifile(groupsfile);
	string line;
	if (ifile.is_open()) {
		getline(ifile,line);
		while (!ifile.eof()) {
			create_group(line);
			getline(ifile,line);
		}
		ifile.close();
	} else {
		string filestr(groupsfile);
		cout << "Error reading groups file: "<< filestr << endl;
		exit(0);
	}
	create_members();
}

GGroups::~GGroups()
{
}

void GGroups::create_group(string &line) {
	vector<string> parts;
	split(line,";",parts);
	if (parts.size()!=3) {
		cout << "Error: wrong format in groups file, line: " << line << endl;
		exit(0);
	}
	char id = parts[0][0];
	for (string::size_type i=0;i<parts[1].length();i++) {
		groups[id].insert(parts[1].at(i));
	}
	for (string::size_type i=0;i<parts[2].length();i++) {
		superset[id].insert(parts[2].at(i));
	}

	//cout << "New group created: " << id << endl;
	//set<char>::iterator i;
	//for (i=groups[id].begin();i!=groups[id].end();i++) {
	//	cout << *i << endl;
	//}
}

void GGroups::create_members() {
	map <char,set<char> >::iterator i;
	for (i=groups.begin();i!=groups.end();i++) {
		char group_id = i->first;
		set<char> group_members = i->second;
		set<char>::iterator ii;
		for (ii=group_members.begin();ii!=group_members.end();ii++) {
			char c = *ii;
			members[c].insert(group_id);
		}
	}
}

void GGroups::insert_name(string pat) {
	if (tmpnames.find(pat)==tmpnames.end()) {
		tmpnames.insert(pat);
	}
}


void GGroups::insert_outcome(string pat,string outcome) {
	map <string,int> cntmap = tmpcnt[pat];
	if (cntmap.find(outcome)==cntmap.end()) {
		cntmap[outcome]=0;
		tmpkids[pat][outcome]=0;
	}
}

void GGroups::show_groups(string info) {
	set <string>::iterator i;
	cout << "----" << info << "----" << endl;
	for (i=tmpnames.begin();i!=tmpnames.end();i++) {
		cout << *i << " : ";
		map <string, int>::iterator ii;
		for (ii=tmpcnt[*i].begin();ii!=tmpcnt[*i].end();ii++) {
			string outcome = ii->first;
			int count = ii->second;
			cout << outcome << "(" << count << ")";
		}
		cout << endl;
	}
}

int GGroups::numgroups(string pat) {
	string::size_type mark = pat.find('<');
	int cnt=0;
	while (mark!=string::npos) {
		cnt++;
		pat = pat.substr(mark+3);
		mark = pat.find('<');
	}
	//cout << "TMP numgroups: " << cnt << endl;
	return cnt;
}

bool GGroups::maxgroups(string &pat) {
	int cnt = numgroups(pat);
	if (cnt>=max_groups) {
		return true;
	} else {
		return false;
	}
}

void GGroups::create_possible_group_pats(const string* patp, list <string> &groupstr) {
	groupstr.push_back("");
	string left, g, right;
	find_parts(patp,left,g,right);
	for (string::size_type i=0;i<left.length();i++) {
		int cursize=groupstr.size();
		for (int n=0;n<cursize;n++) {
			string pat = groupstr.front();
			groupstr.pop_front();
			string newpat = pat + left[i];
			groupstr.push_back(newpat);
			set<char> groupset = members[left[i]];
			set<char>::iterator ii;
			for (ii=groupset.begin();ii!=groupset.end();ii++) {
				if (maxgroups(pat)) break;
				if ((pat.compare("")==0)&&(*ii=='*')) continue;
				string newpat = pat + "<" + (*ii) + ">";
				groupstr.push_back(newpat);
			}
		}
	}
	int cursize=groupstr.size();
	for (int n=0;n<cursize;n++) {
		string pat = groupstr.front();
		groupstr.pop_front();
		string newpat = pat + "-" + g + "-";
		groupstr.push_back(newpat);
	}
	for (string::size_type i=0;i<right.length();i++) {
		int cursize=groupstr.size();
		for (int n=0;n<cursize;n++) {
			string pat = groupstr.front();
			groupstr.pop_front();
			string newpat = pat + right[i];
			groupstr.push_back(newpat);
			set<char> groupset = members[right[i]];
			set<char>::iterator ii;
			for (ii=groupset.begin();ii!=groupset.end();ii++) {
				if (maxgroups(pat)) break;
				if ((*ii=='*')&&(i==right.length()-1)) continue;
				string newpat = pat + "<" + (*ii) + ">";
				groupstr.push_back(newpat);
			}
		}
	}
	list <string>::iterator i;
	for (i=groupstr.begin();i!=groupstr.end();) {
		if (i->find("<")==string::npos) {
			//cout << "erasing " << *i << endl;
			i = groupstr.erase(i);
			if (i==groupstr.end()) break;
		} else {
			i++;
		}
	}
	/*
	cout << "Patterns for " << *patp << endl;
	for (i=groupstr.begin();i!=groupstr.end();i++) {
		cout << "TMP: " << *i << endl;
	}
	*/

}

int GGroups::less_groups(const string* contend,const string* champ) {
	int champnum = numgroups(*champ);
	int contendnum = numgroups(*contend);
	if (contendnum<champnum) {
		return 1;
	}
	if (contendnum>champnum) {
		return -1;
	}
	return 0;
}

void GGroups::add_valid_groups(int len, vector <set<GNode*>*> &order) {
	//cout << "Entering add_valid_groups: " << str_cast(len) << endl;
	set <string>::iterator i;
	for (i=tmpnames.begin();i!=tmpnames.end();i++) {
		string name=*i;
		int max=0;
		string outcome="";
		bool found=false;
		set <GNode*>::iterator ii;
		for (ii=tmpnodes[name].begin();ii!=tmpnodes[name].end();ii++) {
			if ((*ii)->get_max() > max) {
				max = (*ii)->get_max();
			}
		}
		map <string, int>::iterator ij;
		for (ij=tmpcnt[name].begin();ij!=tmpcnt[name].end();ij++) {
			if (ij->second > max) {
				max = ij->second;
				outcome = ij->first;
				if (tmpkids[name][outcome]>minimum_kids) {
					found=true;
				}
			}
		}
		if (found) {
			//cout << "Adding " << name << endl;
			GNode * newnode = new GNode(name,true);
			newnode->set_outcome(outcome);
			newnode->set_max(max);
			newnode->set_length(len);
			newnode->add_grouplinks(tmpnodes[name]);
			order[max]->insert(newnode);
		}
		tmpnodes[name].clear();
		tmpcnt[name].clear();
	}
	tmpnames.clear();
	tmpnodes.clear();
	tmpcnt.clear();
}

bool GGroups::has_member(char setid,char candidate) {
	//true if candidate is a number of set named setid
	return (groups[setid].find(candidate)!=groups[setid].end());
}

bool GGroups::contains(char masterid,char childid) {
	//true if the <masterid> set contains <childid> set
	return (superset[masterid].find(childid)!=superset[masterid].end());
}
