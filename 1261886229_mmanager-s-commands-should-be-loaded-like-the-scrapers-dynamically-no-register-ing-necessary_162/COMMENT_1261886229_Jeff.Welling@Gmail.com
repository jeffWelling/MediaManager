Instead of having to add a register 'X', 'X does this', 'x' line to Command.rb, it should scan the commands/ dir and dynamically load each file in it.  The same way that the scrapers are done.
