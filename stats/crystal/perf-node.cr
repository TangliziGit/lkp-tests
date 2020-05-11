#!/usr/bin/env crystal

sum = {"node-loads" => 0, "node-load-misses" => 0, "node-stores" => 0, "node-store-misses" => 0}
STDIN.each_line do |line|
  _time, value, key = line.split
  next unless value =~ /^\d+$/

  sum[key] += value.to_i
end

node_local_load_ratio = if (sum["node-loads"] + sum["node-load-misses"]).nonzero?
                          (100 * sum["node-loads"]) / (sum["node-loads"] + sum["node-load-misses"])
                        else
                          -1
                        end

node_local_store_ratio = if (sum["node-stores"] + sum["node-store-misses"]).nonzero?
                           (100 * sum["node-stores"]) / (sum["node-stores"] + sum["node-store-misses"])
                         else
                           -1
                         end

puts "node-loads: #{sum["node-loads"]}"
puts "node-load-misses: #{sum["node-load-misses"]}"
puts "node-stores: #{sum["node-stores"]}"
puts "node-store-misses: #{sum["node-store-misses"]}"
puts "node-local-load-ratio: #{node_local_load_ratio}" if node_local_load_ratio != -1
puts "node-local-store-ratio: #{node_local_store_ratio}" if node_local_store_ratio != -1
