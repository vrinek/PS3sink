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
  
  def initialize(root)
    @root = root.gsub(/([^\/])$/, '\\1/')
    filename = `ls '#{@root}'`.split(/\n/).select{|f| f =~ /mkv$/}.reject{|f| f =~ /#{SPLIT}.\d+\.mkv/}[0]
    puts @file = (@root + filename)
  end
  
  def check_for_programs
    for prog in %w(ffmpeg mkvmerge mkvextract mkvinfo)
      raise "Could not find #{prog} executable" unless system("which #{prog}")
    end
    
    raise 'Could not find mp4box or mp4creator' unless system('which mp4box') or system('mp4creator')
  end
  
  def mkvinfo(file = @file)
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
  
  def video_track
    @tracks.select{|t| t[:type] == 'video'}[0]
  end
  
  def split(file = @file)
    if (size = File.size(file)) > FOUR_GB
      unless (splits = ls(/#{SPLIT}.\d+\.mkv/)).empty?
        puts 'Found splits, checking size...'
        sum = 0
        splits.each{|s| sum += File.size(@root + s)}
        
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
        return true
      end
    else
      puts 'Filesize less than 4GB. No need to split'
      return false
    end
  end

  def get_audio(file = @file)
    cmd = "ffmpeg -i '#{file}' -vn -ac 2 -acodec libfaac -ab 128k -threads 2 '#{@root}audio.aac'"
    system cmd
  end
  
  def get_video(file = @file)
    cmd = "mkvextract tracks '#{file}' #{video_track[:number]}:'#{@root}video.h264'"
    system cmd
  end
  
  def correct_video_profile
    puts 'Correcting the video profile...'
    v = File.open(@root+'video.h264', 'r+')
    v.seek 7
    v.putc 0x29
    v.close
  end
  
  def mux_mp4
    if system("which mp4box")
      puts 'Creating mp4 using mp4box...'
      cmd = "mp4box -add '#{@root}video.h264' -add '#{@root}audio.aac' -fps #{video_track[:fps]} -hint '#{@root}file.mp4'"
      system cmd
    elsif system("which mp4creator")
      puts 'Adding the video to the mp4...'
      cmd = "mp4creator -create='#{@root}video.h264' -rate=#{video_track[:fps]} '#{@root}file.mp4'"
      system cmd

      puts 'Hinting the mp4...'
      cmd = "mp4creator -hint=1 '#{@root}file.mp4'"
      system cmd

      puts 'Adding the audio, interleaving and optimising...'
      cmd = "mp4creator -c '#{@root}audio.aac' -interleave -optimize '#{@root}file.mp4'"
      system cmd
    end
  end
  
  def rename_mp4(file = nil)
    puts (new_name = @root.split(/\//).last.gsub(/ +NZB$/, '').gsub(/\.?(720p|1080p).*?$/i, '').gsub(/\./, ' ').gsub(/(s\d{2}e\d{2}|\d{4})/i, '- \\1')).inspect
    
    if file =~ /#{SPLIT}/
      new_name += '-' + file.scan(/#{SPLIT}.(\d+)/).to_s
    end
    
    cmd = "mv '#{@root}file.mp4' '#{@root+new_name}.mp4'"
    system cmd
  end
  
  def automagick
    check_for_programs unless DEBUG
    
    mkvinfo
    puts @tracks.inspect
    
    if split
      puts @files = ls(/#{SPLIT}.\d+\.mkv$/).collect{|f| @root + f}
    else
      @files = [@file]
    end
    
    @files.each{ |file|
      get_audio file
      get_video file
      correct_video_profile
      mux_mp4
      cleanup :audio
      cleanup :video
      rename_mp4(file)
    }
    
    cleanup :mkv
    cleanup :splits
  end
  
  def ls(select = nil, reject = nil)
    ls = `ls '#{@root}'`.split(/\n/)
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
      puts 'Trashing the original MKV...'
      trash ls(/\.mkv$/, split_regexp)
    when :audio
      puts 'Trashing the extracted audio'
      trash ls(/^audio\.(aac|m4a)$/)
    when :video
      puts 'Trashing the extracted video'
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
      cmd = "mv '#{@root+file}' ~/.Trash/"
      system cmd
    }
  end
  
  if DEBUG
    def system(command)
      puts command
    end
  end
end

# ROOT = "/Users/vrinek/Downloads/How.I.Met.Your.Mother.S04E22.720p.HDTV.X264-DIMENSION  NZB/"
ROOT = "/Users/vrinek/Movies/ps3"

ps = Ps3sink.new ROOT
ps.automagick
