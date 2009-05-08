root = "/Users/vrinek/Movies/film/"
filename = `ls #{root}`.split(/\n/).select{|f| f =~ /mkv$/}[0]
file = (root + filename)


raise 'Could not find ffmpeg executable' unless system("which ffmpeg")

puts cmd = "ffmpeg -i #{file.gsub(/ /, '\\ ')} -vn -ac 2 -acodec libfaac -ab 128k #{root}audio.aac"
system cmd