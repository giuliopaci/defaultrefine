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

def create_char_maps(strings):
    """
    Create mappings from the given strings to single ascii characters.  Two
    mappings are returned for optimal access performance:
        1) strings -> chars
        2) chars -> strings.
    
    @param strings: List of strings
    @type strings: C{list} of C{str}
    """
    char_to_str = {}
    str_to_char = {}
    char_availability = {}
    for i in range(ord('a'), ord('z') + 1):
        char_availability[chr(i)] = True
    for i in range(ord('A'), ord('Z') + 1):
        char_availability[chr(i)] = True
    for i in range(ord('1'), ord('9')):
        char_availability[chr(i)] = True
    misses = []
    for s in strings:
        if s in char_availability:
            str_to_char[s] = s
            char_to_str[s] = s
            char_availability[s] = False
        else:
            misses.append(s)
    for s in misses:
        c = None
        for k,v in char_availability.iteritems():
            if v:
                c = k
        if c is None:
            raise RuntimeError, "Character map limit exceeded."
        str_to_char[s] = c
        char_to_str[c] = s
        char_availability[c] = False
    return (char_to_str, str_to_char)

class CharacterMapTestCase(unittest.TestCase):
    def test(self):
        strings = ['a', 'z', 'z_h', 'b' ]
        (char_to_str, str_to_char) = create_char_maps(strings)
        for s in strings:
            mapped = str_to_char[s]
            unmapped = char_to_str[str_to_char[s]]
            print s, " -> ", mapped, " -> ", unmapped
            self.assertEquals(s, unmapped)
        

if __name__ == "__main__":
    unittest.main()
    
    
    
    
    
    
    
    
    
    
    
    
    