root = "/Users/vrinek/Movies/film/"
filename = `ls #{root}`.split(/\n/).select{|f| f =~ /mkv$/}[0]
file = (root + filename)


raise 'Could not find mkvmerge executable' unless system("which mkvmerge")

FOUR = 1024**3*4 # just to be safe

size = File.size(file)
chunks = (size/FOUR.to_f).ceil
puts chunk_size = (size/chunks.to_f).ceil
puts chunk_size * chunks >= size
puts megs = (chunk_size/(1024**2).to_f).ceil


puts cmd = "mkvmerge -o #{file.gsub(/\.mkv$/, '-split.mkv').gsub(/ /, '\\ ')} --split #{megs}M #{file.gsub(/ /, '\\ ')}"
system cmd