#! /usr/bin/ruby
require '/Users/vrinek/Code/ps3sink/ps3sink.rb'
require '/Users/vrinek/Code/ps3sink/nzber.rb'

DEBUG = false
FOLDERS_TO_SCAN = %w(~/Downloads)
ALWAYS_REJECT_SAMPLES = true
IGNORE_SPLITS = false

def possible_landings
  lsr(
    FOLDERS_TO_SCAN,
    /\.(mkv|rar|par2|sfv|nzb)$/,
    /(vol\d+\+\d+\.par2|part(?!0+1[^\d])\d+\.rar)/
  ).delete_if{ |k,v|
    v.empty?
  }
end

def folder_seems_to_have_finished_downloading
  most_files_from_nzb_are_here
end

def folder_is_not_moving
  before = File.mtime(@folder)
  if before >= Time.now - 60
    sleep 2
    after = File.mtime(@folder)

    return before == after
  else
    return true
  end
end

def most_files_from_nzb_are_here(threshold = 0.05)
  unless nzb_of_folder
    puts "can't find nzb :("
    return true
  end
  
  result = Nzber.new(nzb_of_folder).get_files_from_nzb.keys.reject{ |f|
    f =~ /\.par2$/
  }.collect{ |f|
    if File.exist?(@folder + f)
      true
    else
      puts "#{f} is missing..."
      false
    end
  }
  
  bad = result.reject{|r| r}.length
  
  if bad > threshold*(result.length)
    return false
  else
    return true
  end
end

def nzb_of_folder
  folder_has :nzb
end

def par2_of_folder
  folder_has :par2
end

def rar_of_folder
  folder_has :rar
end

def mkv_of_folder
  folder_has :mkv
end

def make_a_parity_check
  puts 'Doing a parity check (and repair if needed)...'
  if system("par2repair -q -q '#{par2_of_folder}'")
    cleanup :par2
  else
    raise 'Parity repair failed'
  end
end

def unrar
  puts 'Unraring the stuff...'
  if system("unrar e -inul '#{rar_of_folder}' '#{File.dirname rar_of_folder}'")
    cleanup :rar
  else
    raise 'Could not unrar the archive'
  end
end

def process_the_mkv
  Ps3sink.new(mkv_of_folder).automagick
end

def folder_has(that)
  case that
  when :par2
    return ls(/\.par2$/, /vol\d+\+\d+\.par2$/)[0]
  when :rar
    return ls(/\.rar$/, /part(?!0+1[^\d])\d+\.rar$/)[0]
  else
    return ls(/\.#{that.to_s}$/)[0]
  end
end

def folder_has_more
  folder_has(:par2) or folder_has(:rar) or folder_has(:mkv)
end

def procedure
  possible_landings.each do |@folder, @files|
    begin
      show_label_for_folder
      if folder_has(:mkv) or folder_seems_to_have_finished_downloading
        puts "Let's get this party started"
      
        while folder_has_more
          make_a_parity_check if folder_has(:par2)
          unrar if folder_has(:rar)
          process_the_mkv if folder_has(:mkv)
        end
      else
        puts "Time to turn off the lights"
      end
    rescue
      puts "Something went wrong"
    end
  end
end

def show_label_for_folder(width = 100)
  puts "\n"*2
  puts "+" + "-"*width + "+"
  puts "|" + @folder.center(width) + "|"
  puts "+" + "-"*width + "+"
end

def lsr(where, select = nil, reject = nil)
  findings = {}
  
  for root in [where].flatten
    root.gsub!(/^~/, `echo ~`.strip)
    subfolders = `ls -R '#{root}'`.split(/\n{2}/)
    subfolders[0] = root.gsub(/\/$/, '') + ":\n" + subfolders[0]
    
    for subfolder in subfolders
      subfolder = subfolder.split(/\n/)
      
      for file in subfolder
        if file == subfolder.first
          findings[key = file.gsub(/:$/, '/').gsub(/\/+/, '/')] = []
        else
          findings[key] << file
        end
      end
      
      if select
        findings[key] = findings[key].select{ |f|
          if select.is_a?(Regexp)
            f =~ Regexp.new(select.source, true)
          elsif select.is_a?(String)
            f =~ select
          end
        }
      end
      
      if reject
        findings[key] = findings[key].reject{ |f|
          if reject.is_a?(Regexp)
            f =~ Regexp.new(reject.source, true)
          elsif reject.is_a?(String)
            f =~ reject
          end
        }
      end
  
      if ALWAYS_REJECT_SAMPLES
        findings[key] = findings[key].reject{ |f|
          f =~ /sample/
        }
      end
  
      if IGNORE_SPLITS
        findings[key] = findings[key].reject{ |f|
          f =~ /#{Ps3sink::SPLIT}.?\d+\.mkv/
        }
      end
    end
  end
  
  return findings
end

def ls(select = nil, reject = nil, root = nil)
  findings = []
  root ||= (@folder or @root).clone
  
  root.gsub!(/^~/, `echo ~`.strip)
  files = `ls '#{root}'`.split(/\n/)

  for file in files
    findings << root + file
  end

  if select
    findings = findings.select{ |f|
      if select.is_a?(Regexp)
        f =~ Regexp.new(select.source, true)
      elsif select.is_a?(String)
        f =~ select
      end
    }
  end

  if reject
    findings = findings.reject{ |f|
      if reject.is_a?(Regexp)
        f =~ Regexp.new(reject.source, true)
      elsif reject.is_a?(String)
        f =~ reject
      end
    }
  end
  
  if ALWAYS_REJECT_SAMPLES
    findings = findings.reject{ |f|
        f =~ /sample/
    }
  end

  if IGNORE_SPLITS
    findings = findings.reject{ |f|
      f =~ /#{Ps3sink::SPLIT}.?\d+\.mkv/
    }
  end
  
  return findings
end

def cleanup(which = :all)
  split_regexp = /#{Ps3sink::SPLIT}.\d+\.mkv$/
  
  case which
  when :par2
    puts 'Trashing parity files...'
    trash ls(/#{par2_of_folder.gsub(/\.par2$/, '')}.*?par2$/), true
  when :sfv
    puts 'Trashing SFV file...'
    trash ls(/sfv$/), true
  when :rar
    puts 'Trashing RAR archives...'
    trash ls(/#{rar_of_folder.gsub(/.?(part\d+)?\.rar/, '')}.*?r(ar|\d{2})$/), true
  when :splits
    puts 'Trashing the splits...'
    trash ls(split_regexp, nil, Ps3sink::TMP), true
  when :mkv
    puts 'Trashing the original MKV...'
    trash @file
  when :audio
    puts 'Trashing the extracted audio'
    trash ls(/^audio\.(aac|m4a|dts|temp\.wav)$/, nil, Ps3sink::TMP), true
  when :video
    puts 'Trashing the extracted video'
    trash ls(/^video\.h264$/, nil, Ps3sink::TMP), true
  when :all
    cleanup :splits
    cleanup :mkv
    cleanup :audio
    cleanup :video
  end
end

def trash(array_or_filename, rm = false)
  [array_or_filename].flatten.each{ |file|
    file = @folder + file unless file =~ /^\//
    if rm and !DEBUG
      cmd = "rm -f '#{file}'"
    else
      cmd = "mv '#{file}' ~/.Trash/"
    end
    system cmd
  }
end

procedure
