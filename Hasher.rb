#Credit for origional generate_hash function goes to 
#http://blog.arctus.co.uk/articles/2007/09/17/compatible-md5-sha-1-file-hashes-in-ruby-java-and-net-c/
#Adapted to be slightly verbose, and to use a cache, with the option of bypassing the cache.
require 'digest/sha1'	
def hash_file(file_path_and_name, bypassCache=nil) #Was generate_hash
	cache=''

	#Only delete files that are being processed so that the database may be consulted manually for information if thetvdb ever has problems or goes down	
	n=sqlAddUpdate("DELETE FROM FileHashCache WHERE PathSHA = '#{hash_filename file_path_and_name}' AND DateAdded < '#{DateTime.now.-(3).strftime("%Y-%m-%d %H:%M:%S")}'")
	puts "Deleted expired cache record of file's hash." if n==1
	cache=sqlSearch("SELECT * FROM FileHashCache WHERE PathSHA = '#{hash_filename file_path_and_name}'")
	unless cache.empty? or bypassCache
		puts "This file was hashed less than 3 days ago, using cached hash."
		return cache[0]['FileSHA']
	end

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
	sqlAddUpdate("INSERT INTO FileHashCache (PathSHA, FileSHA, DateAdded) VALUES ('#{hash_filename file_path_and_name}', '#{digest}', NOW())") if cache.empty?
	return digest
end

#Generate a hash of the path to a file for the purpose of MySQL lookup
def hash_filename path
	hash_func = Digest::SHA1.new # SHA1 or MD5
	hash_func.update(path)
	return hash_func.hexdigest
end


