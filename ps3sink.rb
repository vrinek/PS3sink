class Ps3sink
  begin
    Shoes
    has_shoes = true
  rescue
    has_shoes = false
  end
  
  SPLIT = 'split'
  FOUR_GB = 1024**3*4 # file limit of non 64bit filesystems
  DESTINATIONS = {
    :tv => '/Users/vrinek/Movies/TV/',
    :film => '/Users/vrinek/Movies/film/'
  }
  
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
  
  def initialize(file, new_name = nil)
    @root = File.dirname(file) + '/'
    @file = file
    @new_name = new_name || propose_name
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
    
    info 'Got info from mkv'
    debug @tracks.inspect
  end
  
  def video_track
    @tracks.select{|t| t[:type] == 'video'}[0]
  end
  
  def audio_track
    @tracks.select{|t| t[:type] == 'audio'}[0]
  end
  
  def split(file = @file)
    if (size = File.size(file)) > FOUR_GB
      unless (splits = ls(/#{SPLIT}.\d+\.mkv/)).empty?
        info 'Found splits, checking size...'
        sum = 0
        splits.each{|s| sum += File.size(@root + s)}
        
        if sum < size
          info 'Total filesize does not match, need to split again'
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

        cmd = "mkvmerge -o '#{@root}#{SPLIT}.mkv' --split #{megs}M '#{file}'"
        system cmd
      else
        info 'File is already split'
        return true
      end
    else
      info 'Filesize less than 4GB. No need to split'
      return false
    end
  end

  def get_audio(file = @file)
    info 'Getting the audio track...'
    if audio_track[:codec] =~ /^A.DTS$/ # ffmpeg does not detect dts streams properly
      info 'Detected DTS audio track. Using AudialHub ffmpeg binary...'
      raise 'Could not extract audio to WAV' unless system "'/Library/Application Support/Techspansion/ah104ffmpeg' -y -i '#{file}' -ac 2 -acodec pcm_s16le '#{@root}audio.temp.wav'"
      
      raise 'Could not convert audio to AAC' unless system "ffmpeg -y -i '#{@root}audio.temp.wav' -ac 2 -acodec libfaac -ab 128k '#{@root}audio.aac'"
    else
      system "ffmpeg -i '#{file}' -vn -ac 2 -acodec libfaac -ab 128k '#{@root}audio.aac'"
    end
  end
  
  def get_video(file = @file)
    info 'Getting the video track...'
    cmd = "mkvextract tracks '#{file}' #{video_track[:number]}:'#{@root}video.h264'"
    system cmd
  end
  
  def correct_video_profile
    info 'Correcting the video profile...'
    v = File.open(@root+'video.h264', 'r+')
    v.seek 7
    v.putc 0x29
    v.close
  end
  
  def mux_mp4
    if system("which mp4box")
      info 'Creating mp4 using mp4box...'
      cmd = "mp4box -add '#{@root}video.h264' -add '#{@root}audio.aac' -fps #{video_track[:fps]} -hint '#{@root}file.mp4'"
      raise 'Could not mux MP4' unless system cmd
    elsif system("which mp4creator")
      info 'Adding the video to the mp4...'
      cmd = "mp4creator -create='#{@root}video.h264' -rate=#{video_track[:fps]} '#{@root}file.mp4'"
      system cmd

      info 'Hinting the mp4...'
      cmd = "mp4creator -hint=1 '#{@root}file.mp4'"
      system cmd

      info 'Adding the audio, interleaving and optimising...'
      cmd = "mp4creator -c '#{@root}audio.aac' -interleave -optimize '#{@root}file.mp4'"
      system cmd
    end
  end
  
  def rename_mp4(file = nil)
    if file =~ /#{SPLIT}/
      new_name = @new_name + '-' + file.scan(/#{SPLIT}.(\d+)/).to_s
    else
      new_name = @new_name
    end
    
    new_root = @root
    new_root = DESTINATIONS[:tv] if @new_name =~ /s\d{2}e\d{2}/i
    new_root = DESTINATIONS[:film] if @new_name =~ /\(\d{4}\)/
    
    system cmd = "mv '#{@root}file.mp4' '#{new_root+new_name}.mp4'"
  end
  
  def propose_name
    folder = @root.gsub(/\/$/, '').split(/\//).last
    file = @file.split(/\//).last.gsub(/\.mkv$/, '')

    if folder.length > file.length
      name = folder
    else
      name = file
    end

    name.gsub!(/(\\? )+NZB$/, '')
    name.gsub!(/\\/, '')
    name.gsub!(/^\[\d+\]-\[.*?@efnet\]-(.*?)-\[\d+_\d+\].*?$/i, '\1') # standard @efnet naming
    name.gsub!(/\\ /, ' ')
    name.gsub!(/(720p|1080p|efnet)/, '')
    name.gsub!(/\.nfo$/, '')
    name.gsub!(/([^\d])(\d{4})([^\d]).*?$/, '\1(\2)\3') if name =~ /\.\d{4}\./
    name.gsub!(/s(\d{2}).?e(\d{2}).*?$/i, ' - S\1E\2') if name =~ /s\d{2}.?e\d{2}/i
    name.gsub!(/\./, ' ')
    name.gsub!(/ +/, ' ')
    name.strip!

    return name
  end
  
  def automagick
    check_for_programs
    
    mkvinfo
    
    if split
      debug (@files = ls(/#{SPLIT}.\d+\.mkv$/).collect{|f| @root + f}).inspect
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
  
  unless has_shoes
    def info(text)
      puts text
    end

    def debug(text)
      puts text
    end
  end
end
