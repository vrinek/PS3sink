root = "/Users/vrinek/Movies/film/"
filename = `ls #{root}`.split(/\n/).select{|f| f =~ /mkv$/}[0]
file = (root + filename)


raise 'Could not find mkvinfo executable' unless system("which mkvinfo")

INFO = {
  :number => /Track number/,
  :type => /Track type/,
  :codec => /Codec ID/,
  :duration => /Default duration/,
  :language => /Language/,
  :width => /Pixel width/,
  :height => /Pixel height/,
  :sampling => /Sampling frequency/,
  :channels => /Channels/
}

tracks = `mkvinfo #{file.gsub(/ /, '\\ ')}`.split(/\n/).reject{|l| l =~ /^\|?\+/}.collect{|l| l.gsub(/^\| +\+ ?/, '')}.join("\n").split(/A track/)

tracks = tracks.slice(1, tracks.length)

@tracks = []
for t in tracks
  track = {}
  t = t.split(/\n/)
  
  INFO.keys.each{|k|
    add = t.select{|d| d =~ INFO[k]}[0]
    track[k] = add.scan(/.+?: ?(.+?)$/).to_s if add
  }
  
  track[:fps] = track[:duration].scan(/\((\d+\.\d+) fps/).flatten[0] if track[:duration]

  @tracks << track
end

@tracks.each{|t| puts t.inspect}
