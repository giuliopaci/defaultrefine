#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <cstdlib>

#include <libg2p/RNode.h>
#include <libutil/StringHelper.h>

RNode::RNode(string pat, string out, int rnum) {
	name = pat;
	outcome = out;
	num = rnum;
	if (name.find("<")!=string::npos) {
		groups=true;
	} else {
		groups=false;
	}
	kids.clear();
}

RNode::~RNode()
{
}

bool RNode::node_subof_pat(const string &pat, GGroups *groupp) const {
	//cout << "Entering node_subof_pat with node: " << name << " and pat: " << pat << endl;
	if (!groups) {
		return (pat.find(name)!=pat.npos);
	} else {
		string left,g,right,nodeleft,nodeg,noderight;
		if (!find_parts(&pat,left,g,right)) {
			exit(0);
		}
		if (!find_parts(&name,nodeleft,nodeg,noderight)) {
			exit (0);
		}

		//See if left pat matches
		int i = (int) left.size();
		i--;
		int nodei=(int)nodeleft.size();
		nodei--;
		while (nodei>=0) {
			//cout << "patleft: " << left << " and nodeleft: " << nodeleft << " and i: " << i << " and nodei " << nodei << endl;
			if (i<0) {
				return false;
			}
			bool grouppat=false;
			bool groupnode=false;
			if (nodeleft.at(nodei) == '>') {
				nodei--;
				groupnode=true;
			}
			if (left.at(i) == '>') {
				i--;
				grouppat=true;
			}
			if (groupnode&&grouppat) {
				if (!groupp->contains(nodeleft.at(nodei),left.at(i))) {
					return false;
				}
			} else if (groupnode) {
				if (!groupp->has_member(nodeleft.at(nodei),left.at(i))) {
					return false;
				}
			} else if (grouppat) {
				return false;
			} else {
				if (nodeleft.at(nodei)!=left.at(i)) {
					return false;
				}
			}
			if (groupnode) nodei--;
			if (grouppat) i--;
			i--; nodei--;
		}

		//See if right pat matches
		i=0;
		nodei=0;
		while (nodei<(int)noderight.size()) {
			//cout << "patright: " << right << " and noderight: " << noderight << " and i: " << i << " and nodei " << nodei << endl;
			if (i>=(int)right.size()) {
				return false;
			}
			bool grouppat=false;
			bool groupnode=false;
			if (noderight.at(nodei) == '<') {
				nodei++;
				groupnode=true;
			}
			if (right.at(i) == '>') {
				i++;
				grouppat=true;
			}
			if (groupnode&&grouppat) {
				if (!groupp->contains(noderight.at(nodei),right.at(i))) {
					return false;
				}
			} else if (groupnode) {
				if (!groupp->has_member(noderight.at(nodei),right.at(i))) {
					return false;
				}
			} else if (grouppat) {
				return false;
			} else {
				if (noderight.at(nodei)!=right.at(i)) {
					return false;
				}
			}
			if (groupnode) nodei++;
			if (grouppat) i++;
			i++; nodei++;
		}

		//cout << pat << " matches node: " << name << endl;
		return true;
	}
}
