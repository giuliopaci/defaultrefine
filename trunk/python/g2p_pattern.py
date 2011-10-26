#!/usr/bin/python
# -*- coding: utf-8 -*-
#-----------------------------------------------------------------------------#
#                                                                             #
# License:                                                                    #
#                                                                             #
#   Copyright (c) 2008, 2009, 2010, 2011 The Department of Arts and Culture,  #
#   The Government of the Republic of South Africa.                           #
#                                                                             #
#   All rights reserved.                                                      #
#                                                                             #
#   Contributors:  CSIR, South Africa                                         #
#                                                                             #
#   Redistribution and use in source and binary forms, with or without        #
#   modification, are permitted provided that the following conditions are    #
#   met:                                                                      #
#                                                                             #
#     * Redistributions of source code must retain the above copyright        #
#       notice, this list of conditions and the following disclaimer.         #
#                                                                             #
#     * Redistributions in binary form must reproduce the above copyright     #
#       notice, this list of conditions and the following disclaimer in the   #
#       documentation and/or other materials provided with the distribution.  #
#                                                                             #
#     * Neither the name of the Department of Arts and Culture nor the names  #
#       of its contributors may be used to endorse or promote products        #
#       derived from this software without specific prior written permission. #
#                                                                             #
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS       #
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED #
#   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A           #
#   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER  #
#   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,  #
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,       #
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR        #
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF    #
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING      #
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS        #
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.              #
#                                                                             #
#-----------------------------------------------------------------------------#

import unittest
import re

class Pattern:
    """
    Describes a word pattern in the context of a specific grapheme.  Word patterns
    are substrings of words, representing probable sequences of graphemes.
    """
    def __init__(self, pid, phoneme, context):
        """
        Constructor
        """
        self.__id = pid
        self.__phoneme = phoneme
        self.__context = context

    def __str__(self):
        """
        Overriding "to string" method.
        @Returns: String representation
        @rtype: C{str}
        """
        return "Pattern(%d, \"%s\", \"%s\")" % (self.__id, self.__phoneme, self.__context)

    def __cmp__(self, other):
        """
        Overriding comparison operator.
        @Returns: comparison result (1, 0, -1)
        @rtype: C{int}
        """
        if self.__id != other.__id:
            return -1
        if self.__phoneme != other.__phoneme:
            return -1
        if self.__context != other.__context:
            return -1
        return 0

    def get_id(self):
        """
        Return id.
        @returns: id
        @rtype: C{int}
        """
        return self.__id

    def get_phoneme(self):
        """
        Returns pattern phoneme.
        @returns: phoneme
        @rtype: C{str}
        """
        return self.__phoneme

    def get_context(self):
        """
        Returns pattern context.
        @returns: context
        @rtype: C{str}
        """
        return self.__context

    def get_grapheme(self):
        """
        Return the grapheme that is central to the context.
        @returns: context
        @rtype: C{str}
        """
        m = re.compile('.*-(.*)-.*').match(self.__context)
        if m:
            return m.group(1)
        else:
            raise Exception, 'context parsing failure for context "%s"' %self.__context


class G2PPatternTestCase(unittest.TestCase):
    """
    Test G2P utility methods.
    """
    def test_cmp(self):
        """
        Test comparison operator.
        """
        p1 = Pattern(0, "P", "a-b-c")
        p2 = Pattern(0, "P", "a-b-c")
        self.assertEqual(p1, p2)

        p1 = Pattern(1, "P", "a-b-c")
        p2 = Pattern(0, "P", "a-b-c")
        self.assertNotEqual(p1, p2)

        p1 = Pattern(0, "A", "a-b-c")
        p2 = Pattern(0, "P", "a-b-c")
        self.assertNotEqual(p1, p2)

        p1 = Pattern(0, "P", "a-c-c")
        p2 = Pattern(0, "P", "a-b-c")
        self.assertNotEqual(p1, p2)

    def test_accessors(self):
        """
        Test accessor methods.
        """
        p = Pattern(1, "A", "a-b-c")
        self.assertEquals( p.get_id(), 1)
        self.assertEquals( p.get_phoneme(), "A")
        self.assertEquals( p.get_context(), "a-b-c")
        self.assertEquals( p.get_grapheme(), "b")


if __name__ == "__main__":
    unittest.main()
