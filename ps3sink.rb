class Ps3sink
  DEBUG = false
  
  SPLIT = '-split'
  
  FOUR_GB = 1024**3*4 # file limit of non 64bit filesystems
  
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
  
  ROOT = "/Users/vrinek/Movies/film/"
  FILENAME = `ls '#{ROOT}'`.split(/\n/).select{|f| f =~ /mkv$/}.reject{|f| f =~ /#{SPLIT}.\d+\.mkv/}[0]
  FILE = (ROOT + FILENAME)
  
  def check_for_programs
    for prog in %w(ffmpeg mkvmerge mkvextract mkvinfo)
      raise "Could not find #{prog} executable" unless system("which #{prog}")
    end
  end
  
  def mkvinfo(file = FILE)
    cmd = "mkvinfo '#{file}'"
    tracks = `#{cmd}`.split(/\n/).reject{ |l|
      l =~ /^\|?\+/
    }.collect{ |l|
      l.gsub(/^\| +\+ ?/, '')
    }.join("\n").split(/A track/)

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
    
    puts 'Got info from mkv'
  end
  
  def split(file = FILE)
    if (size = File.size(file)) > FOUR_GB
      unless (splits = ls(/#{SPLIT}.\d+\.mkv/)).empty?
        puts 'Found splits, checking size...'
        sum = 0
        splits.each{|s| sum += File.size(ROOT + s)}
        
        if sum < size
          puts 'Total filesize does not match, need to split again'
          do_split = true
          cleanup :splits
        end
      else
        do_split = true
      end
      
      if do_split
        chunks = (size/FOUR_GB.to_f).ceil
        chunk_size = (size/chunks.to_f).ceil
        raise 'Could not calculate chunk sizes for split' unless chunk_size * chunks >= size
        megs = (chunk_size/(1024**2).to_f).ceil

        cmd = "mkvmerge -o '#{file.gsub(/\.mkv$/, "#{SPLIT}.mkv")}' --split #{megs}M '#{file}'"
        system cmd
      else
        puts 'File is already split'
      end
    else
      puts 'Filesize less than 4GB. No need to split'
      return false
    end
  end

  def get_audio(file = FILE)
    cmd = "ffmpeg -i '#{file}' -vn -ac 2 -acodec libfaac -ab 128k '#{ROOT}audio.aac'"
    system cmd
  end
  
  def automagick
    mkvinfo
    if split
      puts @files = ls(/#{SPLIT}.\d+\.mkv$/)
    else
      @files = [FILE]
    end
  end
  
  def ls(select = nil, reject = nil)
    ls = `ls '#{ROOT}'`.split(/\n/)
    ls = ls.select{|f| f =~ select} if select
    ls = ls.reject{|f| f =~ reject} if reject
    return ls
  end
  
  def cleanup(which = :all)
    split_regexp = /#{SPLIT}.\d+\.mkv$/
    case which
    when :splits
      puts 'Trashing the splits...'
      trash ls(split_regexp)
    when :mkv
      trash ls(/\.mkv$/, split_regexp)
    when :audio
      trash ls(/^audio\.(aac|m4a)$/)
    when :video
      trash ls(/^video\.h264$/)
    when :all
      cleanup :splits
      cleanup :mkv
      cleanup :audio
      cleanup :video
    end
  end
  
  def trash(array_or_filename)
    [array_or_filename].flatten.each{ |file|
      cmd = "mv '#{ROOT}#{file}' ~/.Trash/"
      system cmd
    }
  end
  
  if DEBUG
    def system(command)
      puts command
    end
  end
end

ps = Ps3sink.new
ps.automagick
