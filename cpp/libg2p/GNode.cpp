#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif // HAVE_CONFIG_H

#include <libg2p/GNode.h>
#include <libutil/StringHelper.h>

#include <sstream>
#include <set>

GNode::GNode(const string pat,bool grule)
{
  name=pat;
  grouprule=grule;
  max=0;
  done=0;
  flag=0;
  active=1;
  parents.clear();
  kids.clear();
  //counts.clear();
}

GNode::~GNode()
{
}

void GNode::add_parent(GNode* parent) {
  //cout << "Entering add_parent: " << parent->name << endl;
  int found=0;
  //if (!parents.empty()) {
    for (vector<GNode*>::iterator i=parents.begin();i!=parents.end();i++) {
      if (((*i)->get_name())->compare(*(parent->get_name()))==0) {
        found=1;
        break;
      }
    }
  //}
  if (found==0) {
    parents.push_back(parent);
  }
}

void GNode::add_kid(GNode* kid) {
  //cout << "Entering add_kid: " << kid->name << endl;
  int found=0;
  //if (!kids.empty()) {
    for (vector<GNode*>::iterator i=kids.begin();i!=kids.end();i++) {
      if (((*i)->get_name())->compare(*kid->get_name())==0) {
        found=1;
        break;
      }
    }
  //}
  if (found==0) {
    kids.push_back(kid);
  }
}


/*
void GNode::inc_all(int num) {
  //cout << "Entering inc_all" << endl;
  //if (!counts.empty()) {
    for (map<string,int>::iterator i=counts.begin();i!=counts.end();i++) {
      i->second+=num;
    }
  //}
}

int GNode::update_max() {
  //cout << "update_max" << endl;
  int newmax=0;
  string maxp = this->get_outcome();
  //if (!counts.empty()) {
    for (map<string,int>::iterator i=counts.begin();i!=counts.end();i++) {
      if (i->second > newmax) {
        newmax=i->second;
        maxp=i->first;
      }
    }
  //}
  this->max=newmax;
  this->outcome=maxp;
  return newmax;
}
*/

string GNode::countstr() const {
  string info ="";
  if (active==0) {
    return "-1";
  }
  info = info + outcome + str_cast(max);
  /*
  for (map<string,int>::const_iterator i=counts.begin();i!=counts.end();i++) {
    stringstream intstr;
    intstr << i->second;
    info = info + i->first + intstr.str();
  }
  */
  return info;
}

void GNode::add_grouplinks(set <GNode*> &newnodes) {
  set <GNode*>::iterator i;
  for (i=newnodes.begin();i!=newnodes.end();i++) {
    grouplinks.insert(*i);
    (*i)->grouplinks.insert(this);
  }
}
//---------------------------------------------------------------------------
