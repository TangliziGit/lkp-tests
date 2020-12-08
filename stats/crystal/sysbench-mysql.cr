#!/usr/bin/env crystal

# SQL statistics:
#    queries performed:
#        read:                    210212086
#        write:                   60060591
#        other:                   30030296
#        total:                   300302973
#    transactions:                15015147 (25024.26 per sec.)
#    queries:                     300302973 (500485.16 per sec.)
#    ignored errors:              2      (0.00 per sec.)
#    reconnects:0                 (0.00 per sec.)

while (line = STDIN.gets)
  next unless line =~ /transactions:.*\(\s*(\S+)/

  puts "transactions: #{$1}"
end
