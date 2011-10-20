class NotSupported < Exception; end

FN=%w(alu1 alu2 alu3 alu4 5xp1 9sym apex2 apex4 apex5 bw rd53 rd73 Modulo\ 10\ Counter)
require 'rubygems'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'ruby-debug'

Bundler.require(:default) if defined?(Bundler)

def get(path)
  url = URI.parse('http://revlib.org/' + path)
  res = Net::HTTP.start(url.host, url.port) {|http|
      http.get('/' + path)
  }

  raise "Not a successful endevor" unless res.code == '200'
  Nokogiri::HTML res.body
end

def details(node)
  # Get information about function from the site.
  f = get(node['href'])
  tds = f.css('table table table table table tr:last td')
  raise NotSupported if tds[0].content != 'MCT'

  print node.content + ": "
  print "Library: %s, " % tds[0].content
  print "Lines: %s, " % tds[1].content
  print "Gates: %s, " % tds[2].content
  print "Costs: %s, " % tds[3].content


  # Now get the actual function
  link = tds.css('a')
  f = get(link[0]['href'])
  content = f.css('body p')[0].content
  content.each_line do |line|
    if line =~ /\.variables(.*)/
      @variables = $1.split(' ').map(&:strip)
    end
  end

  raise 'No variables found !!!' if @variables.nil?

  y = content.gsub("\n", ",").match(/.begin(.*).end/)
  y[1].split(',')
end


def distance(q)
  q1 = @variables.index( q[0] )
  q2 = @variables.index( q[1] )
  (q2 - q1).abs - 1
end

def fences(terms)
  count = terms[0][1..-1].to_i - 1
  (1..count).inject(0) do |r,e|
#p [r, e]
#    p terms[e-1..e]
    r+= distance(terms[e..e+1])
  end
end

def distances(gates)
  dist = 0
  gates.each_with_index do |gate, index|
    next if gate.empty?
    terms = gate.split(' ')
    dist += case(terms[0])
      when /^t\d/ then fences(terms)
      else
        raise "We don't know you: index (%d) %s" % [index, gate]
    end
  end
  dist
end

class Fixnum
  def commify
    self.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end
end

@functions  = get('functions.php')

@functions.css('table table table tr td:nth-child(2) a').each do |node|
  begin
    gates = details(node)
    swaps = 2 * distances(gates)
    print "#Swap: %s, " % swaps.commify
    p "QC:: %s" % (3 * swaps).commify
  rescue NotSupported => e
    p "Only MCT functions supported"
  rescue Exception => e
    p "Skipping function" + e.message
  end
end

