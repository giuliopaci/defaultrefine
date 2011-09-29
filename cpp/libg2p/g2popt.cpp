#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <iostream>
#include <fstream>
#include <vector>
#include <list>
#include <string>
#include <map>
#include <cstdlib>
#include <cstring>

#include <libg2p/g2popt.h>
#include <libg2p/GTree.h>
#include <libutil/StringHelper.h>
#include <libg2p/GRule.h>
#include <libg2p/RTree.h>
#include <libg2p/GGroups.h>
#include <libg2p/g2popt.h>

using namespace std;

int fgen_rules_opt(char *g, char * pattsfile, bool use_groups, int min_kids, int max_groups, char * groupsfile, char * rulefile) {
	#ifdef _DEBUG
	cout << "Entering fgen_rules_opt" << endl;
	#endif
    map<int, map<string, map <string,int> > > gpatts;

	ifstream infile(pattsfile);
	string line;
	list<string> patlist;
	GRule* grules = new GRule(use_groups,min_kids,max_groups,groupsfile);
	int best=0;
	bool read=0;
	if (infile.is_open()) {
		getline(infile,line);
		//for each word pattern, generate all sub-patterns and store as
		//gpatts[length of pattern][pattern][phone outcome]
		while (!infile.eof()) {
			read=1;
			string::size_type delim = line.find(';');
			string phone = line.substr(0,delim);
			string word = line.substr(delim+1);
			//cout << line << " and delim " << delim << " and p: " << phone << " and w: " << word << endl;
			patlist.clear();
	 		get_all_pats_limit((const string*)&word,1,1000,patlist);   //keep limit for later
			list<string>::iterator i;
			for (i=patlist.begin();i!=patlist.end();i++) {
	    		int len = (int)i->length()-2;
	    		gpatts[len][*i][phone]++;
	    		if (gpatts[len][*i][phone]>best) {
	    			best=gpatts[len][*i][phone];
	    		}
				//cout << len << ":" << *i << ":" << phone << ":" << gpatts[len][*i][phone] << endl;
			}
			getline(infile,line);
		}
		infile.close();
		cout << "Finding best rules for phone: " << g << endl;
		//call function to create g-specific rules from patterns
	    rules_frompats_opt(g,gpatts,best,grules);
	}
	if (!read) {
		cout << "Warning: " << pattsfile << " empty." << endl;
	}
	grules->fwrite(rulefile);
	delete grules;
	return 1;
}

int get_all_pats_limit(const string *wordp,string::size_type from, string::size_type to, list<string> &patlist) {
	//create list of sub-patterns from word pattern
	//cout << "Entering get_all_pats_limit" << endl;
	string left,g,right;
	if (!find_parts(wordp,left,g,right)) {
		return 0;
	}
	string::size_type leftlen=left.length();
	string::size_type rightlen=right.length();
	for (string::size_type l=0;l<=leftlen;l++) {
		if ((l+1)>to) {break;}
		string newleft=left.substr(leftlen-l,l);
		for (string::size_type r=0;r<=rightlen;r++) {
			if ((l+r+1)>to) {continue;}
			string newright=right.substr(0,r);
			if (((l+r+1)>=from) && ((l+r+1)<=to)) {
				string pat= newleft + "-" + g + "-" + newright;
				patlist.push_back(pat);
			}
        }
	}
	return 1;
}

void rules_frompats_opt(char * g,map<int, map<string, map <string,int> > > &gpatts, int best, GRule *grules) {
	// Extract the best <g>-specific rulegroups based on the set of patterns in <gpatts>
	//cout << "Entering rules_frompats_opt" << endl;
	bool use_groups=grules->get_use_groups();
	int found=0;
	string name = "-";
	name = name + g + "-";
	GTree* tree = new GTree(name,best);
	if (use_groups) {
		tree->set_use_groups(grules->groupp);
	}
	tree->build_tree(gpatts);
	//tree->traverse();
	//pick winning rule
	GNode* winner=tree->get_winning_rule();
	if (winner) {
		found=1;
	}
	set<GNode*> equivlist;
	while (winner) {
		grules->add(winner->get_name(),winner->get_outcome(),winner->get_max());
		//cout << "New rule for " << g << ": " << *(winner->get_name()) << " --> "
		//     << *(winner->get_outcome()) << "\t" << winner->get_max() << endl;
	    //remove rule and update counts, max and order
        tree->remove_rule(winner);
		//tree->traverse();
		bool all_equiv=false;
		if (all_equiv&&(winner->get_max()<10)) {
			tree->get_equiv(winner,equivlist);
			set<GNode*>::iterator i;
			for (i=equivlist.begin();i!=equivlist.end();i++) {
				//cout << "Adding equivalent rule: " << *(*i)->get_name() << endl;
				grules->add((*i)->get_name(),winner->get_outcome(),winner->get_max());
				tree->remove_rule(*i);
			}
		}
	    winner=tree->get_winning_rule();
	}

	queue<GNode*> missed;
	tree->get_leaves(tree->get_root(),missed);
	GNode *n;
	while (!missed.empty()) {
		n= missed.front();
		missed.pop();
		if ((n->get_active()==1)&&(n->get_max()>0)) {
			cout << "Error: missed " << *(n->get_name()) << endl;
		}
	}

	//Add empty rule if no rules found
	if (found==0) {
		grules->add_empty(g,tree->get_root());
	} else {
		//Add 1-g backoff rule, if missed by other rules
		if (grules->has_default(g,tree->get_root())==0) {
			grules->add_default(g,tree->get_root());
		}
	}

	//cout << "Completed, ready to clean up... " << endl;
	//delete tree;
}

//--------------------------------------------------------------------------------//

void read_gnulls(char *gnullfile, vector<string> &glist) {
	ifstream ifile(gnullfile);
	string line;
	if (ifile.is_open()) {
		getline(ifile,line);
		while (!ifile.eof()) {
			string tmp = line.substr(0,2);
			glist.push_back(tmp);
			getline(ifile,line);
		}
		ifile.close();
	} else {
		string gname(gnullfile);
		cout << "Error reading file: "<< gname << endl;
		exit(0);
	}
}

void add_gnulls(vector<string>& gnulls, string &word) {
	vector<string>::iterator i;
	//cout << "Entering add_gnulls: " << word << endl;
	for (i=gnulls.begin();i!=gnulls.end();i++) {
		//cout << (*i) << endl;
		string::size_type current=0;
		string::size_type mark;
		do {
			mark = word.find(*i,current);
			if (mark!=string::npos) {
				mark++;
				word.insert(mark,"0");
			}
		} while (mark!=string::npos);
	}
	//cout << word << endl;
}

int predict(char * inchar, char * rulesfile, bool info, bool nulls, bool spaces, bool gnulls, char * gnullsfile, bool usegroups, char *groupsfile) {
	//string instr(inchar);
	//string rulestr(rulesfile);
	//cout << "Entering predict: " << instr << " with " << rulestr << endl;
	RTree *rtree = new RTree;
	GGroups* groupp;
	if (usegroups) {
		string tmpstring(groupsfile);
		cout << tmpstring << endl;
		groupp = new GGroups(0,0,groupsfile);
		rtree->set_groups(groupp);
	}
	rtree->read_rules(rulesfile);
	//rtree->traverse();
	string word(inchar);
	word = " " + word + " ";
	if (gnulls) {
		vector<string> glist;
		read_gnulls(gnullsfile,glist);
		add_gnulls(glist,word);
	}
	vector <string> result;
	vector <RNode*> rules;
	rtree->predict_word(word,result,rules);

	if (info) {
		vector <RNode*>::iterator ri;
		for (ri=rules.begin();ri!=rules.end();ri++) {
			RNode *winner = *ri;
			cout << str_cast(winner->get_num()) << "\t" << *winner->get_outcome() << " : " <<  *winner->get_name() << endl;
		}
	}
	vector <string>::iterator i;
	for (i=result.begin();i!=result.end();i++) {
		if ((nulls)||((*i).compare("0")!=0)) {
			cout << *i;
			if (spaces) {
				cout << " ";
			}
		}
	}

	cout << endl;
	return 0;
}

//--------------------------------------------------------------------------------//


void format_result(string &word, vector<string> &result,string &format, bool nulls, string &printstr) {
	//cout << "Entering format_result: " << word << " " << format << endl;
	vector <string>::iterator i;
	if (format.compare("htk")==0) {
		printstr = word + "\t";
		for (i=result.begin();i!=result.end();i++) {
			if ((nulls)||((*i).compare("0")!=0)) {
				printstr = printstr + *i + " ";
			}
		}
	} else if (format.compare("semicolon")==0) {
		printstr = word + ";";
		for (i=result.begin();i!=result.end();i++) {
			if ((nulls)||((*i).compare("0")!=0)) {
				printstr = printstr + *i;
			}
		}
		printstr = printstr + ";1";
	} else {
		cout << "Error: Unknown format " << format << endl;
		exit(0);
	}
}

int fpredict(char * listfile, char * rulesfile, char * outfile, bool info, bool nulls,bool gnulls, char *gnullsfile, bool usegroups, char *groupsfile, string format ) {
	RTree *rtree = new RTree;
	vector<string> glist;
	if (gnulls) read_gnulls(gnullsfile,glist);
	GGroups * groupp;
	if (usegroups) {
		string tmpstring(groupsfile);
		cout << tmpstring << endl;
		groupp = new GGroups(0,0,groupsfile);
		rtree->set_groups(groupp);
	}
	rtree->read_rules(rulesfile);
	ifstream ifile(listfile);
	ofstream ofile(outfile);
	string line;
	string printstr;
	vector <string> result;
	vector <RNode*> rules;
	if (ifile.is_open()) {
		getline(ifile,line);
		while (!ifile.eof()) {
			string gline = " " + line + " ";
			if (gnulls) add_gnulls(glist,gline);
			result.clear();
			rtree->predict_word(gline,result,rules);
			if (nulls) {
				gline = gline.substr(1);
				gline = gline.substr(0,gline.length()-1);
				format_result(gline,result,format,nulls,printstr);
			} else {
				format_result(line,result,format,nulls,printstr);
			}
			ofile << printstr << endl;
			getline(ifile,line);
		}
		ifile.close();
	} else {
		cout << "Error reading file: "<< *listfile << endl;
		exit(0);
	}
	ofile.close();
	return 0;
}

//--------------------------------------------------------------------------------//


void id_rules(char *listfile, char *rulesfile, char *reffile, bool usegroups, char *groupsfile, bool gnulls, char *gnullsfile, char *outfile) {
	//Assumes comparing with an aligned dictionary
	string line;
	ifstream rfile(reffile);
	vector <string> parts;
	map <string,string> gref;
	map <string,string> pref;
	if (rfile.is_open()) {
		getline(rfile,line);
		while (!rfile.eof()) {
			//cout << line << endl;
			if (split(line,";",parts)!=3) {
				cout << "Error: wrong format for reference dictionary " << reffile << endl;
				exit(0);
			}
			gref[parts[0]]=parts[1];
			pref[parts[0]]=parts[2];
			getline(rfile,line);
		}
		rfile.close();
	} else {
		string fname(reffile);
		cout << "Error reading file: "<< fname << endl;
		exit(0);
	}

	RTree *rtree = new RTree;
	vector<string> glist;
	if (gnulls) read_gnulls(gnullsfile,glist);
	GGroups * groupp;
	if (usegroups) {
		string tmpstring(groupsfile);
		cout << tmpstring << endl;
		groupp = new GGroups(0,0,groupsfile);
		rtree->set_groups(groupp);
	}
	rtree->read_rules(rulesfile);
	ifstream ifile(listfile);
	ofstream ofile(outfile);
	vector <string> ptested;
	vector <RNode*> rules;
	if (ifile.is_open()) {
		getline(ifile,line);
		while (!ifile.eof()) {
			string gline = " " + line + " ";
			if (gnulls) add_gnulls(glist,gline);
			ptested.clear();
			rtree->predict_word(gline,ptested,rules);
			gline = gline.substr(1);
			gline = gline.substr(0,gline.length()-1);
			if (gref.find(line)==gref.end()) {
				cout << "Warning: word [" << line << "] not found in reference dictionary" << endl;
			} else {
				bool correct=true;
				vector<string> preal;
				split(pref[line]," ",preal);
				vector<string> greal;
				split(gref[line]," ",greal);
				vector<string> gtested;
				for (string::size_type i=0;i<gline.length();i++) {
					gtested.push_back(gline.substr(i,1));
				}
				vector<string>::size_type refi;
				vector<string>::size_type testi=0;
				vector<RNode*>::iterator rulesi=rules.begin();
				for (refi=0;refi<greal.size();refi++) {
					//cout << "HERE" << greal.at(refi) << gtested.at(testi) << endl;
					if (greal.at(refi)!=gtested.at(testi)) {
						if (greal.at(refi).compare("0")==0) {
							cout << "Missing gnull: " << greal.at(refi) << " " << preal.at(refi) << endl;
							correct=false;
							continue;
						} else {
							cout << "Unknown error - please check: " << greal.at(refi) << " " << preal.at(refi) << endl;
							exit(0);
						}
					}
					if (preal.at(refi) != ptested.at(testi)) {
						correct=false;
						cout << "Error: " << greal.at(refi) << ": " << preal.at(refi) << " " << ptested.at(testi) << " ";
						cout << *((*rulesi)->get_name()) << ":" << 	*((*rulesi)->get_outcome()) << endl;
					}
					testi++;
					rulesi++;
				}
				if (!correct) {
					cout << "Word [" << line << "] \tReference: [" << pref[line] << "] \tTested: [";
					for (vector<string>::iterator i=ptested.begin();i!=ptested.end();i++) {
						cout << *i << " ";
					}
					cout << "]" << endl;
				}
			}
			getline(ifile,line);
		}
		ifile.close();
	} else {
		cout << "Error reading file: "<< *listfile << endl;
		exit(0);
	}
	ofile.close();
}

//--------------------------------------------------------------------------------//
