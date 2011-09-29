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

#include <libg2p/GTree.h>
#include <libutil/CmndArgs.h>
#include <libutil/StringHelper.h>
#include <libg2p/GRule.h>
#include <libg2p/RTree.h>
#include <libg2p/GGroups.h>
#include <libg2p/g2popt.h>

using namespace std;

void print_usage(void) {
        cout << "Usage: g2popt extract <g> <pattsfile> <rulesfile> [-u <min_kids> <max_groups> <groupsfile]" << endl;
		cout << "       g2popt predict <word>  <rulesfile> [-i] [-n] [-s] [-g <gnullfile>] [-u <groupsfile>] " << endl;
		cout << "       g2popt predict_file <wordlist> <rulesfile> <outfile> [-f htk|semicolon] [-i] [-n] [-g <gnullfile>] [-u <groupsfile>]" << endl;
		cout << "       g2popt id_rules <wordlist> <rulesfile> <aligned_ref_dict> <outfile> [-g <gnullfile>] [-u <groupsfile>]" << endl;
		cout << "       See separate commands for more info"  << endl;
}

//---------------------------------------------------------------------------

int main (int argc, char *argv[]) {
	if (argc==1) {
		print_usage();
		return 0;
	}

	if (strcmp(argv[1],"extract")==0) {
		bool usegroups;
		int minkids;
		int maxgroups;
		char * groupsfile = NULL;
		vector<char*> params;
		vector<char*> flagparams;
		if ((find_args(argc,argv,2,params)==3)
			&& (parse_flags("u",3,argc,argv,2,usegroups,flagparams)==0)) {
			if (usegroups) {
				minkids=atoi(flagparams[0]);
				maxgroups=atoi(flagparams[1]);
				groupsfile = flagparams[2];
			}
			fgen_rules_opt(params[0],params[1],usegroups,minkids,maxgroups,groupsfile,params[2]);
			return 0;
		}
        cout << "g2popt extract <g> <pattsfile> <rulesfile> [-u <min_kids> <max_groups> <groupsfile>]" << endl;
        cout << "       -u : use groups (default no groups)" << endl;
        cout << "            at least <min_kids> examples (types) before group formed"  << endl;
        cout << "            no more than <max_groups> groups (tokens) per rule"  << endl;
        cout << "            read groups to use from <groupsfile>"  << endl;
        return 0;
 	}

	if (strcmp(argv[1],"predict")==0) {
		bool info;
		bool gnulls;
		bool nulls;
		bool spaces;
		bool usegroups;
		char * gnullsfile = NULL;
		char * groupsfile = NULL;
		vector<char*> params;
		vector<char*> flagparams;
		if ((find_args(argc,argv,2,params)==2)
			&& (parse_flags("i",0,argc,argv,2,info,flagparams)==0)
			&& (parse_flags("n",0,argc,argv,2,nulls,flagparams)==0)
			&& (parse_flags("s",0,argc,argv,2,spaces,flagparams)==0)
			&& (parse_flags("g",1,argc,argv,2,gnulls,flagparams)==0)) {
			if (gnulls) {
				gnullsfile = flagparams[0];
			}
			if (parse_flags("u",1,argc,argv,2,usegroups,flagparams)==0) {
				if (usegroups) {
					groupsfile = flagparams[0];
				}
				predict(params[0],params[1],info,nulls,spaces,gnulls,gnullsfile,usegroups,groupsfile);
        		return 0;
			}
		}
		cout << "g2popt predict <word>  <rulesfile> [-i] [-p] [-s] [-g <gnullfile>] [-u <groupsfile>]" << endl;
		cout << "       -i : print info on rule applied" << endl;
		cout << "       -g : apply graphemic nulls from <gnullfile>"  << endl;
		cout << "       -n : leave phonemic nulls, otherwise removed" << endl;
		cout << "       -s : leave spaces between output phones"  << endl;
        cout << "       -u : use groups (default no groups)" << endl;
        cout << "            read groups to use from <groupsfile>"  << endl;
		return 0;
	}

	if (strcmp(argv[1],"predict_file")==0) {
		bool gnulls;
		bool fspec;
		bool info;
		bool nulls;
		bool usegroups;
		string format("semicolon");
		char * gnullsfile = NULL;
		char * groupsfile = NULL;
		vector<char*> params;
		vector<char*> flagparams;
		if ((find_args(argc,argv,2,params)==3)
		&& (parse_flags("i",0,argc,argv,2,info,flagparams)==0)
		&& (parse_flags("n",0,argc,argv,2,nulls,flagparams)==0)
		&& (parse_flags("f",1,argc,argv,2,fspec,flagparams)==0)) {
			if (fspec) {
				string tmpstr(flagparams[0]);
				if ((strcmp(flagparams[0],"htk")==0)||(strcmp(flagparams[0],"semicolon")==0)){
					format = flagparams[0];
				} else {
					print_usage();
					return 0;
				}
			}
			if (parse_flags("g",1,argc,argv,2,gnulls,flagparams)==0) {
				if (gnulls) {
					gnullsfile = flagparams[0];
				}
				if (parse_flags("u",1,argc,argv,2,usegroups,flagparams)==0) {
					if (usegroups) {
						groupsfile = flagparams[0];
					}
					fpredict(params[0],params[1],params[2],nulls,gnulls,gnullsfile,usegroups,groupsfile,format);
        			return 0;
				}
			}
		}
		cout << "g2popt predict_file <wordlist> <rulesfile> <outfile> [-f htk|semicolon] [-i] [-g <gnullfile>] [-u <groupsfile>]" << endl;
		cout << "       -f : select format (default: semicolon)" << endl;
		cout << "       -i : print info on rule applied" << endl;
		cout << "       -n : leave nulls (both phonemic and graphemic), otherwise removed" << endl;
		cout << "       -g : apply gnulls from <gnullfile>"  << endl;
        cout << "       -u : use groups (default no groups)" << endl;
        cout << "            read groups to use from <groupsfile>"  << endl;
		return 0;
	}

	if (strcmp(argv[1],"id_rules")==0) {
		bool gnulls;
		bool usegroups;
		char * gnullsfile = NULL;
		char * groupsfile = NULL;
		vector<char*> params;
		vector<char*> flagparams;
		if (find_args(argc,argv,2,params)==4) {
			if (parse_flags("g",1,argc,argv,2,gnulls,flagparams)==0) {
				if (gnulls) {
					gnullsfile = flagparams[0];
				}
				if (parse_flags("u",1,argc,argv,2,usegroups,flagparams)==0) {
					if (usegroups) {
						groupsfile = flagparams[0];
					}
					id_rules(params[0],params[1],params[2],usegroups,groupsfile,gnulls,gnullsfile,params[3]);
					return 0;
				}
			}
		}
		cout << "g2popt id_rules <wordlist> <rulesfile> <ref_dict> <outfile> [-g <gnullfile] [-u <groupsfile>]" << endl;
        return 0;
 	}

	print_usage();
	return 0;
}
