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
import logging

class Log:

    """
    Log class.
    """
    def __init__(self, name, log_file_path=None, level=logging.DEBUG, append=True, console=True):
        """
        Initialize log.
        
        @param name : Logger identifier
        @type name: C{string}
        @param log_file_path : Filename for log
        @type log_file_path:C{string}
        @param level : Logging level of detail
        @type level: C{int}
        @param append: if True open log file in append mode, otherwise truncate.
        @type append: bool
        """        
        fmt = "%(asctime)s [%(levelname)s] %(message)s"
        self.__log = logging.getLogger(name)
        formatter = logging.Formatter(fmt)
        if log_file_path != None:
            if append:
                mode = 'a'
            else:
                mode = 'w'
            ofs = logging.FileHandler(log_file_path, mode)
            ofs.setFormatter(formatter)
            self.__log.addHandler(ofs)
        if console:
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(formatter)
            self.__log.addHandler(console_handler)
        self.__log.setLevel(level)
    
    def free(self):
        """
        Close log for writing.
        """
        ofs = self.__log.handlers[0]
        ofs.flush()
        ofs.close()
        self.__log.removeHandler(ofs)
        self.__log = None        
        
    def get_log(self):
        """
        Return the logging object.
        @return: log
        @rtype: logger
        """
        return self.__log

            
class LogTestCase(unittest.TestCase):
    """
    Test case for the Dictionary object.
    """
    DEBUG_STR = 'This is a debug message'
    INFO_STR = 'This is an info message'
    WARNING_STR = 'This is an warning message'
    ERROR_STR = 'This is an error message'
    CRITICAL_STR = 'This is a critical error message'
    
    def test_log(self):
        """
        Test log file writing.
        """      
        log = Log("Test Log", "test.log", append=False)
        log.get_log().debug(self.DEBUG_STR)
        log.get_log().info(self.INFO_STR)
        log.get_log().warning(self.WARNING_STR)
        log.get_log().error(self.ERROR_STR)
        log.get_log().critical(self.CRITICAL_STR)
        log.free()
        log_file = open('test.log', 'r')
        ( head, msg ) = log_file.readline().rstrip().split('] ')        
        self.assertEquals( msg, self.DEBUG_STR )
        ( head, msg ) = log_file.readline().rstrip().split('] ')        
        self.assertEquals( msg, self.INFO_STR )
        ( head, msg ) = log_file.readline().rstrip().split('] ')        
        self.assertEquals( msg, self.WARNING_STR )
        ( head, msg ) = log_file.readline().rstrip().split('] ')        
        self.assertEquals( msg, self.ERROR_STR )
        ( head, msg ) = log_file.readline().rstrip().split('] ')        
        self.assertEquals( msg, self.CRITICAL_STR )
        self.assertEquals( log_file.readline(), '' )
        

if __name__ == '__main__':
    unittest.main()
