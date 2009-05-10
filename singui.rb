require 'ps3sink.rb'

FOLDERS_TO_SCAN = %w(~/Movies ~/Downloads)

Shoes.app :width => 480, :height => 400 do
  def list
    unless @mkvs
      files = {}
      for folder in FOLDERS_TO_SCAN
        `ls -R #{folder}`.split(/\n{2}/).each{ |d|
          files[d.split(/\n/).first] = d.split(/\n/).select{ |f|
            f =~ /mkv$/
          }
        }
      end

      @mkvs = {}
      files.keys.reject{ |k|
        files[k].empty?
      }.each{ |k|
        @mkvs[k] = files[k]
      }
    end

    return @mkvs
  end

  stack do
    title "List of mkvs:"
    list.keys.each { |key|
      caption key
      list[key].each { |mkv|
        flow do
          background '#fda'..'#dc9'
          para mkv
          button "MKV -> MP4 (ps3)", :right => 0 do
            proposed_name = mkv.split(/\//).last.gsub(/\.mkv$/, '').gsub(/\.?(720p|1080p).*?$/i, '').gsub(/\./, ' ').gsub(/(s\d{2}e\d{2}|\d{4})/i, '- \\1').capitalize
            new_name = ask "Name of the MP4? (will use '#{proposed_name}' if empty)"
            new_name = proposed_name if new_name.strip == ''

            ps = Ps3sink.new(key.gsub(/:$/, '/')+mkv, new_name)
            ps.automagick
          end
        end
      }
    }
  end
end
