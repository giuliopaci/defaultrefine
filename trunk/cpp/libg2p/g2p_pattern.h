#ifndef __G2P_PATTERN_H__
#define __G2P_PATTERN_H__

#include <string>

using namespace std;

class Pattern {
  public:
    Pattern(int id, string phoneme, wstring context): _id(id),
                                                      _phoneme(phoneme),
                                                      _context(context) {}
    int get_id(void);
    string get_phoneme(void);
    wstring get_context(void);
  private:
    int _id;
    string _phoneme;
    wstring _context;
};

// --------------------------------------------------------------------------
inline int Pattern::get_id(void)
{
  return this->_id;
}

// --------------------------------------------------------------------------
inline string Pattern::get_phoneme(void)
{
  return this->_phoneme;
}

// --------------------------------------------------------------------------
inline wstring Pattern::get_context(void)
{
  return this->_context;
}

#endif // __G2P_PATTERN_H__
