#!/usr/bin/ruby
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

def item_value(raw_fetch)
  raw_fetch.split("\r\n")[1][4..-1]
end

def print_separator(character="=", count=40, lines=1)
  lines.times do
    puts character*count
  end
end

def display_keys(keys)
  puts "Keys:"
  keys.each_with_index do |v,i|
    puts " [#{i}] #{v}"
  end
end

def fetch_keys(mem_locations, limit=nil)
  if limit && limit.to_i == 0
    puts "* No memory locations were fetched. Exiting..."
    exit
  end
  keys = []
  puts "Processing #{mem_locations.size} memory location(s)."
  mem_locations.each_with_index do |l,i|
    break if limit && i == limit.to_i
    puts "* fetching keys at #{l}..."
    keys += item_keys(stats_cachedump(l))
  end
  keys
end

trap(:INT) {
  puts
  puts "exiting..."
  exit
}

mem_locations = item_mem_locations(stats_items)
print "Fetch how many memory locations (#{mem_locations.size} possible)? [# or (A)ll] "
limit = gets.chomp
if limit =~ /[Aa](ll)?/
  keys = fetch_keys(mem_locations)
else
  keys = fetch_keys(mem_locations, limit)
end
# Display & Inspect keys
loop {
  trap(:INT) {
    puts
    puts "exiting..."
    exit
  }
  
  display_keys(keys)
  print "Which key do you want to inspect? "
  key_index = gets.chomp
  if key_index =~ /[0-9]+/
    key_index = key_index.to_i
    print_separator(">>")
    puts "KEY: #{keys[key_index]}"
    print_separator(">>")
    puts item_value(get(keys[key_index]))
    key_index = nil
    print_separator("<<",40,2)
  else
    puts
    puts " !! Please input one of the listed key indexes."
  end
  puts # empty line
}