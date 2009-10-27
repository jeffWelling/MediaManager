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

  end
end
