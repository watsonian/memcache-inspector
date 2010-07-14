require 'ostruct'
require 'socket'

@options = OpenStruct.new
@options.hostname = 'localhost'
@options.port = '11211'

def memcache_do(command)
  data = ''
  sock = TCPSocket.new(@options.hostname, @options.port)
  sock.print("#{command}\r\n")
  sock.flush
  # memcached does not close the socket once it is done writing
  # the stats data.  We need to read line by line until we detect
  # the END line and then stop/close on our side.
  stats = sock.gets
  while true
    data += stats
    break if stats.strip == 'END'
    stats = sock.gets
  end
  sock.close
  data
end

def stats_items
  memcache_do("stats items")
end

def stats_cachedump(mem_location, length=100)
  memcache_do("stats cachedump #{mem_location} #{length}")
end

def get(key)
  memcache_do("get #{key}")
end

def item_mem_locations(items)
  mem_locations = []
  items.split("\r\n").each do |item|
    details = item.split(" ")
    next if details.first == 'END'
    mem_locations << details[1].split(":")[1]
  end
  mem_locations.uniq
end

def item_keys(cachedump)
  keys = []
  cachedump.split("\r\n").each do |item|
    details = item.split(" ")
    next if details.first == 'END'
    keys << details[1]
  end
  keys
end

mem_location = item_mem_locations(stats_items)

keys = []
mem_location.each do |l|
  keys += item_keys(stats_cachedump(l))
end
puts "Keys:"
keys.each_with_index do |v,i|
  puts " [#{i}] #{v}"
end