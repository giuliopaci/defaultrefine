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

import unittest, os
from log import Log

class Application:
    """
    Singleton Application class.
    """
    class __impl:
        """ 
        Implementation of the application interface
        """

        def __init__(self):
            """
            Initialize application.
            """
            if os.name == 'nt':
                # Windows sends stdout to stderr causing error dialog on close, so we disable
                # console output.
                self.__log = Log('Dictionary Maker Log', 'dictmaker.log', console=False)
            else:
                self.__log = Log('Dictionary Maker Log', 'dictmaker.log')
            self.__log.get_log().debug("Application.__init__()")
            self.__is_audio = True
            try:
                from mixer import Mixer
                self.__mixer = Mixer(self.__log.get_log())
            except ImportError:
                self.__log.get_log().warning("Mixer module not found.  Audio support disabled.")
                self.__is_audio = False
                
        def free(self):
            """
            Free application resources.
            """
            self.__log.get_log().debug("Application.free()")
            if self.__is_audio:
                self.__mixer.free()
            self.__log.free()

        def get_log(self):
            """
            Return the log.
            @return: log
            @rtype: Log
            """
            return self.__log.get_log()

        def get_mixer(self):
            """
            Return the mixer.
            @return: mixer
            @rtype: Mixer
            """
            self.__log.get_log().debug("Application.get_mixer()")
            if self.__is_audio:
                return self.__mixer
            else:
                return None


    __instance = None

    def __init__(self):
        """ 
        Create Application singleton instance
        """
        if Application.__instance is None:
            Application.__instance = Application.__impl()

        self.__dict__['_Application__instance'] = Application.__instance        

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

            
class ApplicationTestCase(unittest.TestCase):
    """
    Test case for the Dictionary object.
    """
    def test_instance(self):
        """
        Test singleton values.
        """
        app_inst = Application()
        app_inst_again = Application()
        self.assertEquals( app_inst.__dict__['_Application__instance'],
                           app_inst_again.__dict__['_Application__instance'] )
        

if __name__ == '__main__':
    unittest.main()
