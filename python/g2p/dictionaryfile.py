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
from word import Word, WordCategories

class DictionaryFile:
    """
        Dictionary file import/export class.
    """
    DICTIONARY_FORMAT_COMMENT = '## Dictionary Maker Format: Word; Pronunciation; Status; Error;'

    def from_file(self, path):
        """
        Loads dictionary from file.
        @param path : Path to dictionary file.
        @type path: C{string}
        @returns : List of C{Word} objects.
        @rtype: C{List} of C{Word}
        """
        dictionary_entries = []
        temp_dictionary_entries = {}
        category_names = []
        lines = open(path, 'U').readlines()
        for line in lines:
            line = unicode(line, "utf-8")
            if line.__contains__(DictionaryFile.DICTIONARY_FORMAT_COMMENT):
                line = line.replace('\n','')
                tmp_categories = line.split(DictionaryFile.DICTIONARY_FORMAT_COMMENT)[1].split(';')
                for cat in tmp_categories:
                    if len(cat) > 0:
                        formatted_name = ''
                        category_name_parts = cat.split(' ')
                        for part in category_name_parts:
                            if len(part) > 0:
                                formatted_name += part + ' '
                        if formatted_name[-1] == ' ':
                            formatted_name = formatted_name[0:len(formatted_name) - 1]
                        category_names.append(formatted_name)
            elif line[0] == '#':
                pass                
            else:
                parts = line.split()
                word = None
                phonemes = None
                status = None
                error = None
                trailing_info_len = len(category_names) + 2
                if len(parts) >= 4:                                
                    word = parts[0]
                    # TODO: Verify word.
                    phonemes = parts[1:len(parts) - trailing_info_len]
                    # TODO: Verify phoneme strings                       
                elif len(parts) == (1 + trailing_info_len):
                    word = parts[0]
                    phonemes = []
                else:
                    raise RuntimeError, "Dictionary format error"
                if len(parts) >= (1 + trailing_info_len):
                    try:
                        status = int(parts[len(parts) - (trailing_info_len )])
                        error = int(parts[len(parts) - (trailing_info_len - 1)])                        
                        category_values = {}
                        if len(category_names) > 0:
                            for i in range(len(category_names)):
                                tmp_cat_value = int(parts[len(parts) - (len(category_names) - i)])
                                category_values[category_names[i]] = tmp_cat_value
                    except ValueError as detail:
                        raise RuntimeError, "Dictionary format error [%s]" % detail
                else:
                    raise RuntimeError, "Dictionary format error"
                if temp_dictionary_entries.has_key(word):
                    pronunciations = temp_dictionary_entries[word]
                    pronunciations.append((phonemes, status, error, category_values))
                    temp_dictionary_entries[word] = pronunciations
                else:
                    temp_dictionary_entries[word] = [(phonemes, status, error, category_values)]
        for category_name in category_names:            
            WordCategories().add_category(category_name)
        for temp_dict_entry in temp_dictionary_entries.keys():
            word = temp_dict_entry
            first_phonemes = temp_dictionary_entries[word][0][0]
            first_status = temp_dictionary_entries[word][0][1]
            first_error = temp_dictionary_entries[word][0][2]
            first_categories = temp_dictionary_entries[word][0][3]
            new_word = Word(word, first_phonemes, first_status, first_error, first_categories)
            for i in range(1,len(temp_dictionary_entries[word])):
                next_phonemes = temp_dictionary_entries[word][i][0]
                next_status = temp_dictionary_entries[word][i][1]
                next_error = temp_dictionary_entries[word][i][2]
                next_categories = temp_dictionary_entries[word][i][3]
                new_word.add_pronunciation_variant(next_phonemes, next_status, next_error)#, next_categories)
            dictionary_entries.append(new_word)
        return dictionary_entries

    def to_file(self, dictionary_entries, path):
        """
        Save dictionary to file.
        @param dictionary_entries: List of C{Word} objects.
        @type dictionary_entries: C{List} of C{Word}
        @param path : Path to write.
        @type path: C{string}
        """
        to_file = open(path, 'w')
        dictionary_format_comment = DictionaryFile.DICTIONARY_FORMAT_COMMENT
        default_word_categories = WordCategories().get_current_categories()
        for category_name in default_word_categories:
            dictionary_format_comment += ' %s;' %(category_name)
        dictionary_format_comment += '\n'        
        to_file.write(dictionary_format_comment.encode('utf-8'))
        dictionary_file_lines = []
        for word in dictionary_entries:
            line = ''
            word_text = word.get_text()
            pronunciations = word.get_pronunciations()
            for pronunciation in pronunciations:
                line += word_text + ' '
                for phoneme in pronunciation:
                    line += phoneme + ' '
                status = word.get_pronunciation_variant_status(pronunciation)
                error = word.get_pronunciation_variant_error(pronunciation)
                line += str(status) + ' '
                line += str(error) + ' '
                word_categories_str = ''
                word_categories = word.get_categories()
                for default_name in default_word_categories:
                    status = False
                    if word_categories.has_key(default_name):
                        status = word_categories[default_name]
                    word_categories_str += str(int(status))
                    word_categories_str += ' '  
                line += word_categories_str + '\n'
            dictionary_file_lines.append(line)
        dictionary_file_lines.sort()
        for line in dictionary_file_lines:
            to_file.write(line.encode('utf-8'))
        to_file.close()

class DictionaryFileTestCase(unittest.TestCase):
    """
    Test case for the Dictionary object.
    """
    def test_to_from_file(self):
        """
        Test dictionary file loading and saving.
        """
        from_file = '../test_data/setswana.dict'
        to_file = '/tmp/setswana.dict'        
        dictionary_entries = DictionaryFile().from_file(from_file)
        DictionaryFile().to_file(dictionary_entries, to_file)
        from_lines = open(from_file, 'U').readlines()
        to_lines = open(to_file, 'U').readlines()
        from_lines.sort()
        to_lines.sort()
        self.assertEquals(len(from_lines), len(to_lines), 'Dictionary sizes differ')
        for i in range(0, len(from_lines)):
            from_parts = from_lines[i].split()
            to_parts = to_lines[i].split()            
            self.assertEquals(from_parts, to_parts, 'Dictionary contents differ')
        # Bad file test.
        self.assertRaises(RuntimeError, DictionaryFile().from_file, '../test_data/setswana_bad.pho')

if __name__ == '__main__':
    unittest.main()
