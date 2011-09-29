#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libutil/CmndArgs.h>

#include <iostream>
#include <fstream>
#include <vector>

//--------------------------------------------------------------------------------//
// assumes all necessary parameters first, followed by optional flags
// assumes all flags 1 char
//--------------------------------------------------------------------------------//

int find_args(int argc, char *argv[], int from, vector<char*> &params) {
	int cnt=0;
	while (from<argc) {
		//cout << "find_args " << from << ": " << argv[from] << endl;
		if ((int)argv[from][0] == (int)'-') {
			break;
		} else {
			params.push_back(argv[from]);
			from++;
			cnt++;
		}
	}
	return cnt;
}

int find_flags(char * flag, int argc, char *argv[], int from, vector<char*> &flagparams) {
	flagparams.clear();
	bool foundflag=false;
	int cnt=0;
	while (from<argc) {
		//cout << "find_flags " << from << ": " << argv[from] << endl;
		if ((int)argv[from][0] != (int)'-') {
			if (!foundflag) {
				from++;
			} else {
				flagparams.push_back(argv[from]);
				from++;
				cnt++;
			}
		} else {
			if (foundflag) {
				break;
			} else {
				if ((int)argv[from][1] == (int)*flag) {
					foundflag=true;
				}
				from++;
			}
		}
	}
	if (foundflag) {
		return cnt;
	} else {
		return -1;
	}
}

//--------------------------------------------------------------------------------//


int parse_flags(char *flag, int goal, int argc, char *argv[], int from, bool &toset, vector<char*> &flagparams) {
	int num = find_flags(flag,argc,argv,from,flagparams);
	if (num<0) {
		toset=false;
		return 0;
	} else if (num==goal) {
		toset=true;
		return 0;
	}
	return -1;
}


//--------------------------------------------------------------------------------//
