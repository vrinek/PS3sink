root = "/Users/vrinek/Movies/film/"
filename = `ls #{root}`.split(/\n/).select{|f| f =~ /mkv$/}[0]
file = (root + filename)


raise 'Could not find mkvextract executable' unless system("which mkvextract")

