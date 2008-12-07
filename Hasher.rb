#Credit for origional generate_hash function goes to 
#http://blog.arctus.co.uk/articles/2007/09/17/compatible-md5-sha-1-file-hashes-in-ruby-java-and-net-c/
#Adapted to be slightly verbose, and to use a cache, with the option of bypassing the cache.
require 'digest/sha1'	
$HashCache||={}
def hash_file(file_path_and_name, bypassCache=nil) #Was generate_hash
	return $HashCache[file_path_and_name] if $HashCache.has_key?(file_path_and_name) unless bypassCache
  hash_func = Digest::SHA1.new # SHA1 or MD5
	print "\nHashing a file "
	sofar=0	
	size=File.size(file_path_and_name)
	current=size/50
  open(file_path_and_name, "rb") do |io|
    while (!io.eof)
            readBuf = io.readpartial(1024)
						sofar=sofar+1024
						print '.' if sofar > current
						current=current+size/50 if sofar > current
            hash_func.update(readBuf)
    end
  end
	
  digest=hash_func.hexdigest
	puts "100%  =>  #{digest}"
	$HashCache.merge!( file_path_and_name => digest ) unless bypassCache
	return digest
end

#Generate a hash of the path to a file for the purpose of MySQL lookup
def hash_filename path
	hash_func = Digest::SHA1.new # SHA1 or MD5
	hash_func.update(path)
	return hash_func.hexdigest
end


