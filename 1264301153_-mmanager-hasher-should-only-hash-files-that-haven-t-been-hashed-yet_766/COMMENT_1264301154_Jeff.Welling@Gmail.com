Currently it hashes every imported file, this should be changed so that it excludes each path that has already been hashed.
