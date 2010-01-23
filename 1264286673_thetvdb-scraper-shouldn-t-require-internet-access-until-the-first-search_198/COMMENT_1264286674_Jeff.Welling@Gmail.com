Currently, Thetvdb tries to initialize when it is loaded.  This should be changed so that it doesn't try to initialize until the first search is performed. 
