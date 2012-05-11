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

from charset import u2a
import unittest

class WordCategories:
    """
    Singleton word categories class
    """
    DEFAULT_CATEGORIES = ['Proper Noun', 'Foreign', 'Partial']
    class __impl:
        """
        Implementation of the word categories singleton
        """ 
        def __init__(self):
            """
            Initialise the WordCagegories
            """
            self.__current_categories = None
            self._setup_default_categories()

        def _setup_default_categories(self):
            """
            Sets up the default word categories
            """
            self.__current_categories = WordCategories.DEFAULT_CATEGORIES

        def set_cateogories(self, categories):
            """
            Sets the categories with a new set of categories
            @param categories: The new set of categories
            @type: C{list} of C{str}
            """
            if categories:
                self.__current_categories = categories
        
        def add_category(self, category_name):
            """
            Adds a word category
            @param category_name: The name of the category to add
            @type category_name: C{str}
            """ 
            if category_name not in self.__current_categories:
                self.__current_categories.append(category_name)

        def edit_category(self, original_category_name, new_category_name):
            """
            Edits a word category
            @param original_category_name: The name of the category to edit
            @type original_category_name: C{str}
            @param new_category_name: The new category name
            @type new_category_name: C{str}
            """
            if original_category_name in self.__current_categories:
                index = self.__current_categories.index(original_category_name)
                self.__current_categories[index] = new_category_name

        def remove_category(self, category_name):
            """
            Removes a word category_name 
            @param category_name: The name of the category to remove
            @type category_name: C{str}
            """
            if category_name in self.__current_categories:
                self.__current_categories.remove(category_name)

        def get_current_categories(self):
            """
            Get the current categories
            return: The current categories
            @rtype: C{list} of C{str}
            """
            return self.__current_categories

    __instance = None

    def __init__(self):
        """
        Create the WordCategories singleton instance
        """
        if WordCategories.__instance is None:
            WordCategories.__instance = WordCategories.__impl()

    def __getattr__(self, attr):
        """ 
        Delegate access to implementation 
        """
        return getattr(self.__instance, attr)

    def __setattr__(self, attr, value):
        """ 
        Delegate access to implementation 
        """
        return setattr(self.__instance, attr, value)

class Word:
    """
    Data associated with words, eg. pronunciation.
    """

    # Word status constants
    STATUS_UNVERIFIED = 0
    STATUS_CORRECT = 1
    STATUS_INVALID = 2
    STATUS_UNCERTAIN = 3
    STATUS_AMBIGUOUS = 4  

    # Word categories
    CATEGORY_PROPER_NOUN = 0
    CATEGORY_FOREIGN = 1
    CATEGORY_PARTIAL = 2

    STATUS_NAMES = {STATUS_UNVERIFIED:'Unverified',
                   STATUS_CORRECT:'Correct',
                   STATUS_INVALID:'Invalid',
                   STATUS_UNCERTAIN:'Uncertain',
                   STATUS_AMBIGUOUS:'Ambiguous'}

    #WORD_CATEGORIES = {CATEGORY_PROPER_NOUN:'Proper Noun',
    #                   CATEGORY_FOREIGN:'Foreign',
    #                   CATEGORY_PARTIAL:'Partial'}                   

    def __init__(self, word, phonemes=None, status=0, error=0, categories={}):
        """
        Initialises the phoneme data object
        @param word: The word
        @type word: c{str}
        @param phonemes: The phoneme list
        @type phonemes: C{List}
        @param status: Word status as set by dictionary file.
        @type status: C{int}
        @param error: Word error as set by dictionary file.
        @type error: C{int}
        @param categories: dictionary containing C{WORD_CATEGORIES} names as keys and {TRUE|FALSE}
        values indicating whether a category is set for this word
        @type categories: C{dict} containing C{str} WORD_CATEGORIES keys and C{TRUE|FALSE}
        values
        """
        self.phonemes = phonemes
        self.pronunciation_variants = {}
        self.default_pronunciation = None
        if phonemes == None:
            self.phonemes = []        
        self.graphemes = list(word)
        self.status = status
        self.error = error
        self.categories = {}        
        default_word_categories = WordCategories().get_current_categories()
        for cat_name in categories.keys():
            if cat_name in default_word_categories:
                self.categories[cat_name] = categories[cat_name]
            else:
                raise Exception("Invalid category detected: %s,%s" % (str(cat_name),\
                                                                      str(categories[cat_name])))
        if phonemes is not None and len(phonemes) > 0:
            self.pronunciation_variants[self.get_pronunciation_str(phonemes)] = (phonemes, status, error)
            self.set_default_pronunciation(phonemes)

    def set_graphemes(self, graphemes):
        """
        Sets the graphemes.
        @param graphemes: List of graphemes (letters) for the word.
        @type graphemes: C{list} of C{str}
        """
        self.graphemes = graphemes
        
    def set_phonemes(self, phonemes):
        """
        Sets the phonemes. If pronunciation variants exist, the default variants phonemes will be 
        set, otherwise this first pronunciation will be the default.
        @param phonemes: The list of phonemes to be set for this word
        @type phonemes: C{list}
        """
        self.phonemes = phonemes
        if len(self.pronunciation_variants.keys()) == 0:
            self.pronunciation_variants[self.get_pronunciation_str(phonemes)] = (phonemes, 0, 0)
            self.set_default_pronunciation(phonemes)
        else:
            status = self.get_status()
            error = self.get_error()
            new_pronunciation = self.get_pronunciation_str(phonemes)
            del self.pronunciation_variants[self.default_pronunciation]            
            self.pronunciation_variants[new_pronunciation] = (phonemes, status, error)
            self.set_default_pronunciation(phonemes)

    def add_pronunciation_variant(self, phonemes, status, error=0):
        """
        Adds a pronunciation variant
        @param phonemes: The phoneme list
        @type phonemes: C{List}
        @param status: Pronunciation status
        @type status: C{int}
        @param error: Pronunciation error
        @type error: C{int}
        """        
        phoneme_str = self.get_pronunciation_str(phonemes)
        if len(phonemes) > 0 and \
            not self.pronunciation_variants.has_key(phoneme_str):            
            self.pronunciation_variants[phoneme_str] = (phonemes, status, error)
        else:
            raise Exception('Invalid phonemes or pronunciation variant already exists.')

    def edit_pronunciation(self, original_phonemes, new_phonemes):
        """
        Edits a pronunciation of this word
        @param original_phonemes: The original pronunciaiton/phonemes to be edited
        @type original_phonemes: C{list}
        @param new_phonemes: The new pronunciaiton/phonemes
        @type new_phonemes: C{list}
        @param status: Pronunciation status
        @type status: C{int}
        @param error: Pronunciation error
        @type error: C{int} 
        """
        orig_phoneme_str = self.get_pronunciation_str(original_phonemes)
        if self.pronunciation_variants.has_key(orig_phoneme_str):
            if len(new_phonemes) > 0:
                status = self.get_pronunciation_variant_status(original_phonemes)
                error = self.get_pronunciation_variant_error(original_phonemes)
                new_phoneme_str = self.get_pronunciation_str(new_phonemes)
                del self.pronunciation_variants[orig_phoneme_str]
                self.pronunciation_variants[new_phoneme_str] = (new_phonemes, status, error)
                if self.default_pronunciation == orig_phoneme_str:
                    self.set_default_pronunciation(new_phonemes)
            else:
                raise Exception('Attempt to edit variant with an invalid phonemes.')
        else:
            raise Exception('Attempt to edit invalid pronunciation variant!')

    def set_default_pronunciation(self, phonemes):
        """
        Sets the default pronunciation for this word
        @param phonemes: The pronunciation (list of phonemes) to be set as default
        @type phonemes: C{list}
        """
        phoneme_str = self.get_pronunciation_str(phonemes)
        if self.pronunciation_variants.has_key(phoneme_str):
            self.default_pronunciation = phoneme_str
        else:
            raise Exception('Attempt to set invalid pronunciaiton as the default!')

    def set_status(self, status, phonemes=None):
        """
        Sets the status for the default pronunciation for this word
        @param status: The status to be set for this word
        @type status: C{int}
        @param phonemes: If provided, the status will be set for this pronunciation
        @type phonemes: C{list}
        """
        if self.default_pronunciation and phonemes is None:
            self.status = status
            phonemes = self.get_phonemes()
            error = self.get_error()
            self.pronunciation_variants[self.default_pronunciation] = (phonemes, status, error)
        elif phonemes:
            phoneme_str = self.get_pronunciation_str(phonemes)
            if self.pronunciation_variants.has_key(phoneme_str):
                error = self.get_pronunciation_variant_error(phonemes)
                self.pronunciation_variants[phoneme_str] = (phonemes, status, error)
            else:
                raise Exception('Attempt to set status for invalid pronunciation/phonemes')
        else:
            raise Exception('No pronunciation exists yet for this word.')

    def set_category(self, category_name, state=True):
        """
        Set a category for this word C{WORD_CATEGORIES} as C{TRUE} or C{FALSE}.
        @param category_name: The category name to set.
        @type category_name: C{str}
        @param state: The state of the category C{TRUE|FALSE}
        @type state: C{bool}
        """
        default_word_categories = WordCategories().get_current_categories()
        if category_name in default_word_categories:
            self.categories[category_name] = state
        else:
            raise Exception('Attempt to set invalid word category')

    def edit_category(self, original_category_name, new_category_name):
        """
        Edits a word categories name
        @param original_category_name: The name of the category to edit
        @type original_category_name: C{str}
        @param new_category_name: The new category name
        @type new_category_name: C{str}
        """
        original_status = False
        if self.categories.has_key(original_category_name):
            original_status = self.categories[original_category_name]
            del self.categories[original_category_name]
        self.categories[new_category_name] = original_status

    def remove_category(self, category_name):
        """
        Removes this word category
        @param category_name: The category to delete
        @type category_name: C{str}
        """
        if self.categories.has_key(category_name):
            del self.categories[category_name]

    def get_text(self):
        """
        Return text for word.
        @returns: text for word
        @rtype: C{str}
        """
        return "".join(self.graphemes)
        
    def set_text(self,graphemes):
        """
        set text for word.
        @returns: text for word
        @rtype: C{str}
        """
       
        if len(graphemes) > 0:
            self.graphemes = list(graphemes)
        else:
            raise Exception('Attempt to set invalid word ')
    
    def edit_word(self, original_word_name, new_word_name):
        """
        Edits a word category
        @param original_word_name: The name of the word to edit
        @type new_word_name: C{str}
        @param new_word_name: The new word name
        @type new_word_name: C{str}
        """
        if original_word_name in self.__current_words:
            index = self.__current_words.index(original_word_name)
            self.__current_words[index] = new_word_name
        
        original_status = False
        if self.words.has_key(original_word_name):
            original_status = self.words[original_word_name]
            del self.words[original_word_name]
        self.words[new_word_name] = original_status

    def get_graphemes(self):
        """
        Returns graphemes for word.
        @return: A list of letters.
        @rtype: C{list} of C{str}
        """
        return self.graphemes
    
    def get_pronunciations(self):
        """
        Returns all of the pronunciations for this word        
        @return: A list of pronunciations for this word
        @rtype: C{list} of C{list}
        """
        pronunciations = []
        for pronunciation_key in self.pronunciation_variants.keys():
            pronunciations.append(self.pronunciation_variants[pronunciation_key][0])
        return pronunciations

    def get_pronunciation(self, phoneme_str):
        """
        The phoneme list corresponding to the provided phoneme string is returned.
        @param phoneme_str: The phoneme string for which to find a corresponding phoneme list.
        @type phoneme_str: C{str}
        @return: The corresponding phoneme list.
        @rtype: C{list}
        """
        if self.pronunciation_variants.has_key(phoneme_str):
            phonemes = self.pronunciation_variants[phoneme_str][0]
            return phonemes
        else:
            return None

    def get_pronunciation_variant_status(self, phonemes=None, phoneme_str=None):
        """
        Gets the status for the specified pronunciation/phonemes
        @param phonemes: The phoneme list "pronunciation"
        @type phonemes: C{List}
        @param phonemes: The phoneme string "pronunciation"
        @type phonemes: C{List}
        @return: The status for the specified pronunciation/phonemes
        @rtype: C{int}
        """
        try:
            if phonemes or phoneme_str:
                if phonemes:
                    phoneme_str = self.get_pronunciation_str(phonemes)    
                pronunciation_status = self.pronunciation_variants[phoneme_str][1]
                return pronunciation_status
            else:
                return None
        except Exception, e:
            raise Exception("Pronunciation does not exist for this word: %s" %(e))       

    def get_pronunciation_variant_error(self, phonemes):
        """
        Gets the error for the specified pronunciation/phonemes
        @param phonemes: The phoneme list/"pronunciation"
        @type phonemes: C{List}
        @return: The error for the specified pronunciation/phonemes
        @rtype: C{int}
        """
        try:            
            phoneme_str = self.get_pronunciation_str(phonemes)
            pronunciation_error = self.pronunciation_variants[phoneme_str][2]            
            return pronunciation_error
        except Exception, e:
            raise Exception("Pronunciation does not exist for this word: %s" %(e)) 

    def get_phonemes(self):
        """
        Returns the default pronunciaiton list of phonemes for this word
        @return: The list of phonemes for this word
        @rtype: C{list}
        """
        if self.default_pronunciation:
            return self.pronunciation_variants[self.default_pronunciation][0]
        else:
            return []

    def get_pronunciation_str(self, phonemes=None):
        """
        Returns the pronunciation (list of phonemes as a string)
        @param phonemes: The phoneme list
        @type phonemes: C{List}
        @return: The pronunciation string
        @rtype: C{str}
        """
        if phonemes is None:
            phonemes = self.get_phonemes()
        phoneme_str = ''        
        for phoneme in phonemes:
            phoneme_str += phoneme + ' '
        phoneme_str = phoneme_str[0:len(phoneme_str) - 1]
        return phoneme_str

    def get_status(self):
        """
        Returns the defualt pronunciations status
        @return: status of the word
        @rtype: C{int}
        """
        if self.default_pronunciation:
            return self.pronunciation_variants[self.default_pronunciation][1]
        else:
            return self.STATUS_UNVERIFIED

    def get_error(self):
        """
        Returns the default pronunciations error
        @return: error for the pronunciation
        @rtype: C{int}
        """
        if self.default_pronunciation:
            return self.pronunciation_variants[self.default_pronunciation][2]
        else:
            return 0

    def get_categories(self):
        """
        Returns the words categories
        @return: categories of the word
        @rtype: C{dict} of {C{int}:C{bool}}
        """
        return self.categories        
        
    def __str__(self):
        """
        Overriding "to string" method.
        """
        display_string = ""
        display_string = display_string + '"%s"' % u2a(self.get_text())
        if len(self.phonemes) > 0:
            display_string += ' "'
            for i in range(len(self.phonemes)):
                if i > 0:
                    display_string += ' '
                display_string += u2a(self.phonemes[i])
            display_string += '"'
        display_string += ' %d %d' % (self.status, self.error)
        return display_string
    
    def __cmp__(self, other):
        """
        Overrides comparison operator.
        @param other: other word
        @type other: Word
        @returns: comparison result (1,0, or -1)
        @rtype: int
        """
        if len(self.phonemes) != len(other.phonemes):
            return len(self.phonemes) - len(other.phonemes)
        for i in range(len(self.phonemes)):
            if self.phonemes[i] != other.phonemes[i]:
                return -1
        if len(self.graphemes) != len(other.graphemes):
            return len(self.graphemes) - len(other.graphemes)
        for i in range(len(self.graphemes)):
            if self.graphemes[i] != other.graphemes[i]:
                return -1
        if self.status != other.status:
            return -1
        if self.error != other.error:
            return -1
        return 0
        
class WordTestCase(unittest.TestCase):
    """
    Test case for the Word object.
    """
    def test_comparator(self):
        """
        Test Word __cmp__ method.
        """
        w1 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        w2 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        self.assertEqual(w1, w2)
        self.assertEqual("hello", w1.get_text())
        w1 = Word("hellos", ['h', 'e', 'l', 'o'], 0, 0)
        w2 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        self.assertNotEqual(w1, w2)
        w1 = Word("hello", ['h', 'e', 'l', 'o', 's'], 0, 0)
        w2 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        self.assertNotEqual(w1, w2)
        w1 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        w2 = Word("hello", ['h', 'e', 'l', 'o'], 1, 0)
        self.assertNotEqual(w1, w2)
        w1 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        w2 = Word("hello", ['h', 'e', 'l', 'o'], 0, 1)
        self.assertNotEqual(w1, w2)

    def test_get_text(self):
        """
        Test Word get_text method.
        """
        w1 = Word("hello", ['h', 'e', 'l', 'o'], 0, 0)
        self.assertEqual(w1.get_text(), "hello")
        
        
if __name__ == "__main__":
    unittest.main()
        
        
        
