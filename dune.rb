require 'rubygems'
require 'mechanize'

Shoes.app :width => 400, :height => 480 do
  @agent = WWW::Mechanize.new
  @agent.user_agent_alias = 'Mac Safari'

  def find(query)
    page = @agent.get("http://www.imdb.com/find?q=#{URI::escape query}")
    page.links.select{ |a|
      a.href =~ /^\/title\/tt\d+\/?$/i and a.text.length > 1
    }.reject{ |a|
      a.node.ancestors.collect{ |s|
        s.name
      }.include?("small")
    }.uniq
  end

  stack do
    flow do
      @query = edit_line :width => 200
      button "Search" do
        find(@query.text).slice(0,10).each{ |match|
          page = @agent.click(match)
          img = page.search("a[name=poster] img")[0]

          @results.append do
            flow do
              image(img.attributes['src'], :height => 40) if img
              para link(page.title, :click => page.uri.to_s)
            end
          end
        }
      end
    end
    
    @results = flow
  end
end
