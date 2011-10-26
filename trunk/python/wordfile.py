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

class WordFile:
    """
        Word file import/export class.
    """
    def from_file(self, path):
        """
        Loads words from a file into a word list
        @param path: Absolute path to the words file
        @type path: C{str}
        @return: list of word strings
        @rtype: C{list} of C{str}
        """
        words = []
        lines = open(path, 'U').readlines()
        for line in lines:
            word = line.replace('\n','')
            try:
                word = unicode(word, 'utf-8')
            except Exception as detail:
                raise RuntimeError, "Word format error [%s]" % detail
            words.append(word)
        return words

    def to_file(self, words, path):
        """
        Saves list of words to a word list file.
        @param words: List of word strings.
        @type words: C{List}
        @param path: Absolute path to the words
        @type path: C{str}
        """
        words_file = open(path, 'w')
        for word in words:
            line = (word + u'\n').encode('utf-8')
            words_file.write(line)
        words_file.close()


class WordFileTestCase(unittest.TestCase):
    """
    Tests case for the Words class
    """
    def test_from_to_file(self):
        """
        Test case for "from_file" and "to_file".
        """
        from_file_path = '../test_data/setswana.wdl'
        to_file_path = '/tmp/setswana.wdl'
        words = WordFile().from_file(from_file_path)
        WordFile().to_file(words, to_file_path)
        from_file_lines = open(from_file_path, 'U').readlines()
        to_file_lines = open(to_file_path, 'U').readlines()    
        self.assertEquals(len(from_file_lines), len(to_file_lines), \
                          "Words file content length differs")        
        for i in range(len(from_file_lines)):
            self.assertEquals(from_file_lines[i], to_file_lines[i], "Word file content differs")
        

if __name__ == '__main__':
    unittest.main()

        



