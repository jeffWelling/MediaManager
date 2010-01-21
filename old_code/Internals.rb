module MediaManager
	module Internals
		extend RetrieveMeta
		def self._fuzzyMatch(str1, str2, verbose=:no)
			fuzzyMatch(str1, str2, verbose)
		end
	end
end
