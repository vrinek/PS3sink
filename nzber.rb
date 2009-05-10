class Nzber
  require 'rubygems'
  require 'xml'

  def sum(array)
    sum = 0
    array.each{ |i|
      sum += i.to_i
    }
  
    return sum
  end
  
  def initialize(path)
    @path = path
    @file = @path.split(/\//).last
    @root = @path.gsub(@file, '')
  end
  
  def automagick
    nzb = XML::Document.file(@path)
    files = {}

    nzb.root.children.select{ |c|
      c.name == 'file'
    }.each{ |f|
      files[f.attributes["subject"].scan(/"(.*?)"/)[0][0]] = sum(f.children.select{ |c|
        c.name == 'segments'
      }[0].children.collect{ |c|
        c.attributes["bytes"].to_i
      })
    }

    status = files.keys.collect{|k|
      File.size(@root+k) == files[k]
    }.uniq

    unless status.include?(false)
      puts 'NZB seems to have finished downloading'
      return true
    else
      puts 'NZB is still downloading...'
      return false
    end
  end
end
