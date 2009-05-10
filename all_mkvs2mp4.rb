#! /usr/bin/ruby
require '/Users/vrinek/Code/ps3sink/ps3sink.rb'
require '/Users/vrinek/Code/ps3sink/nzber.rb'

DEBUG = true
FOLDERS_TO_SCAN = %w(~/Movies ~/Downloads)

def list(force = false)
  if force or @list.nil?
    files = {}
    for folder in FOLDERS_TO_SCAN
      (lsr = `ls -R #{folder}`).split(/\n{2}/).each{ |d|
        files[d.split(/\n/).first] = d.split(/\n/).select{ |f|
          f =~ /(mkv|nzb|nfo|par2|rar)$/
        }.reject{ |f|
          f =~ /sample/i or f =~ /^split.\d+\.mkv$/
        }
      }
    end

    @list = {}
    files.keys.reject{ |k|
      files[k].empty?
    }.each{ |k|
      @list[k] = files[k] if k =~ /^\//
    }
    
    if force
      @folder = @list[@root.gsub(/\/$/, ':')].collect{ |f|
        @root + f
      }
    end
  end
  
  return @list
end

def ls(select = nil, reject = nil)
  ls = `ls '#{@root}'`.split(/\n/)
  ls = ls.select{|f| f =~ select} if select
  ls = ls.reject{|f| f =~ reject} if reject
  return ls
end

def cleanup(which = :all)
  split_regexp = /#{Ps3sink::SPLIT}.\d+\.mkv$/
  
  case which
  when :par2
    puts 'Trashing parity files...'
    trash ls(/par2$/), true
  when :sfv
    puts 'Trashing SFV file...'
    trash ls(/sfv$/), true
  when :rar
    puts 'Trashing RAR archives...'
    trash ls(/r(ar|\d{2})$/), true
  when :splits
    puts 'Trashing the splits...'
    trash ls(split_regexp), true
  when :mkv
    puts 'Trashing the original MKV...'
    trash @file
  when :audio
    puts 'Trashing the extracted audio'
    trash ls(/^audio\.(aac|m4a|dts|temp\.wav)$/), true
  when :video
    puts 'Trashing the extracted video'
    trash ls(/^video\.h264$/), true
  when :all
    cleanup :splits
    cleanup :mkv
    cleanup :audio
    cleanup :video
  end
end

def trash(array_or_filename, rm = false)
  [array_or_filename].flatten.each{ |file|
    file  = @root + file unless file =~ /^\//
    if rm and !DEBUG
      cmd = "rm -f '#{file}'"
    else
      cmd = "mv '#{file}' ~/.Trash/"
    end
    system cmd
  }
end

def nzber(nzb)
  return Nzber.new(nzb).automagick
end

def check(par_or_sfv = nil)
  puts "Checking integrity with #{par_or_sfv.split(/\//).last}..." if par_or_sfv
  
  if par_or_sfv
    case File.extname(par_or_sfv)
    when '.par2'
      if system("par2repair -q '#{par_or_sfv}'")
        cleanup :par2
        return true
      end
    when '.sfv'
      if system("cksfv -g '#{par_or_sfv}'")
        cleanup :sfv
        return true
      end
    end
  else
    puts 'WARN  - Could not verify the integrity of the files. Might end up corrupted...'
    return true
  end
end

def unrar(rar)
  puts "Unraring #{rar.split(/\//).last}..."
  if system("unrar e -inul '#{rar}' '#{File.dirname rar}'")
    cleanup :rar
    return true
  end
end

def sink(mkv)
  @folder.each{|f| puts f} if DEBUG
  
  puts "Sinking #{mkv.split(/\//).last} to MP4..."
  Ps3sink.new(mkv).automagick
end

def guess(what)
  list(true)
  
  case what
  when :par2
    return @folder.select{|f| f =~ /par2$/}.reject{|f| f =~ /vol\d+\+\d+\./i}[0]
  else
    return @folder.select{|f| f =~ /#{what.to_s}$/}[0]
  end
end

list.keys.each { |key|
  puts
  puts '#'*100
  puts '#' + key.center(98) + '#'
  puts '#'*100
  
  @root = key.gsub(/:$/, '/')
  files = {}
  
  list[key].each{ |f|
    files[File.extname(f).gsub(/^\./, '').to_sym] = @root+f
  }
  
  @folder = files.values
  
  @folder.each{|f| puts f} if DEBUG
  
  continue = true
  
  unless files[:mkv]
    continue = nzber(files[:nzb]) if files[:nzb]

    continue = check(files[:par2] || files[:sfv]) if ((files[:par2] || files[:sfv]) and continue)

    continue = unrar(files[:rar]) if (files[:rar] and continue)
  end
  
  sink(files[:mkv] || guess(:mkv)) if ((files[:mkv] || guess(:mkv)) and continue)
  
  unless continue
    puts 'ERROR - something went wrong...'
  end
}
