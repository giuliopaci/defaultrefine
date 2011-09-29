#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libg2p/GTree.h>
#include <libutil/StringHelper.h>

#include <stdio.h>
#include <map>
#include <set>
#include <queue>
#include <cstdlib>

#include <libg2p/GGroups.h>

GTree::GTree(string pat,int max)
{
	use_groups = false;
	best=max;
	root=new GNode(pat,false);
	order.resize(best+1);
	for (int i=0;i<=best;i++) {
		order.at(i)=new set<GNode*>();
		order.at(i)->clear();
	}
}

void GTree::set_use_groups(GGroups * newp)
{
	use_groups = true;
	groupp = newp;
}

GTree::~GTree()
{
	for (vector<set<GNode*>*>::size_type i=0;i<order.size();i++) {
		delete order.at(i);
		order.at(i)=NULL;
	}
	delete root;
}


GNode* GTree::find_node(const string *patp) const {
	//cout << "Entering find_node: " << pat << endl;
	int found=0;
	int busy=1;
	GNode* patnode = NULL;
	GNode* next = root;
	while ((found==0)&&(busy==1)) {
		if ((next->get_name())->compare(*patp)==0) {
			patnode = next;
			found=1;
		} else {
			busy=0;
			for (vector<GNode*>::const_iterator i=next->kids.begin();i!=next->kids.end();i++) {
				if ((*i)->node_subof_pat(patp)) {
					//cout << "Following " << (*i)->get_name() << endl;
					next = *i;
					busy=1;
					break;
				}
			}
		}
	}
	if (found==0) {
		cout << "Error: find_node could not find " << *patp << endl;
	}
	return patnode;
}


void GTree::get_leaves(GNode* startnode,queue<GNode*> &leaves) const {
	//cout << "Entering get_leaves: " << startnode->get_name() << endl;
	set <GNode*> done;
	queue <GNode*> nodes;
	nodes.push(startnode);

	while (!nodes.empty()) {
		GNode *n = nodes.front();
		nodes.pop();
		// cout << n->get_name() << endl;
		if (done.find(n)!=done.end()) {continue;}
		if (n->kids.empty()) {
			leaves.push(n);
		} else {
			for (vector<GNode*>::const_iterator i=n->kids.begin();i!=n->kids.end();i++) {
				nodes.push(*i);
			}
		}
		done.insert(n);
	}
}

void GTree::traverse() const {
	//cout << "Entering traverse" << endl;
	set <GNode*> done;
	queue <GNode*> nodes;
	nodes.push(root);
	while (!nodes.empty()) {
		GNode *n = nodes.front();
		nodes.pop();
		if (done.find(n)!=done.end()) {continue;}
		cout << *(n->get_name()) << "(" << n->countstr() << "): " ;
		for (vector<GNode*>::const_iterator i=n->kids.begin();i!=n->kids.end();i++) {
			nodes.push(*i);
			cout << *((*i)->get_name()) << " ";
		}
		for (set<GNode*>::const_iterator ii=n->grouplinks.begin();ii!=n->grouplinks.end();ii++) {
			cout << "[" << *((*ii)->get_name()) << "(" << (*ii)->countstr() << ")" << "]";
		}
		cout << endl;
		done.insert(n);
	}
}


int GTree::update_best() {
	//cout << "Entering update_best" << endl;
	int max = best;
	int found=0;
	set<GNode*>* possible;
	while (max>0) {
		possible = order[max];
		//assert(possible);
		if (!possible->empty()) {
			best=max;
			found=1;
			break;
		} else {
			max--;
		}
	}
	if (found==0) {
		best=0;
	}
	return best;
}

GNode* GTree::get_winning_rule(void) const {
	//cout << "Entering get_winning_rule" << endl;
	if (best==0) {return NULL;}
	set <GNode*>* possible = order[best];
	//assert(possible);
	//Do conflict resolution
	int maxsize=1000;
	string dummy= "";
	const string *maxpatp=&dummy;
	GNode* winner=NULL;
	for (set<GNode*>::const_iterator i=possible->begin();i!=possible->end();i++) {
		const string *patp = (*i)->get_name();
		int size = (*i)->get_length();
		int gwin = groupp->less_groups(patp,maxpatp);
		if ((size<maxsize)||
				((size==maxsize)&&
					((gwin==1)||
						((gwin==0)&&
							((get_sym(patp)<get_sym(maxpatp))||
								((get_sym(patp)==get_sym(maxpatp))
						 			&&(right_first(patp)>(right_first(maxpatp))))))))) {
			maxpatp=patp;
			maxsize=size;
			winner=*i;
			//cout << "New winner: " << *patp << "\t size: " << str_cast(size) << "\t gwin: " << str_cast(gwin) << endl;
		}
	}
	return winner;
}

int GTree::add_pattern_info(const string* patp, list<string> &parentlist, map<string,int> &num) {
	//cout << "Entering add_pattern_info: " << *patp << endl;
	GNode *newnode;
	if (patp->length()>3) {
		newnode=new GNode(*patp,false);
		newnode->set_length((int)patp->length()-2);
		for (list<string>::iterator i=parentlist.begin();i!=parentlist.end();i++) {
			GNode *parentnode = find_node((const string *) &(*i));
			newnode->add_parent(parentnode);
			parentnode->add_kid(newnode);
		}
	} else {
		newnode=root;
		newnode->set_length(1);
	}

	int max=0;
	string maxp;
	list <string> newgroups;
	list <string>::iterator li;
	if (use_groups) {
		groupp->create_possible_group_pats(patp,newgroups);
		for (li=newgroups.begin();li!=newgroups.end();li++) {
				groupp->insert_name(*li);
				groupp->tmpnodes[*li].insert(newnode);
		}
	}
	for (map<string,int>::iterator i=num.begin();i!=num.end();i++) {
		if (i->second>max) {
			max = i->second;
			maxp = i->first;
		}
		if (use_groups) {
			for (li=newgroups.begin();li!=newgroups.end();li++) {
				string newstr = *li;
				groupp->insert_outcome(newstr,i->first);
				groupp->tmpcnt[newstr][i->first] += i->second;
				groupp->tmpkids[newstr][i->first]++;
			}
		}
	}
	newnode->set_max(max);
	newnode->set_outcome(maxp);
	order[max]->insert(newnode);
	return newnode->get_max();
}

void GTree::build_tree(map<int, map<string, map <string,int> > > &gpatts) {
	//cout << "Entering build_tree" << endl;
	best=0;
	//Build tree according to length of patterns
	//this ensures that parents exist before kids are added
	for (int len=1;len<=(int) gpatts.size();len++) {
		//cout << "build tree, length: " << str_cast(len) << endl;
		for (map<string, map <string,int> >::iterator i=gpatts[len].begin();i!=gpatts[len].end();i++) {
			const string* patp = (const string*) &(*i).first;
			string left,g,right;
			if (!find_parts(patp,left,g,right)) {
				exit(0);
			}
			//Create list of parents
			list<string> parentlist;
			if (left.length()>0) {
				string newleft = left.substr(1);
				newleft.append("-");
				newleft.append(g);
				newleft.append("-");
				newleft.append(right);
				parentlist.push_back(newleft);
				//cout << *patp << " has parent " << newleft << endl;
			}
			if (right.length()>0) {
				string newright = left;
				newright.append("-");
				newright.append(g);
				newright.append("-");
				string::size_type newlen=right.length()-1;
				if (newlen>0) {
					newright.append(right.substr(0,newlen));
				}
				parentlist.push_back(newright);
				//cout << *patp << " has parent " << newright << endl;
			}
			//cout << "Adding " << *patp << str_cast(len) << endl;
			//Create a new node in the tree for this pattern and link to parents
			//Update group counters (inside groupp), if groups used
			int max = add_pattern_info(patp,parentlist,(*i).second);
			if (max>best) {
				best=max;
			}
		}
		int max_grouppatlen=6;
		if (use_groups) {
			//string info = "length: " + str_cast(len);
			//groupp->show_groups(info);

			//Use accumulated group counters to decide which group patterns to add to tree
			//Clean accumulated group counters
			groupp->add_valid_groups(len,order);
		}
		if (len==max_grouppatlen)
			use_groups=false;
	}
	//traverse();
	use_groups=true;
}

void GTree::delete_order(GNode *rule) {
	//cout << "Entering delete_order: " << *(rule->get_name()) << endl;
	int best = rule->get_max();
	order[best]->erase(rule);
}

void GTree::remove_linked_rule(GNode* rule, const string *outcome) {
	//cout << "Entering remove_linked_rule:" << *(rule->get_name()) << endl;
	list<GNode*> inc;
	list<GNode*> dec;
	queue<GNode*> wordnodes;
	get_leaves(rule,wordnodes);
	GNode *n;
	while (!wordnodes.empty()) {
		n = wordnodes.front();
		wordnodes.pop();
		//cout << *n->get_name() << " : " << *n->get_outcome() << n->get_done() << endl;
		if ((n->get_outcome())->compare(*outcome)==0) {
			if (n->get_done()==0) {
				dec.push_back(n);
				n->set_done();
				//cout << "Done: " << *n->get_name() << endl;
			}
		} else {
			if (n->get_done()==1) {
				inc.push_back(n);
				n->clear_done();
				//cout << "Undone: " << *n->get_name() << endl;
			}
		}
	}
	//update counts, max and order, using flag to indicate which nodes have been done
	update_info_for_tree(root,inc,dec);
	clear_flags();
}

void GTree::remove_rule(GNode* rule) {
	//cout << "Entering remove_rule:" << *(rule->get_name()) << endl;
	rule->clear_active();
	const string *outcome = rule->get_outcome();
	delete_order(rule);
	if ((use_groups)&&(rule->is_group())) {
		for (set <GNode*>::iterator i=rule->grouplinks.begin();i!=rule->grouplinks.end();i++) {
			remove_linked_rule(*i,outcome);
		}
	} else {
		remove_linked_rule(rule,outcome);
	}
	update_best();
	//traverse();
}

void GTree::clear_flags() {
	//cout << "Entering clear_flags" << endl;
	queue<GNode*> nodes;
	nodes.push(this->root);
	while (nodes.size() > 0) {
		GNode* n =  nodes.front();
		nodes.pop();
		n->clear_flag();
		for (vector<GNode*>::iterator i=n->kids.begin();i!=n->kids.end();i++) {
			if ((*i)->get_flag()==1) {
				nodes.push(*i);
			}
		}
	}
}

void GTree::update_order(GNode* node,int prevmax,int newmax) {
	//cout << "Entering update_order: " << node->get_name() << endl;
	if ((prevmax<=0)&&(newmax<=0)) {
		return;
	}
	if (prevmax>0) {
		order[prevmax]->erase(node);
	} else {
		order[0]->erase(node);
	}
	if (newmax>0) {
		order[newmax]->insert(node);
	} else {
		order[0]->insert(node);
	}
}

void GTree::update_info_for_tree(GNode* node, list<GNode*> &inc, list<GNode*> &dec) {
	//cout << "Entering update_info_for_tree: " << *(node->get_name()) << " : ";
	//int test = node->get_name().compare("l-e-");
	if (node->get_flag()==1) {
		return;
	}
	int add = (int)inc.size();
	int del = (int)dec.size();
	int change = add - del;
	//cout << str_cast(change) << endl;
	node->set_flag();
	if (node->get_active()==1) {
		int prevmax = node->get_max();
		int newmax = node->inc_all(change); //The more negative change, the better
		update_order(node,prevmax,newmax);
	}
	if (use_groups) {
		for (set <GNode*>::iterator i=node->grouplinks.begin();i!=node->grouplinks.end();i++) {
			//cout << "Updating group node: " << *((*i)->get_name()) << " : " << str_cast(change) << endl;
			if ((*i)->get_active()==1) {
				int prevmax = (*i)->get_max();
				int newmax = (*i)->inc_all(change);
				update_order(*i,prevmax,newmax);
			}
		}
	}
	for (vector<GNode*>::iterator i=node->kids.begin();i!=node->kids.end();i++) {
		if ((*i)->get_flag()==1) {continue;}
		list <GNode*>new_inc;
		list <GNode*>new_dec;
		int work=0;
		for (list<GNode*>::iterator ii=inc.begin();ii!=inc.end();ii++) {
			//cout << node->get_name() << " : " << (*i)->get_name() << " : " << (*ii)->get_name() << endl;
			if ((*i)->node_subof_pat((*ii)->get_name())==1) {
				new_inc.push_back(*ii);
				work=1;
			}
		}
		for (list<GNode*>::iterator ii=dec.begin();ii!=dec.end();ii++) {
			//cout << node->get_name() << " : " << (*i)->get_name() << " : " << (*ii)->get_name() << endl;
			if ((*i)->node_subof_pat((*ii)->get_name())==1) {
				new_dec.push_back(*ii);
				work=1;
			}
		}
		if (work==1) {
			update_info_for_tree(*i,new_inc,new_dec);
		}
	}
}


void GTree::get_pats_of_size(const string *name, const string *pat, int length, set<GNode*> &patlist) {
	//cout << "Entering get_leaves: " << startnode->get_name() << endl;
	set <GNode*> done;
	done.clear();
	queue <GNode*> nodes;
	nodes.push(root);
	while (!nodes.empty()) {
		GNode *n = nodes.front();
		nodes.pop();
		// cout << n->get_name() << endl;
		if (done.find(n)!=done.end()) {continue;}
		if (n->node_subof_pat(name)) {
			if ((n->get_length()==length)&&(pat->compare(*n->get_name())!=0)) {
				patlist.insert(n);
				//cout << "Possible equiv: " << *n->get_name() << endl;
			} else if (n->get_length()<length) {
				for (vector<GNode*>::const_iterator i=n->kids.begin();i!=n->kids.end();i++) {
					nodes.push(*i);
				}
			}
		}
		done.insert(n);
	}
}


bool GTree::get_equiv(GNode *winner,set<GNode*> &equivlist) {
	set<GNode*> tmplist;
	equivlist.clear();
	queue<GNode*> leaves;
	set<GNode*> check_leaves;
	get_leaves(winner,leaves);
	GNode *first = leaves.front();
	leaves.pop();
	get_pats_of_size(first->get_name(),winner->get_name(),winner->get_length(),equivlist);
	check_leaves.insert(first);
	//cout << "Leave: " << *first->get_name() << endl;
	while (!leaves.empty()) {
		tmplist.clear();
		GNode *next=leaves.front();
		//cout << "Leave: " << *next->get_name() << endl;
		leaves.pop();
		set<GNode*>::iterator i;
		for (i=equivlist.begin();i!=equivlist.end();i++) {
			if (!(*i)->node_subof_pat(next->get_name())) {
				tmplist.insert(*i);
				//cout << "a) Removed node " << *(*i)->get_name() << ". It clashed with word " << *next->get_name() << endl;
			}
		}
		for (i=tmplist.begin();i!=tmplist.end();i++) {
			set<GNode*>::iterator tmp;
			tmp = equivlist.find(*i);
			if (tmp!=equivlist.end()) {
				equivlist.erase(tmp);
			}
		}
		if (equivlist.empty()) {return false;}
		check_leaves.insert(next);
	}
	set<GNode*>::iterator i;
	for (i=equivlist.begin();i!=equivlist.end();i++) {
		queue <GNode*> posleaves;
		get_leaves(*i,posleaves);
		while (!posleaves.empty()) {
			GNode *next=posleaves.front();
			posleaves.pop();
			if (check_leaves.find(next)==check_leaves.end()) {
				tmplist.insert(*i);
				//cout << "b) Removed node " << *(*i)->get_name() << ". It matched additional word " << *next->get_name() << endl;
				break;
			}
		}
	}
	for (i=tmplist.begin();i!=tmplist.end();i++) {
		set<GNode*>::iterator tmp;
		tmp = equivlist.find(*i);
		if (tmp!=equivlist.end()) {
			equivlist.erase(tmp);
		}
	}
	if (equivlist.empty()) {
		return false;
	} else {
		return true;
	}
}

//---------------------------------------------------------------------------
