#This function taken from http://rubyquiz.com/quiz22.html
#Credit to Jason Bailey
$data = [
["M" , 1000],
["CM" , 900],
["D" , 500],
["CD" , 400],
["C" , 100],
["XC" , 90],
["L" , 50],
["XL" , 40],
["X" , 10],
["IX" , 9],
["V" , 5],
["IV" , 4],
["I" , 1]
]


def toArabic(rom)
	reply = 0
	return '' if rom.nil?
	for key, value in $data
		while rom.index(key) == 0
			reply += value
			rom.slice!(key)
		end
	end
	reply
end

