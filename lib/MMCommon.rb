module MediaManager
  #Functions/methods that are common to all of the MediaManager app
  module MMCommon
    autoload :Find, 'find'

    #scans a target, returning the full path of every item found, in an array
    def scan_target target
      items=[]
      Find.find(target) do |it|
        items << it
      end
      items
    end

    #returns true if str matches any of the exclusion matches
    #ar_of_excludes must be an array of regexes
    def excluded? str, ar_of_excludes
      ar_of_excludes.each {|exclude|
        return true if str.match(exclude)
      }
      false
    end

  end
end
