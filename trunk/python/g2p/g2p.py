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

import sys
import unittest
import copy
import re

from application import Application
from dictionaryfile import DictionaryFile
from wordfile import WordFile
from charset import u2a
from g2p_pattern import Pattern
from word import Word
import cPickle as pickle
from multiprocessing import Process, Pipe
from time import sleep
import ctypes
from ctypes import *
import platform

def init_count_map(graphemes, phonemes):
    """
    Create a mapping graphemes to phonemes with an initial count value of 1.
    @param graphemes: List of graphemes
    @type graphemes: C{list} of C{str}
    @param phonemes: List of phonemes
    @type phonemes: C{list} of C{str}
    @return: Mapping
    @rtype: C{dict}
    """
    count_map = {}
    for g in graphemes:
        count_map[g] = {}
        for p in phonemes:
            count_map[g][p] = 1
    return count_map

def update_count_map(dict, count_map):
    """
    Update grapheme/phoneme counts using the given dictionary.
    @param dict: List of Words
    @type dict: C{List} of C{Word}
    @param count_map: Grapheme/phoneme count mapping
    @type count_map: C{dict}
    """
    for w in dict:
        graphs = w.get_graphemes()
        phones = w.get_phonemes()
        if len(graphs) == len(phones):
            for i in range(len(graphs)):
                count_map[graphs[i]][phones[i]] += 1

class G2PUpdater(Process):
    """
    G2P update process
    """
    def __init__(self, dict, pipe):
        """
        Initialize G2P update process
        @param dict: Dictionary of words to process.
        @type dict: C{list} of C{Word}
        @param pipe: Communication pipe.
        @type pipe: C{Pipe}
        """
        Process.__init__(self)
        log = Application().get_log()
        log.info("G2PUpdater.__init__()")
        self.dict = dict
        self.pipe = pipe

    def run(self):
        """
        Run G2P update process
        """
        log = Application().get_log()
        log.info("G2PUpdater.run()")
        g2p = G2P()
        g2p.set_dictionary(self.dict)
        log.info("G2PUpdater updating rules...")
        g2p.update_rules()
        log.info("G2PUpdater updating rules complete")
        self.pipe.send((g2p.character_map, g2p.rules))
        log.info("G2PUpdater exiting run block")

class G2P:
    """
    Grapheme to Phoneme prediction.
    """
    MAX_PATTERN_LEN = 8
    MIN_PATTERN_LEN = 1

    def __init__(self):
        """
        G2P constructor.
        """
        self.log = Application().get_log()
        self.log.debug("G2P.__init__()")
        self.dict = None                  # All words being considered
        self.graphemes = None             # Grapheme list
        self.phonemes = None              # Phoneme list
        self.character_map = None         # Maps phonemes to single characters for convenience
        self.aligned_graphemes = None
        self.aligned_phonemes = None
        self.gnulled_dict = None
        self.aligned_dict = None
        self.patterns = None
        self.rules = []
        self.setup_g2plib()

    def setup_g2plib(self):
        """
        Setup G2P C++ library bindings
        """
        system = platform.system()
        if system == 'Linux':
            self.g2plib = cdll.LoadLibrary("libg2p.so")
        elif system == 'Windows':
            self.g2plib = cdll.LoadLibrary("WinG2PDLL.dll")
        else:
            raise OSError
        self.g2plib.set_grapheme.argtypes = [ c_char ]
        self.g2plib.add_pattern.argtypes = [ c_int, c_char_p, c_wchar_p ]
        self.g2plib.generate_rules.restype = POINTER(c_char_p)
        self.g2plib.set_rules.argtypes = [ POINTER(c_char_p), c_int ]
        self.g2plib.predict_pronunciation.argtypes = [ c_wchar_p ]
        self.g2plib.predict_pronunciation.restype = c_wchar_p

    def set_dictionary(self, dict):
        """
        Set G2P dictionary.
        @param: list of words
        @type dict: C{list} of C{Word}
        """
        self.dict = copy.deepcopy(dict)
        self.generate_graphemes()
        self.generate_phonemes()
        self.generate_character_map()
        self.align_words()
        self.extract_patterns()
        
    def get_dictionary(self):
        """
        Return active dictionary.
        @returns: list of words
        @rtype: C{list} of C{Word}
        """
        return self.dict

    def update_rules(self):
        """
        Update rules with current word list
        """
        self.log.debug("G2P.update_rules()")
        self.generate_rules()
        ctype_rules = (c_char_p * len(self.rules))()
        ctype_rules[:] = self.rules
        self.g2plib.set_rules(ctype_rules, len(ctype_rules))

    def update_rules_async(self, dict):
        """
        Update rules with current word list asynchronously.  Call callback when complete.
        Keep old prediction rules active during new rule processing.
        """
        self.log.debug("G2P.update_rules_async()")
        self.pipe, pipe = Pipe()
        self.updater = G2PUpdater(dict, pipe)
        self.updater.start()

    def poll_update_rules_async(self):
        """
        Polls asynchronous rule update.  Must be called periodically until it returns
        False.
        @returns: True if rule update is still processing, otherwise False.
        @rtype: C{boolean}
        """
        is_updating = True
        if not self.updater.is_alive():
            return False
        while self.pipe.poll():
            (self.character_map, self.rules) = self.pipe.recv()
            ctype_rules = (c_char_p * len(self.rules))()
            ctype_rules[:] = self.rules
            self.g2plib.set_rules(ctype_rules, len(ctype_rules))
            is_updating = False
        return is_updating

    def abort_update_rules_async(self):
        """
        Abort rule update process.
        """
        self.updater.terminate()

    def predict_pronunciation(self, word_str):
        """
        Predict pronunciation of a word.
        @param word_str: List of predicted phonemes
        @type word_str: C{list} of C{str}
        """
        if len(self.rules) == 0:
            self.log.warn('G2P.predict_pronunciation(): G2P rules not yet built')
            return []
        self.log.debug('G2P.predict_pronunciation("%s")' %word_str)
        mapped_phonemes = self.g2plib.predict_pronunciation(word_str)
        if mapped_phonemes == None:
            return []
        phonemes = []
        for c in mapped_phonemes:
            for k,v in self.character_map.items():
                if c == v:
                    phonemes.append(k)
        return phonemes

    def generate_graphemes(self):
        """
        Step 2. Generate grapheme list from word list.        
        """
        self.log.debug("G2P.generate_graphemes()")
        # Add null grapheme possibility
        self.graphemes = [ u'0' ]
        for w in self.dict:
            self.graphemes.extend(w.graphemes)
        self.graphemes = list(set(self.graphemes))
        
    def generate_phonemes(self):
        """
        Step 3. Generate phoneme list from word list.  
        """
        self.log.debug("G2P.generate_phonemes()")
        self.phonemes = []
        for w in self.dict:
            for p in w.get_phonemes():
                self.phonemes.append(p)
        self.phonemes = list(set(self.phonemes))
        
    def generate_character_map(self):
        """
        Step 4. Generate mapping of phonemes to single characters.
        
        Note, this is Required by libG2P as an optimization.        
        """
        self.log.debug("G2P.generate_character_map()")
        self.character_map = {}        
        char_value = ord('A')
        for p in self.phonemes:
            if not p in self.character_map:
                self.character_map[p] = chr(char_value)
                char_value += 1
                if char_value == ord('Z') + 1:
                    char_value = ord('a')
                if char_value > ord('z'):
                    raise RuntimeError, "Character map limit exceeded."

    def generate_probability_maps(self, align_counts, gnull_counts):
        """
        Calculate probabilities based on count maps.
        @param align_counts: Counts the number of times X aligns with Y
        @type align_counts: C{dict}
        @param gnull_counts: Counts the number of times X aligns to Y after a there was a 
                             previous alignment to 0
        @type gnull_counts: C{dict}
        @returns: tuple of probability maps
        @rtype: ( C{dict} of C{int}, C{dict} of C{int} )
        """
        # Initialize
        align_probs = {}
        gnull_probs = {}
        for g in self.graphemes:
            align_probs[g] = {}
            gnull_probs[g] = {}
            for p in self.phonemes:
                align_probs[g][p] = 0
                gnull_probs[g][p] = 0
        # Calculate
        scale_factor = float(1)
        for g in self.graphemes:
            g_total = 0
            g_total_0 = 0
            for p in self.phonemes:
                g_total += align_counts[g][p]
                g_total_0 += gnull_counts[g][p]
            g_total_all = g_total + g_total_0
            for p in self.phonemes:
                align_probs[g][p] = scale_factor * align_counts[g][p] / g_total_all
                gnull_probs[g][p] = scale_factor * gnull_counts[g][p] / g_total_all    
        return (align_probs, gnull_probs)

    def generate_word_gnulls(self, word, align_probs, gnull_probs):
        """
        Generate graphemic nulls for given word.
        @param word: a word
        @type word: C{Word}
        @param align_probs: Alignment probability map
        @type align_probs: C{dict} of C{int}
        @param gnull_probs: Graphemic null map
        @type align_probs: C{dict} of C{int}
        """
        try:
            label = " ".join(word.get_text())
            g_states = list(word.graphemes)
            p_states = list(word.phonemes)
            free_phones = len(p_states) - len(g_states)
    
            # Allows first grapheme to be null
            g_states.insert(0, '0')
            
            # Initialize map of grapheme/phoneme probability scores.  Scores 
            # represent best probobilities at a given point.
            scores = {}
            for p_i in range(len(p_states)):
                if p_i not in scores:
                    scores[p_i] = {}
                for g_i in range(len(g_states)):
                    scores[p_i][g_i] = 0
            scores[0][0] = align_probs[g_states[0]][p_states[0]]
            scores[0][1] = align_probs[g_states[1]][p_states[0]]
    
            # Backtrack maps grapheme/phoneme pairs with a list of intervening 
            # phonemes.  This is the best path (indices) to get from the grapheme 
            # to the phoneme.
            backtrack = {}        
            for p_i in range(len(p_states)):
                if p_i not in backtrack:
                    backtrack[p_i] = {}
                for g_i in range(len(g_states)):
                    backtrack[p_i][g_i] = []
            backtrack[0][0] = [ 0 ]
            backtrack[0][1] = [ 1 ]
            for i in range(2, len(g_states)):
                backtrack[0][i].append(i)
    
            # Counts how many gnulls have been inserted for given path.  Used as an 
            # optimization to short-circuit search loop because you can't insert 
            # more than are available.
            null_counts = {}
            for p_i in range(len(p_states)):
                null_counts[p_i] = {}
                for g_i in range(len(g_states)):
                    null_counts[p_i][g_i] = 0
            null_counts[0][0] = 1
            null_counts[0][1]
            
            pre_backtrack = list(backtrack[len(p_states)-1][len(g_states) -1])
            
            # For each phoneme, calculate the best path 
            for p_i in range(1,len(p_states)):
                for g_i in range(len(g_states)):
                    # Search all possible paths and keep the best to be in state g_i 
                    # at time p_i.  This is the best route from p_states[t] to p_states[t+1]
                    p_score = 0
                    g_j_max = 0
                    for g_j in range(len(g_states)):
                        # Possible route g_j to g_i
                        score = 0
                        if g_i == g_j and null_counts[p_i-1][g_j] < free_phones:
                            score = float(scores[p_i-1][g_j] * align_probs['0'][p_states[p_i]])                            
                        elif g_i == g_j+1:
                            score = float(scores[p_i-1][g_j] * align_probs[g_states[g_i]][p_states[p_i]])
                        else:
                            score = 0
                        if score >= p_score:
                            p_score = score
                            g_j_max = g_j
                    scores[p_i][g_i] = p_score
                    backtrack[p_i][g_i] = list(backtrack[p_i-1][g_j_max])
                    backtrack[p_i][g_i].append(g_i)
                    bt_list = list(backtrack[p_i][g_i])
                    if bt_list[-1] == bt_list[-2]:
                        null_counts[p_i][g_i] = null_counts[p_i-1][g_j_max] + 1
                    else:
                        null_counts[p_i][g_i] = null_counts[p_i-1][g_j_max]
    
            
            final_graphs = word.graphemes
            final_backtrack = list(backtrack[len(p_states)-1][len(g_states) -1])
            final_graphs = []
            final_graphs.append(g_states[final_backtrack[0]])
            for i in range(1, len(final_backtrack)):
                if final_backtrack[i] == final_backtrack[i-1]:
                    final_graphs.append('0')
                else:
                    final_graphs.append(g_states[final_backtrack[i]])
    
            return (final_graphs, scores[len(p_states)-1][len(g_states)-1])
        except:
            self.log.error("generate_word_gnulls(): Exception caught word=%s, phones=[ %s] " \
                            %(word.get_text(), ",".join(word.get_phonemes())))
            raise
    
    def generate_gnulled_dict(self):
        """
        Iterate through dictionary and substitute gnull markers ('0') for graphemes where
        one to one grapheme/phoneme alignment is not possible.
        """
        gnull_subs = {}
        t_prob = 0
        p_prob = 0
        prob_threshold = 1
        # 'align_counts' counts the number of grapheme/phoneme alignments.
        align_counts = init_count_map(self.graphemes, self.phonemes)
        update_count_map(self.dict, align_counts)        
        # 'gnull_counts' count the number of times a grapheme aligned to a phoneme after a there
        # was a previous alignment to '0'.
        gnull_counts = init_count_map(self.graphemes, self.phonemes)
        # Calculate probabilities based on current counts.
        (align_probs, gnull_probs) = self.generate_probability_maps(align_counts, gnull_counts)
        while p_prob == 0 or t_prob/p_prob > prob_threshold:
            p_prob = t_prob
            t_prob = 0
            self.log.debug("generate_gnull_subs(): Recalculating probabilities")
            align_counts = init_count_map(self.graphemes, self.phonemes)
            update_count_map(self.dict, align_counts)                
            gnull_counts = init_count_map(self.graphemes, self.phonemes)
            for i in range(len(self.dict)):
                w = self.dict[i]
                if (len(w.get_graphemes()) < len(w.get_phonemes())):
                    (graphs, g_prob) = self.generate_word_gnulls(w, align_probs, gnull_probs)
                    t_prob += g_prob
                    # For each gnull found, capture one character before and one after, when
                    # possible.  Eg. au0tonomou0s would yield "u0t" and "u0s".                    
                    for m in re.finditer('(.{0,1}0.{0,1})', "".join(graphs)):
                        replace = m.group(0)
                        find = replace.replace("0", "")
                        gnull_subs[find] = replace                        
                    for i in range(0, len(graphs)):
                        align_counts[graphs[i]][w.phonemes[i]] += 1
            if t_prob == 0:
                break
            # Recalculate probabilities based on current counts.
            (align_probs, gnull_probs) = self.generate_probability_maps(align_counts, gnull_counts)
        
        self.gnulled_dict = copy.deepcopy(self.dict)
        for i in range(len(self.gnulled_dict)):
            graphs = self.gnulled_dict[i].get_text()
            for (find, replace) in gnull_subs.items():
                if len(replace) == 2:
                    if replace[0] == '0':
                        # replaces at beginning of word, only
                        if graphs[0] == find:
                            graphs = replace + graphs[1:]
                    else:
                        # replaces at end of word, only
                        if graphs[-1:] == find:
                            graphs = graphs[:-1] + replace
                else:
                    graphs = graphs.replace(find, replace)                
            graphs = graphs.replace('00', '0')
            if self.gnulled_dict[i].get_text() != graphs:
                self.gnulled_dict[i].set_text(graphs)
    
    def align_word(self, w_graphs, w_phones, align_probs, gnull_probs):
        """
        Align word
        @param w_graphs: aligned graphemes for the given word
        @type w_graphs: C{list} of C{str}
        @param w_phones: aligned phonemes for the given word
        @type w_phones: C{list} of C{str}
        @param align_probs: Alignment probabilities
        @type align_probs: C{dict}
        @param gnull_probs: Gnull alignment probabilities
        @type gnull_probs: C{dict}
        @returns: tuple of aligned graphemes, aligned phonemes, and overall score.
        @rtype: ( C{int}, C{list} of C{str}, C{list} of C{str} )
        """
        # 'free_graph_count' is the number of graphemes without a corresponding phoneme.
        free_graph_count = len(w_graphs) - len(w_phones)        
        if free_graph_count == 0:
            return (1, w_graphs, w_phones)
        if (free_graph_count < 0):
            return (0, w_graphs, w_phones)
            
        g_states = list(w_graphs)
        p_states = list(w_phones)

        # 'score' maps grapheme/phoneme pairs with probability score.
        score = {}
        for g_i in range(len(g_states)):
            if g_i not in score:
                score[g_i] = {}
            for p_i in range(len(p_states)):
                score[g_i][p_i] = 1.0

        # 'backtrack' maps grapheme/phoneme pairs with list of intervening phonemes.
        backtrack = {}        
        for g_i in range(len(g_states)):
            if g_i not in backtrack:
                backtrack[g_i] = {}
            for p_i in range(len(p_states)):
                backtrack[g_i][p_i] = [ p_i ]
        
        # 'count' maps grapheme/phoneme pairs (by index) to raw counts.
        counts = {}
        for g_i in range(len(g_states)):
            if g_i not in counts:
                counts[g_i] = {}
            for p_i in range(len(p_states)):
                counts[g_i][p_i] = 0

        for g_i in range(1, len(g_states)):
            for p_i in range(len(p_states)):
                m_score = 0
                i_max = 0
                for p_j in range(len(p_states)):
                    if p_j == p_i and counts[g_i - 1][p_j] < free_graph_count:
                        road = backtrack[g_i - 1][p_j]
                        num = len(road) - 1
                        while num > 0 and num < len(road) and road[num] == p_i:
                            num -= 1
                        t_score = 0
                        if g_states[g_i] in gnull_probs and \
                           p_states[p_i] in gnull_probs[g_states[g_i]]:
                            t_score = score[g_i - 1][p_j] * \
                                gnull_probs[g_states[g_i]][p_states[p_i]]                        
                    elif p_i == p_j + 1:
                        t_score = 0
                        if g_states[g_i] in align_probs and \
                           p_states[p_i] in align_probs[g_states[g_i]]:
                            t_score = score[g_i - 1][p_j] * \
                                align_probs[g_states[g_i]][p_states[p_i]]
                    else:
                        t_score = 0
                    if t_score >= m_score:
                        m_score = t_score
                        i_max = p_j
                score[g_i][p_i] = m_score
                backtrack[g_i][p_i] = list(backtrack[g_i - 1][i_max])
                backtrack[g_i][p_i].append(p_i)
                counts[g_i][p_i] = 0                                
                # Check if last two backtrack items match.
                if backtrack[g_i][p_i][-1] == backtrack[g_i][p_i][-2]:
                    counts[g_i][p_i] = counts[g_i - 1][i_max] + 1
                else:                    
                    counts[g_i][p_i] = counts[g_i - 1][i_max]            

        final = backtrack[len(g_states)-1][len(p_states)-1]
        w_phones[0] = p_states[final[0]]
        for i in range(1, len(final)):
            if final[i] == final[i-1]:
                v = '0'
            else:
                v = p_states[final[i]]
            try:
                w_phones[i] = v
            except IndexError:
                w_phones.append(v)
        final_score = score[len(w_graphs) - 1][len(p_states) - 1]
        return (final_score, w_graphs, w_phones)                        
    
    def align_words(self):
        """
        Step 6. Align words.        
        """        
        self.log.debug("G2P.align_words()")
        
        self.log.debug("Generating graphemic dictionary")
        self.generate_gnulled_dict()
        self.log.debug("Graphemic dictionary complete")
        #TODO: Disabled graphemic null substitution because it hurts the prediction results.
        #      Have kept the graphemic null generation above so that it continues to be tested
        #      and validated during development.
        #self.aligned_dict = copy.deepcopy(self.gnulled_dict)
        
        self.aligned_dict = copy.deepcopy(self.dict)

        # Count the number of times X aligns to Y.
        align_counts = init_count_map(self.graphemes, self.phonemes)
        update_count_map(self.aligned_dict, align_counts)
        # Count the number of times X aligns to Y after a there was a previous alignment to 0
        gnull_counts = init_count_map(self.graphemes, self.phonemes)
        # Recalculate probabilities based on counts.
        (align_probs, gnull_probs) = self.generate_probability_maps(align_counts, gnull_counts)
        self.aligned_phonemes = {}
        self.aligned_graphemes = {}
        t_prob = 0
        p_prob = 0
        prob_threshold = 1
        while p_prob == 0 or t_prob/p_prob > prob_threshold:
            p_prob = t_prob
            t_prob = 0
            align_counts = init_count_map(self.graphemes, self.phonemes)
            gnull_counts = init_count_map(self.graphemes, self.phonemes)
            for w in self.aligned_dict:
                (w_prob, 
                 self.aligned_graphemes[w.get_text()],
                 self.aligned_phonemes[w.get_text()]) = \
                    self.align_word(w.get_graphemes(), w.get_phonemes(), align_probs, gnull_probs)
                t_prob += w_prob
                for i in range(len(w.get_graphemes())):
                    try:
                        if w.get_phonemes()[i] == '0':
                            count = i-1
                            while w.get_phonemes()[count] == '0':
                                count -= 1
                            gnull_counts[w.get_graphemes()[i]][w.get_phonemes()[count]] += 1
                        else:
                            align_counts[w.get_graphemes()[i]][w.get_phonemes()[i]] += 1
                    except KeyError:
                        pass
            # Recalculate probabilities based on counts.
            (align_probs, gnull_probs) = self.generate_probability_maps(align_counts, gnull_counts)

    def extract_patterns(self):
        """
        Step 7. Extract word patterns from alignment data.        
        """
        self.log.debug("G2P.extract_patterns()")
        pid = 0
        self.patterns = []
        for w in self.aligned_dict:
            w_graphs = self.aligned_graphemes[w.get_text()]
            w_phones = self.aligned_phonemes[w.get_text()]
            for i in range(len(w_graphs)):                
                phoneme = w_phones[i]
                context = " %s-%s-%s " \
                          % ("".join(w_graphs[:i]), w_graphs[i], "".join(w_graphs[i+1:]))
                self.patterns.append(Pattern(pid, phoneme, context))
                pid += 1
                
    def generate_rules(self):
        """
        Step 8. Generate word prediction rules.
        """
        self.log.debug("G2P.generate_rules()")
        self.rules = []
        for g in self.graphemes:            
            self.g2plib.set_grapheme(u2a(g))
            for p in self.patterns:
                if p.get_grapheme() == g:
                    if p.get_phoneme() != u'0':
                        mapped_phone = self.character_map[p.get_phoneme()]
                    else:
                        mapped_phone = u'0'                    
                    self.g2plib.add_pattern(p.get_id(), mapped_phone, u2a(p.get_context()))
            new_rules = self.g2plib.generate_rules()
            for rule in new_rules:
                if rule == None:
                    break
                self.rules.append(rule)
            self.g2plib.clear_patterns()
                
    def __getstate__(self):
        """
        Called when object is pickled (saved to file).
        @returns: object attribute dictionary
        @rtype: C{dict}
        """
        self.log.debug("G2P.__getstate__()")
        odict = self.__dict__.copy() # copy the dict since we change it
        # Remove data that will require re-initialization upon reload.
        del odict['log']
        del odict['g2plib']
        if 'updater' in odict:
            del odict['updater']
        if 'pipe' in odict:
            del odict['pipe']
        return odict

    def __setstate__(self, dict):
        """
        Called when object is un-pickled (loaded from file).
        """
        # Called when project is loaded from file.
        self.__dict__.update(dict)   # update attributes
        self.log = Application().get_log()
        self.log.debug("G2P.__setstate__()")
        self.setup_g2plib()
        ctype_rules = (c_char_p * len(self.rules))()
        ctype_rules[:] = self.rules
        self.g2plib.set_rules(ctype_rules, len(ctype_rules))

class G2PTestCase(unittest.TestCase):
    """
    Test case for the G2P object.
    """
    TSN_FULL_DICT_PATH = '../test_data/setswana-dict/setswana.dict'
    TSN_TEST_DICT_PATH = '../test_data/setswana-dict/setswana.shuf.1024.dict'
    TSN_TRAIN_DICT_PATH = '../test_data/setswana-dict/setswana.shuf.3988.dict'

    def run_regression(self, g2p, dict_words, test_words, unittest_assert=True, show_results=True):
        """
        Run regression test and report results.
        @param g2p: G2P object
        @type g2p: C{G2P}
        @param dict_words: Dictionary word list
        @type dict_words: C{List} of C{Word}
        @param test_words: Test word list
        @type test_words: C{List} of C{str}
        @param unittest_assert: If True, Unittest assert failure unless 100% accuracy.  
                                Otherwise, skip Unittest assert and continue running.
        @type unittest_assert: C{bool}
        """
        log = Application().get_log()
        failed_count = 0
        for t_word in test_words:
            for d_word in dict_words:
                if t_word == d_word.get_text():
                    result_str = "OKAY"
                    graphs = d_word.get_graphemes()
                    phones = d_word.get_phonemes()
                    pred_phones = g2p.predict_pronunciation(t_word)
                    if phones != pred_phones:
                        failed_count += 1
                        log.error('Prediction failed for "%s" : "%s" != "%s"' \
                                  %(t_word, ' '.join(phones), ' '.join(pred_phones)))
        word_count = len(test_words)
        correct_count = word_count - failed_count
        if show_results:
            log.info("Test results: [%d/%d] %d%% correct" \
                     %(word_count, correct_count, (float(correct_count) / float(word_count)) * 100))
        if unittest_assert:
            self.assertEquals(correct_count, word_count)
        return correct_count

    def test_set_dictionary(self):
        """
        Test word set/get.
        """
        log = Application().get_log()
        log.info("G2PTestCase.test_set_dictionary()")
        words = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        g2p = G2P()
        g2p.set_dictionary(words)
        words2 = g2p.get_dictionary()[:]
        self.assertEquals(len(words), len(words2), \
                          'set_dictionary()/get_dictionary() length failure.')
        for w in words:
           if w not in words2:
               self.fail('set_dictionary()/get_dictionary indexing failure.')

    def test_pickling(self):
        """
        Test g2p data reading and writing.
        """
        log = Application().get_log()
        log.info("G2PTestCase.test_pickling()")
        SAVE_FILE = "../test_data/tsn.g2p"
        g2p_to_file = G2P()
        dict_words = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        g2p_to_file.set_dictionary(copy.deepcopy(dict_words))
        g2p_to_file.update_rules()
        pickle.dump(g2p_to_file, open(SAVE_FILE, 'wb'))
        g2p_from_file = pickle.load( open(SAVE_FILE) )
        test_words = []
        for w in dict_words[:20]:
            test_words.append(w.get_text())
        test_count = len(test_words)
        correct_count = \
            self.run_regression(g2p_from_file, dict_words, test_words, unittest_assert=False)
        # TODO: "correct_count" below should equal "test_count"
        self.assertTrue(correct_count >= 1)

    def test_setswana(self):
        """
        Test with Setswana data set.
        """
        log = Application().get_log()
        log.info("G2PTestCase.test_setswana()")
        all_dict = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        train_dict = DictionaryFile().from_file(self.TSN_TRAIN_DICT_PATH)
        test_dict = DictionaryFile().from_file(self.TSN_TEST_DICT_PATH)
        g2p = G2P()
        g2p.set_dictionary(copy.deepcopy(train_dict))
        g2p.update_rules()
        # Predict train set words
        test_words = []
        for w in train_dict:
            test_words.append(w.get_text())
        train_count = len(test_words)
        train_correct = self.run_regression(g2p, all_dict, test_words, unittest_assert=False, 
                                            show_results=False)
        # Predict test set words
        test_words = []
        for w in test_dict:
            test_words.append(w.get_text())
        test_count = len(test_words)
        correct = self.run_regression(g2p, all_dict, test_words, unittest_assert=False, 
                                      show_results=False)
        log.info("Train set results: [%d/%d] %d%% correct" \
                 %(train_count, train_correct, (float(train_correct) / float(train_count)) * 100))
        log.info("Test set results: [%d/%d] %d%% correct" \
                 %(test_count, correct, (float(correct) / float(test_count)) * 100))
        # TODO: "correct_count" should equal the "test_count"
        self.assertTrue(correct > 1)

    def test_abort(self):
        """
        Test cancelling rule update.
        """
        abort_delay = 5
        log = Application().get_log()
        log.info("G2PTestCase.test_abort()")
        setswana_dict = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        g2p = G2P()
        g2p.set_dictionary(copy.deepcopy(setswana_dict))
        g2p.update_rules_async(setswana_dict)
        log.info('Pausing %d second before aborting rule rebuilding' %abort_delay)
        sleep(abort_delay)
        log.info('Aborting rule rebuilding')
        g2p.abort_update_rules_async()
        while g2p.poll_update_rules_async():
            log.info("Waiting while rules are updated...")
            sleep(1)

    def test_update_rules_async(self):
        """
        Tests asynchronous rule updating by doing the following:
            1. Update rules synchronously
            2. Test pronunciation prediction
            3. Start asynchronous rule update with expanded dictionary
            4. While update is being processed, test first word list pronunciation predictions
            5. When update is complete, test second word list pronunciation prediction.
        """
        log = Application().get_log()
        log.info("G2PTestCase.test_update_rules_async()")
        g2p = G2P()
        # Synchronous test
        dict_words = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        test_words = []
        for w in dict_words[:20]:
            test_words.append(w.get_text())
        test_count = len(test_words)
        g2p.set_dictionary(copy.deepcopy(dict_words))
        g2p.update_rules()
        correct_count = self.run_regression(g2p, dict_words, test_words, unittest_assert=False)
        # TODO: "correct_count" below should be 100%
        self.assertTrue(correct_count > 1)
        log.info('Adding words words and conducting "in-place" asynchronous update_rules test')
        dict_words_async = DictionaryFile().from_file(self.TSN_FULL_DICT_PATH)
        async_test_words = []
        for w in dict_words[20:40]:
            async_test_words.append(w.get_text())
        dict_words.extend(dict_words_async)
        g2p.update_rules_async(dict_words_async)
        while g2p.poll_update_rules_async():
            log.info("Waiting while rules are updated...")
            # Verify G2P still callable and correct.
            correct_count = self.run_regression(g2p, dict_words, test_words, unittest_assert=False)
            # TODO: "correct_count" below should be 100%
            self.assertTrue(correct_count > 1)
            sleep(1)
        # Testing with new rules
        correct_count = self.run_regression(g2p, dict_words_async, async_test_words, 
                                            unittest_assert=False)
        # TODO: "correct_count" below should equal "test_count"
        self.assertTrue(correct_count > 1)

if __name__ == "__main__":
    suite = unittest.TestSuite()
    suite.addTest(G2PTestCase('test_set_dictionary'))
    suite.addTest(G2PTestCase('test_pickling'))
    suite.addTest(G2PTestCase('test_update_rules_async'))
    suite.addTest(G2PTestCase('test_setswana'))
    suite.addTest(G2PTestCase('test_abort'))
    result = unittest.TextTestRunner().run(suite)
    if not result.wasSuccessful():
        sys.exit(1)
    sys.exit(0)
