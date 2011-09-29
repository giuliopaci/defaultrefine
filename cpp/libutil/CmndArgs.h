#ifndef CMNDARGS_H_
#define CMNDARGS_H_

#include <vector>

using namespace std;

//--------------------------------------------------------------------------------//
// assumes all necessary parameters first, followed by optional flags
// assumes all flags 1 char
//--------------------------------------------------------------------------------//

int find_args(int argc, char *argv[], int from, vector<char*> &params);
// Find all non-flag parameters starting from <from> and add to <params>
// Return number of non-flag parameters found

int parse_flags(char *flag, int goal, int argc, char *argv[], int from, bool &toset, vector<char*> &flagparams);
// Determine if a specific <flag> is set, starting after <from> and set <toset> accordingly.
// If found, adddd flag paramaters to <flagparams>
// Return number of flag parameters found for this specific flag

#endif /*CMNDARGS_H_*/
